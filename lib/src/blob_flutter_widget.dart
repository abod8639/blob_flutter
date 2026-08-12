import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'blob_controller.dart';

import 'blob_noise_type.dart';
import 'blob_math.dart';
import 'blob_painter.dart';
import 'blob_input_listener.dart';
import 'blob_compute_params.dart';
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
/// - [RenderBox.globalToLocal] results are cached and recomputed only when touch
///   positions actually change.
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
    this.controller,
    this.gradient = const LinearGradient(
      colors: [Colors.blueAccent, Colors.purpleAccent],
    ),
    this.isColorAnimated = true,
    this.colorAnimationSpeed = 1.0,
    this.waveIntensity = 1.0,
    this.enableHover = false,
    this.noiseType = BlobNoiseType.harmonic,
  }) : assert(particleCount > 0, 'particleCount must be greater than 0'),
       assert(tapScaleFactor >= 0.0, 'tapScaleFactor must be greater than or equal to 0.0'),
       assert(colorAnimationSpeed >= 0.0, 'colorAnimationSpeed must be greater than or equal to 0.0'),
       assert(waveIntensity >= 0.0, 'waveIntensity must be greater than or equal to 0.0');

  @override
  State<BlobFlutter> createState() => _ParticleBlobState();
}

class _ParticleBlobState extends State<BlobFlutter>
    with SingleTickerProviderStateMixin {

  // ── Animation ──────────────────────────────────────────────────────────────

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Continuous animation clock (seconds). Wraps to prevent float precision
  /// loss over long runtimes. (LOGIC-01 fix)
  double _time = 0.0;

  /// BUG-05 fix: drives repaint only on CustomPaint, not the full widget tree.
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  int _frameCount = 0;

  // ── Controller ─────────────────────────────────────────────────────────────

  late BlobController _controller;
  bool _ownsController = false;

  // ── Particle Data ──────────────────────────────────────────────────────────

  /// Flat base sphere: [x0,y0,z0, x1,y1,z1, ...]. Immutable after generation.
  /// BUG-07 fix: Float32List instead of `List<List<double>>`.
  Float32List _baseSphere = Float32List(0);

  /// Output buffer: [x0,y0, x1,y1, ...] in screen pixels. Replaced each frame
  /// with the worker's result on native, mutated in-place on Web.
  Float32List _projectedPoints = Float32List(0);

  // ── Shader ─────────────────────────────────────────────────────────────────

  ui.FragmentProgram? _program; // ARCH-03 fix: stored to prevent premature GC
  ui.FragmentShader?  _shader;

  // ── Shader Dirty Tracking ──────────────────────────────────────────────────
  //
  // Shader uniforms are split into two groups:
  //   "static"  — resolution, gradient type/position, animation speed, wave
  //               intensity.  These change rarely (layout change, controller
  //               update) and are re-pushed only when [_shaderStaticDirty] is
  //               set.
  //   "dynamic" — uTime pushed every frame; gradient colours when isRainbow.
  //
  // This eliminates up to 25 redundant setFloat() calls per frame.

  bool _shaderStaticDirty = true;
  bool _shaderColorsDirty = true;

  /// Tracks the last gradient seen by the shader so external controller
  /// changes (controller.setGradient) are detected automatically.
  Gradient? _lastPushedGradient;

  // ── Layout ─────────────────────────────────────────────────────────────────

  /// BUG-02 fix: size cached from LayoutBuilder, never read inside ticker.
  Size _cachedSize = Size.zero;

  // ── Touch State ────────────────────────────────────────────────────────────

  List<Offset> _activeTouches = const [];

  /// Cached result of [RenderBox.globalToLocal].  Recomputed only when
  /// [_activeTouches] positions actually change.
  List<Offset> _localTouches      = const [];
  List<Offset> _lastGlobalTouches = const [];

  /// Encoded touches for the worker message: [x0,y0, x1,y1, …].
  Float32List _encodedTouches = Float32List(0);

  // ── Worker ─────────────────────────────────────────────────────────────────

  BlobWorker? _worker;
  bool _workerReady = false;
  bool _workerBusy  = false;

  // ── Rainbow Color Cache ─────────────────────────────────────────────────────

  /// Pre-allocated list reused every frame in rainbow mode.
  /// Eliminates one [List] allocation + 4 [Color] allocations per frame.
  final List<Color> _rainbowColors = List<Color>.filled(
    4, const Color(0xFFFFFFFF),
  );

  // ── Effective Colour Helpers ───────────────────────────────────────────────

  Gradient get _effectiveGradient => _controller.gradient ?? widget.gradient;

  List<Color> get _effectiveColors {
    if (_controller.isRainbowMode) {
      final double h = (_time * 40.0) % 360.0;
      _rainbowColors[0] = HSVColor.fromAHSV(1.0, h,              0.85, 1.0).toColor();
      _rainbowColors[1] = HSVColor.fromAHSV(1.0, (h + 60)  % 360, 0.85, 1.0).toColor();
      _rainbowColors[2] = HSVColor.fromAHSV(1.0, (h + 120) % 360, 0.85, 1.0).toColor();
      _rainbowColors[3] = HSVColor.fromAHSV(1.0, (h + 180) % 360, 0.85, 1.0).toColor();
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
          tapScaleFactor:      widget.tapScaleFactor,
          isColorAnimated:     widget.isColorAnimated,
          colorAnimationSpeed: widget.colorAnimationSpeed,
          waveIntensity:       widget.waveIntensity,
          enableHover:         widget.enableHover,
          noiseType:           widget.noiseType,
          gradient:            widget.gradient,
        );

    _generateBuffers(widget.particleCount);
    _loadShader();
    _startWorker();

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(BlobFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Regenerate particle buffers and restart worker if count changed.
    if (oldWidget.particleCount != widget.particleCount) {
      _generateBuffers(widget.particleCount);
      _restartWorker();
    }

    // Swap controller ownership cleanly.
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller = widget.controller ??
          BlobController(
            tapScaleFactor:      widget.tapScaleFactor,
            isColorAnimated:     widget.isColorAnimated,
            colorAnimationSpeed: widget.colorAnimationSpeed,
            waveIntensity:       widget.waveIntensity,
            enableHover:         widget.enableHover,
            noiseType:           widget.noiseType,
            gradient:            widget.gradient,
          );
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
    } else if (_ownsController) {
      bool staticChanged = false;
      if (oldWidget.tapScaleFactor != widget.tapScaleFactor) {
        _controller.setTapScaleFactor(widget.tapScaleFactor);
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
    _baseSphere      = BlobMath.generateFibonacciSphere(count); // BUG-01 guarded
    _projectedPoints = Float32List(count * 2);
  }

  Future<void> _loadShader() async {
    try {
      // ARCH-03: store program as field to prevent premature GC
      try {
        _program = await ui.FragmentProgram.fromAsset(
            'packages/blob_flutter/shaders/blob.frag');
      } catch (_) {
        _program = await ui.FragmentProgram.fromAsset('shaders/blob.frag');
      }
      if (mounted) {
        setState(() {
          _shader = _program!.fragmentShader();
          _shaderStaticDirty = true;
          _shaderColorsDirty = true;
        });
      }
    } catch (e) {
      debugPrint('[BlobFlutter] Shader load failed: $e');
      // Falls back to solid fallbackColor in BlobPainter.
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
    _workerBusy  = false;
    _startWorker();
  }

  // ── Ticker Callback ────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (!mounted || _cachedSize == Size.zero) return;

    // ARCH-02 fix: use actual frame delta, clamped to prevent spiral of death.
    final double dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;

    // Advance time and apply rotation damping.
    _time = BlobMath.wrapTime(_time + dt * _controller.speed);
    _controller.applyDamping(); // LOGIC-02 fix

    // Always push the time uniform so colour animation remains smooth even
    // when particle positions are being computed in the background worker.
    _updateDynamicUniforms();

    if (_workerReady && !_workerBusy) {
      // ── Async path (native) / microtask path (Web) ─────────────────────────
      _workerBusy = true;
      _worker!.compute(_buildWorkerParams()).then(_onParticlesReady);
    } else if (!_workerReady) {
      // ── Sync fallback: worker still initialising (first few frames only) ───
      _updateLocalTouches();
      BlobMath.projectParticles(
        count:             widget.particleCount,
        radius:            widget.radius,
        blobiness:         _controller.blobiness,
        dispersion:        _controller.dispersion,
        rotationX:         _controller.rotationX,
        rotationY:         _controller.rotationY,
        time:              _time,
        viewportWidth:     _cachedSize.width,
        viewportHeight:    _cachedSize.height,
        activeTouches:     _localTouches,
        baseSphere:        _baseSphere,
        projectedPoints:   _projectedPoints,
        autoRotationSpeed: _controller.autoRotationSpeed,
        noiseFrequency:    _controller.noiseFrequency,
        viewDistance:      _controller.viewDistance,
        noiseType:         _controller.noiseType,
      );
      _frameCount++;
      _frameNotifier.value = _frameCount;
    } else {
      // ── Worker busy: still repaint so colour animation stays smooth ─────────
      _frameCount++;
      _frameNotifier.value = _frameCount;
    }
  }

  void _onParticlesReady(Float32List? result) {
    _workerBusy = false;
    if (!mounted || result == null) return;

    // Replace the projected-points buffer with the worker's result.
    // On native, this is the zero-copy materialised TransferableTypedData.
    // On Web, this is the same pre-allocated buffer written in-place.
    _projectedPoints = result;

    _frameCount++;
    _frameNotifier.value = _frameCount;
  }

  // ── Touch Cache ────────────────────────────────────────────────────────────

  /// Recomputes [_localTouches] and [_encodedTouches] only when the global
  /// touch positions have changed since the last call.
  void _updateLocalTouches() {
    if (_activeTouches.isEmpty) {
      if (_localTouches.isNotEmpty) {
        _localTouches      = const [];
        _lastGlobalTouches = const [];
        _encodedTouches    = Float32List(0);
      }
      return;
    }

    // Skip recalculation when positions haven't changed.
    if (_offsetListEquals(_activeTouches, _lastGlobalTouches)) return;
    _lastGlobalTouches = List<Offset>.of(_activeTouches);

    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached) {
      _localTouches = _activeTouches
          .map((p) => ro.globalToLocal(p))
          .toList(growable: false);
    } else {
      _localTouches = List<Offset>.of(_activeTouches);
    }

    // Encode for the worker message.
    final buf = Float32List(_localTouches.length * 2);
    for (int i = 0; i < _localTouches.length; i++) {
      buf[i * 2]     = _localTouches[i].dx;
      buf[i * 2 + 1] = _localTouches[i].dy;
    }
    _encodedTouches = buf;
  }

  static bool _offsetListEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Worker Param Builder ───────────────────────────────────────────────────

  ProjectParamsFlat _buildWorkerParams() {
    _updateLocalTouches();
    return ProjectParamsFlat(
      count:             widget.particleCount,
      radius:            widget.radius,
      blobiness:         _controller.blobiness,
      dispersion:        _controller.dispersion,
      rotationX:         _controller.rotationX,
      rotationY:         _controller.rotationY,
      time:              _time,
      viewportWidth:     _cachedSize.width,
      viewportHeight:    _cachedSize.height,
      encodedTouches:    _encodedTouches,
      autoRotationSpeed: _controller.autoRotationSpeed,
      noiseFrequency:    _controller.noiseFrequency,
      viewDistance:      _controller.viewDistance,
      noiseTypeIndex:    _controller.noiseType.index,
    );
  }

  // ── Shader Uniforms ────────────────────────────────────────────────────────

  /// Updates the fragment shader every frame.
  ///
  /// Only [uTime] (index 2) is pushed unconditionally.  Static uniforms
  /// (resolution, gradient geometry, animation speed, wave intensity) are
  /// re-pushed only when [_shaderStaticDirty] is set.  Colour uniforms are
  /// re-pushed only in rainbow mode (every frame) or when [_shaderColorsDirty]
  /// is set (gradient changed).
  void _updateDynamicUniforms() {
    final s = _shader;
    if (s == null) return;

    // Detect external gradient changes (e.g., controller.setGradient()).
    final currentGradient = _effectiveGradient;
    if (currentGradient != _lastPushedGradient) {
      _lastPushedGradient = currentGradient;
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
    }

    // Push static uniforms only when dirty.
    if (_shaderStaticDirty) {
      _pushStaticUniforms(s);
      _shaderStaticDirty = false;
    }

    // 2: uTime — always changes.
    s.setFloat(2, _time);

    // Colours — every frame in rainbow mode, otherwise only when dirty.
    if (_controller.isRainbowMode) {
      _pushColors(s, _effectiveColors);
    } else if (_shaderColorsDirty) {
      _pushColors(s, _effectiveColors);
      _shaderColorsDirty = false;
    }
  }

  /// Pushes resolution, gradient geometry, animation speed, and wave intensity.
  /// Called once after the shader loads and whenever any of these change.
  void _pushStaticUniforms(ui.FragmentShader s) {
    // 0-1: uResolution
    s.setFloat(0, _cachedSize.width);
    s.setFloat(1, _cachedSize.height);

    // Gradient geometry (19-24)
    _pushGradientParams(s);

    // 23: uColorAnimationSpeed
    final bool isAnim = _controller.isColorAnimated;
    s.setFloat(23, isAnim ? _controller.colorAnimationSpeed : 0.0);

    // 25: uWaveIntensity
    s.setFloat(25, _controller.waveIntensity);
  }

  /// Pushes uColor1-4 and uColorCount (indices 3-18, 26).
  void _pushColors(ui.FragmentShader s, List<Color> colors) {
    final int count = colors.length.clamp(1, 4);
    final c1 = colors[0];
    final c2 = count > 1 ? colors[1] : c1;
    final c3 = count > 2 ? colors[2] : c2;
    final c4 = count > 3 ? colors[3] : c3;

    // uColor1 (3-6)
    s.setFloat(3,  c1.r); s.setFloat(4,  c1.g);
    s.setFloat(5,  c1.b); s.setFloat(6,  c1.a);
    // uColor2 (7-10)
    s.setFloat(7,  c2.r); s.setFloat(8,  c2.g);
    s.setFloat(9,  c2.b); s.setFloat(10, c2.a);
    // uColor3 (11-14)
    s.setFloat(11, c3.r); s.setFloat(12, c3.g);
    s.setFloat(13, c3.b); s.setFloat(14, c3.a);
    // uColor4 (15-18)
    s.setFloat(15, c4.r); s.setFloat(16, c4.g);
    s.setFloat(17, c4.b); s.setFloat(18, c4.a);

    // 26: uColorCount
    s.setFloat(26, _controller.isRainbowMode ? 4.0 : count.toDouble());
  }

  /// Parses [_effectiveGradient] and pushes gradient geometry + type uniforms.
  void _pushGradientParams(ui.FragmentShader s) {
    final g = _effectiveGradient;
    double startX = 0.5, startY = 0.0;
    double endX   = 0.5, endY   = 1.0;
    double gradType = 0.0; // 0 = Linear, 1 = Radial, 2 = Sweep

    if (g is LinearGradient) {
      gradType = 0.0;
      final begin = g.begin.resolve(TextDirection.ltr);
      final end   = g.end.resolve(TextDirection.ltr);
      startX = (begin.x + 1.0) / 2.0;
      startY = (begin.y + 1.0) / 2.0;
      endX   = (end.x   + 1.0) / 2.0;
      endY   = (end.y   + 1.0) / 2.0;
    } else if (g is RadialGradient) {
      gradType = 1.0;
      final center = g.center.resolve(TextDirection.ltr);
      startX = (center.x + 1.0) / 2.0;
      startY = (center.y + 1.0) / 2.0;
      endX   = g.radius;
      endY   = 0.0;
    } else if (g is SweepGradient) {
      gradType = 2.0;
      final center = g.center.resolve(TextDirection.ltr);
      startX = (center.x + 1.0) / 2.0;
      startY = (center.y + 1.0) / 2.0;
      endX   = 0.0;
      endY   = 0.0;
    }

    // 19-20: uGradientStart
    s.setFloat(19, startX);
    s.setFloat(20, startY);
    // 21-22: uGradientEnd
    s.setFloat(21, endX);
    s.setFloat(22, endY);
    // 24: uGradientType
    s.setFloat(24, gradType);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // BUG-02 fix: LayoutBuilder captures the widget's actual render size and
    // caches it for use in the ticker, avoiding MediaQuery inside the ticker.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width  = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.radius * 2.0;
        final double height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.radius * 2.0;

        final newSize = Size(width, height);
        if (newSize != _cachedSize) {
          _cachedSize = newSize;
          _shaderStaticDirty = true; // resolution changed → repush
        }

        return SizedBox(
          width:  width,
          height: height,
          child: BlobInputListener(
            controller:       _controller,
            enableHover:      widget.enableHover,
            onTouchesChanged: (touches) {
              _activeTouches = touches;
            },
            child: ValueListenableBuilder<int>(
              valueListenable: _frameNotifier,
              builder: (_, frame, __) {
                // RepaintBoundary isolates the blob from the rest of the tree.
                return RepaintBoundary(
                  child: CustomPaint(
                    painter: BlobPainter(
                      positions:     _projectedPoints,
                      generation:    frame,
                      shader:        _shader,
                      pointSize:     widget.pointSize,
                      fallbackColor: _color1,
                    ),
                    size:       Size.infinite,
                    isComplex:  true,
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
