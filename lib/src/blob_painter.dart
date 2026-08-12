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

  /// Snapshot of the frame counter used for efficient [shouldRepaint]
  /// comparison — we repaint only when the generation changes,
  /// not on every parent rebuild (ARCH-05 fix).
  final int _generation;

  int get generation => _generation;

  // ── Shared Paint ────────────────────────────────────────────────────────────
  /// Single [Paint] instance shared across all [BlobPainter.paint] calls.
  ///
  /// Canvas drawing always executes on the UI thread (never concurrently), so
  /// sharing a single mutable [Paint] is safe and eliminates one heap
  /// allocation per frame at 60 Hz.
  static final Paint _sharedPaint = Paint()
    ..strokeCap   = StrokeCap.round
    ..isAntiAlias = true;

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

    _sharedPaint.strokeWidth = pointSize;
    if (shader != null) {
      _sharedPaint.shader = shader;
    } else {
      _sharedPaint.shader = null;   // clear any previous shader reference
      _sharedPaint.color  = fallbackColor;
    }

    canvas.drawRawPoints(ui.PointMode.points, positions, _sharedPaint);
  }

  /// Only request repaint when the frame generation counter has changed,
  /// preventing unnecessary repaints on parent-driven rebuilds (ARCH-05 fix).
  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return _generation   != oldDelegate._generation  ||
           shader        != oldDelegate.shader       ||
           pointSize     != oldDelegate.pointSize    ||
           fallbackColor != oldDelegate.fallbackColor;
  }
}
