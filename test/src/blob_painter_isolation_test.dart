import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_painter.dart';

void main() {
  group('BlobPainter Instance Isolation Tests', () {
    test('two BlobPainter instances do not share the same Paint object', () {
      final painter1 = BlobPainter(
        positions: Float32List(10),
        generation: 1,
        pointSize: 2.0,
        fallbackGradient:
            const LinearGradient(colors: [Colors.blue, Colors.red]),
        fallbackColor: Colors.red,
      );

      final painter2 = BlobPainter(
        positions: Float32List(10),
        generation: 1,
        pointSize: 4.0,
        fallbackGradient:
            const LinearGradient(colors: [Colors.green, Colors.yellow]),
        fallbackColor: Colors.yellow,
      );

      expect(identical(painter1.paintInstance, painter2.paintInstance), isFalse,
          reason: 'Each BlobPainter must have an independent Paint instance');
    });

    test('custom paint parameter is respected', () {
      final customPaint = Paint()..color = Colors.amber;
      final painter = BlobPainter(
        positions: Float32List(10),
        generation: 1,
        pointSize: 2.0,
        fallbackGradient:
            const LinearGradient(colors: [Colors.blue, Colors.red]),
        paint: customPaint,
      );

      expect(identical(painter.paintInstance, customPaint), isTrue);
    });

    test('fallbackColor mutation does not bleed between painters', () {
      final painterA = BlobPainter(
        positions: Float32List.fromList([10, 10, 20, 20]),
        generation: 1,
        pointSize: 2.0,
        fallbackGradient:
            const LinearGradient(colors: [Colors.red, Colors.red]),
        fallbackColor: Colors.red,
      );

      final painterB = BlobPainter(
        positions: Float32List.fromList([30, 30, 40, 40]),
        generation: 1,
        pointSize: 5.0,
        fallbackGradient:
            const LinearGradient(colors: [Colors.blue, Colors.blue]),
        fallbackColor: Colors.blue,
      );

      // Mutate painter A's paint
      painterA.paintInstance.color = Colors.red;
      painterA.paintInstance.strokeWidth = 2.0;

      // Painter B's paint should have its own properties
      painterB.paintInstance.color = Colors.blue;
      painterB.paintInstance.strokeWidth = 5.0;

      expect(painterA.paintInstance.color.toARGB32(), Colors.red.toARGB32());
      expect(painterB.paintInstance.color.toARGB32(), Colors.blue.toARGB32());
      expect(painterA.paintInstance.strokeWidth, 2.0);
      expect(painterB.paintInstance.strokeWidth, 5.0);
    });
  });
}
