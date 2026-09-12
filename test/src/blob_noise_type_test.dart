import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';

void main() {
  group('BlobNoiseType Enum Tests', () {
    test('contains exact 8 noise algorithm types', () {
      expect(BlobNoiseType.values.length, 8);
      expect(BlobNoiseType.values, [
        BlobNoiseType.harmonic,
        BlobNoiseType.spiky,
        BlobNoiseType.fractal,
        BlobNoiseType.cellular,
        BlobNoiseType.vortex,
        BlobNoiseType.sphericalHarmonics,
        BlobNoiseType.simplex,
        BlobNoiseType.wave,
      ]);
    });

    test('indices match expected sequence for isolate message encoding', () {
      expect(BlobNoiseType.harmonic.index, 0);
      expect(BlobNoiseType.spiky.index, 1);
      expect(BlobNoiseType.fractal.index, 2);
      expect(BlobNoiseType.cellular.index, 3);
      expect(BlobNoiseType.vortex.index, 4);
      expect(BlobNoiseType.sphericalHarmonics.index, 5);
      expect(BlobNoiseType.simplex.index, 6);
      expect(BlobNoiseType.wave.index, 7);
    });

    test('recovers enum correctly from integer index', () {
      for (int i = 0; i < BlobNoiseType.values.length; i++) {
        expect(BlobNoiseType.values[i].index, i);
      }
    });

    test('names match procedural algorithm descriptions', () {
      expect(BlobNoiseType.harmonic.name, 'harmonic');
      expect(BlobNoiseType.spiky.name, 'spiky');
      expect(BlobNoiseType.fractal.name, 'fractal');
      expect(BlobNoiseType.cellular.name, 'cellular');
      expect(BlobNoiseType.vortex.name, 'vortex');
      expect(BlobNoiseType.sphericalHarmonics.name, 'sphericalHarmonics');
      expect(BlobNoiseType.simplex.name, 'simplex');
      expect(BlobNoiseType.wave.name, 'wave');
    });
  });
}
