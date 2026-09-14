import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// High-performance painter that draws all blob particles in a single draw call
/// using [Canvas.drawRawPoints].
///
/// Receives a flat [Float32List] of (x, y) pairs and renders them as round
/// points with an optional [ui.FragmentShader] for GPU-side coloring.
class BlobPainter extends CustomPainter {
  final Float32List positions;
  final ui.FragmentShader? shader;
  final double pointSize;
  final Gradient fallbackGradient;
  final Color fallbackColor;

  /// Snapshot of the frame counter used for efficient [shouldRepaint]
  /// comparison — we repaint only when the generation changes,
  /// not on every parent rebuild (ARCH-05 fix).
  final int _generation;

  int get generation => _generation;

  // ── Instance Paint ──────────────────────────────────────────────────────────
  /// Encapsulated [Paint] instance dedicated to this painter/widget instance.
  ///
  /// Prevents state leakage, color bleeding, and race conditions between multiple
  /// concurrent [BlobFlutter] widgets rendered on the same screen.
  final Paint _paint;

  /// Exposes the [Paint] instance for testing and introspection.
  @visibleForTesting
  Paint get paintInstance => _paint;

  BlobPainter({
    required this.positions,
    required int generation,
    this.shader,
    required this.pointSize,
    required this.fallbackGradient,
    this.fallbackColor = const Color(0xFF448AFF),
    Paint? paint,
  })  : _generation = generation,
        _paint = paint ??
            (Paint()
              ..strokeCap = StrokeCap.round
              ..isAntiAlias = true);

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;

    _paint.strokeWidth = pointSize;
    if (shader != null) {
      _paint.shader = shader;
      _paint.color = const Color(0xFF000000);
    } else {
      // Primary fallback: Render complete native GPU gradient via Canvas engine
      final rect = (size.isEmpty || !size.isFinite)
          ? Rect.fromLTWH(0, 0, pointSize, pointSize)
          : Offset.zero & size;
      try {
        _paint.shader = fallbackGradient.createShader(rect);
      } catch (_) {
        _paint.shader = null;
        _paint.color = fallbackColor;
      }
    }

    canvas.drawRawPoints(ui.PointMode.points, positions, _paint);
  }

  /// Only request repaint when the frame generation counter has changed,
  /// preventing unnecessary repaints on parent-driven rebuilds (ARCH-05 fix).
  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return _generation != oldDelegate._generation ||
        shader != oldDelegate.shader ||
        pointSize != oldDelegate.pointSize ||
        fallbackColor != oldDelegate.fallbackColor ||
        fallbackGradient != oldDelegate.fallbackGradient;
  }
}
