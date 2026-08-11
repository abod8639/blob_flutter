/// Defines the procedural 3D noise deformation algorithm used to morph the particle sphere.
enum BlobNoiseType {
  /// Classic harmonic sine-cosine wave superposition.
  /// Produces smooth, fluid, organic liquid blob motion.
  harmonic,

  /// Sharp ridges, peaks, and spiky tentacles.
  /// Produces an urchin, virus, or crystalline spiky surface.
  spiky,

  /// Fractal Brownian Motion (fBm / multi-octave noise).
  /// Produces complex, turbulent cloud/terrain surface details.
  fractal,

  /// Worley/Cellular pseudo-noise.
  /// Produces segmented, biological cell, bubble, or faceted clusters.
  cellular,

  /// Twisting vortex/tornado deformation along the Y-axis.
  /// Produces a swirling galaxy/cyclone deformation.
  vortex,

  /// Symmetrical harmonic standing waves derived from spherical coordinates.
  /// Produces acoustic cymatics and quantum orbital symmetric geometries.
  sphericalHarmonics,

  /// Ultra-smooth 3D simplex noise with uniform omni-directional deformation.
  /// Produces natural flowing liquid with zero directional axis artifacts.
  simplex,

  /// Dynamic fire flame noise with upward turbulent flickering and tapering top.
  /// Produces dancing fire flames and rising heat tendrils.
  flame,
}
