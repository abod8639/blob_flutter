import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'blob_compute_params.dart';
import 'blob_controller.dart';
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
/// algorithm and deformed over time using fast sine-wave noise. The result is
/// projected to 2D via perspective division and rendered in a single GPU draw
/// call using [Canvas.drawRawPoints].
///
/// All rendering data is managed in flat [Float32List] buffers to eliminate
/// Garbage Collection pressure. A [ui.FragmentShader] handles per-pixel
/// coloring on the GPU.
///
/// ## Interaction
/// - **Drag**: Rotates the blob. Rotation decays naturally with inertia.
/// - **Tap & Hold**: Disperses the particles radially outward.
/// - **Mouse Hover** (desktop/web): Applies a subtle rotation following the cursor.
///
/// ## Color & Gradient Control
/// Supports [LinearGradient], [RadialGradient], and [SweepGradient] with:
/// - Exact coordinate/alignment positioning ([LinearGradient.begin], [LinearGradient.end], etc.)
/// - Up to 4 distinct color stops
/// - Static mode ([isColorAnimated] = `false` or [colorAnimationSpeed] = `0.0`) for fixed color positions
/// - Dynamic mode with customizable [colorAnimationSpeed] and [waveIntensity]
///
/// ## Performance Notes
/// - Uses [ValueNotifier] + [ValueListenableBuilder] so only [CustomPaint]
///   rebuilds per frame, not the entire widget subtree. (BUG-05 fix)
/// - Uses actual ticker delta time for device-rate-independent animation. (ARCH-02 fix)
/// - On native platforms, particle math is offloaded to a persistent background
///   [Isolate] so the UI thread stays free. On Flutter Web the same computation
///   runs synchronously (Web has no Isolate.spawn support).
/// - Shader uniforms are split into "static" (pushed only on change) and
///   "dynamic" (only uTime pushed every frame) to minimise Dart→GPU round-trips.
/// - Rainbow-mode colour list is pre-allocated; no heap allocation per frame.
/// - Touch transformation results are cached and recomputed only when positions change.
class BlobFlutter extends StatefulWidget {
  /// Total number of particles. Default: 5000.
  final int particleCount;

  /// Base radius of the blob sphere in logical pixels. Default: 150.0.
  final double radius;

  /// Rendered size of each particle point. Default: 2.0.
  final double pointSize;

  /// Optional external controller. If null, an internal one is created.
  final BlobController? controller;

  /// Scale multiplier applied to particle dispersion on touch/tap.
  /// Range: [0.0, 5.0]. Default: 1.0.
  final double tapScaleFactor;

  /// Multiplier applied to the touch interaction radius size.
  /// Range: [0.1, 5.0]. Default: 1.0.
  final double touchRadiusFactor;

  /// The gradient used to color the particles.
  /// Supports [LinearGradient], [RadialGradient], and [SweepGradient].
  final Gradient gradient;

  /// Whether the color gradient is dynamically animated across the blob
  /// or stays static in fixed position. Default: `true`.
  final bool isColorAnimated;

  /// Speed of color gradient flow / wave animation. Default: `1.0`.
  /// Set to `0.0` for completely static colors.
  final double colorAnimationSpeed;

  /// Intensity of wave distortion applied to the color flow.
  /// `0.0` = clean geometric gradient, `1.0` = organic liquid shimmer. Default: `1.0`.
  final double waveIntensity;

  /// Whether particle dispersion and interaction triggers on mouse hover without clicking.
  /// Default: `false`.
  final bool enableHover;

  /// The procedural 3D noise deformation algorithm used to shape the blob.
  /// Default: [BlobNoiseType.harmonic].
  final BlobNoiseType noiseType;

  const BlobFlutter({
    super.key,
    this.particleCount = 5000,
    this.radius = 150.0,
    this.pointSize = 2.0,
    this.tapScaleFactor = 1.0,
    this.touchRadiusFactor = 1.0,
    this.controller,
    this.gradient = const LinearGradient(
      colors: [Colors.blueAccent, Colors.purpleAccent],
    ),
    this.isColorAnimated = true,
    this.colorAnimationSpeed = 1.0,
    this.waveIntensity = 1.0,
    this.enableHover = false,
    this.noiseType = BlobNoiseType.harmonic,
  })  : assert(particleCount > 0, 'particleCount must be greater than 0'),
        assert(tapScaleFactor >= 0.0,
            'tapScaleFactor must be greater than or equal to 0.0'),
        assert(touchRadiusFactor >= 0.0,
            'touchRadiusFactor must be greater than or equal to 0.0'),
        assert(colorAnimationSpeed >= 0.0,
            'colorAnimationSpeed must be greater than or equal to 0.0'),
        assert(waveIntensity >= 0.0,
            'waveIntensity must be greater than or equal to 0.0');

  @override
  State<BlobFlutter> createState() => _ParticleBlobState();
}

class _ParticleBlobState extends State<BlobFlutter>
    with SingleTickerProviderStateMixin {
  // ── Animation ──────────────────────────────────────────────────────────────

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Continuous animation clock (seconds). Wraps to prevent float precision loss.
  double _time = 0.0;

  /// Drives repaint only on CustomPaint, not the full widget tree.
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  int _frameCount = 0;

  // ── Controller ─────────────────────────────────────────────────────────────

  late BlobController _controller;
  bool _ownsController = false;

  // ── Particle Data & Touch Manager ──────────────────────────────────────────

  Float32List _baseSphere = Float32List(0);
  Float32List _projectedPoints = Float32List(0);

  final BlobTouchManager _touchManager = BlobTouchManager();

  // ── Shader & Dirty Tracking ────────────────────────────────────────────────

  // ui.FragmentProgram? _program;
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
    4,
    const Color(0xFFFFFFFF),
  );

  // ── Effective Colour Helpers ───────────────────────────────────────────────

  Gradient get _effectiveGradient => _controller.gradient ?? widget.gradient;

  List<Color> get _effectiveColors {
    if (_controller.isRainbowMode) {
      final double h = (_time * 40.0) % 360.0;
      _rainbowColors[0] =
          HSVColor.fromAHSV(1.0, h, 0.85, 1.0).toColor();
      _rainbowColors[1] =
          HSVColor.fromAHSV(1.0, (h + 60) % 360, 0.85, 1.0).toColor();
      _rainbowColors[2] =
          HSVColor.fromAHSV(1.0, (h + 120) % 360, 0.85, 1.0).toColor();
      _rainbowColors[3] =
          HSVColor.fromAHSV(1.0, (h + 180) % 360, 0.85, 1.0).toColor();
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        BlobController(
          tapScaleFactor: widget.tapScaleFactor,
          touchRadiusFactor: widget.touchRadiusFactor,
          isColorAnimated: widget.isColorAnimated,
          colorAnimationSpeed: widget.colorAnimationSpeed,
          waveIntensity: widget.waveIntensity,
          enableHover: widget.enableHover,
          noiseType: widget.noiseType,
          gradient: widget.gradient,
        );

    _generateBuffers(widget.particleCount);
    _loadShader();
    _startWorker();

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(BlobFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.particleCount != widget.particleCount) {
      _generateBuffers(widget.particleCount);
      _restartWorker();
    }

    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller = widget.controller ??
          BlobController(
            tapScaleFactor: widget.tapScaleFactor,
            touchRadiusFactor: widget.touchRadiusFactor,
            isColorAnimated: widget.isColorAnimated,
            colorAnimationSpeed: widget.colorAnimationSpeed,
            waveIntensity: widget.waveIntensity,
            enableHover: widget.enableHover,
            noiseType: widget.noiseType,
            gradient: widget.gradient,
          );
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
    } else if (_ownsController) {
      bool staticChanged = false;
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
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frameNotifier.dispose();
    _shader?.dispose();
    _worker?.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  void _generateBuffers(int count) {
    _baseSphere = BlobMath.generateFibonacciSphere(count);
    _projectedPoints = Float32List(count * 2);
  }

  Future<void> _loadShader() async {
    final program = await BlobShaderHelper.loadProgram();
    if (program != null && mounted) {
      setState(() {
        // _program = program;
        _shader = program.fragmentShader();
        _shaderStaticDirty = true;
        _shaderColorsDirty = true;
      });
    }
  }

  void _startWorker() {
    final w = BlobWorker();
    _worker = w;
    w.init(_baseSphere, widget.particleCount).then((_) {
      if (mounted && _worker == w) {
        _workerReady = true;
      }
    });
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

    final double dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;

    _time = BlobMath.wrapTime(_time + dt * _controller.speed);
    _controller.applyDamping();

    _updateDynamicUniforms();

    if (_workerReady && !_workerBusy) {
      _workerBusy = true;
      _worker!.compute(_buildWorkerParams()).then(_onParticlesReady);
    } else if (!_workerReady) {
      _touchManager.updateLocalTouches(context);
      BlobMath.projectParticles(
        count: widget.particleCount,
        radius: widget.radius,
        blobiness: _controller.blobiness,
        dispersion: _controller.dispersion,
        rotationX: _controller.rotationX,
        rotationY: _controller.rotationY,
        time: _time,
        viewportWidth: _cachedSize.width,
        viewportHeight: _cachedSize.height,
        activeTouches: _touchManager.localTouches,
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
    } else {
      _frameCount++;
      _frameNotifier.value = _frameCount;
    }
  }

  void _onParticlesReady(Float32List? result) {
    _workerBusy = false;
    if (!mounted || result == null) return;

    _projectedPoints = result;
    _frameCount++;
    _frameNotifier.value = _frameCount;
  }

  // ── Worker Param Builder ───────────────────────────────────────────────────

  ProjectParamsFlat _buildWorkerParams() {
    _touchManager.updateLocalTouches(context);
    return ProjectParamsFlat(
      count: widget.particleCount,
      radius: widget.radius,
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
        isRainbowMode: false,
      );
      _shaderColorsDirty = false;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.radius * 2.0;
        final double height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.radius * 2.0;

        final newSize = Size(width, height);
        if (newSize != _cachedSize) {
          _cachedSize = newSize;
          _shaderStaticDirty = true;
        }

        return SizedBox(
          width: width,
          height: height,
          child: BlobInputListener(
            controller: _controller,
            enableHover: widget.enableHover,
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
                      pointSize: widget.pointSize,
                      fallbackColor: _color1,
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
    );
  }
}
