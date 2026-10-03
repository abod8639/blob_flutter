import 'dart:async';
import 'dart:isolate';
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

      worker.errorPortForTesting
          .send(['Test Isolate Crash', 'Stack frame #1\nStack frame #2']);
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

    test(
        'errorPort completes readyCompleter with error if isolate crashes before handshake',
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

    test(
        'init completes with error when isolate spawn fails asynchronously (L106-L111)',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      BlobWorker.isolateSpawner = (
        void Function(List<Object?>) entry,
        List<Object?> message, {
        bool errorsAreFatal = false,
        SendPort? onError,
        String? debugName,
      }) {
        return Future.error(Exception('Spawn failed async'));
      };

      try {
        await expectLater(
          worker.init(sphere, count),
          throwsA(isA<BlobWorkerException>().having(
            (e) => e.code,
            'code',
            BlobErrorCode.workerSpawnFailed,
          )),
        );
      } finally {
        BlobWorker.isolateSpawner = Isolate.spawn;
        worker.dispose();
      }
    });

    test(
        'catchError in init does not re-complete readyCompleter if already disposed',
        () async {
      final worker = BlobWorker();
      const count = 10;
      final sphere = BlobMath.generateFibonacciSphere(count);

      final completer = Completer<Isolate>();
      BlobWorker.isolateSpawner = (
        void Function(List<Object?>) entry,
        List<Object?> message, {
        bool errorsAreFatal = false,
        SendPort? onError,
        String? debugName,
      }) {
        return completer.future;
      };

      try {
        final initFuture = worker.init(sphere, count);
        worker.dispose();
        // Now reject the spawn future after worker is already disposed
        completer.completeError(Exception('Spawn failed after dispose'));
        await expectLater(initFuture, completes);
      } finally {
        BlobWorker.isolateSpawner = Isolate.spawn;
      }
    });

    test(
        'worker isolate handles raw flat parameters message without transferable wrapper (L212)',
        () async {
      late void Function(List<Object?>) capturedEntry;
      final originalSpawner = BlobWorker.isolateSpawner;
      BlobWorker.isolateSpawner = (
        entry,
        message, {
        bool errorsAreFatal = false,
        SendPort? onError,
        String? debugName,
      }) {
        capturedEntry = entry;
        return Isolate.spawn(entry, message,
            errorsAreFatal: errorsAreFatal,
            onError: onError,
            debugName: debugName);
      };

      final worker = BlobWorker();
      const count = 20;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);
      worker.dispose();
      BlobWorker.isolateSpawner = originalSpawner;

      // Spawn worker isolate using the captured worker entry
      final rx = ReceivePort();
      final handshakeCompleter = Completer<SendPort>();
      final resultCompleter = Completer<TransferableTypedData>();

      rx.listen((msg) {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete(msg as SendPort);
        } else if (!resultCompleter.isCompleted) {
          resultCompleter.complete(msg as TransferableTypedData);
        }
      });

      final isolate =
          await Isolate.spawn(capturedEntry, [rx.sendPort, sphere, count]);
      final workerPort = await handshakeCompleter.future;

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

      // Sending flat params message directly (first is int, not List) hits L212: else { paramsList = msg; }
      final flatMessage = params.toMessage();
      workerPort.send(flatMessage);

      final response = await resultCompleter.future;
      final points = response.materialize().asFloat32List();
      expect(points.length, count * 2);

      isolate.kill();
      rx.close();
    });

    test(
        'supports complex temporal interleaving across consecutive frames (L242-L245, L247)',
        () async {
      final worker = BlobWorker();
      const count = 30;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);

      ProjectParamsFlat createParams(bool isComplex, double time) =>
          ProjectParamsFlat(
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
            encodedTouches: Float32List(0),
            autoRotationSpeed: 0.5,
            noiseFrequency: 1.0,
            viewDistance: 2.0,
            noiseTypeIndex: BlobNoiseType.simplex.index,
            touchRadiusFactor: 1.0,
            isComplex: isComplex,
          );

      // Frame 0: isComplex: true, frameIndex == 0 -> frameIndex becomes 1
      final frame0 = await worker.compute(createParams(true, 0.0));
      expect(frame0, isNotNull);
      expect(frame0!.length, count * 2);

      // Frame 1: isComplex: true, frameIndex == 1 -> startIndex = 1, stride = 2, frameIndex becomes 2
      final frame1 = await worker.compute(createParams(true, 1.0));
      expect(frame1, isNotNull);
      expect(frame1!.length, count * 2);

      // Frame 2: isComplex: true, frameIndex == 2 -> startIndex = 0, stride = 2, frameIndex becomes 3
      final frame2 = await worker.compute(createParams(true, 2.0));
      expect(frame2, isNotNull);
      expect(frame2!.length, count * 2);

      // Frame 3: isComplex: false -> else { frameIndex = 0; }
      final frame3 = await worker.compute(createParams(false, 3.0));
      expect(frame3, isNotNull);
      expect(frame3!.length, count * 2);

      worker.dispose();
    });

    test(
        'worker isolate allocates scratch depth-sort buffers on first frame (L233-L235)',
        () async {
      final worker = BlobWorker();
      const count = 30;
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
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        encodedTouches: Float32List(0),
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: BlobNoiseType.harmonic.index,
        touchRadiusFactor: 1.0,
        enableDepthSort: true,
      );

      // Frame 1: allocates rawPoints, depths, particleBins (L233-L235)
      final result1 = await worker.compute(params);
      expect(result1, isNotNull);
      expect(result1!.length, count * 2);

      // Frame 2: scratch buffers already match dimensions, reuses them cleanly
      final result2 = await worker.compute(params);
      expect(result2, isNotNull);
      expect(result2!.length, count * 2);

      worker.dispose();
    });
  });
}
