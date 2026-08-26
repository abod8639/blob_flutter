import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_shader_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlobShaderHelper Tests', () {
    test('loadProgram loads FragmentProgram from assets or handles missing gracefully', () async {
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
          isRainbowMode: true,
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
  });
}
