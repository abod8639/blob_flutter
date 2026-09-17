import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/blob_flutter.dart';

void main() {
  group('BlobFlutter Library Export Tests', () {
    test('exports BlobNoiseType enum with all procedural noise types', () {
      expect(
          BlobNoiseType.values,
          containsAll([
            BlobNoiseType.harmonic,
            BlobNoiseType.spiky,
            BlobNoiseType.fractal,
            BlobNoiseType.cellular,
            BlobNoiseType.vortex,
            BlobNoiseType.sphericalHarmonics,
            BlobNoiseType.simplex,
            BlobNoiseType.wave,
            BlobNoiseType.custom,
          ]));
    });

    test('exports BlobMath and BlobCustomNoiseFunction correctly', () {
      double customNoise(double px, double py, double pz, double f, double time,
          double blobiness) {
        return 1.0 + BlobMath.fastSimplex3D(px, py, pz) * 0.2;
      }

      final controller = BlobController(
        noiseType: BlobNoiseType.custom,
        customNoise: customNoise,
      );

      expect(controller.noiseType, BlobNoiseType.custom);
      expect(controller.customNoise, isNotNull);
      controller.dispose();
    });

    test('exports BlobController with standard constructor and control methods',
        () {
      final controller = BlobController(
        radius: 120.0,
        pointSize: 2.5,
        particleCount: 1000,
        noiseType: BlobNoiseType.spiky,
      );

      expect(controller.radius, 120.0);
      expect(controller.pointSize, 2.5);
      expect(controller.particleCount, 1000);
      expect(controller.noiseType, BlobNoiseType.spiky);

      controller.setRadius(150.0);
      expect(controller.radius, 150.0);
      controller.dispose();
    });

    testWidgets('exports BlobFlutter widget which renders correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BlobFlutter(
                particleCount: 100,
                radius: 80.0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);
    });
  });
}
