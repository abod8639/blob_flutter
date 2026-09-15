import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'blob_compute_params.dart';
import 'blob_exception.dart';
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
/// ### Error Handling
/// * Isolate errors are captured via a dedicated error [ReceivePort] and
///   forwarded through the optional [onError] callback passed to [init].
/// * If the isolate crashes before the handshake completes, the [Future]
///   returned by [init] completes with an error rather than hanging forever.
///
/// ### Lifecycle
/// Call [init] once, then [compute] for every frame, then [dispose] on
/// teardown (e.g., from [State.dispose]).
class BlobWorker {
  final ReceivePort _rx = ReceivePort();
  final ReceivePort _errorPort = ReceivePort();
  Isolate? _isolate;
  SendPort? _tx;

  final Completer<void> _readyCompleter = Completer<void>();
  final List<Completer<Float32List?>> _pending = [];
  bool _disposed = false;
  bool _initStarted = false;

  /// `true` once the worker isolate has sent its [SendPort] back.
  bool get isReady => _tx != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Spawns the worker [Isolate] and transfers [baseSphere] to it.
  ///
  /// The returned [Future] completes when the worker is ready to accept
  /// [compute] requests, or completes with an error if the isolate fails
  /// to initialise.
  ///
  /// [onError] is called with a [BlobWorkerException] whenever the isolate
  /// reports an unhandled error after the initial handshake.
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) async {
    _initStarted = true;
    _rx.listen(_onMessage);

    // Subscribe to isolate error port before spawning so we never miss an
    // early crash.
    _errorPort.listen((dynamic errorMessage) {
      // Dart sends errors as a two-element list: [errorString, stackString].
      final String errorStr = errorMessage is List && errorMessage.isNotEmpty
          ? errorMessage[0].toString()
          : errorMessage.toString();
      final String? stackStr =
          errorMessage is List && errorMessage.length > 1
              ? errorMessage[1]?.toString()
              : null;
      final StackTrace? stackTrace =
          stackStr != null ? StackTrace.fromString(stackStr) : null;

      final exception = BlobWorkerException.spawnFailed(
        cause: errorStr,
        stackTrace: stackTrace,
      );

      // If the isolate crashed before sending the handshake port, complete
      // the readyCompleter with an error so the caller is not left hanging.
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(exception, stackTrace);
      }

      onError?.call(exception);
    });

    _isolate = await Isolate.spawn(
      _workerEntry,
      [_rx.sendPort, baseSphere, count],
      debugName: 'blob_particle_worker',
      errorsAreFatal: false,
      onError: _errorPort.sendPort,
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

  final List<Object?> _paramsBuffer = List<Object?>.filled(18, null);

  /// Submits [params] to the worker for parallel computation.
  ///
  /// When [recycleBuffer] is provided (e.g. from a previous frame), its memory
  /// is transferred zero-copy to the worker isolate and reused directly as the
  /// output projection buffer, eliminating per-frame heap allocations (Double Buffering).
  ///
  /// Returns a [Future] that resolves with the projected [Float32List] when
  /// the worker finishes.  Returns `null` if [dispose] has been called.
  Future<Float32List?> compute(ProjectParamsFlat params, [Float32List? recycleBuffer]) {
    if (_tx == null || _disposed) return Future.value(null);
    final completer = Completer<Float32List?>();
    _pending.add(completer);
    final TransferableTypedData? transferableRecycled = recycleBuffer != null
        ? TransferableTypedData.fromList([recycleBuffer])
        : null;
    _tx!.send([params.toMessage(_paramsBuffer), transferableRecycled]);
    return completer.future;
  }

  /// Kills the worker [Isolate] and releases all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rx.close();
    _errorPort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    for (final c in _pending) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
    // Only complete the ready completer with error if init() was actually
    // called. If dispose() is called on a worker that was never initialized
    // (e.g. in a test teardown), we skip this to avoid unexpected exceptions.
    if (_initStarted && !_readyCompleter.isCompleted) {
      _readyCompleter.completeError(
        BlobWorkerException.spawnFailed(cause: 'Worker disposed before ready.'),
      );
    }
  }

  // ── Isolate Entry Point ───────────────────────────────────────────────────

  /// Runs inside the spawned [Isolate].
  ///
  /// The worker keeps [baseSphere] in its own heap and processes frame
  /// messages in a tight `for` loop, returning results via
  /// [TransferableTypedData] (zero-copy).
  static void _workerEntry(List<Object?> args) async {
    final mainPort = args[0] as SendPort;
    final sphere = args[1] as Float32List;
    final count = args[2] as int;

    // Send our port back to the main isolate (handshake).
    final rx = ReceivePort();
    mainPort.send(rx.sendPort);

    await for (final msg in rx) {
      if (msg is! List) continue;

      final Object? first = msg.isNotEmpty ? msg[0] : null;
      final List<dynamic> paramsList;
      final TransferableTypedData? recycledTransferable;

      if (first is List) {
        paramsList = first;
        recycledTransferable =
            msg.length > 1 ? msg[1] as TransferableTypedData? : null;
      } else {
        paramsList = msg;
        recycledTransferable = null;
      }

      final p = ProjectParamsFlat.fromMessage(paramsList);

      // Reuse recycled buffer if available and matches dimensions, otherwise allocate.
      Float32List output;
      if (recycledTransferable != null) {
        output = recycledTransferable.materialize().asFloat32List();
        if (output.length != count * 2) {
          output = Float32List(count * 2);
        }
      } else {
        output = Float32List(count * 2);
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
        baseSphere: sphere,
        projectedPoints: output,
        autoRotationSpeed: p.autoRotationSpeed,
        noiseFrequency: p.noiseFrequency,
        viewDistance: p.viewDistance,
        noiseType: BlobNoiseType.values[p.noiseTypeIndex],
        touchRadiusFactor: p.touchRadiusFactor,
      );

      // Transfer ownership back to main isolate — zero-copy on native.
      mainPort.send(TransferableTypedData.fromList([output]));
    }
  }
}
