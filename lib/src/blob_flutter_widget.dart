import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'blob_controller.dart';
import 'blob_exception.dart';
import 'blob_input_listener.dart';
import 'blob_math.dart';
import 'blob_noise_type.dart';
import 'blob_painter.dart';
import 'blob_particle_coordinator.dart';
import 'blob_shader_coordinator.dart';
import 'blob_shader_helper.dart';
import 'blob_touch_manager.dart';
import 'blob_visibility_manager.dart';
import 'blob_worker.dart';

/// A high-performance Flutter widget that renders an animated 3D particle blob.
///
/// Particles are distributed uniformly on a 3D sphere via the Fibonacci lattice
/// algorithm and deformed over time using procedural noise algorithms. The result is
/// projected to 2D via perspective division and rendered in a single GPU draw
/// call using [Canvas.drawRawPoints].
///
/// All rendering data is managed in flat `Float32List` buffers to eliminate
/// Garbage Collection pressure. A `FragmentShader` handles per-pixel
/// coloring on the GPU.
///
/// ## Interaction & Physics
/// - **Drag**: Rotates the blob with realistic inertial damping.
/// - **Pinch-to-Scale**: Multi-touch zoom in/out (configurable via [BlobController.pinchToScale]).
/// - **Tap & Hold**: Disperses the particles radially outward.
/// - **Mouse Hover** (desktop/web): Tracks cursor and applies subtle rotation/dispersion.
///
/// ## Full Runtime Control via [BlobController]
/// All geometric properties (`radius`, `pointSize`, `particleCount`, `scale`, `centerOffset`, `alignment`),
/// physics (`speed`, `blobiness`, `dispersion`, `dampingFactor`), noise modes ([BlobNoiseType]),
/// and shaders ([gradient], `isRainbowMode`) can be controlled dynamically at runtime
/// without rebuilding the widget tree.
class BlobFlutter extends StatefulWidget {
  /// Global toggle controlling whether [BlobFlutter] automatically starts
  /// playing when running in a test environment (`flutter_test`).
  ///
  /// Defaults to `false` so that `WidgetTester.pumpAndSettle` does not time out.
  /// Set to `true` if your test suite explicitly pumps frames via `tester.pump(duration)`
  /// and expects tickers to run without manual activation.
  static bool autoPlayInTests = false;

  /// Whether the current execution context is inside a Flutter test environment.
  static bool get isRunningInTest => BlobShaderHelper.isRunningInTest;

  // ── Controller-managed parameter storage (nullable for conflict detection) ─
  final int? _particleCount;
  final double? _radius;
  final double? _pointSize;
  final double? _speed;
  final double? _tapScaleFactor;
  final double? _touchRadiusFactor;
  final Gradient? _gradient;
  final bool? _isColorAnimated;
  final double? _colorAnimationSpeed;
  final double? _waveIntensity;
  final bool? _hover;
  final bool? _dragRotation;
  final bool? _hoverRotation;
  final bool? _pinchToScale;
  final double? _rotationX;
  final double? _rotationY;
  final BlobNoiseType? _noiseType;
  final BlobCustomNoiseFunction? _customNoise;
  final bool? _autoFit;
  final double? _radiusFactor;
  final bool? _webTemporalInterleaving;
  final int? _maxWebParticles;
  final bool? _isComplex;
  final bool? _enableDepthSort;
  final bool? _enableDepthCueing;
  final double? _depthCueingFactor;

  /// Whether the blob automatically resizes its radius to fit the parent container bounds.
  ///
  /// When `true` and the container has bounded dimensions, the radius is calculated
  /// dynamically as `(min(width, height) / 2.0) * radiusFactor`.
  ///
  /// Default: `false`.
  bool get autoFit => _autoFit ?? false;

  /// Multiplier applied to half the minimum container dimension when [autoFit] is enabled.
  ///
  /// Default: 0.85 (leaves 15% breathing room for wave undulations and particle displacement).
  double get radiusFactor => _radiusFactor ?? 0.85;

  /// Whether temporal interleaving is enabled on Flutter Web to alternate particle updates
  /// across successive frames for smooth 60 FPS performance on single-threaded JavaScript.
  ///
  /// Default: `true`.
  bool get webTemporalInterleaving => _webTemporalInterleaving ?? true;

  /// Maximum particle cap automatically enforced when running on Flutter Web.
  ///
  /// Prevents single-threaded JavaScript main event loop lockups when high particle counts
  /// (e.g. 5,000 to 10,000) are configured for native platforms.
  /// Default: `3000`. Set to `null` to disable capping.
  int? get maxWebParticles => _maxWebParticles;

  /// Whether temporal interleaving / striding across frames is enabled.
  ///
  /// When `true`, particle projection is interleaved across alternating frames
  /// (even and odd strides) to cut CPU computation time in half.
  /// When `false` (default), all particles are computed fully on every frame.
  bool get isComplex => _isComplex ?? false;

  /// Whether depth sorting (Painter's algorithm: back-to-front rendering) is enabled.
  ///
  /// When `true` (default), particles are sorted by their 3D depth (Z) so that
  /// foreground particles properly occlude background particles.
  bool get enableDepthSort => _enableDepthSort ?? true;

  /// Whether depth-cueing (size attenuation across depth slices) is enabled.
  ///
  /// When `true` (default), distant particles appear smaller and nearer particles appear larger.
  bool get enableDepthCueing => _enableDepthCueing ?? true;

  /// Intensity of depth-cueing perspective scaling. Range: `[0.0, 1.0]`. Default: 0.4.
  double get depthCueingFactor => _depthCueingFactor ?? 0.4;

  /// Total number of particles. Default: 5000.
  int get particleCount => _particleCount ?? 5000;

  /// Base unscaled radius of the 3D particle sphere or planar surface in logical pixels.
  double get radius => _radius ?? 150.0;

  /// Visual diameter of each rendered particle point in logical pixels.
  double get pointSize => _pointSize ?? 2.0;

  /// Optional external [BlobController] to inspect and dynamically modify blob
  /// properties (radius, rotation, speed, noise type, colors, dispersion) at runtime.
  ///
  /// When provided, the widget binds to this controller. When `null`, an internal
  /// controller is automatically created and managed by the widget's lifecycle.
  final BlobController? controller;

  /// Impulse intensity multiplier applied to particle dispersion upon touch, tap, or click.
  double get tapScaleFactor => _tapScaleFactor ?? 0.40;

  /// Area of influence multiplier for interactive pointer touches relative to [radius].
  double get touchRadiusFactor => _touchRadiusFactor ?? 0.30;

  /// The color gradient applied to particles via the GPU fragment shader.
  Gradient get gradient =>
      _gradient ??
      const LinearGradient(
        colors: [Colors.blueAccent, Colors.purpleAccent],
      );

  /// Playback speed multiplier for procedural noise deformations and wave undulations.
  double get speed => _speed ?? 1.0;

  /// Whether the shader gradient dynamically flows and shifts across particles over time.
  bool get isColorAnimated => _isColorAnimated ?? true;

  /// Speed multiplier for the GPU color gradient flow animation.
  double get colorAnimationSpeed => _colorAnimationSpeed ?? 1.0;

  /// Intensity of wave distortion and refraction shimmer applied to the color shader.
  double get waveIntensity => _waveIntensity ?? 1.0;

  /// Whether particles disperse and react to mouse cursor hovering without clicking.
  bool get hover => _hover ?? false;

  /// Whether mouse/touch drag gestures rotate and spin the 3D object on the canvas.
  bool get dragRotation => _dragRotation ?? false;

  /// Whether moving the mouse cursor without clicking applies subtle 3D tilt towards the cursor.
  bool get hoverRotation => _hoverRotation ?? false;

  /// Whether multi-touch pinch-to-scale zooming is enabled.
  bool get pinchToScale => _pinchToScale ?? false;

  /// Initial persistent 3D orientation angle around the horizontal X-axis (pitch/tilt) in radians.
  double get rotationX => _rotationX ?? 0.0;

  /// Initial persistent 3D orientation angle around the vertical Y-axis (yaw/turn) in radians.
  double get rotationY => _rotationY ?? 0.0;

  /// The procedural mathematical deformation algorithm used to sculpt the particle mesh.
  BlobNoiseType get noiseType => _noiseType ?? BlobNoiseType.harmonic;

  /// User-defined procedural noise algorithm when [noiseType] is [BlobNoiseType.custom].
  BlobCustomNoiseFunction? get customNoise => _customNoise;

  /// Optional callback invoked when an error occurs during shader compilation,
  /// asset loading, or background worker isolate execution.
  final void Function(BlobFlutterException error, StackTrace? stackTrace)?
      onError;

  /// Optional custom widget builder displayed if an unrecoverable failure occurs.
  ///
  /// If `null` (default), the widget automatically falls back to lightweight CPU
  /// point rendering with default colors, ensuring your UI never crashes or breaks.
  final Widget Function(BuildContext context, BlobFlutterException error)?
      errorBuilder;

  /// Whether to suppress automatic FlutterError reporting to the debugging console.
  ///
  /// In production apps, defaults to `false`.
  /// In test environments (e.g. `flutter_test`), automatically defaults to `true`
  /// to prevent shader asset load failures from polluting or breaking test suites.
  final bool? silentErrorLogging;

  /// Internal testing override for verifying missing shader asset fallback handling.
  @visibleForTesting
  final String? testShaderAssetPath;

  /// Internal testing override for injecting or mocking a [BlobWorker].
  @visibleForTesting
  final BlobWorker Function()? workerFactory;

  /// Whether the animation loop starts playing automatically.
  ///
  /// In production apps, defaults to `true`.
  /// In test environments (e.g. `flutter_test`), automatically defaults to `false`
  /// to prevent `WidgetTester.pumpAndSettle` from timing out, unless explicitly
  /// set to `true` or enabled via [autoPlayInTests].
  final bool? autoPlay;

  /// Whether to automatically pause the animation ticker and computation
  /// when the widget scrolls offscreen or is outside the visible screen viewport.
  ///
  /// When `true` (default), detects when the widget leaves the visible screen
  /// (with a 50 logical pixel pre-wake buffer) and halts the animation ticker
  /// and worker isolate computation, saving CPU/GPU and battery. Resumes
  /// immediately upon scrolling back into view.
  final bool autoPauseOffscreen;

  /// Whether to automatically pause the animation ticker and computation
  /// when the application is in the background, minimized, or inactive.
  ///
  /// When `true` (default), uses [WidgetsBindingObserver] to pause the ticker on
  /// [AppLifecycleState.paused], [AppLifecycleState.inactive], and [AppLifecycleState.hidden],
  /// and automatically resumes when the app returns to [AppLifecycleState.resumed].
  final bool autoPauseOnAppBackground;

  /// Whether to automatically pause the animation ticker and computation
  /// when the current navigation route is covered, navigated away from, or inactive.
  ///
  /// When `true` (default), automatically listens to [ModalRoute] and halts the
  /// ticker and isolate computations when another page is pushed via [Navigator.push].
  /// Resumes seamlessly when the route becomes top/current again upon [Navigator.pop].
  final bool autoPauseOnRouteChange;

  /// Optional [RouteObserver] to subscribe to for navigation events.
  ///
  /// While [autoPauseOnRouteChange] automatically detects route transitions via
  /// [ModalRoute], providing a [RouteObserver] provides secondary confirmation via
  /// standard [RouteAware] lifecycle events.
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;

  /// Whether the blob responds to touch, drag, and mouse interactions.
  ///
  /// When `false`, touch gestures and mouse hover events are completely ignored
  /// and pass through seamlessly to underlying widgets in a [Stack] (ideal for
  /// background wallpapers or decorative illustrations).
  ///
  /// Default: `true`.
  final bool interactive;

  /// How pointer events should be hit-tested by the blob container.
  ///
  /// - [HitTestBehavior.translucent] (default): Receives pointer events within its
  ///   bounds to disperse particles and allow drag rotation while ALSO allowing
  ///   events to pass through to underlying widgets (e.g. buttons or text fields in a [Stack]).
  /// - [HitTestBehavior.opaque]: Completely absorbs all touch and mouse events.
  /// - [HitTestBehavior.deferToChild]: Only intercepts events if a hit-testable child is tapped.
  final HitTestBehavior hitTestBehavior;

  /// Creates a [BlobFlutter] widget.
  const BlobFlutter({
    super.key,
    int? particleCount,
    double? radius,
    double? pointSize,
    double? speed,
    double? tapScaleFactor,
    double? touchRadiusFactor,
    this.controller,
    Gradient? gradient,
    bool? isColorAnimated,
    double? colorAnimationSpeed,
    double? waveIntensity,
    bool? hover,
    bool? dragRotation,
    bool? hoverRotation,
    bool? pinchToScale,
    this.interactive = true,
    this.hitTestBehavior = HitTestBehavior.translucent,
    double? rotationX,
    double? rotationY,
    BlobNoiseType? noiseType,
    BlobCustomNoiseFunction? customNoise,
    this.onError,
    this.errorBuilder,
    this.silentErrorLogging,
    this.testShaderAssetPath,
    this.workerFactory,
    this.autoPlay,
    this.autoPauseOffscreen = true,
    this.autoPauseOnAppBackground = true,
    this.autoPauseOnRouteChange = true,
    this.routeObserver,
    bool? autoFit,
    double? radiusFactor,
    bool? webTemporalInterleaving,
    int? maxWebParticles,
    bool? isComplex,
    bool? enableDepthSort,
    bool? enableDepthCueing,
    double? depthCueingFactor,
  })  : _particleCount = particleCount,
        _radius = radius,
        _pointSize = pointSize,
        _speed = speed,
        _tapScaleFactor = tapScaleFactor,
        _touchRadiusFactor = touchRadiusFactor,
        _gradient = gradient,
        _isColorAnimated = isColorAnimated,
        _colorAnimationSpeed = colorAnimationSpeed,
        _waveIntensity = waveIntensity,
        _hover = hover,
        _dragRotation = dragRotation,
        _hoverRotation = hoverRotation,
        _pinchToScale = pinchToScale,
        _rotationX = rotationX,
        _rotationY = rotationY,
        _noiseType = noiseType,
        _customNoise = customNoise,
        _autoFit = autoFit,
        _radiusFactor = radiusFactor,
        _webTemporalInterleaving = webTemporalInterleaving,
        _maxWebParticles = maxWebParticles,
        _isComplex = isComplex,
        _enableDepthSort = enableDepthSort,
        _enableDepthCueing = enableDepthCueing,
        _depthCueingFactor = depthCueingFactor,
        assert(
          maxWebParticles == null || maxWebParticles > 0,
          "BlobFlutter: 'maxWebParticles' must be positive or null (received $maxWebParticles). "
          'Example fix: BlobFlutter(maxWebParticles: 3000).',
        ),
        assert(
          radiusFactor == null || (radiusFactor > 0.0 && radiusFactor <= 2.0),
          "BlobFlutter: 'radiusFactor' must be between 0.0 and 2.0 (received $radiusFactor). "
          'Example fix: BlobFlutter(radiusFactor: 0.85).',
        ),
        assert(
          depthCueingFactor == null ||
              (depthCueingFactor >= 0.0 && depthCueingFactor <= 1.0),
          "BlobFlutter: 'depthCueingFactor' must be between 0.0 and 1.0 (received $depthCueingFactor). "
          'Example fix: BlobFlutter(depthCueingFactor: 0.4).',
        ),
        assert(
          particleCount == null || particleCount > 0,
          "BlobFlutter: 'particleCount' must be greater than 0 (received $particleCount). "
          'Example fix: BlobFlutter(particleCount: 5000).',
        ),
        assert(
          radius == null || radius > 0.0,
          "BlobFlutter: 'radius' must be greater than 0.0 (received $radius). "
          'Example fix: BlobFlutter(radius: 150.0).',
        ),
        assert(
          pointSize == null || pointSize > 0.0,
          "BlobFlutter: 'pointSize' must be greater than 0.0 (received $pointSize). "
          'Example fix: BlobFlutter(pointSize: 2.0).',
        ),
        assert(
          speed == null || speed >= 0.0,
          "BlobFlutter: 'speed' must be non-negative (received $speed). "
          'Example fix: BlobFlutter(speed: 1.0).',
        ),
        assert(
          tapScaleFactor == null || tapScaleFactor >= 0.0,
          "BlobFlutter: 'tapScaleFactor' must be non-negative (received $tapScaleFactor). "
          'Example fix: BlobFlutter(tapScaleFactor: 0.40).',
        ),
        assert(
          touchRadiusFactor == null || touchRadiusFactor >= 0.0,
          "BlobFlutter: 'touchRadiusFactor' must be non-negative (received $touchRadiusFactor). "
          'Example fix: BlobFlutter(touchRadiusFactor: 0.30).',
        ),
        assert(
          colorAnimationSpeed == null || colorAnimationSpeed >= 0.0,
          "BlobFlutter: 'colorAnimationSpeed' must be non-negative (received $colorAnimationSpeed). "
          'Example fix: BlobFlutter(colorAnimationSpeed: 1.0).',
        ),
        assert(
          waveIntensity == null || waveIntensity >= 0.0,
          "BlobFlutter: 'waveIntensity' must be non-negative (received $waveIntensity). "
          'Example fix: BlobFlutter(waveIntensity: 1.0).',
        );

  /// Returns a list of parameter names passed directly to [BlobFlutter] that
  /// conflict with an attached [controller].
  static List<String> findConflictingParameters(BlobFlutter w) {
    if (w.controller == null) return const [];
    final list = <String>[];
    if (w._particleCount != null) list.add('particleCount');
    if (w._radius != null) list.add('radius');
    if (w._pointSize != null) list.add('pointSize');
    if (w._speed != null) list.add('speed');
    if (w._tapScaleFactor != null) list.add('tapScaleFactor');
    if (w._touchRadiusFactor != null) list.add('touchRadiusFactor');
    if (w._gradient != null) list.add('gradient');
    if (w._isColorAnimated != null) list.add('isColorAnimated');
    if (w._colorAnimationSpeed != null) list.add('colorAnimationSpeed');
    if (w._waveIntensity != null) list.add('waveIntensity');
    if (w._hover != null) list.add('hover');
    if (w._dragRotation != null) list.add('dragRotation');
    if (w._hoverRotation != null) list.add('hoverRotation');
    if (w._pinchToScale != null) list.add('pinchToScale');
    if (w._rotationX != null) list.add('rotationX');
    if (w._rotationY != null) list.add('rotationY');
    if (w._noiseType != null) list.add('noiseType');
    if (w._customNoise != null) list.add('customNoise');
    if (w._autoFit != null) list.add('autoFit');
    if (w._radiusFactor != null) list.add('radiusFactor');
    if (w._webTemporalInterleaving != null) list.add('webTemporalInterleaving');
    if (w._maxWebParticles != null) list.add('maxWebParticles');
    if (w._isComplex != null) list.add('isComplex');
    if (w._enableDepthSort != null) list.add('enableDepthSort');
    if (w._enableDepthCueing != null) list.add('enableDepthCueing');
    if (w._depthCueingFactor != null) list.add('depthCueingFactor');
    return list;
  }

  @override
  State<BlobFlutter> createState() => _ParticleBlobState();
}

class _ParticleBlobState extends State<BlobFlutter>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animation ──────────────────────────────────────────────────────────────

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Continuous animation clock (seconds). Wraps to prevent float precision loss.
  double _time = 0.0;

  /// Drives repaint only on CustomPaint, not the full widget tree.
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  int _frameCount = 0;

  // ── Coordinators & Managers ───────────────────────────────────────────────

  late final BlobVisibilityManager _visibilityManager;
  late final BlobShaderCoordinator _shaderCoordinator;
  late final BlobParticleCoordinator _particleCoordinator;
  final BlobTouchManager _touchManager = BlobTouchManager();

  // ── Controller ─────────────────────────────────────────────────────────────

  late BlobController _controller;
  bool _ownsController = false;
  int _lastParticleCount = 5000;

  // ── Layout & Paint ─────────────────────────────────────────────────────────

  Size _cachedSize = Size.zero;
  Offset _cachedCombinedOffset = Offset.zero;

  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  BlobFlutterException? _lastError;

  // ── Test Introspection Getters ─────────────────────────────────────────────

  /// Whether the internal animation ticker is currently actively ticking.
  @visibleForTesting
  bool get isTickerActive => _ticker.isActive;

  /// Whether the widget has detected that it is currently outside the screen viewport.
  @visibleForTesting
  bool get isOffscreen => _visibilityManager.isOffscreen;

  /// Whether the widget has detected that the application is in background/inactive state.
  @visibleForTesting
  bool get isAppInBackground => _visibilityManager.isAppInBackground;

  /// Whether the widget has detected that its hosting route is currently hidden or inactive.
  @visibleForTesting
  bool get isRouteHidden => _visibilityManager.isRouteHidden;

  /// Executes a single animation tick for testing deterministic tick handling.
  @visibleForTesting
  void onTickForTesting(Duration elapsed) => _onTick(elapsed);

  // ── Test & Environment Helpers ────────────────────────────────────────────

  bool get _effectiveAutoPlay =>
      widget.autoPlay ??
      (!BlobFlutter.isRunningInTest || BlobFlutter.autoPlayInTests);

  bool get _effectiveSilentErrorLogging =>
      widget.silentErrorLogging ?? BlobFlutter.isRunningInTest;

  bool get _shouldTickerRun =>
      !_controller.isPaused &&
      !(widget.autoPauseOnAppBackground &&
          _visibilityManager.isAppInBackground) &&
      !(widget.autoPauseOffscreen && _visibilityManager.isOffscreen) &&
      !(widget.autoPauseOnRouteChange && _visibilityManager.isRouteHidden);

  void _updateCombinedOffset() {
    _cachedCombinedOffset = Offset(
      _controller.centerOffset.dx +
          _controller.alignment.x * (_cachedSize.width / 2.0),
      _controller.centerOffset.dy +
          _controller.alignment.y * (_cachedSize.height / 2.0),
    );
  }

  void _reportControllerConflicts(
    List<String> conflicts,
    String contextDescription,
  ) {
    final exception =
        BlobControllerConflictException.fromParameters(conflicts);
    widget.onError?.call(exception, StackTrace.current);
    assert(() {
      if (!_effectiveSilentErrorLogging) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: StackTrace.current,
            library: 'blob_flutter',
            context: ErrorDescription(contextDescription),
            informationCollector: () => [
              ErrorSummary(
                'Parameters (${conflicts.join(', ')}) were passed alongside an external [controller].',
              ),
              ErrorDescription(
                'When [controller] is provided, it serves as the single source of truth. '
                'Widget-level parameters are ignored.',
              ),
              ErrorHint(
                'Configure these properties directly on the BlobController instance, '
                'or remove them from BlobFlutter.',
              ),
            ],
          ),
        );
      }
      return true;
    }());
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final conflicts = BlobFlutter.findConflictingParameters(widget);
    if (widget.controller != null && conflicts.isNotEmpty) {
      _reportControllerConflicts(
        conflicts,
        'while initializing BlobFlutter with conflicting parameters',
      );
    }
    WidgetsBinding.instance.addObserver(this);

    _visibilityManager = BlobVisibilityManager(
      onStateChanged: _syncTickerState,
    );
    _shaderCoordinator = BlobShaderCoordinator();
    _particleCoordinator = BlobParticleCoordinator();

    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        BlobController(
          radius: widget.radius,
          pointSize: widget.pointSize,
          particleCount: widget.particleCount,
          speed: widget.speed,
          tapScaleFactor: widget.tapScaleFactor,
          touchRadiusFactor: widget.touchRadiusFactor,
          rotationX: widget.rotationX,
          rotationY: widget.rotationY,
          hover: widget.hover,
          dragRotation: widget.dragRotation,
          hoverRotation: widget.hoverRotation,
          pinchToScale: widget.pinchToScale,
          isColorAnimated: widget.isColorAnimated,
          colorAnimationSpeed: widget.colorAnimationSpeed,
          waveIntensity: widget.waveIntensity,
          noiseType: widget.noiseType,
          customNoise: widget.customNoise,
          gradient: widget.gradient,
          isPaused: !_effectiveAutoPlay,
          autoFit: widget.autoFit,
          radiusFactor: widget.radiusFactor,
          webTemporalInterleaving: widget.webTemporalInterleaving,
          maxWebParticles: widget._maxWebParticles ?? 3000,
          isComplex: widget.isComplex,
          enableDepthSort: widget.enableDepthSort,
          enableDepthCueing: widget.enableDepthCueing,
          depthCueingFactor: widget.depthCueingFactor,
        );

    _lastParticleCount = _controller.effectiveParticleCount;
    _controller.addListener(_onControllerChanged);

    _particleCoordinator.generateBuffers(_lastParticleCount);
    _loadShader();
    _startWorker();

    _ticker = createTicker(_onTick);
    if (_shouldTickerRun) {
      _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibilityManager.updateDependencies(
      context: context,
      autoPauseOffscreen: widget.autoPauseOffscreen,
      autoPauseOnRouteChange: widget.autoPauseOnRouteChange,
      routeObserver: widget.routeObserver,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visibilityManager.handleAppLifecycleState(
      state,
      autoPauseOnAppBackground: widget.autoPauseOnAppBackground,
    );
  }

  void _onControllerChanged() {
    _updateCombinedOffset();
    if (_controller.effectiveParticleCount != _lastParticleCount) {
      _lastParticleCount = _controller.effectiveParticleCount;
      _particleCoordinator.generateBuffers(_lastParticleCount);
      _restartWorker();
    }
    _syncTickerState();
    if (_controller.isPaused && mounted) {
      _renderStaticFrame();
    }
  }

  void _syncTickerState() {
    if (!_shouldTickerRun) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
    } else {
      if (!_ticker.isActive && mounted) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _renderStaticFrame() {
    if (_cachedSize == Size.zero || !mounted) return;
    try {
      _updateCombinedOffset();
      _shaderCoordinator.updateDynamicUniforms(
        controller: _controller,
        widgetGradient: widget.gradient,
        cachedSize: _cachedSize,
        time: _time,
        onError: (renderError) {
          if (mounted) {
            setState(() => _lastError = renderError);
          }
          widget.onError?.call(renderError, renderError.stackTrace);
        },
      );
      _particleCoordinator.renderStaticFrame(
        controller: _controller,
        touchManager: _touchManager,
        cachedSize: _cachedSize,
        time: _time,
        context: context,
        onFrameUpdated: () {
          _frameCount++;
          _frameNotifier.value = _frameCount;
        },
      );
    } catch (err, st) {
      final exception = BlobFlutterException(
        message: 'Unexpected error during static frame render.',
        cause: err,
        stackTrace: st,
      );
      widget.onError?.call(exception, st);
    }
  }

  @override
  void didUpdateWidget(BlobFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);

    final conflicts = BlobFlutter.findConflictingParameters(widget);
    if (widget.controller != null && conflicts.isNotEmpty) {
      _reportControllerConflicts(
        conflicts,
        'while updating BlobFlutter with conflicting parameters',
      );
    }

    if (oldWidget.particleCount != widget.particleCount && _ownsController) {
      _controller.setParticleCount(widget.particleCount);
    }

    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller = widget.controller ??
          BlobController(
            radius: widget.radius,
            pointSize: widget.pointSize,
            particleCount: widget.particleCount,
            speed: widget.speed,
            tapScaleFactor: widget.tapScaleFactor,
            touchRadiusFactor: widget.touchRadiusFactor,
            rotationX: widget.rotationX,
            rotationY: widget.rotationY,
            hover: widget.hover,
            dragRotation: widget.dragRotation,
            hoverRotation: widget.hoverRotation,
            pinchToScale: widget.pinchToScale,
            isColorAnimated: widget.isColorAnimated,
            colorAnimationSpeed: widget.colorAnimationSpeed,
            waveIntensity: widget.waveIntensity,
            noiseType: widget.noiseType,
            gradient: widget.gradient,
            isPaused: !_effectiveAutoPlay,
            autoFit: widget.autoFit,
            radiusFactor: widget.radiusFactor,
            webTemporalInterleaving: widget.webTemporalInterleaving,
            maxWebParticles: widget._maxWebParticles ?? 3000,
            isComplex: widget.isComplex,
            enableDepthSort: widget.enableDepthSort,
            enableDepthCueing: widget.enableDepthCueing,
            depthCueingFactor: widget.depthCueingFactor,
          );
      _lastParticleCount = _controller.effectiveParticleCount;
      _controller.addListener(_onControllerChanged);
      _particleCoordinator.generateBuffers(_lastParticleCount);
      _restartWorker();
      _shaderCoordinator.markDirty();
      _syncTickerState();
    } else if (_ownsController) {
      bool staticChanged = false;
      if (oldWidget.autoPlay != widget.autoPlay) {
        _controller.setIsPaused(!_effectiveAutoPlay);
      }
      if (oldWidget.radius != widget.radius) {
        _controller.setRadius(widget.radius);
      }
      if (oldWidget.pointSize != widget.pointSize) {
        _controller.setPointSize(widget.pointSize);
      }
      if (oldWidget.speed != widget.speed) {
        _controller.setSpeed(widget.speed);
      }
      if (oldWidget.tapScaleFactor != widget.tapScaleFactor) {
        _controller.setTapScaleFactor(widget.tapScaleFactor);
      }
      if (oldWidget.touchRadiusFactor != widget.touchRadiusFactor) {
        _controller.setTouchRadiusFactor(widget.touchRadiusFactor);
      }
      if (oldWidget.isColorAnimated != widget.isColorAnimated) {
        _controller.setIsColorAnimated(widget.isColorAnimated);
        staticChanged = true;
      }
      if (oldWidget.colorAnimationSpeed != widget.colorAnimationSpeed) {
        _controller.setColorAnimationSpeed(widget.colorAnimationSpeed);
        staticChanged = true;
      }
      if (oldWidget.waveIntensity != widget.waveIntensity) {
        _controller.setWaveIntensity(widget.waveIntensity);
        staticChanged = true;
      }
      if (oldWidget.hover != widget.hover) {
        _controller.setHover(widget.hover);
      }
      if (oldWidget.dragRotation != widget.dragRotation) {
        _controller.setDragRotation(widget.dragRotation);
      }
      if (oldWidget.hoverRotation != widget.hoverRotation) {
        _controller.setHoverRotation(widget.hoverRotation);
      }
      if (oldWidget.autoFit != widget.autoFit) {
        _controller.setAutoFit(widget.autoFit);
      }
      if (oldWidget.radiusFactor != widget.radiusFactor) {
        _controller.setRadiusFactor(widget.radiusFactor);
      }
      if (oldWidget.webTemporalInterleaving != widget.webTemporalInterleaving) {
        _controller.setWebTemporalInterleaving(widget.webTemporalInterleaving);
      }
      if (oldWidget.maxWebParticles != widget.maxWebParticles) {
        _controller.setMaxWebParticles(widget.maxWebParticles);
      }
      if (oldWidget.isComplex != widget.isComplex) {
        _controller.setIsComplex(widget.isComplex);
      }
      if (oldWidget.enableDepthSort != widget.enableDepthSort) {
        _controller.setEnableDepthSort(widget.enableDepthSort);
      }
      if (oldWidget.enableDepthCueing != widget.enableDepthCueing) {
        _controller.setEnableDepthCueing(widget.enableDepthCueing);
      }
      if (oldWidget.depthCueingFactor != widget.depthCueingFactor) {
        _controller.setDepthCueingFactor(widget.depthCueingFactor);
      }
      if (oldWidget.pinchToScale != widget.pinchToScale) {
        _controller.setPinchToScale(widget.pinchToScale);
      }
      if (oldWidget.rotationX != widget.rotationX) {
        _controller.setRotationX(widget.rotationX);
      }
      if (oldWidget.rotationY != widget.rotationY) {
        _controller.setRotationY(widget.rotationY);
      }
      if (oldWidget.noiseType != widget.noiseType) {
        _controller.setNoiseType(widget.noiseType);
      }
      if (oldWidget.customNoise != widget.customNoise) {
        _controller.setCustomNoise(widget.customNoise, switchToCustom: false);
      }
      if (oldWidget.gradient != widget.gradient) {
        _controller.setGradient(widget.gradient);
        staticChanged = true;
        _shaderCoordinator.markDirty(colorsDirty: true);
      }
      if (staticChanged) _shaderCoordinator.markDirty(staticDirty: true);
    }

    _visibilityManager.handleWidgetUpdated(
      context: context,
      oldAutoPauseOffscreen: oldWidget.autoPauseOffscreen,
      newAutoPauseOffscreen: widget.autoPauseOffscreen,
      oldAutoPauseOnAppBackground: oldWidget.autoPauseOnAppBackground,
      newAutoPauseOnAppBackground: widget.autoPauseOnAppBackground,
      oldAutoPauseOnRouteChange: oldWidget.autoPauseOnRouteChange,
      newAutoPauseOnRouteChange: widget.autoPauseOnRouteChange,
      oldRouteObserver: oldWidget.routeObserver,
      newRouteObserver: widget.routeObserver,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibilityManager.dispose();
    _controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _frameNotifier.dispose();
    _shaderCoordinator.dispose();
    _particleCoordinator.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  // ── Initialization & Subsystem Startup ────────────────────────────────────

  void _loadShader() {
    _shaderCoordinator.loadShader(
      silent: _effectiveSilentErrorLogging,
      overrideAssetPath: widget.testShaderAssetPath,
      onError: (exception) {
        if (!mounted) return;
        setState(() {
          _lastError = exception;
        });
        widget.onError?.call(exception, exception.stackTrace);
      },
      onShaderLoaded: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _startWorker() {
    _particleCoordinator.startWorker(
      particleCount: _controller.effectiveParticleCount,
      workerFactory: widget.workerFactory,
      onError: (exception, st, {required bool isAsync}) {
        if (isAsync && mounted) {
          setState(() {
            _lastError = exception;
          });
        } else {
          _lastError = exception;
        }
        widget.onError?.call(exception, st);
      },
      onWorkerReady: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _restartWorker() {
    _particleCoordinator.restartWorker(
      particleCount: _controller.effectiveParticleCount,
      workerFactory: widget.workerFactory,
      onError: (exception, st, {required bool isAsync}) {
        if (isAsync && mounted) {
          setState(() {
            _lastError = exception;
          });
        } else {
          _lastError = exception;
        }
        widget.onError?.call(exception, st);
      },
      onWorkerReady: () {
        if (mounted) setState(() {});
      },
    );
  }

  // ── Ticker Callback ────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (!mounted || _cachedSize == Size.zero) return;

    if (_visibilityManager.checkTickVisibility(
      context: context,
      autoPauseOffscreen: widget.autoPauseOffscreen,
    )) {
      _syncTickerState();
      return;
    }

    try {
      final double dt =
          ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _lastElapsed = elapsed;

      _time = BlobMath.wrapTime(_time + dt * _controller.speed);
      _controller.applyDamping();

      _shaderCoordinator.updateDynamicUniforms(
        controller: _controller,
        widgetGradient: widget.gradient,
        cachedSize: _cachedSize,
        time: _time,
        onError: (renderError) {
          if (mounted) {
            setState(() => _lastError = renderError);
          }
          widget.onError?.call(renderError, renderError.stackTrace);
        },
      );

      _particleCoordinator.processTick(
        controller: _controller,
        touchManager: _touchManager,
        cachedSize: _cachedSize,
        time: _time,
        context: context,
        isStillMounted: mounted,
        onFrameUpdated: () {
          _frameCount++;
          _frameNotifier.value = _frameCount;
        },
        onComputeError: (exception, st) {
          widget.onError?.call(exception, st);
        },
      );
    } catch (err, st) {
      final exception = BlobFlutterException(
        message: 'Unexpected error during animation tick.',
        cause: err,
        stackTrace: st,
      );
      widget.onError?.call(exception, st);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final error = _lastError;
    if (error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

    return Semantics(
      label: 'Animated 3D particle blob',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool hasBoundedWidth = constraints.hasBoundedWidth;
          final bool hasBoundedHeight = constraints.hasBoundedHeight;
          final bool effectiveAutoFit = widget.autoFit || _controller.autoFit;
          final double effectiveRadiusFactor =
              widget._radiusFactor ?? _controller.radiusFactor;

          double responsiveRadius = _controller.radius;
          if (effectiveAutoFit && hasBoundedWidth && hasBoundedHeight) {
            final double minDim =
                math.min(constraints.maxWidth, constraints.maxHeight);
            if (minDim > 0.0) {
              responsiveRadius = (minDim / 2.0) * effectiveRadiusFactor;
              if ((_controller.radius - responsiveRadius).abs() > 0.5) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      (_controller.radius - responsiveRadius).abs() > 0.5) {
                    _controller.setRadius(responsiveRadius);
                  }
                });
              }
            }
          }

          final double width = hasBoundedWidth
              ? constraints.maxWidth
              : responsiveRadius * 2.0;
          final double height = hasBoundedHeight
              ? constraints.maxHeight
              : responsiveRadius * 2.0;

          final newSize = Size(width, height);
          if (newSize != _cachedSize) {
            _cachedSize = newSize;
            _updateCombinedOffset();
            _shaderCoordinator.markDirty(staticDirty: true);
            if (_controller.isPaused) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _controller.isPaused) {
                  _renderStaticFrame();
                }
              });
            }
          }

          return SizedBox(
            width: width,
            height: height,
            child: BlobInputListener(
              controller: _controller,
              hover: widget.hover,
              hitTestBehavior: widget.hitTestBehavior,
              interactive: widget.interactive,
              onTouchesChanged: (touches) {
                _touchManager.updateActiveTouches(touches);
              },
              child: ValueListenableBuilder<int>(
                valueListenable: _frameNotifier,
                builder: (_, frame, __) {
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: BlobPainter(
                        positions: _particleCoordinator.projectedPoints,
                        generation: frame,
                        shader: _shaderCoordinator.shader,
                        pointSize: _controller.pointSize,
                        fallbackColor: _shaderCoordinator.getFallbackColor(
                          _controller,
                          widget.gradient,
                          _time,
                        ),
                        fallbackGradient:
                            _shaderCoordinator.getEffectiveFallbackGradient(
                          _controller,
                          widget.gradient,
                          _time,
                        ),
                        centerOffset: _cachedCombinedOffset,
                        radius: _controller.radius * _controller.scale,
                        paint: _paint,
                        enableDepthCueing: _controller.enableDepthCueing,
                        depthCueingFactor: _controller.depthCueingFactor,
                      ),
                      size: Size.infinite,
                      isComplex: _controller.isComplex,
                      willChange: true,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
