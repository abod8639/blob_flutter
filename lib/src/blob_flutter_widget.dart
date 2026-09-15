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
/// - **Pinch-to-Scale**: Multi-touch zoom in/out (configurable via [BlobController.enablePinchToScale]).
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
  static bool enableAutoPlayInTests = false;

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
  final bool? _enableHover;
  final bool? _enableDragRotation;
  final bool? _enableHoverRotation;
  final bool? _enablePinchToScale;
  final double? _rotationX;
  final double? _rotationY;
  final BlobNoiseType? _noiseType;

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
  bool get enableHover => _enableHover ?? false;

  /// Whether mouse/touch drag gestures rotate and spin the 3D object on the canvas.
  bool get enableDragRotation => _enableDragRotation ?? false;

  /// Whether moving the mouse cursor without clicking applies subtle 3D tilt towards the cursor.
  bool get enableHoverRotation => _enableHoverRotation ?? false;

  /// Whether multi-touch pinch-to-scale zooming is enabled.
  bool get enablePinchToScale => _enablePinchToScale ?? false;

  /// Initial persistent 3D orientation angle around the horizontal X-axis (pitch/tilt) in radians.
  double get rotationX => _rotationX ?? 0.0;

  /// Initial persistent 3D orientation angle around the vertical Y-axis (yaw/turn) in radians.
  double get rotationY => _rotationY ?? 0.0;

  /// The procedural mathematical deformation algorithm used to sculpt the particle mesh.
  BlobNoiseType get noiseType => _noiseType ?? BlobNoiseType.harmonic;

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
  /// to prevent [WidgetTester.pumpAndSettle] from timing out, unless explicitly
  /// set to `true` or enabled via [BlobFlutter.enableAutoPlayInTests].
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
    bool? enableHover,
    bool? enableDragRotation,
    bool? enableHoverRotation,
    bool? enablePinchToScale,
    this.interactive = true,
    this.hitTestBehavior = HitTestBehavior.translucent,
    double? rotationX,
    double? rotationY,
    BlobNoiseType? noiseType,
    this.onError,
    this.errorBuilder,
    this.silentErrorLogging,
    this.testShaderAssetPath,
    this.workerFactory,
    this.autoPlay,
    this.autoPauseOffscreen = true,
    this.autoPauseOnAppBackground = true,
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
        _enableHover = enableHover,
        _enableDragRotation = enableDragRotation,
        _enableHoverRotation = enableHoverRotation,
        _enablePinchToScale = enablePinchToScale,
        _rotationX = rotationX,
        _rotationY = rotationY,
        _noiseType = noiseType,
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
    if (w._enableHover != null) list.add('enableHover');
    if (w._enableDragRotation != null) list.add('enableDragRotation');
    if (w._enableHoverRotation != null) list.add('enableHoverRotation');
    if (w._enablePinchToScale != null) list.add('enablePinchToScale');
    if (w._rotationX != null) list.add('rotationX');
    if (w._rotationY != null) list.add('rotationY');
    if (w._noiseType != null) list.add('noiseType');
    return list;
  }

  @override
  State<BlobFlutter> createState() {
    final conflicts = findConflictingParameters(this);
    if (controller != null && conflicts.isNotEmpty) {
      final exception =
          BlobControllerConflictException.fromParameters(conflicts);
      onError?.call(exception, StackTrace.current);
      throw exception;
    }
    return _ParticleBlobState();
  }
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

  // ── Test & Environment Helpers ────────────────────────────────────────────

  bool get _effectiveAutoPlay =>
      widget.autoPlay ??
      (!BlobFlutter.isRunningInTest || BlobFlutter.enableAutoPlayInTests);

  bool get _effectiveSilentErrorLogging =>
      widget.silentErrorLogging ?? BlobFlutter.isRunningInTest;

  bool get _shouldTickerRun =>
      !_controller.isPaused &&
      !(widget.autoPauseOnAppBackground && _visibilityManager.isAppInBackground) &&
      !(widget.autoPauseOffscreen && _visibilityManager.isOffscreen);

  void _updateCombinedOffset() {
    _cachedCombinedOffset = Offset(
      _controller.centerOffset.dx +
          _controller.alignment.x * (_cachedSize.width / 2.0),
      _controller.centerOffset.dy +
          _controller.alignment.y * (_cachedSize.height / 2.0),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final conflicts = BlobFlutter.findConflictingParameters(widget);
    if (widget.controller != null && conflicts.isNotEmpty) {
      final exception =
          BlobControllerConflictException.fromParameters(conflicts);
      widget.onError?.call(exception, StackTrace.current);
      throw exception;
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
          enableHover: widget.enableHover,
          enableDragRotation: widget.enableDragRotation,
          enableHoverRotation: widget.enableHoverRotation,
          enablePinchToScale: widget.enablePinchToScale,
          isColorAnimated: widget.isColorAnimated,
          colorAnimationSpeed: widget.colorAnimationSpeed,
          waveIntensity: widget.waveIntensity,
          noiseType: widget.noiseType,
          gradient: widget.gradient,
          isPaused: !_effectiveAutoPlay,
        );

    _lastParticleCount = _controller.particleCount;
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
    if (_controller.particleCount != _lastParticleCount) {
      _lastParticleCount = _controller.particleCount;
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
    _updateCombinedOffset();
    _shaderCoordinator.updateDynamicUniforms(
      controller: _controller,
      widgetGradient: widget.gradient,
      cachedSize: _cachedSize,
      time: _time,
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
  }

  @override
  void didUpdateWidget(BlobFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);

    final conflicts = BlobFlutter.findConflictingParameters(widget);
    if (widget.controller != null && conflicts.isNotEmpty) {
      final exception =
          BlobControllerConflictException.fromParameters(conflicts);
      widget.onError?.call(exception, StackTrace.current);
      throw exception;
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
            enableHover: widget.enableHover,
            enableDragRotation: widget.enableDragRotation,
            enableHoverRotation: widget.enableHoverRotation,
            enablePinchToScale: widget.enablePinchToScale,
            isColorAnimated: widget.isColorAnimated,
            colorAnimationSpeed: widget.colorAnimationSpeed,
            waveIntensity: widget.waveIntensity,
            noiseType: widget.noiseType,
            gradient: widget.gradient,
            isPaused: !_effectiveAutoPlay,
          );
      _lastParticleCount = _controller.particleCount;
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
      if (oldWidget.enableHover != widget.enableHover) {
        _controller.setEnableHover(widget.enableHover);
      }
      if (oldWidget.enableDragRotation != widget.enableDragRotation) {
        _controller.setEnableDragRotation(widget.enableDragRotation);
      }
      if (oldWidget.enableHoverRotation != widget.enableHoverRotation) {
        _controller.setEnableHoverRotation(widget.enableHoverRotation);
      }
      if (oldWidget.enablePinchToScale != widget.enablePinchToScale) {
        _controller.setEnablePinchToScale(widget.enablePinchToScale);
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
      particleCount: _controller.particleCount,
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
      particleCount: _controller.particleCount,
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
    );
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
          final double width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : _controller.radius * 2.0;
          final double height = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : _controller.radius * 2.0;

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
              enableHover: widget.enableHover,
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
                      ),
                      size: Size.infinite,
                      isComplex: true,
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
