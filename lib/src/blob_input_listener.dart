import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'blob_controller.dart';

/// A widget that handles all multi-touch inputs, panning/drag interactions,
/// pinch-to-scale zooming, and mouse hover effects for [BlobFlutter].
///
/// It isolates gesture tracking and pointer state management from the main
/// particle rendering and lifecycle logic.
class BlobInputListener extends StatefulWidget {
  final Widget child;
  final BlobController controller;
  final ValueChanged<List<Offset>> onTouchesChanged;
  final bool hover;
  final HitTestBehavior hitTestBehavior;
  final bool interactive;

  const BlobInputListener({
    super.key,
    required this.child,
    required this.controller,
    required this.onTouchesChanged,
    this.hover = false,
    this.hitTestBehavior = HitTestBehavior.translucent,
    this.interactive = true,
  });

  /// Test hook to simulate unattached or non-RenderBox objects during mouse pointer up events.
  @visibleForTesting
  static RenderObject? Function(BuildContext context)? debugFindRenderObject;

  @override
  State<BlobInputListener> createState() => _BlobInputListenerState();
}

class _BlobInputListenerState extends State<BlobInputListener> {
  final Map<int, Offset> _touchPoints = {};
  Offset? _hoverPosition;
  double _baseScale = 1.0;

  bool get _isHoverEffective =>
      widget.hover || widget.controller.hover;

  late bool _cachedCanScale;
  late bool _cachedCanDragRotate;
  late bool _cachedhover;
  late bool _cachedhoverRotation;

  @override
  void initState() {
    super.initState();
    _cachedCanScale = widget.controller.pinchToScale;
    _cachedCanDragRotate = widget.controller.dragRotation;
    _cachedhover = widget.controller.hover;
    _cachedhoverRotation = widget.controller.hoverRotation;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final canScale = widget.controller.pinchToScale;
    final canDragRotate = widget.controller.dragRotation;
    final enableHover = widget.controller.hover;
    final enableHoverRotation = widget.controller.hoverRotation;

    if (canScale != _cachedCanScale ||
        canDragRotate != _cachedCanDragRotate ||
        enableHover != _cachedhover ||
        enableHoverRotation != _cachedhoverRotation) {
      _cachedCanScale = canScale;
      _cachedCanDragRotate = canDragRotate;
      _cachedhover = enableHover;
      _cachedhoverRotation = enableHoverRotation;
      setState(() {});
    }
  }

  void _updateTouchState(PointerEvent event, bool isDown) {
    if (!widget.interactive) return;

    final bool isMouseOrTrackpad = event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad;

    if (isDown) {
      _touchPoints[event.pointer] = event.position;
      if (isMouseOrTrackpad) {
        _hoverPosition = event.position;
      }
    } else {
      _touchPoints.remove(event.pointer);
      if (isMouseOrTrackpad) {
        final renderObject =
            BlobInputListener.debugFindRenderObject?.call(context) ??
                context.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.attached &&
            renderObject.hasSize) {
          final local = renderObject.globalToLocal(event.position);
          if (renderObject.size.contains(local)) {
            _hoverPosition = event.position;
          } else {
            _hoverPosition = null;
          }
        } else {
          _hoverPosition = event.position;
        }
      } else {
        _hoverPosition = null;
      }
    }

    _notifyTouches();
  }

  void _notifyTouches() {
    if (!widget.interactive) {
      if (_touchPoints.isNotEmpty || _hoverPosition != null) {
        _touchPoints.clear();
        _hoverPosition = null;
      }
      widget.controller.setDispersion(0.0);
      widget.onTouchesChanged(const []);
      return;
    }

    if (_touchPoints.isNotEmpty) {
      // Scale dispersion based on the number of active fingers and the tap scale factor
      widget.controller.setDispersion(
        (0.4 + 0.2 * _touchPoints.length) * widget.controller.tapScaleFactor,
      );
      widget.onTouchesChanged(_touchPoints.values.toList());
    } else if (_isHoverEffective && _hoverPosition != null) {
      // Hover interaction without clicking: disperse particles around hover cursor
      widget.controller.setDispersion(
        0.5 * widget.controller.tapScaleFactor,
      );
      widget.onTouchesChanged([_hoverPosition!]);
    } else {
      widget.controller.setDispersion(0.0);
      widget.onTouchesChanged(const []);
    }
  }

  @override
  void didUpdateWidget(BlobInputListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _cachedCanScale = widget.controller.pinchToScale;
      _cachedCanDragRotate = widget.controller.dragRotation;
      _cachedhover = widget.controller.hover;
      _cachedhoverRotation = widget.controller.hoverRotation;
    }
    if (!_isHoverEffective && _hoverPosition != null) {
      _hoverPosition = null;
      _notifyTouches();
    }
    if (!widget.interactive &&
        (_touchPoints.isNotEmpty || _hoverPosition != null)) {
      _notifyTouches();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.interactive) {
      return IgnorePointer(
        ignoring: true,
        child: widget.child,
      );
    }

    final bool canScale = widget.controller.pinchToScale;
    final bool canDragRotate = widget.controller.dragRotation;
    final bool attachScaleRecognizer = canScale || canDragRotate;

    Widget content = widget.child;
    if (attachScaleRecognizer) {
      content = GestureDetector(
        behavior: widget.hitTestBehavior,
        onScaleStart: (details) {
          _baseScale = widget.controller.scale;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount > 1 &&
              widget.controller.pinchToScale &&
              details.scale != 1.0) {
            widget.controller.setScale(_baseScale * details.scale);
          } else if (widget.controller.dragRotation) {
            // Drag / pan rotation impulse
            widget.controller.addRotationImpulse(details.focalPointDelta);
          }
        },
        child: content,
      );
    }

    return MouseRegion(
      opaque: widget.hitTestBehavior == HitTestBehavior.opaque,
      onHover: (event) {
        if (_touchPoints.isEmpty) {
          // Suppress rotation on hover unless explicitly enabled in controller
          if (widget.controller.hoverRotation &&
              event.localDelta.distanceSquared >= 2.25) {
            widget.controller.addRotationImpulse(event.localDelta * 0.3);
          }

          if (_isHoverEffective) {
            _hoverPosition = event.position;
            _notifyTouches();
          }
        }
      },
      onExit: (event) {
        if (_hoverPosition != null) {
          _hoverPosition = null;
          _notifyTouches();
        }
      },
      child: Listener(
        behavior: widget.hitTestBehavior,
        onPointerDown: (event) => _updateTouchState(event, true),
        onPointerMove: (event) => _updateTouchState(event, true),
        onPointerUp: (event) => _updateTouchState(event, false),
        onPointerCancel: (event) {
          _touchPoints.remove(event.pointer);
          _hoverPosition = null;
          _notifyTouches();
        },
        child: content,
      ),
    );
  }
}
