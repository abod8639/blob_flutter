import 'package:flutter/material.dart';

import 'blob_noise_type.dart';

/// A controller for the [ParticleBlob] widget that provides programmatic
/// control over blob geometry, animation speed, particle physics, and color flows.
///
/// Follows the [ChangeNotifier] contract — call [dispose] when no longer needed
/// if the controller is created externally.
///
/// Example:
/// ```dart
/// final controller = ParticleBlobController();
/// // ...
/// controller.setSpeed(2.0);
/// controller.setNoiseType(BlobNoiseType.spiky);
/// controller.setIsColorAnimated(false); // Static color mode
/// controller.setGradient(LinearGradient(...));
/// // ...
/// controller.dispose();
/// ```
class BlobController extends ChangeNotifier {
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _dispersion = 0.0;
  double _dampingFactor;
  double _autoRotationSpeed = 0.5;
  double _noiseFrequency = 1.0;
  BlobNoiseType _noiseType = BlobNoiseType.harmonic;
  double _viewDistance = 2.0;
  double _tapScaleFactor = 1.0;
  bool _isRainbowMode = false;
  bool _isColorAnimated = true;
  double _colorAnimationSpeed = 1.0;
  double _waveIntensity = 1.0;
  bool _enableHover = false;
  Gradient? _gradient;

  /// Accumulated manual rotation from drag gestures.
  /// LOGIC-02: Managed with damping — decays in the animation ticker rather
  /// than growing infinitely.
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  BlobController({
    double dampingFactor = 0.92,
    double tapScaleFactor = 1.0,
    bool isColorAnimated = true,
    double colorAnimationSpeed = 1.0,
    double waveIntensity = 1.0,
    bool enableHover = false,
    BlobNoiseType noiseType = BlobNoiseType.harmonic,
    Gradient? gradient,
  }) : _dampingFactor = dampingFactor,
       _tapScaleFactor = tapScaleFactor,
       _isColorAnimated = isColorAnimated,
       _colorAnimationSpeed = colorAnimationSpeed,
       _waveIntensity = waveIntensity,
       _enableHover = enableHover,
       _noiseType = noiseType,
       _gradient = gradient,
       assert(dampingFactor >= 0.0 && dampingFactor <= 1.0,
            'dampingFactor must be between 0.0 and 1.0'),
       assert(tapScaleFactor >= 0.0,
            'tapScaleFactor must be greater than or equal to 0.0'),
       assert(colorAnimationSpeed >= 0.0,
            'colorAnimationSpeed must be greater than or equal to 0.0'),
       assert(waveIntensity >= 0.0,
            'waveIntensity must be greater than or equal to 0.0');

  /// Noise amplitude: how much the sphere surface is displaced.
  /// 0.0 = perfect sphere, higher = more distorted.
  double get blobiness => _blobiness;

  /// Animation speed multiplier. 1.0 = normal, 2.0 = double, 0.5 = half.
  double get speed => _speed;

  /// Radial dispersion. 0.0 = default shape, 1.0 = particles pushed far out.
  double get dispersion => _dispersion;

  /// Scale multiplier applied to particle dispersion on touch/tap.
  /// Range: [0.0, 5.0]. Default: 1.0.
  double get tapScaleFactor => _tapScaleFactor;

  /// Whether the color gradient cycles through a rainbow sequence.
  bool get isRainbowMode => _isRainbowMode;

  /// Whether the colors animate dynamically across the blob or stay static.
  bool get isColorAnimated => _isColorAnimated;

  /// Speed of color animation/wave motion. 0.0 = static/fixed colors.
  double get colorAnimationSpeed => _colorAnimationSpeed;

  /// Wave distortion intensity applied to the color gradient.
  /// 0.0 = clean geometric gradient, 1.0 = liquid/organic wave shimmer.
  double get waveIntensity => _waveIntensity;

  /// Whether particle dispersion and interaction triggers on mouse hover without clicking.
  bool get enableHover => _enableHover;

  /// Optional runtime gradient override.
  Gradient? get gradient => _gradient;

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

  /// Current accumulated X-axis rotation (from drag, with damping applied).
  double get rotationX => _rotationX;

  /// Current accumulated Y-axis rotation (from drag, with damping applied).
  double get rotationY => _rotationY;

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

  /// Resets accumulated rotation to zero immediately.
  void resetRotation() {
    if (_rotationX != 0.0 || _rotationY != 0.0) {
      _rotationX = 0.0;
      _rotationY = 0.0;
      notifyListeners();
    }
  }
}
