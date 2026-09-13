import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_shader_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlobShaderHelper Tests', () {
    test(
        'loadProgram loads FragmentProgram from assets or handles missing gracefully',
        () async {
      final program = await BlobShaderHelper.loadProgram();
      expect(program, anyOf(isNull, isA<ui.FragmentProgram>()));

      if (program != null) {
        final shader = program.fragmentShader();

        // Test pushStaticUniforms
        const size = Size(400.0, 600.0);
        const gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red, Colors.blue],
        );

        BlobShaderHelper.pushStaticUniforms(
          shader: shader,
          size: size,
          gradient: gradient,
          isColorAnimated: true,
          colorAnimationSpeed: 2.0,
          waveIntensity: 1.5,
        );

        BlobShaderHelper.pushStaticUniforms(
          shader: shader,
          size: size,
          gradient: gradient,
          isColorAnimated: false,
          colorAnimationSpeed: 2.0,
          waveIntensity: 1.5,
        );

        // Test pushColors
        BlobShaderHelper.pushColors(
          shader: shader,
          colors: const [],
          isRainbowMode: false,
        );

        BlobShaderHelper.pushColors(
          shader: shader,
          colors: [const Color(0xFFFF0000)],
          isRainbowMode: false,
        );

        BlobShaderHelper.pushColors(
          shader: shader,
          colors: [
            const Color(0xFFFF0000),
            const Color(0xFF00FF00),
            const Color(0xFF0000FF),
            const Color(0xFFFFFF00),
          ],
          isRainbowMode: false,
        );

        // Test with 8 colors
        BlobShaderHelper.pushColors(
          shader: shader,
          colors: List.generate(8, (i) => Color(0xFF000000 + i * 0x111111)),
          isRainbowMode: true,
        );

        // Test with > 8 colors (downsampling)
        BlobShaderHelper.pushColors(
          shader: shader,
          colors: List.generate(12, (i) => Color(0xFF000000 + i * 0x101010)),
          isRainbowMode: false,
        );

        // Test pushGradientParams with various gradient types
        const linear = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.black, Colors.white],
        );
        BlobShaderHelper.pushGradientParams(shader: shader, gradient: linear);

        const radial = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [Colors.black, Colors.white],
        );
        BlobShaderHelper.pushGradientParams(shader: shader, gradient: radial);

        const sweep = SweepGradient(
          center: Alignment.center,
          colors: [Colors.black, Colors.white],
        );
        BlobShaderHelper.pushGradientParams(shader: shader, gradient: sweep);
      }
    });

    test('pushColorsToSetter correctly pushes custom gradient stops (indices 43-50)', () {
      final floats = <int, double>{};
      final colors = [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
      ];
      final stops = [0.0, 0.2, 1.0];

      BlobShaderHelper.pushColorsToSetter(
        setFloat: (idx, val) => floats[idx] = val,
        colors: colors,
        stops: stops,
        isRainbowMode: false,
      );

      // uColorCount at index 42
      expect(floats[42], 3.0);

      // uStops1 at indices 43-46
      expect(floats[43], closeTo(0.0, 0.0001));
      expect(floats[44], closeTo(0.2, 0.0001));
      expect(floats[45], closeTo(1.0, 0.0001));
      expect(floats[46], closeTo(1.0, 0.0001));

      // uStops2 at indices 47-50
      expect(floats[47], closeTo(1.0, 0.0001));
      expect(floats[48], closeTo(1.0, 0.0001));
      expect(floats[49], closeTo(1.0, 0.0001));
      expect(floats[50], closeTo(1.0, 0.0001));
    });

    test('pushColorsToSetter with null stops calculates evenly distributed stops', () {
      final floats = <int, double>{};
      final colors = [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
      ];

      BlobShaderHelper.pushColorsToSetter(
        setFloat: (idx, val) => floats[idx] = val,
        colors: colors,
        stops: null,
        isRainbowMode: false,
      );

      expect(floats[42], 3.0);
      expect(floats[43], closeTo(0.0, 0.0001));
      expect(floats[44], closeTo(0.5, 0.0001));
      expect(floats[45], closeTo(1.0, 0.0001));
      expect(floats[46], closeTo(1.0, 0.0001));
    });

    test('pushColorsToSetter with isRainbowMode = true distributes 8 stops across 0.0 to 1.0', () {
      final floats = <int, double>{};
      final colors = List.generate(8, (i) => Color(0xFF000000 + i * 0x111111));

      BlobShaderHelper.pushColorsToSetter(
        setFloat: (idx, val) => floats[idx] = val,
        colors: colors,
        isRainbowMode: true,
      );

      expect(floats[42], 8.0);
      for (int i = 0; i < 8; i++) {
        expect(floats[43 + i], closeTo(i / 7.0, 0.0001));
      }
    });

    test('pushColorsToSetter with > 8 colors downsamples stops smoothly', () {
      final floats = <int, double>{};
      final colors = List.generate(16, (i) => Color(0xFF000000 + i * 0x101010));
      final stops = List.generate(16, (i) => i / 15.0);

      BlobShaderHelper.pushColorsToSetter(
        setFloat: (idx, val) => floats[idx] = val,
        colors: colors,
        stops: stops,
        isRainbowMode: false,
      );

      expect(floats[42], 8.0);
      expect(floats[43], closeTo(0.0, 0.0001));
      expect(floats[50], closeTo(1.0, 0.0001));
    });
  });
}
