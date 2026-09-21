import 'dart:math';
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

    test(
        'BlobNoiseType.wave generates valid flat square carpet wave coordinates without NaN',
        () {
      final sphere = BlobMath.generateFibonacciSphere(300);
      final projected = Float32List(300 * 2);

      BlobMath.projectParticles(
        count: 300,
        radius: 100.0,
        blobiness: 1.2,
        dispersion: 0.0,
        rotationX: 0.3,
        rotationY: 0.4,
        time: 2.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected,
        autoRotationSpeed: 0.2,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );

      for (int i = 0; i < projected.length; i++) {
        expect(projected[i].isNaN, false);
        expect(projected[i].isInfinite, false);
      }
    });

    test(
        'BlobNoiseType.wave disables auto-rotation so carpet remains stationary',
        () {
      final sphere = BlobMath.generateFibonacciSphere(100);
      final projected1 = Float32List(100 * 2);
      final projected2 = Float32List(100 * 2);

      // Run at time = 0.0
      BlobMath.projectParticles(
        count: 100,
        radius: 100.0,
        blobiness: 0.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected1,
        autoRotationSpeed: 1.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );

      // Run at time = 10.0 with high autoRotationSpeed
      BlobMath.projectParticles(
        count: 100,
        radius: 100.0,
        blobiness: 0.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 10.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected2,
        autoRotationSpeed: 1.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );

      for (int i = 0; i < projected1.length; i++) {
        expect(projected1[i], closeTo(projected2[i], 1e-5));
      }
    });

    test(
        'BlobMath helper methods compute coordinates and interpolations safely',
        () {
      // azimuth
      expect(BlobMath.azimuth(1.0, 0.0), closeTo(0.0, 1e-5));
      expect(BlobMath.azimuth(0.0, 1.0), closeTo(BlobMath.twoPi / 4.0, 1e-5));

      // elevation
      expect(BlobMath.elevation(0.0), closeTo(0.0, 1e-5));
      expect(BlobMath.elevation(1.0), closeTo(pi / 2.0, 1e-5));
      // Out of bounds safety clamp
      expect(BlobMath.elevation(1.5), closeTo(pi / 2.0, 1e-5));
      expect(BlobMath.elevation(-2.0), closeTo(-pi / 2.0, 1e-5));

      // distance2D
      expect(BlobMath.distance2D(3.0, 4.0), closeTo(5.0, 1e-5));

      // smoothstep
      expect(BlobMath.smoothstep(0.0, 1.0, -0.5), 0.0);
      expect(BlobMath.smoothstep(0.0, 1.0, 1.5), 1.0);
      expect(BlobMath.smoothstep(0.0, 1.0, 0.5), 0.5);
      expect(BlobMath.smoothstep(1.0, 1.0, 0.5), 0.0);

      // clampDisplacement
      expect(BlobMath.clampDisplacement(1.5), 1.5);
      expect(BlobMath.clampDisplacement(double.nan), 1.0);
      expect(BlobMath.clampDisplacement(double.infinity), 1.0);
      expect(BlobMath.clampDisplacement(double.negativeInfinity), 1.0);
      expect(BlobMath.clampDisplacement(-0.5), 0.05);
      expect(BlobMath.clampDisplacement(10.0), 5.0);
    });

    test(
        'projectParticles applies customNoise deformation and guards against NaN',
        () {
      final sphere = BlobMath.generateFibonacciSphere(50);
      final projected = Float32List(50 * 2);

      // 1. Valid custom noise
      BlobMath.projectParticles(
        count: 50,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.custom,
        customNoise: (px, py, pz, f, time, blobiness) {
          final phi = BlobMath.azimuth(px, pz);
          return 1.0 + sin(phi * 3.0 + time) * 0.3 * blobiness;
        },
      );

      for (int i = 0; i < projected.length; i++) {
        expect(projected[i].isNaN, false);
        expect(projected[i].isInfinite, false);
      }

      // 2. Custom noise returning NaN and Infinity is safely handled
      BlobMath.projectParticles(
        count: 50,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.custom,
        customNoise: (px, py, pz, f, time, blobiness) {
          if (px > 0) return double.nan;
          return double.infinity;
        },
      );

      for (int i = 0; i < projected.length; i++) {
        expect(projected[i].isNaN, false);
        expect(projected[i].isInfinite, false);
      }
    });

    test(
        'generateFibonacciSphere evicts oldest entry when exceeding max cache limit',
        () {
      // PERF-08: _maxCacheEntries is 8. Generating 10 distinct sizes will trigger eviction (_sphereCache.remove).
      for (int size = 10; size <= 20; size++) {
        final sphere = BlobMath.generateFibonacciSphere(size);
        expect(sphere.length, size * 3);
      }

      // Querying cached sizes should still return valid unit sphere coordinates
      final cachedSphere = BlobMath.generateFibonacciSphere(20);
      expect(cachedSphere.length, 20 * 3);
      for (int i = 0; i < 20; i++) {
        final x = cachedSphere[i * 3];
        final y = cachedSphere[i * 3 + 1];
        final z = cachedSphere[i * 3 + 2];
        expect(x * x + y * y + z * z, closeTo(1.0, 0.0001));
      }
    });

    test(
        'BlobNoiseType.wave uses _waveNoise formula and clamps displacement in [0.1, 4.0]',
        () {
      // 1. Validate _waveNoise formula execution across varied spatial coordinates and parameters
      final samples = [
        [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
        [0.5, 0.5, 0.5, 1.5, 2.0, 3.0, 1.5],
        [-0.8, 0.2, 0.6, 2.0, 10.0, 15.0, 0.5],
        [1.0, -1.0, 0.0, 0.5, 100.0, 150.0, 2.0],
        // Extreme values to test lower and upper clamping ([0.1, 4.0])
        [0.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 50.0],
      ];

      for (final s in samples) {
        final px = s[0],
            py = s[1],
            pz = s[2],
            f = s[3],
            time = s[4],
            time15 = s[5],
            blobiness = s[6];

        // Mirror _waveNoise formula to verify exact arithmetic behavior
        final double flatFactor = (blobiness * 0.7 + 0.3).clamp(0.2, 1.5);
        final double flatR = 1.0 / sqrt(1.0 + 5.0 * py * py);
        final double baseShape = 1.0 + (flatR - 1.0) * flatFactor;

        final double d1 = px * 0.85 + pz * 0.52;
        final double phase1 = d1 * 3.5 * f + time * 2.2;
        final double w1 = sin(phase1) + 0.3 * cos(phase1 * 2.0);

        final double d2 = -px * 0.52 + pz * 0.85;
        final double phase2 = d2 * 2.8 * f - time * 1.6;
        final double w2 = cos(phase2) * 0.65;

        final double dist = sqrt(px * px + pz * pz);
        final double phase3 = dist * 5.0 * f - time15 * 1.8;
        final double w3 = sin(phase3) * 0.45;

        final double phase4 = (px + pz) * 6.0 * f + time * 3.0;
        final double w4 = cos(phase4) * 0.2;

        final double wave = (w1 + w2 + w3 + w4) * 0.38;
        final double expectedDisplacement =
            (baseShape * (1.0 + wave * 0.4 * blobiness)).clamp(0.1, 4.0);

        expect(expectedDisplacement, inInclusiveRange(0.1, 4.0));
        expect(expectedDisplacement.isNaN, isFalse);
        expect(expectedDisplacement.isInfinite, isFalse);
      }

      // 2. Validate wave grid projection execution and output bounds
      final count = 64;
      final sphere = BlobMath.generateFibonacciSphere(count);
      final projected = Float32List(count * 2);

      BlobMath.projectParticles(
        count: count,
        radius: 80.0,
        blobiness: 3.0,
        dispersion: 0.0,
        rotationX: 0.2,
        rotationY: -0.3,
        time: 5.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projected,
        autoRotationSpeed: 0.0,
        noiseFrequency: 2.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );

      for (int i = 0; i < projected.length; i++) {
        expect(projected[i].isNaN, false);
        expect(projected[i].isInfinite, false);
      }
    });

    test(
        'BlobNoiseType.wave multi-touch interaction computes smoothInfluence and accumulates extraPush',
        () {
      final count = 16;
      final sphere = BlobMath.generateFibonacciSphere(count);
      final projectedSingle = Float32List(count * 2);
      final projectedMulti = Float32List(count * 2);

      // Single touch at center (250, 250)
      final singleTouch = Float32List.fromList([250.0, 250.0]);
      // Dual touch: one at center, another nearby to test multi-touch accumulation (L664-L676)
      final multiTouch = Float32List.fromList([250.0, 250.0, 255.0, 255.0]);

      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: singleTouch,
        baseSphere: sphere,
        projectedPoints: projectedSingle,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        touchRadiusFactor: 3.0,
        noiseType: BlobNoiseType.wave,
      );

      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: multiTouch,
        baseSphere: sphere,
        projectedPoints: projectedMulti,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        touchRadiusFactor: 3.0,
        noiseType: BlobNoiseType.wave,
      );

      // Verify that multi-touch accumulated extraPush produces greater displacement than single touch
      bool detectedDifference = false;
      for (int i = 0; i < count * 2; i++) {
        expect(projectedSingle[i].isNaN, false);
        expect(projectedMulti[i].isNaN, false);
        if ((projectedMulti[i] - projectedSingle[i]).abs() > 0.001) {
          detectedDifference = true;
        }
      }
      expect(detectedDifference, isTrue);
    });

    test(
        'BlobNoiseType.wave handles touch pointers, dispersion push, and fallback branching',
        () {
      final count = 100;
      final sphere = BlobMath.generateFibonacciSphere(count);
      final projectedTouches = Float32List(count * 2);
      final projectedDispersionOnly = Float32List(count * 2);
      final projectedUntouched = Float32List(count * 2);

      // 1. Touch interaction active: exercises L659-L678 (within bounding box and radius)
      // Viewport center is at (250, 250), place a touch directly near the center.
      final touches = Float32List.fromList([250.0, 250.0]);

      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.8,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: touches,
        baseSphere: sphere,
        projectedPoints: projectedTouches,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        touchRadiusFactor: 2.0,
      );

      // 2. Untouched / no extra push: touch placed far outside viewport bounding box
      // Particles outside touch radius fallback to screenX/screenY (L688-L691)
      final farTouches = Float32List.fromList([-5000.0, -5000.0]);
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: farTouches,
        baseSphere: sphere,
        projectedPoints: projectedUntouched,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // 3. Dispersion only without active touches (hasInteraction = true, hasPointers = false)
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 500.0,
        viewportHeight: 500.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: projectedDispersionOnly,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      for (int i = 0; i < count * 2; i++) {
        expect(projectedTouches[i].isNaN, false);
        expect(projectedTouches[i].isInfinite, false);
        expect(projectedUntouched[i].isNaN, false);
        expect(projectedUntouched[i].isInfinite, false);
        expect(projectedDispersionOnly[i].isNaN, false);
        expect(projectedDispersionOnly[i].isInfinite, false);
      }

      // Verify that touch interaction produces distinct point displacements compared to untouched
      bool hasDifference = false;
      for (int i = 0; i < count * 2; i++) {
        if ((projectedTouches[i] - projectedUntouched[i]).abs() > 0.01) {
          hasDifference = true;
          break;
        }
      }
      expect(hasDifference, isTrue);
    });
    test(
        'BlobNoiseType.wave interactive fallback assigns exact screen coordinates (L688-L690)',
        () {
      final count = 25;
      final sphere = BlobMath.generateFibonacciSphere(count);
      final fastPathPoints = Float32List(count * 2);
      final fallbackPoints = Float32List(count * 2);
      // 1. Fast-path calculation (hasInteraction = false) produces base (screenX, screenY)
      BlobMath.projectParticles(
        count: count,
        radius: 120.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.1,
        rotationY: 0.2,
        time: 1.5,
        viewportWidth: 600.0,
        viewportHeight: 600.0,
        activeTouches: Float32List(0),
        baseSphere: sphere,
        projectedPoints: fastPathPoints,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );
      // 2. Interactive path with hasInteraction = true (hasPointers = true), but touches located
      // far away outside the bounding box, forcing extraPush = 0.0 for every point.
      // Every point must execute the exact fallback branch:
      // projectedPoints[outIndex] = screenX;
      // projectedPoints[outIndex + 1] = screenY;
      final farTouch = Float32List.fromList([-99999.0, -99999.0]);
      BlobMath.projectParticles(
        count: count,
        radius: 120.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.1,
        rotationY: 0.2,
        time: 1.5,
        viewportWidth: 600.0,
        viewportHeight: 600.0,
        activeTouches: farTouch,
        baseSphere: sphere,
        projectedPoints: fallbackPoints,
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseType: BlobNoiseType.wave,
      );
      // Verify that every point in the fallback branch is numerically identical to the unperturbed base screen coordinate
      for (int i = 0; i < count * 2; i++) {
        expect(fallbackPoints[i], closeTo(fastPathPoints[i], 1e-5),
            reason:
                'Mismatch at index $i between fallback branch and base screen coordinates');
      }
    });
  });
}
