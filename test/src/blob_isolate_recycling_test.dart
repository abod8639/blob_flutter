import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_worker_native.dart';

void main() {
  group('BlobWorker Native Isolate Buffer Recycling Tests', () {
    test('computes frames with recycledBuffer and preserves output validity',
        () async {
      final worker = BlobWorker();
      const count = 100;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);
      expect(worker.isReady, isTrue);

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

      // Frame 1: Compute without recycled buffer
      final frame1 = await worker.compute(params);
      expect(frame1, isNotNull);
      expect(frame1!.length, count * 2);

      // Frame 2: Compute without recycled buffer
      final frame2 = await worker.compute(params);
      expect(frame2, isNotNull);
      expect(frame2!.length, count * 2);

      // Frame 3: Pass frame 1 back as recycled buffer
      final frame3 = await worker.compute(params, frame1);
      expect(frame3, isNotNull);
      expect(frame3!.length, count * 2);

      // Frame 4: Pass frame 2 back as recycled buffer
      final frame4 = await worker.compute(params, frame2);
      expect(frame4, isNotNull);
      expect(frame4!.length, count * 2);

      worker.dispose();
    });

    test('reallocates output buffer when recycled buffer length does not match count * 2',
        () async {
      final worker = BlobWorker();
      const count = 30;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);
      expect(worker.isReady, isTrue);

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

      // Pass a recycled buffer of mismatched size (e.g. length 10 instead of 60)
      final mismatchedRecycled = Float32List(10);
      final frame = await worker.compute(params, mismatchedRecycled);
      expect(frame, isNotNull);
      expect(frame!.length, count * 2);

      worker.dispose();
    });
  });
}
