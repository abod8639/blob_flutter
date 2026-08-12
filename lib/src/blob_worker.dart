/// Platform-aware particle-computation worker.
///
/// This library file uses Dart's conditional export mechanism to deliver the
/// correct implementation without any runtime `if` checks or `kIsWeb` guards:
///
/// * **Native** (iOS · Android · macOS · Windows · Linux): exports
///   [blob_worker_native.dart] — a persistent [Isolate] that offloads the
///   per-frame 3-D particle math loop off the main UI thread entirely.
///
/// * **Web** (Flutter Web / Wasm): exports [blob_worker_web.dart] — a
///   synchronous stub using the same public API.  Flutter Web does not
///   support `dart:isolate` `Isolate.spawn`, so the computation runs on the
///   main thread, unchanged from the pre-worker behaviour, while benefiting
///   from all other optimisations (noise-function hoisting, static Paint,
///   shader dirty-tracking, etc.).
///
/// Consumers import only this file; the platform split is transparent.
export 'blob_worker_native.dart'
    if (dart.library.js_interop) 'blob_worker_web.dart';
