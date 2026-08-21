import 'dart:typed_data';

import 'blob_compute_params.dart';
import 'blob_math.dart';
import 'blob_noise_type.dart';

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

  /// No-op on Web: stores references needed for synchronous computation.
  Future<void> init(Float32List baseSphere, int count) async {
    _sphere = baseSphere;
    _output = Float32List(count * 2);
  }

  /// Runs [BlobMath.projectParticles] synchronously and returns a completed
  /// [Future] wrapping the result buffer.
  Future<Float32List?> compute(ProjectParamsFlat p) {
    BlobMath.projectParticles(
      count:             p.count,
      radius:            p.radius,
      scale:             p.scale,
      centerOffsetX:     p.centerOffsetX,
      centerOffsetY:     p.centerOffsetY,
      blobiness:         p.blobiness,
      dispersion:        p.dispersion,
      rotationX:         p.rotationX,
      rotationY:         p.rotationY,
      time:              p.time,
      viewportWidth:     p.viewportWidth,
      viewportHeight:    p.viewportHeight,
      activeTouches:     p.encodedTouches,
      baseSphere:        _sphere,
      projectedPoints:   _output,
      autoRotationSpeed: p.autoRotationSpeed,
      noiseFrequency:    p.noiseFrequency,
      viewDistance:      p.viewDistance,
      noiseType:         BlobNoiseType.values[p.noiseTypeIndex],
      touchRadiusFactor: p.touchRadiusFactor,
    );

    // Return the pre-allocated buffer directly (no copy on Web).
    return Future.value(_output);
  }

  /// No-op on Web.
  void dispose() {}
}
