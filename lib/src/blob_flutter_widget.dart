import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'blob_compute_params.dart';
import 'blob_controller.dart';
import 'blob_exception.dart';
import 'blob_input_listener.dart';
import 'blob_math.dart';
import 'blob_noise_type.dart';
import 'blob_painter.dart';
import 'blob_shader_helper.dart';
import 'blob_touch_manager.dart';
import 'blob_worker.dart';

/// A high-performance Flutter widget that renders an animated 3D particle blob.
///
/// Particles are distributed uniformly on a 3D sphere via the Fibonacci lattice
/// algorithm and deformed over time using procedural noise algorithms. The result is
/// projected to 2D via perspective division and rendered in a single GPU draw
/// call using [Canvas.drawRawPoints].
///
/// All rendering data is managed in flat [Float32List] buffers to eliminate
/// Garbage Collection pressure. A [ui.FragmentShader] handles per-pixel
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
  /// Defaults to `false` so that [WidgetTester.pumpAndSettle] does not time out.
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

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Continuous animation clock (seconds). Wraps to prevent float precision loss.
  double _time = 0.0;

  /// Drives repaint only on CustomPaint, not the full widget tree.
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  int _frameCount = 0;

  // ── Lifecycle & Offscreen State ────────────────────────────────────────────

  bool _isAppInBackground = false;
  bool _isOffscreen = false;
  ScrollPosition? _scrollPosition;

  /// Whether the internal animation ticker is currently actively ticking.
  @visibleForTesting
  bool get isTickerActive => _ticker.isActive;

  /// Whether the widget has detected that it is currently outside the screen viewport.
  @visibleForTesting
  bool get isOffscreen => _isOffscreen;

  /// Whether the widget has detected that the application is in background/inactive state.
  @visibleForTesting
  bool get isAppInBackground => _isAppInBackground;

  // ── Controller ─────────────────────────────────────────────────────────────

  late BlobController _controller;
  bool _ownsController = false;
  int _lastParticleCount = 5000;

  // ── Particle Data & Touch Manager ──────────────────────────────────────────

  Float32List _baseSphere = Float32List(0);
  Float32List _projectedPoints = Float32List(0);
  Float32List? _recycleBuffer;

  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  int _visibilityTickCounter = 0;
  Offset _cachedCombinedOffset = Offset.zero;

  void _updateCombinedOffset() {
    _cachedCombinedOffset = Offset(
      _controller.centerOffset.dx +
          _controller.alignment.x * (_cachedSize.width / 2.0),
      _controller.centerOffset.dy +
          _controller.alignment.y * (_cachedSize.height / 2.0),
    );
  }

  final BlobTouchManager _touchManager = BlobTouchManager();

  // ── Shader & Dirty Tracking ────────────────────────────────────────────────

  ui.FragmentShader? _shader;

  bool _shaderStaticDirty = true;
  bool _shaderColorsDirty = true;

  Gradient? _lastPushedGradient;

  // ── Layout & Worker ────────────────────────────────────────────────────────

  Size _cachedSize = Size.zero;

  BlobWorker? _worker;
  bool _workerReady = false;
  bool _workerBusy = false;

  // ── Rainbow Color Cache ─────────────────────────────────────────────────────

  final List<Color> _rainbowColors = List<Color>.filled(
    8,
    const Color(0xFFFFFFFF),
  );

  // ── Effective Colour Helpers ───────────────────────────────────────────────

  Gradient get _effectiveGradient => _controller.gradient ?? widget.gradient;

  Gradient get _effectiveFallbackGradient {
    if (_controller.isRainbowMode) {
      return SweepGradient(colors: _effectiveColors);
    }
    final g = _effectiveGradient;
    if (g.colors.length >= 2) {
      return g;
    } else if (g.colors.length == 1) {
      return LinearGradient(colors: [g.colors.first, g.colors.first]);
    }
    return const LinearGradient(
      colors: [Colors.blueAccent, Colors.purpleAccent],
    );
  }

  List<Color> get _effectiveColors {
    if (_controller.isRainbowMode) {
      final double h = (_time * 40.0) % 360.0;
      for (int i = 0; i < 8; i++) {
        _rainbowColors[i] =
            HSVColor.fromAHSV(1.0, (h + i * 45.0) % 360.0, 0.85, 1.0).toColor();
      }
      return _rainbowColors;
    }
    final g = _effectiveGradient;
    return g.colors.isNotEmpty
        ? g.colors
        : const [Colors.blueAccent, Colors.purpleAccent];
  }

  Color get _color1 {
    final colors = _effectiveColors;
    return colors.isNotEmpty ? colors.first : Colors.pinkAccent;
  }

  // ── Test & Environment Helpers ────────────────────────────────────────────

  bool get _effectiveAutoPlay =>
      widget.autoPlay ??
      (!BlobFlutter.isRunningInTest || BlobFlutter.enableAutoPlayInTests);

  bool get _effectiveSilentErrorLogging =>
      widget.silentErrorLogging ?? BlobFlutter.isRunningInTest;

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

    _generateBuffers(_lastParticleCount);
    _loadShader();
    _startWorker();

    _ticker = createTicker(_onTick);
    if (_shouldTickerRun) {
      _ticker.start();
    }
  }

  bool get _shouldTickerRun =>
      !_controller.isPaused &&
      !(widget.autoPauseOnAppBackground && _isAppInBackground) &&
      !(widget.autoPauseOffscreen && _isOffscreen);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScrollListener();
    if (widget.autoPauseOffscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkVisibility();
      });
    }
  }

  void _updateScrollListener() {
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      try {
        _scrollPosition?.removeListener(_onScrollUpdated);
      } catch (_) {}
      _scrollPosition = newPosition;
      _scrollPosition?.addListener(_onScrollUpdated);
    }
  }

  void _onScrollUpdated() {
    if (!widget.autoPauseOffscreen) return;
    _checkVisibility();
  }

  void _checkVisibility() {
    if (!mounted || !widget.autoPauseOffscreen) return;
    final visible = _isRenderObjectVisible();
    final isOff = !visible;
    if (isOff != _isOffscreen) {
      _isOffscreen = isOff;
      _syncTickerState();
    }
  }

  bool _isRenderObjectVisible() {
    if (!mounted) return false;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return true;
    if (renderObject is! RenderBox) return true;
    if (!renderObject.hasSize || renderObject.size.isEmpty) return true;

    final view = View.maybeOf(context);
    if (view == null) return true;
    final physicalSize = view.physicalSize;
    final pixelRatio = view.devicePixelRatio;
    if (pixelRatio <= 0.0 || physicalSize.isEmpty) return true;
    final screenSize = physicalSize / pixelRatio;

    try {
      final translation = renderObject.getTransformTo(null).getTranslation();
      final rect = Rect.fromLTWH(
        translation.x,
        translation.y,
        renderObject.size.width,
        renderObject.size.height,
      );

      // Pre-wake buffer of 50 logical pixels so animation wakes up slightly before entering viewport
      final screenBounds = Rect.fromLTWH(
        -50.0,
        -50.0,
        screenSize.width + 100.0,
        screenSize.height + 100.0,
      );

      return rect.overlaps(screenBounds);
    } catch (_) {
      return true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.autoPauseOnAppBackground) return;
    final isBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (isBackground != _isAppInBackground) {
      _isAppInBackground = isBackground;
      _syncTickerState();
    }
  }

  void _onControllerChanged() {
    _updateCombinedOffset();
    if (_controller.particleCount != _lastParticleCount) {
      _lastParticleCount = _controller.particleCount;
      _generateBuffers(_lastParticleCount);
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
    _updateDynamicUniforms();
    _touchManager.updateLocalTouches(context);
    final double alignOffsetX =
        _controller.alignment.x * (_cachedSize.width / 2.0);
    final double alignOffsetY =
        _controller.alignment.y * (_cachedSize.height / 2.0);

    BlobMath.projectParticles(
      count: _controller.particleCount,
      radius: _controller.radius,
      scale: _controller.scale,
      centerOffsetX: _controller.centerOffset.dx + alignOffsetX,
      centerOffsetY: _controller.centerOffset.dy + alignOffsetY,
      blobiness: _controller.blobiness,
      dispersion: _controller.dispersion,
      rotationX: _controller.rotationX,
      rotationY: _controller.rotationY,
      time: _time,
      viewportWidth: _cachedSize.width,
      viewportHeight: _cachedSize.height,
      activeTouches: _touchManager.localTouchesFlat,
      baseSphere: _baseSphere,
      projectedPoints: _projectedPoints,
      autoRotationSpeed: _controller.autoRotationSpeed,
      noiseFrequency: _controller.noiseFrequency,
      viewDistance: _controller.viewDistance,
      noiseType: _controller.noiseType,
      touchRadiusFactor: _controller.touchRadiusFactor,
    );
    _frameCount++;
    _frameNotifier.value = _frameCount;
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
      _generateBuffers(_lastParticleCount);
      _restartWorker();
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
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
        _shaderColorsDirty = true;
      }
      if (staticChanged) _shaderStaticDirty = true;
    }

    if (oldWidget.autoPauseOffscreen != widget.autoPauseOffscreen) {
      if (!widget.autoPauseOffscreen) {
        _isOffscreen = false;
      } else {
        _checkVisibility();
      }
      _syncTickerState();
    }

    if (oldWidget.autoPauseOnAppBackground != widget.autoPauseOnAppBackground) {
      if (!widget.autoPauseOnAppBackground) {
        _isAppInBackground = false;
      }
      _syncTickerState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _scrollPosition?.removeListener(_onScrollUpdated);
    } catch (_) {}
    _scrollPosition = null;
    _controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _frameNotifier.dispose();
    _shader?.dispose();
    _worker?.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  BlobFlutterException? _lastError;

  // ── Initialization ─────────────────────────────────────────────────────────

  void _generateBuffers(int count) {
    _baseSphere = BlobMath.generateFibonacciSphere(count);
    // Preserve old projected points to avoid a visual flash while the worker
    // restarts and computes the first result for the new particle count.
    // The worker will replace _projectedPoints on its first successful result.
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

  Future<void> _loadShader() async {
    final program = await BlobShaderHelper.loadProgram(
      silent: _effectiveSilentErrorLogging,
      overrideAssetPath: widget.testShaderAssetPath,
      onError: (exception) {
        if (!mounted) return;
        setState(() {
          _lastError = exception;
        });
        widget.onError?.call(exception, exception.stackTrace);
      },
    );
    if (program != null && mounted) {
      setState(() {
        _shader = program.fragmentShader();
        _shaderStaticDirty = true;
        _shaderColorsDirty = true;
      });
    }
  }

  void _startWorker() {
    try {
      final w = widget.workerFactory?.call() ?? BlobWorker();
      _worker = w;
      w.init(_baseSphere, _controller.particleCount).then((_) {
        if (mounted && _worker == w) {
          _workerReady = true;
        }
      }).catchError((Object err, StackTrace st) {
        final exception =
            BlobWorkerException.spawnFailed(cause: err, stackTrace: st);
        if (mounted) {
          setState(() {
            _lastError = exception;
            _workerReady = false;
          });
        }
        widget.onError?.call(exception, st);
      });
    } catch (err, st) {
      final exception =
          BlobWorkerException.spawnFailed(cause: err, stackTrace: st);
      _lastError = exception;
      _workerReady = false;
      widget.onError?.call(exception, st);
    }
  }

  void _restartWorker() {
    _worker?.dispose();
    _workerReady = false;
    _workerBusy = false;
    _startWorker();
  }

  // ── Ticker Callback ────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (!mounted || _cachedSize == Size.zero) return;

    if (widget.autoPauseOffscreen) {
      _visibilityTickCounter++;
      if (_visibilityTickCounter >= 30) {
        _visibilityTickCounter = 0;
        if (!_isRenderObjectVisible()) {
          _isOffscreen = true;
          _syncTickerState();
          return;
        }
      }
    }

    final double dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;

    _time = BlobMath.wrapTime(_time + dt * _controller.speed);
    _controller.applyDamping();

    _updateDynamicUniforms();

    if (_workerReady && !_workerBusy) {
      _workerBusy = true;
      final recycle = _recycleBuffer;
      _recycleBuffer = null;
      _worker!.compute(_buildWorkerParams(), recycle).then(_onParticlesReady);
    } else if (!_workerReady) {
      _touchManager.updateLocalTouches(context);
      final double alignOffsetX =
          _controller.alignment.x * (_cachedSize.width / 2.0);
      final double alignOffsetY =
          _controller.alignment.y * (_cachedSize.height / 2.0);

      BlobMath.projectParticles(
        count: _controller.particleCount,
        radius: _controller.radius,
        scale: _controller.scale,
        centerOffsetX: _controller.centerOffset.dx + alignOffsetX,
        centerOffsetY: _controller.centerOffset.dy + alignOffsetY,
        blobiness: _controller.blobiness,
        dispersion: _controller.dispersion,
        rotationX: _controller.rotationX,
        rotationY: _controller.rotationY,
        time: _time,
        viewportWidth: _cachedSize.width,
        viewportHeight: _cachedSize.height,
        activeTouches: _touchManager.localTouchesFlat,
        baseSphere: _baseSphere,
        projectedPoints: _projectedPoints,
        autoRotationSpeed: _controller.autoRotationSpeed,
        noiseFrequency: _controller.noiseFrequency,
        viewDistance: _controller.viewDistance,
        noiseType: _controller.noiseType,
        touchRadiusFactor: _controller.touchRadiusFactor,
      );
      _frameCount++;
      _frameNotifier.value = _frameCount;
    } else if (_controller.isColorAnimated || _controller.isRainbowMode) {
      // Worker is computing next particle positions; refresh frame for color animation
      _frameCount++;
      _frameNotifier.value = _frameCount;
    }
  }

  void _onParticlesReady(Float32List? result) {
    _workerBusy = false;
    if (!mounted || result == null) return;

    if (_projectedPoints.isNotEmpty) {
      _recycleBuffer = _projectedPoints;
    }
    _projectedPoints = result;
    _frameCount++;
    _frameNotifier.value = _frameCount;
  }

  // ── Worker Param Builder ───────────────────────────────────────────────────

  ProjectParamsFlat _buildWorkerParams() {
    _touchManager.updateLocalTouches(context);
    final double alignOffsetX =
        _controller.alignment.x * (_cachedSize.width / 2.0);
    final double alignOffsetY =
        _controller.alignment.y * (_cachedSize.height / 2.0);

    return ProjectParamsFlat(
      count: _controller.particleCount,
      radius: _controller.radius,
      scale: _controller.scale,
      centerOffsetX: _controller.centerOffset.dx + alignOffsetX,
      centerOffsetY: _controller.centerOffset.dy + alignOffsetY,
      blobiness: _controller.blobiness,
      dispersion: _controller.dispersion,
      rotationX: _controller.rotationX,
      rotationY: _controller.rotationY,
      time: _time,
      viewportWidth: _cachedSize.width,
      viewportHeight: _cachedSize.height,
      encodedTouches: _touchManager.encodedTouches,
      autoRotationSpeed: _controller.autoRotationSpeed,
      noiseFrequency: _controller.noiseFrequency,
      viewDistance: _controller.viewDistance,
      noiseTypeIndex: _controller.noiseType.index,
      touchRadiusFactor: _controller.touchRadiusFactor,
    );
  }

  // ── Shader Uniforms ────────────────────────────────────────────────────────

  void _updateDynamicUniforms() {
    final s = _shader;
    if (s == null) return;

    final currentGradient = _effectiveGradient;
    if (currentGradient != _lastPushedGradient) {
      _lastPushedGradient = currentGradient;
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
    }

    if (_shaderStaticDirty) {
      BlobShaderHelper.pushStaticUniforms(
        shader: s,
        size: _cachedSize,
        gradient: currentGradient,
        isColorAnimated: _controller.isColorAnimated,
        colorAnimationSpeed: _controller.colorAnimationSpeed,
        waveIntensity: _controller.waveIntensity,
        centerOffset: _controller.centerOffset,
        radius: _controller.radius * _controller.scale,
        alignment: _controller.alignment,
      );
      _shaderStaticDirty = false;
    }

    // Index 2: uTime
    s.setFloat(2, _time);

    if (_controller.isRainbowMode) {
      BlobShaderHelper.pushColors(
        shader: s,
        colors: _effectiveColors,
        isRainbowMode: true,
      );
    } else if (_shaderColorsDirty) {
      BlobShaderHelper.pushColors(
        shader: s,
        colors: _effectiveColors,
        stops: currentGradient.stops,
        isRainbowMode: false,
      );
      _shaderColorsDirty = false;
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
            _shaderStaticDirty = true;
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
                        positions: _projectedPoints,
                        generation: frame,
                        shader: _shader,
                        pointSize: _controller.pointSize,
                        fallbackColor: _color1,
                        fallbackGradient: _effectiveFallbackGradient,
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
