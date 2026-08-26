import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_worker.dart';

void main() {
  group('BlobWorker Conditional Export Tests', () {
    test('instantiates and computes projected particles via transparent export', () async {
      final worker = BlobWorker();
      const count = 30;
      final sphere = BlobMath.generateFibonacciSphere(count);

      await worker.init(sphere, count);

      final params = ProjectParamsFlat(
        count: count,
        radius: 80.0,
        scale: 1.0,
        centerOffsetX: 0.0,
        centerOffsetY: 0.0,
        blobiness: 1.2,
        dispersion: 0.1,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 300.0,
        viewportHeight: 300.0,
        encodedTouches: Float32List(0),
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
        noiseTypeIndex: BlobNoiseType.fractal.index,
        touchRadiusFactor: 1.0,
      );

      final result = await worker.compute(params);
      expect(result, isNotNull);
      expect(result!.length, count * 2);

      worker.dispose();
    });
  });
}
