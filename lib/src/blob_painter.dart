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
  final Color fallbackColor;

  /// Snapshot of the [Float32List.buffer] identity used for efficient
  /// [shouldRepaint] comparison — we repaint only when the buffer changes,
  /// not on every parent rebuild (ARCH-05 fix).
  final int _generation;

  int get generation => _generation;

  BlobPainter({
    required this.positions,
    required int generation,
    this.shader,
    required this.pointSize,
    required this.fallbackColor,
  }) : _generation = generation;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = pointSize
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (shader != null) {
      paint.shader = shader;
    } else {
      paint.color = fallbackColor;
    }

    canvas.drawRawPoints(ui.PointMode.points, positions, paint);
  }

  /// Only request repaint when the frame generation counter has changed,
  /// preventing unnecessary repaints on parent-driven rebuilds (ARCH-05 fix).
  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return _generation != oldDelegate._generation ||
        shader != oldDelegate.shader ||
        pointSize != oldDelegate.pointSize ||
        fallbackColor != oldDelegate.fallbackColor;
  }
}
