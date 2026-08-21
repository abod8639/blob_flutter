import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'blob_compute_params.dart';
import 'blob_math.dart';
import 'blob_noise_type.dart';

/// Native particle-computation worker backed by a **persistent** [Isolate].
///
/// ### Architecture
/// * [baseSphere] geometry is sent **once** during [init] and stored in the
///   worker's heap.  No per-frame sphere copy.
/// * Each frame, a compact message list (13 doubles + a small touch buffer)
///   is sent via [SendPort].
/// * Results are returned as [TransferableTypedData] — **zero-copy** on
///   native platforms (iOS, Android, macOS, Windows, Linux).
/// * Only **one** computation is in-flight at any time.  A new [compute] call
///   while the previous is still running is queued; results arrive in order.
///
/// ### Lifecycle
/// Call [init] once, then [compute] for every frame, then [dispose] on
/// teardown (e.g., from [State.dispose]).
class BlobWorker {
  final ReceivePort _rx = ReceivePort();
  Isolate? _isolate;
  SendPort? _tx;

  final Completer<void> _readyCompleter = Completer<void>();
  final List<Completer<Float32List?>> _pending = [];
  bool _disposed = false;

  /// `true` once the worker isolate has sent its [SendPort] back.
  bool get isReady => _tx != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Spawns the worker [Isolate] and transfers [baseSphere] to it.
  ///
  /// The returned [Future] completes when the worker is ready to accept
  /// [compute] requests.
  Future<void> init(Float32List baseSphere, int count) async {
    _rx.listen(_onMessage);

    _isolate = await Isolate.spawn(
      _workerEntry,
      [_rx.sendPort, baseSphere, count],
      debugName: 'blob_particle_worker',
      errorsAreFatal: false,
    );

    return _readyCompleter.future;
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      // Handshake: worker sends its port first.
      _tx = msg;
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      return;
    }
    if (msg is TransferableTypedData && _pending.isNotEmpty) {
      // Result: materialise zero-copy and fulfil the oldest pending completer.
      _pending.removeAt(0).complete(msg.materialize().asFloat32List());
    }
  }

  /// Submits [params] to the worker for parallel computation.
  ///
  /// Returns a [Future] that resolves with the projected [Float32List] when
  /// the worker finishes.  Returns `null` if [dispose] has been called.
  Future<Float32List?> compute(ProjectParamsFlat params) {
    if (_tx == null || _disposed) return Future.value(null);
    final completer = Completer<Float32List?>();
    _pending.add(completer);
    _tx!.send(params.toMessage());
    return completer.future;
  }

  /// Kills the worker [Isolate] and releases all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rx.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    for (final c in _pending) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
  }

  // ── Isolate Entry Point ───────────────────────────────────────────────────

  /// Runs inside the spawned [Isolate].
  ///
  /// The worker keeps [baseSphere] in its own heap and processes frame
  /// messages in a tight `for` loop, returning results via
  /// [TransferableTypedData] (zero-copy).
  static void _workerEntry(List<Object?> args) async {
    final mainPort  = args[0] as SendPort;
    final sphere    = args[1] as Float32List;
    final count     = args[2] as int;

    // Send our port back to the main isolate (handshake).
    final rx = ReceivePort();
    mainPort.send(rx.sendPort);

    await for (final msg in rx) {
      if (msg is! List) continue;

      final p = ProjectParamsFlat.fromMessage(msg.cast<dynamic>());

      // Compute projected positions into a fresh buffer.
      final output = Float32List(count * 2);
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
        baseSphere:        sphere,
        projectedPoints:   output,
        autoRotationSpeed: p.autoRotationSpeed,
        noiseFrequency:    p.noiseFrequency,
        viewDistance:      p.viewDistance,
        noiseType:         BlobNoiseType.values[p.noiseTypeIndex],
        touchRadiusFactor: p.touchRadiusFactor,
      );

      // Transfer ownership back to main isolate — zero-copy on native.
      // After this call `output` is neutered; we allocate a fresh buffer
      // at the top of each iteration, so there is no use-after-transfer.
      mainPort.send(TransferableTypedData.fromList([output]));
    }
  }
}
