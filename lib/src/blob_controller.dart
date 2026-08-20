import 'package:flutter/material.dart';

import 'blob_noise_type.dart';

/// A controller for the [BlobFlutter] widget that provides programmatic
/// control over blob geometry (radius, pointSize, particleCount, scale, offset),
/// animation speed, particle physics, pinch-to-scale, and color flows.
///
/// Follows the [ChangeNotifier] contract — call [dispose] when no longer needed
/// if the controller is created externally.
///
/// Example:
/// ```dart
/// final controller = BlobController(
///   radius: 180.0,
///   pointSize: 2.5,
///   particleCount: 6000,
/// );
/// // ...
/// controller.setRadius(200.0);
/// controller.setPointSize(3.0);
/// controller.setScale(1.5);
/// controller.setCenterOffset(const Offset(20, -10));
/// controller.setNoiseType(BlobNoiseType.spiky);
/// // ...
/// controller.dispose();
/// ```
class BlobController extends ChangeNotifier {
  // ── Geometry & Topology ───────────────────────────────────────────────────
  double _radius;
  double _pointSize;
  int _particleCount;
  double _scale = 1.0;
  double _minScale = 0.1;
  double _maxScale = 10.0;
  Offset _centerOffset = Offset.zero;
  Alignment _alignment = Alignment.center;

  // ── Dynamics & Noise ──────────────────────────────────────────────────────
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _dispersion = 0.0;
  double _dampingFactor;
  double _autoRotationSpeed = 0.5;
  double _noiseFrequency = 1.0;
  BlobNoiseType _noiseType = BlobNoiseType.harmonic;
  double _viewDistance = 2.0;

  // ── Touch & Interaction ───────────────────────────────────────────────────
  double _tapScaleFactor = 1.0;
  double _touchRadiusFactor = 1.0;
  bool _enableHover = false;
  bool _enablePinchToScale = true;

  // ── Color & Shaders ───────────────────────────────────────────────────────
  bool _isRainbowMode = false;
  bool _isColorAnimated = true;
  double _colorAnimationSpeed = 1.0;
  double _waveIntensity = 1.0;
  Gradient? _gradient;

  // ── Accumulated Drag Rotation ─────────────────────────────────────────────
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  BlobController({
    double radius = 150.0,
    double pointSize = 2.0,
    int particleCount = 5000,
    double speed = 1.0,
    double scale = 1.0,
    double minScale = 0.1,
    double maxScale = 10.0,
    Offset centerOffset = Offset.zero,
    Alignment alignment = Alignment.center,
    double dampingFactor = 0.92,
    double tapScaleFactor = 1.0,
    double touchRadiusFactor = 1.0,
    double autoRotationSpeed = 0.5,
    double blobiness = 1.0,
    double dispersion = 0.0,
    double noiseFrequency = 1.0,
    double viewDistance = 2.0,
    bool enableHover = false,
    bool isColorAnimated = true,
    double colorAnimationSpeed = 1.0,
    double waveIntensity = 1.0,
    bool enablePinchToScale = true,
    BlobNoiseType noiseType = BlobNoiseType.harmonic,
    Gradient? gradient,
  })  : _radius = radius,
        _pointSize = pointSize,
        _particleCount = particleCount,
        _speed = speed,
        _scale = scale,
        _minScale = minScale,
        _maxScale = maxScale,
        _centerOffset = centerOffset,
        _alignment = alignment,
        _dampingFactor = dampingFactor,
        _tapScaleFactor = tapScaleFactor,
        _touchRadiusFactor = touchRadiusFactor,
        _autoRotationSpeed = autoRotationSpeed,
        _blobiness = blobiness,
        _dispersion = dispersion,
        _noiseFrequency = noiseFrequency,
        _viewDistance = viewDistance,
        _enableHover = enableHover,
        _isColorAnimated = isColorAnimated,
        _colorAnimationSpeed = colorAnimationSpeed,
        _waveIntensity = waveIntensity,
        _enablePinchToScale = enablePinchToScale,
        _noiseType = noiseType,
        _gradient = gradient,
        assert(radius > 0.0, 'radius must be greater than 0.0'),
        assert(pointSize > 0.0, 'pointSize must be greater than 0.0'),
        assert(particleCount > 0, 'particleCount must be greater than 0'),
        assert(speed >= 0.0, 'speed must be greater than or equal to 0.0'),
        assert(scale > 0.0, 'scale must be greater than 0.0'),
        assert(minScale > 0.0 && minScale <= maxScale,
            'minScale must be > 0.0 and <= maxScale'),
        assert(dampingFactor >= 0.0 && dampingFactor <= 1.0,
            'dampingFactor must be between 0.0 and 1.0'),
        assert(tapScaleFactor >= 0.0,
            'tapScaleFactor must be greater than or equal to 0.0'),
        assert(touchRadiusFactor >= 0.0,
            'touchRadiusFactor must be greater than or equal to 0.0'),
        assert(blobiness >= 0.0, 'blobiness must be greater than or equal to 0.0'),
        assert(dispersion >= 0.0, 'dispersion must be greater than or equal to 0.0'),
        assert(noiseFrequency >= 0.0,
            'noiseFrequency must be greater than or equal to 0.0'),
        assert(viewDistance > 0.0, 'viewDistance must be greater than 0.0'),
        assert(colorAnimationSpeed >= 0.0,
            'colorAnimationSpeed must be greater than or equal to 0.0'),
        assert(waveIntensity >= 0.0,
            'waveIntensity must be greater than or equal to 0.0');

  // ── Geometry Getters ──────────────────────────────────────────────────────

  /// Base sphere radius in logical pixels.
  double get radius => _radius;

  /// Rendered size of each particle point in logical pixels.
  double get pointSize => _pointSize;

  /// Total number of 3D particles distributed on the sphere.
  int get particleCount => _particleCount;

  /// Current zoom/scale multiplier applied to the blob radius. Default: 1.0.
  double get scale => _scale;

  /// Minimum allowable scale limit for pinch gestures and setters.
  double get minScale => _minScale;

  /// Maximum allowable scale limit for pinch gestures and setters.
  double get maxScale => _maxScale;

  /// Pixel offset translation applied to the center of the blob projection.
  Offset get centerOffset => _centerOffset;

  /// Alignment of the blob within its parent viewport box.
  Alignment get alignment => _alignment;

  /// Effective radius after scale factor is applied (`radius * scale`).
  double get effectiveRadius => _radius * _scale;

  // ── Dynamics & Physics Getters ────────────────────────────────────────────

  /// Noise amplitude: how much the sphere surface is displaced.
  /// 0.0 = perfect sphere, higher = more distorted.
  double get blobiness => _blobiness;

  /// Animation speed multiplier. 1.0 = normal, 2.0 = double, 0.5 = half.
  double get speed => _speed;

  /// Alias for [speed].
  double get animationSpeed => _speed;

  /// Radial dispersion. 0.0 = default shape, 1.0 = particles pushed far out.
  double get dispersion => _dispersion;

  /// Scale multiplier applied to particle dispersion on touch/tap.
  /// Range: [0.0, 5.0]. Default: 1.0.
  double get tapScaleFactor => _tapScaleFactor;

  /// Multiplier for the touch interaction radius.
  /// Range: [0.1, 5.0]. Default: 1.0.
  double get touchRadiusFactor => _touchRadiusFactor;

  /// Damping factor applied each frame: 1.0 = no decay, 0.0 = instant stop.
  /// Range: [0.0, 1.0].
  double get dampingFactor => _dampingFactor;

  /// Constant background auto-rotation speed (Y-axis spin).
  double get autoRotationSpeed => _autoRotationSpeed;

  /// Noise frequency multiplier: controls how dense/spiky the waves are.
  double get noiseFrequency => _noiseFrequency;

  /// The procedural noise deformation algorithm used to shape the blob.
  BlobNoiseType get noiseType => _noiseType;

  /// Perspective/3D depth camera distance.
  double get viewDistance => _viewDistance;

  /// Whether hover interaction is enabled on mouse movement without clicking.
  bool get enableHover => _enableHover;

  /// Whether pinch-to-scale two-finger zoom interaction is enabled.
  bool get enablePinchToScale => _enablePinchToScale;

  // ── Color & Shader Getters ────────────────────────────────────────────────

  /// Whether the color gradient cycles through a rainbow sequence.
  bool get isRainbowMode => _isRainbowMode;

  /// Whether the colors animate dynamically across the blob or stay static.
  bool get isColorAnimated => _isColorAnimated;

  /// Speed of color animation/wave motion. 0.0 = static/fixed colors.
  double get colorAnimationSpeed => _colorAnimationSpeed;

  /// Wave distortion intensity applied to the color gradient.
  /// 0.0 = clean geometric gradient, 1.0 = liquid/organic wave shimmer.
  double get waveIntensity => _waveIntensity;

  /// Optional runtime gradient override.
  Gradient? get gradient => _gradient;

  /// Current accumulated X-axis rotation (from drag, with damping applied).
  double get rotationX => _rotationX;

  /// Current accumulated Y-axis rotation (from drag, with damping applied).
  double get rotationY => _rotationY;

  // ── Geometry Setters ──────────────────────────────────────────────────────

  /// Dynamically sets the sphere radius. Clamped to [1.0, 5000.0].
  void setRadius(double value) {
    final clamped = value.clamp(1.0, 5000.0);
    if (_radius != clamped) {
      _radius = clamped;
      notifyListeners();
    }
  }

  /// Dynamically sets the point size of rendered particles. Clamped to [0.1, 100.0].
  void setPointSize(double value) {
    final clamped = value.clamp(0.1, 100.0);
    if (_pointSize != clamped) {
      _pointSize = clamped;
      notifyListeners();
    }
  }

  /// Dynamically sets the particle count. Clamped to [10, 100000].
  /// This will trigger buffer reallocation and worker restart in the widget.
  void setParticleCount(int value) {
    final clamped = value.clamp(10, 100000);
    if (_particleCount != clamped) {
      _particleCount = clamped;
      notifyListeners();
    }
  }

  /// Dynamically sets the scale multiplier. Clamped within `[minScale, maxScale]`.
  void setScale(double value) {
    final clamped = value.clamp(_minScale, _maxScale);
    if (_scale != clamped) {
      _scale = clamped;
      notifyListeners();
    }
  }

  /// Configures the minimum and maximum allowable scale limits.
  void setScaleLimits({double? minScale, double? maxScale}) {
    bool changed = false;
    if (minScale != null && minScale > 0.0 && minScale != _minScale) {
      _minScale = minScale;
      changed = true;
    }
    if (maxScale != null && maxScale >= _minScale && maxScale != _maxScale) {
      _maxScale = maxScale;
      changed = true;
    }
    if (changed) {
      _scale = _scale.clamp(_minScale, _maxScale);
      notifyListeners();
    }
  }

  /// Applies a relative scale factor multiplier (useful for pinch gestures).
  void applyScaleFactor(double factor) {
    if (factor <= 0.0) return;
    setScale(_scale * factor);
  }

  /// Zooms in by the given step amount (default +0.1).
  void zoomIn([double step = 0.1]) => setScale(_scale + step);

  /// Zooms out by the given step amount (default -0.1).
  void zoomOut([double step = 0.1]) => setScale(_scale - step);

  /// Dynamically sets the center pixel offset translation.
  void setCenterOffset(Offset value) {
    if (_centerOffset != value) {
      _centerOffset = value;
      notifyListeners();
    }
  }

  /// Dynamically sets the viewport alignment.
  void setAlignment(Alignment value) {
    if (_alignment != value) {
      _alignment = value;
      notifyListeners();
    }
  }

  /// Enables or disables pinch-to-scale gesture handling.
  void setEnablePinchToScale(bool value) {
    if (_enablePinchToScale != value) {
      _enablePinchToScale = value;
      notifyListeners();
    }
  }

  // ── Dynamics & Physics Setters ────────────────────────────────────────────

  /// Sets the noise amplitude. Clamped to [0.0, 5.0].
  void setBlobiness(double value) {
    final clamped = value.clamp(0.0, 5.0);
    if (_blobiness != clamped) {
      _blobiness = clamped;
      notifyListeners();
    }
  }

  /// Sets the animation speed multiplier. Clamped to [0.0, 10.0].
  void setSpeed(double value) {
    final clamped = value.clamp(0.0, 10.0);
    if (_speed != clamped) {
      _speed = clamped;
      notifyListeners();
    }
  }

  /// Alias for [setSpeed].
  void setAnimationSpeed(double value) => setSpeed(value);

  /// Sets the dispersion level. Clamped to [0.0, 3.0].
  void setDispersion(double value) {
    final clamped = value.clamp(0.0, 3.0);
    if (_dispersion != clamped) {
      _dispersion = clamped;
      notifyListeners();
    }
  }

  /// Sets the tap scale factor. Clamped to be non-negative.
  void setTapScaleFactor(double value) {
    final clamped = value.clamp(0.0, double.infinity);
    if (_tapScaleFactor != clamped) {
      _tapScaleFactor = clamped;
      notifyListeners();
    }
  }

  /// Sets the touch interaction radius multiplier. Clamped to [0.1, 10.0].
  void setTouchRadiusFactor(double value) {
    final clamped = value.clamp(0.1, 10.0);
    if (_touchRadiusFactor != clamped) {
      _touchRadiusFactor = clamped;
      notifyListeners();
    }
  }

  /// Sets the damping factor dynamically. Clamped to [0.0, 1.0].
  void setDampingFactor(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_dampingFactor != clamped) {
      _dampingFactor = clamped;
      notifyListeners();
    }
  }

  /// Sets the background auto-rotation speed. Clamped to [-3.0, 3.0].
  void setAutoRotationSpeed(double value) {
    final clamped = value.clamp(-3.0, 3.0);
    if (_autoRotationSpeed != clamped) {
      _autoRotationSpeed = clamped;
      notifyListeners();
    }
  }

  /// Sets the noise frequency multiplier. Clamped to [0.1, 5.0].
  void setNoiseFrequency(double value) {
    final clamped = value.clamp(0.1, 5.0);
    if (_noiseFrequency != clamped) {
      _noiseFrequency = clamped;
      notifyListeners();
    }
  }

  /// Sets the procedural noise deformation algorithm used to shape the blob.
  void setNoiseType(BlobNoiseType value) {
    if (_noiseType != value) {
      _noiseType = value;
      notifyListeners();
    }
  }

  /// Sets the perspective camera distance. Clamped to [0.8, 5.0].
  void setViewDistance(double value) {
    final clamped = value.clamp(0.8, 5.0);
    if (_viewDistance != clamped) {
      _viewDistance = clamped;
      notifyListeners();
    }
  }

  /// Sets whether the color gradient cycles through a rainbow sequence.
  void setIsRainbowMode(bool value) {
    if (_isRainbowMode != value) {
      _isRainbowMode = value;
      notifyListeners();
    }
  }

  /// Sets whether the color gradient is animated or static.
  void setIsColorAnimated(bool value) {
    if (_isColorAnimated != value) {
      _isColorAnimated = value;
      notifyListeners();
    }
  }

  /// Sets the color animation speed. Clamped to [0.0, 10.0].
  void setColorAnimationSpeed(double value) {
    final clamped = value.clamp(0.0, 10.0);
    if (_colorAnimationSpeed != clamped) {
      _colorAnimationSpeed = clamped;
      notifyListeners();
    }
  }

  /// Sets the wave distortion intensity. Clamped to [0.0, 5.0].
  void setWaveIntensity(double value) {
    final clamped = value.clamp(0.0, 5.0);
    if (_waveIntensity != clamped) {
      _waveIntensity = clamped;
      notifyListeners();
    }
  }

  /// Dynamically changes the gradient at runtime.
  void setGradient(Gradient? value) {
    if (_gradient != value) {
      _gradient = value;
      notifyListeners();
    }
  }

  /// Sets whether hover interaction is enabled on mouse movement without clicking.
  void setEnableHover(bool value) {
    if (_enableHover != value) {
      _enableHover = value;
      notifyListeners();
    }
  }

  /// Alias for [setEnableHover].
  void setIsHoverEnabled(bool value) => setEnableHover(value);

  // ── Drag Rotation & Damping ───────────────────────────────────────────────

  /// Adds an angular velocity impulse from a drag gesture.
  /// Delta is in screen pixels — sensitivity is applied internally.
  void addRotationImpulse(Offset delta) {
    _rotationX += delta.dy * 0.005;
    _rotationY += delta.dx * 0.005;
    notifyListeners();
  }

  /// LOGIC-02: Called every tick from the widget's animation loop.
  /// Applies exponential decay to the rotation so it naturally comes to rest.
  /// Returns true if the rotation is still non-negligible (needs repaint).
  bool applyDamping() {
    _rotationX *= _dampingFactor;
    _rotationY *= _dampingFactor;

    // Snap to zero below threshold to prevent infinite tiny values
    if (_rotationX.abs() < 0.0001) _rotationX = 0.0;
    if (_rotationY.abs() < 0.0001) _rotationY = 0.0;

    return _rotationX != 0.0 || _rotationY != 0.0;
  }

  // ── Resets ────────────────────────────────────────────────────────────────

  /// Resets accumulated rotation to zero immediately.
  void resetRotation() {
    if (_rotationX != 0.0 || _rotationY != 0.0) {
      _rotationX = 0.0;
      _rotationY = 0.0;
      notifyListeners();
    }
  }

  /// Resets scale factor back to 1.0.
  void resetScale() => setScale(1.0);

  /// Resets center offset translation back to [Offset.zero].
  void resetCenterOffset() => setCenterOffset(Offset.zero);

  /// Resets scale, center offset, and rotation.
  void resetGeometry() {
    bool changed = false;
    if (_scale != 1.0) {
      _scale = 1.0;
      changed = true;
    }
    if (_centerOffset != Offset.zero) {
      _centerOffset = Offset.zero;
      changed = true;
    }
    if (_rotationX != 0.0 || _rotationY != 0.0) {
      _rotationX = 0.0;
      _rotationY = 0.0;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Resets all transform properties (rotation, scale, centerOffset, dispersion).
  void resetAll() {
    bool changed = false;
    if (_scale != 1.0) {
      _scale = 1.0;
      changed = true;
    }
    if (_centerOffset != Offset.zero) {
      _centerOffset = Offset.zero;
      changed = true;
    }
    if (_rotationX != 0.0 || _rotationY != 0.0) {
      _rotationX = 0.0;
      _rotationY = 0.0;
      changed = true;
    }
    if (_dispersion != 0.0) {
      _dispersion = 0.0;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
