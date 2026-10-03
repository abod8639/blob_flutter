import 'dart:typed_data';

import 'package:blob_flutter/blob_flutter.dart';

import 'blob_compute_params.dart';

/// Flutter Web stub for [BlobWorker].
///
/// Flutter Web does not support spawning true [Isolate]s via
/// `dart:isolate`.  This stub exposes the same async [BlobWorker] API but
/// executes the particle computation **synchronously** on the main thread,
/// preserving the original performance characteristics on Web while allowing
/// native builds to benefit from the parallel Isolate implementation.
///
/// The [Future] returned by [compute] resolves in the same microtask queue
/// (i.e., before the next event-loop iteration), so the ticker callback
/// behaves identically to the native path from the widget's perspective.
class BlobWorker {
  late Float32List _sphere;
  late Float32List _output;
  bool _disposed = false;
  int _frameIndex = 0;

  /// No-op on Web: stores references needed for synchronous computation.
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) async {
    _sphere = baseSphere;
    _output = Float32List(count * 2);
    _disposed = false;
    _frameIndex = 0;
  }

  /// Runs [BlobMath.projectParticles] synchronously and returns a completed
  /// [Future] wrapping the result buffer.
  ///
  /// When [p.webTemporalInterleaving] is `true` and particle count is large
  /// (>= 1,000 particles), the computation is interleaved across two frames:
  /// - Even frames update even indices.
  /// - Odd frames update odd indices.
  ///
  /// This cuts the CPU execution time on the JavaScript main event loop by ~50%
  /// while preserving a smooth 60 FPS visual experience. On the initial frame
  /// or when buffer size changes, all particles are calculated to prevent
  /// uninitialized coordinates.
  Future<Float32List?> compute(ProjectParamsFlat p,
      [Float32List? recycleBuffer]) {
    if (_disposed) return Future.value(null);

    final int requiredLength = p.count * 2;
    if (_output.length != requiredLength) {
      _output = Float32List(requiredLength);
      _frameIndex = 0;
    }

    final bool shouldInterleave = p.isComplex;
    int startIndex = 0;
    int stride = 1;

    if (shouldInterleave) {
      if (_frameIndex > 0) {
        startIndex = _frameIndex % 2;
        stride = 2;
      }
      _frameIndex++;
    } else {
      _frameIndex = 0;
    }

    BlobMath.projectParticles(
      count: p.count,
      radius: p.radius,
      scale: p.scale,
      centerOffsetX: p.centerOffsetX,
      centerOffsetY: p.centerOffsetY,
      blobiness: p.blobiness,
      dispersion: p.dispersion,
      rotationX: p.rotationX,
      rotationY: p.rotationY,
      time: p.time,
      viewportWidth: p.viewportWidth,
      viewportHeight: p.viewportHeight,
      activeTouches: p.encodedTouches,
      baseSphere: _sphere,
      projectedPoints: _output,
      autoRotationSpeed: p.autoRotationSpeed,
      noiseFrequency: p.noiseFrequency,
      viewDistance: p.viewDistance,
      noiseType: BlobNoiseType.values[p.noiseTypeIndex],
      touchRadiusFactor: p.touchRadiusFactor,
      startIndex: startIndex,
      stride: stride,
    );

    // Return the pre-allocated buffer directly (no copy on Web).
    return Future.value(_output);
  }

  /// Marks worker as disposed.
  void dispose() {
    _disposed = true;
  }
}
