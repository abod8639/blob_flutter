import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';

void main() {
  group('BlobMath Tests', () {
    test(
        'generateFibonacciSphere generates unit sphere points and asserts invalid inputs',
        () {
      expect(
        () => BlobMath.generateFibonacciSphere(0),
        throwsAssertionError,
      );
      expect(
        () => BlobMath.generateFibonacciSphere(-10),
        throwsAssertionError,
      );

      final samples = 100;
      final sphere = BlobMath.generateFibonacciSphere(samples);
      expect(sphere.length, samples * 3);

      // Verify that all points lie on the unit sphere (distance from origin is 1.0)
      for (int i = 0; i < samples; i++) {
        final x = sphere[i * 3];
        final y = sphere[i * 3 + 1];
        final z = sphere[i * 3 + 2];
        final actualDist = (x * x + y * y + z * z);
        expect(actualDist, closeTo(1.0, 0.0001));
      }
    });

    test('generateFibonacciSphere handles single sample case', () {
      final sphere = BlobMath.generateFibonacciSphere(1);
      expect(sphere.length, 3);
      expect(sphere[0], 1.0);
      expect(sphere[1], 0.0);
      expect(sphere[2], 0.0);
    });

    test('wrapTime keeps time wrapped within limits and handles large values',
        () {
      expect(BlobMath.wrapTime(5.0), 5.0);

      // Multiple of the limit should wrap to 0.0
      final limit = BlobMath.twoPi * 100.0;
      expect(BlobMath.wrapTime(limit), closeTo(0.0, 0.0001));

      final hugeTime = limit + 3.5;
      expect(BlobMath.wrapTime(hugeTime), closeTo(3.5, 0.0001));
    });

    test('fastSimplex3D returns deterministic values bounded in [-2.0, 2.0]',
        () {
      final val1 = BlobMath.fastSimplex3D(0.5, 0.5, 0.5);
      final val2 = BlobMath.fastSimplex3D(0.5, 0.5, 0.5);
      expect(val1, val2);
      expect(val1, inInclusiveRange(-2.0, 2.0));

      final valOrigin = BlobMath.fastSimplex3D(0.0, 0.0, 0.0);
      expect(valOrigin, inInclusiveRange(-2.0, 2.0));

      final valNeg = BlobMath.fastSimplex3D(-1.5, -2.5, 3.5);
      expect(valNeg, inInclusiveRange(-2.0, 2.0));
    });

    test(
        'projectParticles projects points correctly with scale, offset, and dispersion',
        () {
      final count = 10;
      final baseSphere = BlobMath.generateFibonacciSphere(count);
      final projectedBase = Float32List(count * 2);
      final projectedWithDispersion = Float32List(count * 2);
      final projectedWithOffsetAndScale = Float32List(count * 2);

      // 1. Project base points
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: baseSphere,
        projectedPoints: projectedBase,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // Verify centered projection
      for (int i = 0; i < count; i++) {
        expect(projectedBase[i * 2], isNot(0.0));
        expect(projectedBase[i * 2 + 1], isNot(0.0));
        expect(projectedBase[i * 2].isNaN, false);
        expect(projectedBase[i * 2 + 1].isNaN, false);
      }

      // 2. Project with scale and offset
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        scale: 1.5,
        centerOffsetX: 50.0,
        centerOffsetY: -30.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: baseSphere,
        projectedPoints: projectedWithOffsetAndScale,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      for (int i = 0; i < count; i++) {
        expect(projectedWithOffsetAndScale[i * 2], isNot(0.0));
        expect(projectedWithOffsetAndScale[i * 2 + 1], isNot(0.0));
      }

      // 3. Project with uniform dispersion
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: baseSphere,
        projectedPoints: projectedWithDispersion,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // Verify that dispersion pushes points further from center
      for (int i = 0; i < count; i++) {
        final distBaseX = (projectedBase[i * 2] - 200.0).abs();
        final distDispX = (projectedWithDispersion[i * 2] - 200.0).abs();
        expect(distDispX, greaterThanOrEqualTo(distBaseX));
      }
    });

    test(
        'projectParticles handles active multi-touch interactions and touchRadiusFactor',
        () {
      final count = 20;
      final baseSphere = BlobMath.generateFibonacciSphere(count);
      final projectedTouches = Float32List(count * 2);

      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.2,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List.fromList([200.0, 200.0, 100.0, 100.0]),
        baseSphere: baseSphere,
        projectedPoints: projectedTouches,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        touchRadiusFactor: 1.5,
      );

      for (int i = 0; i < count * 2; i++) {
        expect(projectedTouches[i].isNaN, false);
        expect(projectedTouches[i].isInfinite, false);
      }
    });

    test(
        'projectParticles executes accurately for every BlobNoiseType algorithm',
        () {
      final sphere = BlobMath.generateFibonacciSphere(100);
      final projected = Float32List(100 * 2);

      for (final noiseType in BlobNoiseType.values) {
        BlobMath.projectParticles(
          count: 100,
          radius: 100.0,
          blobiness: 1.5,
          dispersion: 0.2,
          rotationX: 0.5,
          rotationY: 0.5,
          time: 2.5,
          viewportWidth: 400.0,
          viewportHeight: 400.0,
          activeTouches: Float32List(0),
          baseSphere: sphere,
          projectedPoints: projected,
          autoRotationSpeed: 0.5,
          noiseFrequency: 1.2,
          viewDistance: 2.0,
          noiseType: noiseType,
        );

        for (int i = 0; i < projected.length; i++) {
          expect(projected[i].isNaN, false,
              reason: 'NaN found in $noiseType at index $i');
          expect(projected[i].isInfinite, false,
              reason: 'Infinity found in $noiseType at index $i');
        }
      }
    });
  });
}
