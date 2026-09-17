import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'blob_compute_params.dart';
import 'blob_controller.dart';
import 'blob_exception.dart';
import 'blob_math.dart';
import 'blob_noise_type.dart';
import 'blob_touch_manager.dart';
import 'blob_worker.dart';

/// Coordinates flat particle buffers, background isolate execution,
/// and CPU-based synchronous projection fallback for [BlobFlutter].
class BlobParticleCoordinator {
  Float32List _baseSphere = Float32List(0);
  Float32List _projectedPoints = Float32List(0);
  Float32List? _recycleBuffer;

  BlobWorker? _worker;
  bool _workerReady = false;
  bool _workerBusy = false;

  /// Flat buffer containing 3D coordinates (x, y, z) on a unit sphere.
  Float32List get baseSphere => _baseSphere;

  /// Flat buffer containing projected 2D coordinates (x, y) rendered on canvas.
  Float32List get projectedPoints => _projectedPoints;

  /// Whether the background computation worker isolate is initialized and available.
  bool get isWorkerReady => _workerReady;

  /// Generates or resizes the flat Float32List buffers.
  void generateBuffers(int count) {
    _baseSphere = BlobMath.generateFibonacciSphere(count);
    final newLength = count * 2;
    if (_projectedPoints.length != newLength) {
      _recycleBuffer = null;
      final oldPoints = _projectedPoints;
      _projectedPoints = Float32List(newLength);
      final copyLen =
          oldPoints.length < newLength ? oldPoints.length : newLength;
      if (copyLen > 0) {
        _projectedPoints.setRange(0, copyLen, oldPoints);
      }
    }
  }

  /// Spawns and initializes the background worker isolate.
  void startWorker({
    required int particleCount,
    BlobWorker Function()? workerFactory,
    required void Function(
      BlobFlutterException error,
      StackTrace? stackTrace, {
      required bool isAsync,
    }) onError,
    required VoidCallback onWorkerReady,
  }) {
    try {
      final w = workerFactory?.call() ?? BlobWorker();
      _worker = w;
      w.init(
        _baseSphere,
        particleCount,
        onError: (exception) {
          if (_worker != w) return;
          // Isolate unhandled error after successful handshake.
          onError(exception, exception.stackTrace, isAsync: true);
        },
      ).then((_) {
        if (_worker == w) {
          _workerReady = true;
          onWorkerReady();
        }
      }).catchError((Object err, StackTrace st) {
        if (_worker != w) return;
        final exception =
            BlobWorkerException.spawnFailed(cause: err, stackTrace: st);
        _workerReady = false;
        onError(exception, st, isAsync: true);
      });
    } catch (err, st) {
      final exception =
          BlobWorkerException.spawnFailed(cause: err, stackTrace: st);
      _workerReady = false;
      onError(exception, st, isAsync: false);
    }
  }

  /// Disposes existing worker and restarts with current particle buffers.
  void restartWorker({
    required int particleCount,
    BlobWorker Function()? workerFactory,
    required void Function(
      BlobFlutterException error,
      StackTrace? stackTrace, {
      required bool isAsync,
    }) onError,
    required VoidCallback onWorkerReady,
  }) {
    _worker?.dispose();
    _workerReady = false;
    _workerBusy = false;
    startWorker(
      particleCount: particleCount,
      workerFactory: workerFactory,
      onError: onError,
      onWorkerReady: onWorkerReady,
    );
  }

  /// Builds worker computation parameters for the current frame.
  ProjectParamsFlat buildWorkerParams({
    required BlobController controller,
    required BlobTouchManager touchManager,
    required Size cachedSize,
    required double time,
    required BuildContext context,
  }) {
    touchManager.updateLocalTouches(context);
    final double alignOffsetX =
        controller.alignment.x * (cachedSize.width / 2.0);
    final double alignOffsetY =
        controller.alignment.y * (cachedSize.height / 2.0);

    return ProjectParamsFlat(
      count: controller.particleCount,
      radius: controller.radius,
      scale: controller.scale,
      centerOffsetX: controller.centerOffset.dx + alignOffsetX,
      centerOffsetY: controller.centerOffset.dy + alignOffsetY,
      blobiness: controller.blobiness,
      dispersion: controller.dispersion,
      rotationX: controller.rotationX,
      rotationY: controller.rotationY,
      time: time,
      viewportWidth: cachedSize.width,
      viewportHeight: cachedSize.height,
      encodedTouches: touchManager.encodedTouches,
      autoRotationSpeed: controller.autoRotationSpeed,
      noiseFrequency: controller.noiseFrequency,
      viewDistance: controller.viewDistance,
      noiseTypeIndex: controller.noiseType.index,
      touchRadiusFactor: controller.touchRadiusFactor,
    );
  }

  /// Executes synchronous CPU projection directly on the main thread.
  void projectParticlesSync({
    required BlobController controller,
    required BlobTouchManager touchManager,
    required Size cachedSize,
    required double time,
    required BuildContext context,
  }) {
    if (_baseSphere.length ~/ 3 != controller.particleCount) {
      generateBuffers(controller.particleCount);
    }
    touchManager.updateLocalTouches(context);
    final double alignOffsetX =
        controller.alignment.x * (cachedSize.width / 2.0);
    final double alignOffsetY =
        controller.alignment.y * (cachedSize.height / 2.0);

    BlobMath.projectParticles(
      count: controller.particleCount,
      radius: controller.radius,
      scale: controller.scale,
      centerOffsetX: controller.centerOffset.dx + alignOffsetX,
      centerOffsetY: controller.centerOffset.dy + alignOffsetY,
      blobiness: controller.blobiness,
      dispersion: controller.dispersion,
      rotationX: controller.rotationX,
      rotationY: controller.rotationY,
      time: time,
      viewportWidth: cachedSize.width,
      viewportHeight: cachedSize.height,
      activeTouches: touchManager.localTouchesFlat,
      baseSphere: _baseSphere,
      projectedPoints: _projectedPoints,
      autoRotationSpeed: controller.autoRotationSpeed,
      noiseFrequency: controller.noiseFrequency,
      viewDistance: controller.viewDistance,
      noiseType: controller.noiseType,
      customNoise: controller.customNoise,
      touchRadiusFactor: controller.touchRadiusFactor,
    );
  }

  /// Processes frame computation on animation tick.
  ///
  /// [onComputeError] is called if the background worker raises an exception
  /// during an active compute call. The frame is skipped gracefully.
  void processTick({
    required BlobController controller,
    required BlobTouchManager touchManager,
    required Size cachedSize,
    required double time,
    required BuildContext context,
    required bool isStillMounted,
    required VoidCallback onFrameUpdated,
    void Function(BlobFlutterException error, StackTrace? stackTrace)?
        onComputeError,
  }) {
    final bool isCustomWithNoise =
        controller.noiseType == BlobNoiseType.custom &&
            controller.customNoise != null;

    if (isCustomWithNoise) {
      // Custom noise callbacks (such as anonymous closures or lambdas) cannot be serialized
      // across isolate boundaries via SendPort in Dart. We execute CPU projection directly
      // on the main thread (<0.5ms for 3,000 particles) with zero GC and full closure compatibility.
      projectParticlesSync(
        controller: controller,
        touchManager: touchManager,
        cachedSize: cachedSize,
        time: time,
        context: context,
      );
      onFrameUpdated();
    } else if (_workerReady && !_workerBusy) {
      _workerBusy = true;
      final recycle = _recycleBuffer;
      _recycleBuffer = null;
      final params = buildWorkerParams(
        controller: controller,
        touchManager: touchManager,
        cachedSize: cachedSize,
        time: time,
        context: context,
      );
      _worker!.compute(params, recycle).then((result) {
        _workerBusy = false;
        if (!isStillMounted || result == null) return;
        if (_projectedPoints.isNotEmpty) {
          _recycleBuffer = _projectedPoints;
        }
        _projectedPoints = result;
        onFrameUpdated();
      }).catchError((Object err, StackTrace st) {
        // Compute error: worker stays alive but we skip this frame's result.
        _workerBusy = false;
        final exception =
            BlobWorkerException.computeFailed(cause: err, stackTrace: st);
        onComputeError?.call(exception, st);
      });
    } else if (!_workerReady) {
      projectParticlesSync(
        controller: controller,
        touchManager: touchManager,
        cachedSize: cachedSize,
        time: time,
        context: context,
      );
      onFrameUpdated();
    } else if (controller.isColorAnimated || controller.isRainbowMode) {
      // Worker is computing next particle positions; refresh frame for color animation
      onFrameUpdated();
    }
  }

  /// Test hook to simulate unexpected error during static frame render in test environments.
  @visibleForTesting
  static void Function()? debugOnRenderStaticFrame;

  /// Renders a single static frame (used when paused or resizing).
  void renderStaticFrame({
    required BlobController controller,
    required BlobTouchManager touchManager,
    required Size cachedSize,
    required double time,
    required BuildContext context,
    required VoidCallback onFrameUpdated,
  }) {
    if (cachedSize == Size.zero) return;
    if (debugOnRenderStaticFrame != null) {
      debugOnRenderStaticFrame!();
    }
    projectParticlesSync(
      controller: controller,
      touchManager: touchManager,
      cachedSize: cachedSize,
      time: time,
      context: context,
    );
    onFrameUpdated();
  }

  /// Disposes background worker isolate.
  void dispose() {
    _worker?.dispose();
    _worker = null;
    _workerReady = false;
    _workerBusy = false;
  }
}
