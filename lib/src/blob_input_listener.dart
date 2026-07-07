import 'package:flutter/material.dart';
import 'particle_blob_controller.dart';

// Ahmed
/// A widget that handles all multi-touch inputs, panning/drag interactions,
/// and mouse hover effects for the [ParticleBlob].
///
/// It isolates gesture tracking and pointer state management from the main
/// particle rendering and lifecycle logic.
class BlobInputListener extends StatefulWidget {
  final Widget child;
  final ParticleBlobController controller;
  final ValueChanged<List<Offset>> onTouchesChanged;

  const BlobInputListener({
    super.key,
    required this.child,
    required this.controller,
    required this.onTouchesChanged,
  });

  @override
  State<BlobInputListener> createState() => _BlobInputListenerState();
}

class _BlobInputListenerState extends State<BlobInputListener> {
  final Map<int, Offset> _touchPoints = {};

  void _updateTouchState(PointerEvent event, bool isDown) {
    if (isDown) {
      _touchPoints[event.pointer] = event.position; // Store global position to handle moving blobs
    } else {
      _touchPoints.remove(event.pointer);
    }

    if (_touchPoints.isNotEmpty) {
      // Scale dispersion based on the number of active fingers and the tap scale factor
      widget.controller.setDispersion(
        (0.4 + 0.2 * _touchPoints.length) * widget.controller.tapScaleFactor,
      );
    } else {
      widget.controller.setDispersion(0.0);
    }

    // Send a copy of active touch points back to the parent
    widget.onTouchesChanged(_touchPoints.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (_touchPoints.isEmpty) {
          // Subtle auto-nudge on hover (not full drag — just orientation hint)
          widget.controller.addRotationImpulse(event.localDelta * 0.3);
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
