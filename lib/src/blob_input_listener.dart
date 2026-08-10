import 'package:flutter/material.dart';
import 'package:particle_blob/src/blob_controller.dart';

/// A widget that handles all multi-touch inputs, panning/drag interactions,
/// and mouse hover effects for the [ParticleBlob].
///
/// It isolates gesture tracking and pointer state management from the main
/// particle rendering and lifecycle logic.
class BlobInputListener extends StatefulWidget {
  final Widget child;
  final BlobController controller;
  final ValueChanged<List<Offset>> onTouchesChanged;
  final bool enableHover;

  const BlobInputListener({
    super.key,
    required this.child,
    required this.controller,
    required this.onTouchesChanged,
    this.enableHover = false,
  });

  @override
  State<BlobInputListener> createState() => _BlobInputListenerState();
}

class _BlobInputListenerState extends State<BlobInputListener> {
  final Map<int, Offset> _touchPoints = {};
  Offset? _hoverPosition;

  bool get _isHoverEffective => widget.enableHover || widget.controller.enableHover;

  void _updateTouchState(PointerEvent event, bool isDown) {
    if (isDown) {
      _touchPoints[event.pointer] = event.position; // Store global position to handle moving blobs
    } else {
      _touchPoints.remove(event.pointer);
    }

    _notifyTouches();
  }

  void _notifyTouches() {
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
    if (!_isHoverEffective && _hoverPosition != null) {
      _hoverPosition = null;
      _notifyTouches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (_touchPoints.isEmpty) {
          // Subtle auto-nudge on hover (not full drag — just orientation hint)
          widget.controller.addRotationImpulse(event.localDelta * 0.3);

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
        onPointerDown: (event) => _updateTouchState(event, true),
        onPointerMove: (event) => _updateTouchState(event, true),
        onPointerUp: (event) => _updateTouchState(event, false),
        onPointerCancel: (event) => _updateTouchState(event, false),
        child: GestureDetector(
          onPanUpdate: (details) {
            // Drag: rotation impulse with inertia
            widget.controller.addRotationImpulse(details.delta);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
