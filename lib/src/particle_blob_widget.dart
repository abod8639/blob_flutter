import 'package:flutter/material.dart';

import 'blob_controller.dart';
import 'blob_flutter_widget.dart';
import 'blob_noise_type.dart';

/// Legacy wrapper for [BlobFlutter] to maintain backwards compatibility.
class ParticleBlob extends StatelessWidget {
  final int particleCount;
  final double radius;
  final double pointSize;
  final BlobController? controller;
  final double tapScaleFactor;
  final Gradient gradient;
  final bool isColorAnimated;
  final double colorAnimationSpeed;
  final double waveIntensity;
  final bool enableHover;
  final BlobNoiseType noiseType;

  const ParticleBlob({
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
  });

  @override
  Widget build(BuildContext context) {
    return BlobFlutter(
      particleCount: particleCount,
      radius: radius,
      pointSize: pointSize,
      controller: controller,
      tapScaleFactor: tapScaleFactor,
      gradient: gradient,
      isColorAnimated: isColorAnimated,
      colorAnimationSpeed: colorAnimationSpeed,
      waveIntensity: waveIntensity,
      enableHover: enableHover,
      noiseType: noiseType,
    );
  }
}
