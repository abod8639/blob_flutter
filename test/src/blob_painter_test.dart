import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_painter.dart';
import 'package:blob_flutter/src/blob_shader_helper.dart';

class _MockCanvas extends Fake implements Canvas {
  int drawRawPointsCallCount = 0;
  ui.PointMode? pointMode;
  Float32List? points;
  Paint? paint;

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    drawRawPointsCallCount++;
    this.pointMode = pointMode;
    this.points = points;
    this.paint = paint;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlobPainter Tests', () {
    test('initializes properties correctly', () {
      final positions = Float32List.fromList([1.0, 2.0]);
      final painter = BlobPainter(
        positions: positions,
        generation: 5,
        pointSize: 3.5,
        fallbackColor: Colors.purple,
      );

      expect(painter.positions, positions);
      expect(painter.generation, 5);
      expect(painter.pointSize, 3.5);
      expect(painter.fallbackColor, Colors.purple);
      expect(painter.shader, isNull);
    });

    test('paint method skips when positions are empty', () {
      final canvas = _MockCanvas();
      final painter = BlobPainter(
        positions: Float32List(0),
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );
      painter.paint(canvas, Size.zero);
      expect(canvas.drawRawPointsCallCount, 0);
    });

    test('paint method draws points on canvas with fallback color when shader is null', () {
      final canvas = _MockCanvas();
      final positions = Float32List.fromList([10.0, 20.0, 30.0, 40.0]);
      final painter = BlobPainter(
        positions: positions,
        generation: 1,
        pointSize: 3.0,
        fallbackColor: const Color(0xFF4CAF50),
      );
      painter.paint(canvas, Size.zero);

      expect(canvas.drawRawPointsCallCount, 1);
      expect(canvas.pointMode, ui.PointMode.points);
      expect(canvas.points, positions);
      expect(canvas.paint?.strokeWidth, 3.0);
      expect(canvas.paint?.strokeCap, StrokeCap.round);
      expect(canvas.paint?.isAntiAlias, true);
      expect(canvas.paint?.color.toARGB32(), const Color(0xFF4CAF50).toARGB32());
      expect(canvas.paint?.shader, isNull);
    });

    test('shouldRepaint detects changes in generation, pointSize, and fallbackColor', () {
      final positions1 = Float32List(10);
      final positions2 = Float32List(10);

      final painterBase = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterIdentical = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterDiffGen = BlobPainter(
        positions: positions1,
        generation: 2,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterDiffSize = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 3.0,
        fallbackColor: Colors.red,
      );

      final painterDiffColor = BlobPainter(
        positions: positions2,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.blue,
      );

      expect(painterBase.shouldRepaint(painterIdentical), false);
      expect(painterBase.shouldRepaint(painterDiffGen), true);
      expect(painterBase.shouldRepaint(painterDiffSize), true);
      expect(painterBase.shouldRepaint(painterDiffColor), true);
    });

    test('paint and shouldRepaint with real FragmentShader if available', () async {
      final program = await BlobShaderHelper.loadProgram();
      if (program != null) {
        final shader1 = program.fragmentShader();
        final shader2 = program.fragmentShader();

        final canvas = _MockCanvas();
        final positions = Float32List.fromList([10.0, 20.0]);
        final painterWithShader = BlobPainter(
          positions: positions,
          generation: 1,
          shader: shader1,
          pointSize: 4.0,
          fallbackColor: Colors.white,
        );

        painterWithShader.paint(canvas, Size.zero);
        expect(canvas.drawRawPointsCallCount, 1);
        expect(canvas.paint?.shader, shader1);

        final painterDiffShader = BlobPainter(
          positions: positions,
          generation: 1,
          shader: shader2,
          pointSize: 4.0,
          fallbackColor: Colors.white,
        );

        expect(painterWithShader.shouldRepaint(painterDiffShader), true);
      }
    });
  });
}
