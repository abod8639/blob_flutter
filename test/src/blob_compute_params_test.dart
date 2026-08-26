import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';

void main() {
  group('ProjectParamsFlat Tests', () {
    test('constructs with default optional parameters', () {
      final touches = Float32List(0);
      final params = ProjectParamsFlat(
        count: 1000,
        radius: 120.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        encodedTouches: touches,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: BlobNoiseType.harmonic.index,
      );

      expect(params.count, 1000);
      expect(params.radius, 120.0);
      expect(params.scale, 1.0);
      expect(params.centerOffsetX, 0.0);
      expect(params.centerOffsetY, 0.0);
      expect(params.blobiness, 1.0);
      expect(params.dispersion, 0.0);
      expect(params.rotationX, 0.0);
      expect(params.rotationY, 0.0);
      expect(params.time, 1.0);
      expect(params.viewportWidth, 400.0);
      expect(params.viewportHeight, 400.0);
      expect(params.encodedTouches, touches);
      expect(params.autoRotationSpeed, 0.5);
      expect(params.noiseFrequency, 1.0);
      expect(params.viewDistance, 2.0);
      expect(params.noiseTypeIndex, BlobNoiseType.harmonic.index);
      expect(params.touchRadiusFactor, 1.0);
    });

    test('serializes and deserializes all 18 fields faithfully via toMessage and fromMessage', () {
      final touches = Float32List.fromList([10.5, 20.5, 30.5, 40.5]);
      final params = ProjectParamsFlat(
        count: 500,
        radius: 180.0,
        scale: 1.5,
        centerOffsetX: 25.0,
        centerOffsetY: -15.0,
        blobiness: 2.0,
        dispersion: 0.3,
        rotationX: 0.1,
        rotationY: 0.2,
        time: 5.0,
        viewportWidth: 800.0,
        viewportHeight: 600.0,
        encodedTouches: touches,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.2,
        viewDistance: 2.5,
        noiseTypeIndex: BlobNoiseType.vortex.index,
        touchRadiusFactor: 1.25,
      );

      final message = params.toMessage();
      expect(message.length, 18);
      expect(message[0], 500);
      expect(message[1], 180.0);
      expect(message[2], 1.5);
      expect(message[3], 25.0);
      expect(message[4], -15.0);
      expect(message[5], 2.0);
      expect(message[6], 0.3);
      expect(message[7], 0.1);
      expect(message[8], 0.2);
      expect(message[9], 5.0);
      expect(message[10], 800.0);
      expect(message[11], 600.0);
      expect(message[12], 0.5);
      expect(message[13], 1.2);
      expect(message[14], 2.5);
      expect(message[15], BlobNoiseType.vortex.index);
      expect(message[16], 1.25);
      expect(message[17], touches);

      final restored = ProjectParamsFlat.fromMessage(message);

      expect(restored.count, 500);
      expect(restored.radius, 180.0);
      expect(restored.scale, 1.5);
      expect(restored.centerOffsetX, 25.0);
      expect(restored.centerOffsetY, -15.0);
      expect(restored.blobiness, 2.0);
      expect(restored.dispersion, 0.3);
      expect(restored.rotationX, 0.1);
      expect(restored.rotationY, 0.2);
      expect(restored.time, 5.0);
      expect(restored.viewportWidth, 800.0);
      expect(restored.viewportHeight, 600.0);
      expect(restored.autoRotationSpeed, 0.5);
      expect(restored.noiseFrequency, 1.2);
      expect(restored.viewDistance, 2.5);
      expect(restored.noiseTypeIndex, BlobNoiseType.vortex.index);
      expect(restored.touchRadiusFactor, 1.25);
      expect(restored.encodedTouches, touches);
    });

    test('handles empty touches Float32List during serialization', () {
      final params = ProjectParamsFlat(
        count: 10,
        radius: 50.0,
        blobiness: 0.5,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 0.0,
        viewportWidth: 100.0,
        viewportHeight: 100.0,
        encodedTouches: Float32List(0),
        autoRotationSpeed: 0.0,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: 0,
      );

      final message = params.toMessage();
      final restored = ProjectParamsFlat.fromMessage(message);
      expect(restored.encodedTouches.isEmpty, true);
    });
  });
}
