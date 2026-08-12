import 'dart:typed_data';

/// Flat, isolate-safe bundle of per-frame particle-projection parameters.
///
/// **Why flat?** Dart isolates communicate by copying messages.  Custom class
/// instances are not directly transferable, but primitives and typed-data
/// buffers are.  [ProjectParamsFlat] serialises everything into a plain [List]
/// (via [toMessage]) that the Dart runtime can copy cheaply across isolate
/// boundaries without reflection or manual serialisation code.
class ProjectParamsFlat {
  final int    count;
  final double radius;
  final double blobiness;
  final double dispersion;
  final double rotationX;
  final double rotationY;
  final double time;
  final double viewportWidth;
  final double viewportHeight;

  /// Encoded touch positions: [x0, y0, x1, y1, …].
  /// Empty [Float32List] means no active touches.
  final Float32List encodedTouches;

  final double autoRotationSpeed;
  final double noiseFrequency;
  final double viewDistance;

  /// [BlobNoiseType.index] — avoids sending a Dart enum across the boundary.
  final int noiseTypeIndex;

  const ProjectParamsFlat({
    required this.count,
    required this.radius,
    required this.blobiness,
    required this.dispersion,
    required this.rotationX,
    required this.rotationY,
    required this.time,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.encodedTouches,
    required this.autoRotationSpeed,
    required this.noiseFrequency,
    required this.viewDistance,
    required this.noiseTypeIndex,
  });

  /// Packs all fields into a [List] that satisfies Dart's isolate message
  /// protocol (primitives + [Float32List]).
  List<Object?> toMessage() => [
    count,
    radius, blobiness, dispersion,
    rotationX, rotationY,
    time, viewportWidth, viewportHeight,
    autoRotationSpeed, noiseFrequency, viewDistance,
    noiseTypeIndex,
    encodedTouches,
  ];

  /// Restores a [ProjectParamsFlat] from a message previously produced by
  /// [toMessage].
  factory ProjectParamsFlat.fromMessage(List<dynamic> m) =>
      ProjectParamsFlat(
        count:             m[0]  as int,
        radius:            m[1]  as double,
        blobiness:         m[2]  as double,
        dispersion:        m[3]  as double,
        rotationX:         m[4]  as double,
        rotationY:         m[5]  as double,
        time:              m[6]  as double,
        viewportWidth:     m[7]  as double,
        viewportHeight:    m[8]  as double,
        autoRotationSpeed: m[9]  as double,
        noiseFrequency:    m[10] as double,
        viewDistance:      m[11] as double,
        noiseTypeIndex:    m[12] as int,
        encodedTouches:    m[13] as Float32List,
      );
}
