import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_exception.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_worker_native.dart';

void main() {
  group('BlobWorker Native Isolate Tests', () {
    test('lifecycle: init, isReady, compute, and dispose', () async {
      final worker = BlobWorker();
      expect(worker.isReady, false);

      const count = 50;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);
      expect(worker.isReady, true);

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
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        encodedTouches: Float32List(0),
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: BlobNoiseType.harmonic.index,
        touchRadiusFactor: 1.0,
      );

      final result = await worker.compute(params);
      expect(result, isNotNull);
      expect(result!.length, count * 2);

      for (int i = 0; i < result.length; i++) {
        expect(result[i].isNaN, false);
        expect(result[i].isInfinite, false);
      }

      worker.dispose();

      // Computing after dispose should return null immediately
      final afterDisposeResult = await worker.compute(params);
      expect(afterDisposeResult, isNull);
    });

    test('compute returns null if not initialized', () async {
      final worker = BlobWorker();
      final params = ProjectParamsFlat(
        count: 10,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        encodedTouches: Float32List(0),
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: 0,
      );

      final result = await worker.compute(params);
      expect(result, isNull);
      worker.dispose();
    });

    test('dispose before handshake completes the readyCompleter with error',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      // Start init (begins the handshake async), then immediately dispose.
      final initFuture = worker.init(sphere, count);
      worker.dispose();

      // The future should complete with a BlobWorkerException, not hang forever.
      bool caughtError = false;
      try {
        await initFuture;
      } on BlobWorkerException {
        caughtError = true;
      } catch (_) {
        caughtError = true;
      }
      expect(caughtError, isTrue);
    });

    test('init accepts and does not call onError when worker starts normally',
        () async {
      final worker = BlobWorker();
      const count = 20;
      final sphere = BlobMath.generateFibonacciSphere(count);

      BlobWorkerException? receivedError;
      await worker.init(
        sphere,
        count,
        onError: (e) => receivedError = e,
      );

      expect(worker.isReady, true);
      expect(receivedError, isNull);
      worker.dispose();
    });
  });
}
