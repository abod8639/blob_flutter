import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_exception.dart';
import 'package:blob_flutter/src/blob_particle_coordinator.dart';
import 'package:blob_flutter/src/blob_touch_manager.dart';
import 'package:blob_flutter/src/blob_worker_native.dart';

class MockBlobWorker implements BlobWorker {
  void Function(BlobWorkerException error)? registeredOnError;
  bool _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  SendPort get errorPortForTesting => throw UnimplementedError();

  @override
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) async {
    registeredOnError = onError;
    _isReady = true;
  }

  @override
  Future<Float32List?> compute(
    ProjectParamsFlat params, [
    Float32List? recycleBuffer,
  ]) async {
    return Float32List(params.count * 2);
  }

  @override
  void dispose() {
    _isReady = false;
  }
}

class FailingComputeWorker extends MockBlobWorker {
  @override
  Future<Float32List?> compute(
    ProjectParamsFlat params, [
    Float32List? recycleBuffer,
  ]) {
    return Future.error(Exception('Compute failed simulated'));
  }
}

void main() {
  group('BlobParticleCoordinator Tests', () {
    test('baseSphere and isWorkerReady getters (L23, L29)', () {
      final coordinator = BlobParticleCoordinator();
      coordinator.generateBuffers(40);

      // Verify L23: baseSphere getter
      expect(coordinator.baseSphere.length, 40 * 3);
      // Verify L29: isWorkerReady getter
      expect(coordinator.isWorkerReady, isFalse);
    });

    test('startWorker handles async isolate error callback (L65-L69)',
        () async {
      final coordinator = BlobParticleCoordinator();
      coordinator.generateBuffers(20);
      final mockWorker = MockBlobWorker();

      BlobFlutterException? capturedError;
      bool? isAsyncFlag;

      coordinator.startWorker(
        workerFactory: () => mockWorker,
        particleCount: 20,
        onError: (err, st, {required bool isAsync}) {
          capturedError = err;
          isAsyncFlag = isAsync;
        },
        onWorkerReady: () {},
      );

      // Wait for init completion
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(coordinator.isWorkerReady, isTrue);

      // Trigger isolate unhandled error via worker's registered onError (L65-L69)
      final dummyError =
          BlobWorkerException.spawnFailed(cause: 'Crash after ready');
      mockWorker.registeredOnError!(dummyError);

      expect(capturedError, isNotNull);
      expect(capturedError, dummyError);
      expect(isAsyncFlag, isTrue);

      // Now test the early return branch `if (_worker != w) return;` (L66)
      coordinator.dispose();
      capturedError = null;
      mockWorker.registeredOnError!(dummyError);
      expect(capturedError, isNull);
    });

    testWidgets('processTick handles compute error in worker (L224-L228)',
        (tester) async {
      final coordinator = BlobParticleCoordinator();
      coordinator.generateBuffers(20);
      final failingWorker = FailingComputeWorker();

      late BuildContext savedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox(width: 200, height: 200);
            },
          ),
        ),
      );

      coordinator.startWorker(
        workerFactory: () => failingWorker,
        particleCount: 20,
        onError: (_, __, {required bool isAsync}) {},
        onWorkerReady: () {},
      );

      await tester.pump();
      expect(coordinator.isWorkerReady, isTrue);

      final controller = BlobController();
      final touchManager = BlobTouchManager();
      BlobFlutterException? capturedComputeError;

      coordinator.processTick(
        controller: controller,
        touchManager: touchManager,
        cachedSize: const Size(200, 200),
        time: 1.0,
        context: savedContext,
        isStillMounted: true,
        onFrameUpdated: () {},
        onComputeError: (err, st) {
          capturedComputeError = err;
        },
      );

      // Let microtasks and catchError execute
      await tester.pump();

      expect(capturedComputeError, isNotNull);
      expect(capturedComputeError, isA<BlobWorkerException>());
      expect((capturedComputeError as BlobWorkerException).code,
          BlobErrorCode.workerComputeFailed);
      expect(capturedComputeError!.cause.toString(),
          contains('Compute failed simulated'));

      coordinator.dispose();
      controller.dispose();
    });
  });
}
