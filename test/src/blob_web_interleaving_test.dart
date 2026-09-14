import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_worker_web.dart';

void main() {
  group('Blob Web Temporal Interleaving Tests', () {
    test('BlobMath.projectParticles updates only specified indices when stride > 1',
        () {
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);
      final points = Float32List(count * 2);

      // Pre-fill points with sentinel value -999.0
      points.fillRange(0, points.length, -999.0);

      // Update even particles only (startIndex = 0, stride = 2)
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        scale: 1.0,
        centerOffsetX: 0.0,
        centerOffsetY: 0.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.harmonic,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: points,
        startIndex: 0,
        stride: 2,
      );

      // Even particles (indices 0, 2, 4, 6, 8) must have been calculated (not -999.0)
      for (int i = 0; i < count; i += 2) {
        expect(points[i * 2], isNot(-999.0));
        expect(points[i * 2 + 1], isNot(-999.0));
      }

      // Odd particles (indices 1, 3, 5, 7, 9) must remain untouched (-999.0)
      for (int i = 1; i < count; i += 2) {
        expect(points[i * 2], -999.0);
        expect(points[i * 2 + 1], -999.0);
      }

      // Now update odd particles (startIndex = 1, stride = 2)
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        scale: 1.0,
        centerOffsetX: 0.0,
        centerOffsetY: 0.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.harmonic,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: points,
        startIndex: 1,
        stride: 2,
      );

      // Now all particles should be calculated
      for (int i = 0; i < count; i++) {
        expect(points[i * 2], isNot(-999.0));
        expect(points[i * 2 + 1], isNot(-999.0));
      }
    });

    test('BlobWorker (web) completes compute and handles large particle counts',
        () async {
      final worker = BlobWorker();
      const count = 2000;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);

      final params = ProjectParamsFlat(
        count: count,
        radius: 100.0,
        scale: 1.0,
        centerOffsetX: 0.0,
        centerOffsetY: 0.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: 0,
        touchRadiusFactor: 1.0,
        encodedTouches: Float32List(0),
      );

      // Frame 1 (full computation)
      final res1 = await worker.compute(params);
      expect(res1, isNotNull);
      expect(res1!.length, count * 2);

      // Frame 2 (interleaved computation)
      final res2 = await worker.compute(params);
      expect(res2, isNotNull);
      expect(res2!.length, count * 2);

      // Frame 3 (interleaved computation next phase)
      final res3 = await worker.compute(params);
      expect(res3, isNotNull);
      expect(res3!.length, count * 2);

      worker.dispose();
    });
  });
}
