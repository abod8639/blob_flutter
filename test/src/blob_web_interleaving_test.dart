import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_worker_web.dart';

void main() {
  group('Blob Web Temporal Interleaving Tests', () {
    test(
        'BlobMath.projectParticles updates only specified indices when stride > 1',
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

      // Frame 2 (full computation without interleaving)
      final res2 = await worker.compute(params);
      expect(res2, isNotNull);
      expect(res2!.length, count * 2);

      // Frame 3 (full computation next frame)
      final res3 = await worker.compute(params);
      expect(res3, isNotNull);
      expect(res3!.length, count * 2);

      worker.dispose();
    });

    test('BlobWorker alternates updating even and odd particles when interleaving is active',
        () async {
      final worker = BlobWorker();
      const count = 1000;
      final sphere = BlobMath.generateFibonacciSphere(count);
      await worker.init(sphere, count);

      ProjectParamsFlat createParams(double time, bool interleave) {
        return ProjectParamsFlat(
          count: count,
          radius: 100.0,
          scale: 1.0,
          centerOffsetX: 0.0,
          centerOffsetY: 0.0,
          blobiness: 1.0,
          dispersion: 0.0,
          rotationX: 0.0,
          rotationY: 0.0,
          time: time,
          viewportWidth: 400.0,
          viewportHeight: 400.0,
          autoRotationSpeed: 0.5,
          noiseFrequency: 1.0,
          viewDistance: 2.0,
          noiseTypeIndex: 0,
          touchRadiusFactor: 1.0,
          encodedTouches: Float32List(0),
          webTemporalInterleaving: interleave,
          isComplex: interleave,
          enableDepthSort: false,
        );
      }

      // Frame 0 (time = 0.0): initial frame computes all particles
      final f0 = await worker.compute(createParams(0.0, true));
      expect(f0, isNotNull);
      final f0Copy = Float32List.fromList(f0!);

      // Frame 1 (time = 1.0): updates odd particles (stride: 2, startIndex: 1)
      final f1 = await worker.compute(createParams(1.0, true));
      expect(f1, isNotNull);

      // Even particle 2 should NOT have changed between Frame 0 and Frame 1
      expect(f1![4], equals(f0Copy[4]));
      expect(f1[5], equals(f0Copy[5]));

      // Odd particle 1 SHOULD have changed due to time progression
      expect(f1[2], isNot(equals(f0Copy[2])));
      expect(f1[3], isNot(equals(f0Copy[3])));

      final f1Copy = Float32List.fromList(f1);

      // Frame 2 (time = 2.0): updates even particles (stride: 2, startIndex: 0)
      final f2 = await worker.compute(createParams(2.0, true));
      expect(f2, isNotNull);

      // Even particle 2 SHOULD have changed
      expect(f2![4], isNot(equals(f1Copy[4])));
      expect(f2[5], isNot(equals(f1Copy[5])));

      // Odd particle 1 should NOT have changed between Frame 1 and Frame 2
      expect(f2[2], equals(f1Copy[2]));
      expect(f2[3], equals(f1Copy[3]));

      worker.dispose();
    });

    test(
        'BlobWorker computes all particles every frame when isComplex is false',
        () async {
      final worker = BlobWorker();
      const count = 1000;
      final sphere = BlobMath.generateFibonacciSphere(count);
      await worker.init(sphere, count);

      ProjectParamsFlat createParams(double time) {
        return ProjectParamsFlat(
          count: count,
          radius: 100.0,
          scale: 1.0,
          centerOffsetX: 0.0,
          centerOffsetY: 0.0,
          blobiness: 1.0,
          dispersion: 0.0,
          rotationX: 0.0,
          rotationY: 0.0,
          time: time,
          viewportWidth: 400.0,
          viewportHeight: 400.0,
          autoRotationSpeed: 0.5,
          noiseFrequency: 1.0,
          viewDistance: 2.0,
          noiseTypeIndex: 0,
          touchRadiusFactor: 1.0,
          encodedTouches: Float32List(0),
          isComplex: false,
          enableDepthSort: false,
        );
      }

      final f0 = await worker.compute(createParams(0.0));
      expect(f0, isNotNull);
      final f0Copy = Float32List.fromList(f0!);

      final f1 = await worker.compute(createParams(1.0));
      expect(f1, isNotNull);

      // When isComplex is false, both even (particle 2) and odd (particle 1) particles are updated
      expect(f1![2], isNot(equals(f0Copy[2])));
      expect(f1[3], isNot(equals(f0Copy[3])));
      expect(f1[4], isNot(equals(f0Copy[4])));
      expect(f1[5], isNot(equals(f0Copy[5])));

      worker.dispose();
    });
  });
}
