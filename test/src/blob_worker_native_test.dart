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

    test('dispose before handshake completes cleanly without unhandled error',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      // Start init (begins the handshake async), then immediately dispose.
      final initFuture = worker.init(sphere, count);
      worker.dispose();

      // The future should complete cleanly, not hang forever.
      await expectLater(initFuture, completes);
      expect(worker.isReady, isFalse);
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

    test('errorPort handles isolate error list with message and stack trace',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      BlobWorkerException? receivedError;
      await worker.init(
        sphere,
        count,
        onError: (e) => receivedError = e,
      );

      worker.errorPortForTesting.send(['Test Isolate Crash', 'Stack frame #1\nStack frame #2']);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedError, isNotNull);
      expect(receivedError!.code, BlobErrorCode.workerSpawnFailed);
      expect(receivedError!.cause, 'Test Isolate Crash');
      expect(receivedError!.stackTrace.toString(), contains('Stack frame #1'));

      worker.dispose();
    });

    test('errorPort handles isolate error when message is a non-list string',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      BlobWorkerException? receivedError;
      await worker.init(
        sphere,
        count,
        onError: (e) => receivedError = e,
      );

      worker.errorPortForTesting.send('Single error string');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedError, isNotNull);
      expect(receivedError!.cause, 'Single error string');
      expect(receivedError!.stackTrace, isNull);

      // Subsequent messages after dispose are ignored (hits `if (_disposed) return;`)
      worker.dispose();
      receivedError = null;
      worker.errorPortForTesting.send('Ignored error string');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(receivedError, isNull);
    });

    test('errorPort completes readyCompleter with error if isolate crashes before handshake',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      // Simulate isolate crash arriving before handshake
      worker.errorPortForTesting.send(['Crash before handshake', null]);
      final initFuture = worker.init(sphere, count);

      await expectLater(
        initFuture,
        throwsA(isA<BlobWorkerException>().having(
          (e) => e.cause,
          'cause',
          'Crash before handshake',
        )),
      );

      worker.dispose();
    });
  });
}
