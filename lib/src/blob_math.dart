import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'blob_noise_type.dart';

/// Function signature for a single-particle noise displacement function.
///
/// Selected once per frame via [BlobMath._selectNoise], then called for every
/// particle.  This moves the [BlobNoiseType] switch from O(particleCount) to
/// O(1) per frame.
typedef _NoiseFunc = double Function(
  double px,
  double py,
  double pz,
  double f,
  double time,
  double time15,
  double blobiness,
);

/// Utility class for all 3D particle mathematics.
///
/// Uses a flat [Float32List] for the base sphere (BUG-07 fix):
/// Points are packed as [x0,y0,z0, x1,y1,z1, ...].
/// Access via index `i*3`, `i*3+1`, `i*3+2`.
class BlobMath {
  /// Constant: 2π, used for time wrapping.
  static const double twoPi = pi * 2.0;

  /// Constant: golden angle in radians for Fibonacci lattice.
  static const double _goldenAngle = pi * (3.0 - 2.2360679774997896);

  // Simplex 3D gradients and static permutation table
  static final Float32List _grad3 = Float32List.fromList([
    1, 1, 0, -1, 1, 0, 1, -1, 0, -1, -1, 0,
    1, 0, 1, -1, 0, 1, 1, 0, -1, -1, 0, -1,
    0, 1, 1, 0, -1, 1, 0, 1, -1, 0, -1, -1,
    1, 1, 0, 0, -1, 1, -1, 1, 0, 0, -1, -1,
  ]);

  static final Uint8List _perm = _initPerm();

  static Uint8List _initPerm() {
    final p = Uint8List(512);
    // Fixed deterministic seed permutation for zero frame allocations and consistency
    final base = List<int>.generate(256, (i) => (i * 151 + 73) & 255);
    for (int i = 0; i < 512; i++) {
      p[i] = base[i & 255];
    }
    return p;
  }

  /// Evaluates 3D Simplex noise at coordinates ([x], [y], [z]).
  /// Returns value approximately in range [-1.0, 1.0].
  static double fastSimplex3D(double xin, double yin, double zin) {
    const double f3 = 1.0 / 3.0;
    final double s = (xin + yin + zin) * f3;
    final int i = (xin + s).floor();
    final int j = (yin + s).floor();
    final int k = (zin + s).floor();

    const double g3 = 1.0 / 6.0;
    final double t = (i + j + k) * g3;
    final double x00 = i - t;
    final double y00 = j - t;
    final double z00 = k - t;
    final double x0 = xin - x00;
    final double y0 = yin - y00;
    final double z0 = zin - z00;

    int i1, j1, k1;
    int i2, j2, k2;

    if (x0 >= y0) {
      if (y0 >= z0) {
        i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 1; k2 = 0;
      } else if (x0 >= z0) {
        i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 0; k2 = 1;
      } else {
        i1 = 0; j1 = 0; k1 = 1; i2 = 1; j2 = 0; k2 = 1;
      }
    } else {
      if (y0 < z0) {
        i1 = 0; j1 = 0; k1 = 1; i2 = 0; j2 = 1; k2 = 1;
      } else if (x0 < z0) {
        i1 = 0; j1 = 1; k1 = 0; i2 = 0; j2 = 1; k2 = 1;
      } else {
        i1 = 0; j1 = 1; k1 = 0; i2 = 1; j2 = 1; k2 = 0;
      }
    }

    final double x1 = x0 - i1 + g3;
    final double y1 = y0 - j1 + g3;
    final double z1 = z0 - k1 + g3;
    final double x2 = x0 - i2 + 2.0 * g3;
    final double y2 = y0 - j2 + 2.0 * g3;
    final double z2 = z0 - k2 + 2.0 * g3;
    final double x3 = x0 - 1.0 + 3.0 * g3;
    final double y3 = y0 - 1.0 + 3.0 * g3;
    final double z3 = z0 - 1.0 + 3.0 * g3;

    final int ii = i & 255;
    final int jj = j & 255;
    final int kk = k & 255;

    double n0 = 0.0, n1 = 0.0, n2 = 0.0, n3 = 0.0;

    double t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0;
    if (t0 > 0) {
      t0 *= t0;
      final int gi0 = (_perm[ii + _perm[jj + _perm[kk]]] % 12) * 3;
      n0 = t0 * t0 * (_grad3[gi0] * x0 + _grad3[gi0 + 1] * y0 + _grad3[gi0 + 2] * z0);
    }

    double t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1;
    if (t1 > 0) {
      t1 *= t1;
      final int gi1 = (_perm[ii + i1 + _perm[jj + j1 + _perm[kk + k1]]] % 12) * 3;
      n1 = t1 * t1 * (_grad3[gi1] * x1 + _grad3[gi1 + 1] * y1 + _grad3[gi1 + 2] * z1);
    }

    double t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2;
    if (t2 > 0) {
      t2 *= t2;
      final int gi2 = (_perm[ii + i2 + _perm[jj + j2 + _perm[kk + k2]]] % 12) * 3;
      n2 = t2 * t2 * (_grad3[gi2] * x2 + _grad3[gi2 + 1] * y2 + _grad3[gi2 + 2] * z2);
    }

    double t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3;
    if (t3 > 0) {
      t3 *= t3;
      final int gi3 = (_perm[ii + 1 + _perm[jj + 1 + _perm[kk + 1]]] % 12) * 3;
      n3 = t3 * t3 * (_grad3[gi3] * x3 + _grad3[gi3 + 1] * y3 + _grad3[gi3 + 2] * z3);
    }

    return 32.0 * (n0 + n1 + n2 + n3);
  }

  // ── Per-particle noise functions ────────────────────────────────────────────
  //
  // Each static method corresponds to one [BlobNoiseType] variant and is
  // selected once per frame by [_selectNoise], eliminating the O(particleCount)
  // switch that previously ran inside the particle loop.

  static double _harmonicNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double n = sin(px * 3.0 * f + time) *
                     cos(py * 2.0 * f - time) *
                     sin(pz * 4.0 * f + time15);
    return 1.0 + n * 0.3 * blobiness;
  }

  static double _spikyNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double raw = (sin(px * 4.0 * f + time) +
                        cos(py * 4.0 * f - time) +
                        sin(pz * 4.0 * f + time15)) / 3.0;
    final double spike = 1.0 - raw.abs();
    final double n = spike * spike * spike;
    return 1.0 + (n * 0.6 - 0.1) * blobiness;
  }

  static double _fractalNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    double n = sin(px * 2.0 * f + time) *
               cos(py * 2.0 * f - time) *
               sin(pz * 2.0 * f + time);
    n += 0.5  * (sin(px * 4.0 * f - time15) * cos(py * 4.0 * f + time15));
    n += 0.25 * (sin(px * 8.0 * f + time * 2.0) * sin(pz * 8.0 * f - time * 2.0));
    return 1.0 + n * 0.22 * blobiness;
  }

  static double _cellularNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double c1 = cos(px * 3.0 * f + time);
    final double c2 = cos(py * 3.0 * f - time);
    final double c3 = cos(pz * 3.0 * f + time15);
    final double cell = sqrt((c1 * c1 + c2 * c2 + c3 * c3) / 3.0);
    return 1.0 + (cell - 0.58) * 0.5 * blobiness;
  }

  static double _vortexNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double angle = py * 3.0 + time;
    final double cosA  = cos(angle);
    final double sinA  = sin(angle);
    final double tx = px * cosA - pz * sinA;
    final double tz = px * sinA + pz * cosA;
    final double n = sin(tx * 3.0 * f) * cos(tz * 3.0 * f + time) * cos(py * 2.0 * f);
    return 1.0 + n * 0.35 * blobiness;
  }

  static double _sphericalHarmonicsNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double phi   = atan2(pz, px);
    final double theta = asin(py.clamp(-1.0, 1.0));
    final double n = sin(4.0 * phi * f + time) * cos(3.0 * theta * f + time15);
    return 1.0 + n * 0.35 * blobiness;
  }

  static double _simplexNoise(double px, double py, double pz,
      double f, double time, double time15, double blobiness) {
    final double n = fastSimplex3D(
      px * f * 1.5 + sin(time * 0.5) * 0.2,
      py * f * 1.5 + cos(time * 0.5) * 0.2,
      pz * f * 1.5 + time * 0.3,
    );
    return 1.0 + n * 0.35 * blobiness;
  }

  /// Returns the noise function matching [type].
  ///
  /// Called **once per frame**, before the particle loop, so that the inner
  /// loop body contains only a direct function call with no branching.
  static _NoiseFunc _selectNoise(BlobNoiseType type) {
    switch (type) {
      case BlobNoiseType.harmonic:           return _harmonicNoise;
      case BlobNoiseType.spiky:              return _spikyNoise;
      case BlobNoiseType.fractal:            return _fractalNoise;
      case BlobNoiseType.cellular:           return _cellularNoise;
      case BlobNoiseType.vortex:             return _vortexNoise;
      case BlobNoiseType.sphericalHarmonics: return _sphericalHarmonicsNoise;
      case BlobNoiseType.simplex:            return _simplexNoise;
    }
  }

  /// Generates points evenly distributed on a unit sphere using the Fibonacci
  /// lattice algorithm, stored in a flat [Float32List] of length [samples * 3].
  ///
  /// Layout: [x0, y0, z0, x1, y1, z1, ...]
  ///
  /// BUG-01 fix: Guards against [samples] <= 1 to prevent division by zero.
  static Float32List generateFibonacciSphere(int samples) {
    assert(samples > 0, 'samples must be greater than 0');
    final buffer = Float32List(samples * 3);

    for (int i = 0; i < samples; i++) {
      // BUG-01: safe division — when samples == 1, y = 0.0
      final double y =
          samples > 1 ? 1.0 - (i / (samples - 1)) * 2.0 : 0.0;

      final double radiusAtY = sqrt((1.0 - y * y).clamp(0.0, 1.0));
      final double theta = _goldenAngle * i;

      buffer[i * 3]     = cos(theta) * radiusAtY; // x
      buffer[i * 3 + 1] = y;                       // y
      buffer[i * 3 + 2] = sin(theta) * radiusAtY; // z
    }
    return buffer;
  }

  /// Wraps [time] to stay within [0, 2π * 100] to prevent floating-point
  /// precision degradation over long runtimes (LOGIC-01 fix).
  static double wrapTime(double time) {
    const double limit = twoPi * 100.0;
    return time % limit;
  }

  /// Projects 3D sphere particles onto a 2D viewport with organic noise
  /// displacement, multi-touch dispersion, and perspective rotation.
  ///
  /// The noise algorithm is selected **once** via [_selectNoise] before the
  /// particle loop, avoiding O(count) branch evaluations per frame.
  static void projectParticles({
    required int count,
    required double radius,
    required double blobiness,
    required double dispersion,
    required double rotationX,
    required double rotationY,
    required double time,
    required double viewportWidth,
    required double viewportHeight,
    required List<Offset> activeTouches,
    required Float32List baseSphere,
    required Float32List projectedPoints,
    required double autoRotationSpeed,
    required double noiseFrequency,
    required double viewDistance,
    BlobNoiseType noiseType = BlobNoiseType.harmonic,
    double touchRadiusFactor = 1.0,
  }) {
    final double centerX = viewportWidth  / 2.0;
    final double centerY = viewportHeight / 2.0;

    // Auto-rotation angle derived from time and autoRotationSpeed
    final double autoRotY  = time * autoRotationSpeed;
    final double totalRotY = autoRotY + rotationY;
    final double cosRotY   = cos(totalRotY);
    final double sinRotY   = sin(totalRotY);
    final double cosRotX   = cos(rotationX);
    final double sinRotX   = sin(rotationX);

    // Precalculate time constant for noise functions
    final double time15 = time * 1.5;
    final double f = noiseFrequency;

    // Cache variables for touch interaction
    final bool   hasPointers = activeTouches.isNotEmpty;
    final int    touchCount  = activeTouches.length;
    final double effectiveTouchRadius = radius * 2.0 * touchRadiusFactor;

    // ── Select noise function ONCE per frame (O(1)) ──────────────────────────
    final _NoiseFunc noise = _selectNoise(noiseType);

    for (int i = 0; i < count; i++) {
      final int base = i * 3;

      double px = baseSphere[base];
      double py = baseSphere[base + 1];
      double pz = baseSphere[base + 2];

      // Apply procedural noise displacement via the pre-selected function
      final double displacement = noise(px, py, pz, f, time, time15, blobiness);
      px *= displacement;
      py *= displacement;
      pz *= displacement;

      // Apply rotations (Y-axis first, then X-axis)
      final double xAfterY = px * cosRotY + pz * sinRotY;
      final double zAfterY = -px * sinRotY + pz * cosRotY;
      final double yAfterX = py * cosRotX - zAfterY * sinRotX;
      final double zAfterX = py * sinRotX + zAfterY * cosRotX;

      double rx = xAfterY;
      double ry = yAfterX;
      final double rz = zAfterX;

      // Perspective projection with clamped Z denominator
      final double safeZ     = (viewDistance + rz).clamp(0.1, 10.0);
      final double baseScale = radius / safeZ;

      // Projected screen coordinates before dispersion
      final double screenX = centerX + rx * baseScale * 2.0;
      final double screenY = centerY + ry * baseScale * 2.0;

      // Direction-aware touch dispersion based on actual screen position
      double extraPush = 0.0;
      if (hasPointers) {
        for (int t = 0; t < touchCount; t++) {
          final Offset touch    = activeTouches[t];
          final double dx       = screenX - touch.dx;
          final double dy       = screenY - touch.dy;
          final double dist     = sqrt(dx * dx + dy * dy);
          final double influence =
              (1.0 - (dist / effectiveTouchRadius).clamp(0.0, 1.0));
          extraPush += dispersion * influence * 2.0;
        }
      } else if (dispersion > 0.0) {
        // Controller-driven uniform radial dispersion
        extraPush = dispersion;
      }

      // Apply dispersion push only to X and Y screen displacements
      final double pushScale = 1.0 + extraPush;
      rx *= pushScale;
      ry *= pushScale;

      final int outIndex = i * 2;
      projectedPoints[outIndex]     = centerX + rx * baseScale * 2.0;
      projectedPoints[outIndex + 1] = centerY + ry * baseScale * 2.0;
    }
  }
}
