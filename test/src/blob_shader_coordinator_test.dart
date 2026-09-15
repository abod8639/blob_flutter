import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_exception.dart';
import 'package:blob_flutter/src/blob_shader_coordinator.dart';

void main() {
  group('BlobShaderCoordinator Tests', () {
    test('getEffectiveFallbackGradient handles 1 color, 0 colors, and rainbow (L90)', () {
      final coordinator = BlobShaderCoordinator();
      final controller = BlobController();

      // Test with 1 color gradient (L90)
      const singleColorGradient = LinearGradient(colors: [Colors.red]);
      final fallback1 = coordinator.getEffectiveFallbackGradient(
        controller,
        singleColorGradient,
        0.0,
      );
      expect(fallback1.colors.length, 2);
      expect(fallback1.colors[0], Colors.red);
      expect(fallback1.colors[1], Colors.red);

      // Test with 0 colors (empty gradient fallback)
      const emptyGradient = LinearGradient(colors: []);
      final fallbackEmpty = coordinator.getEffectiveFallbackGradient(
        controller,
        emptyGradient,
        0.0,
      );
      expect(fallbackEmpty.colors.length, 2);
      expect(fallbackEmpty.colors[0], Colors.blueAccent);
      expect(fallbackEmpty.colors[1], Colors.purpleAccent);

      // Test with 2+ colors
      const twoColorGradient = LinearGradient(colors: [Colors.green, Colors.yellow]);
      final fallback2 = coordinator.getEffectiveFallbackGradient(
        controller,
        twoColorGradient,
        0.0,
      );
      expect(fallback2, twoColorGradient);

      // Test rainbow mode
      controller.setIsRainbowMode(true);
      final fallbackRainbow = coordinator.getEffectiveFallbackGradient(
        controller,
        twoColorGradient,
        0.0,
      );
      expect(fallbackRainbow, isA<SweepGradient>());
    });

    test('getFallbackColor returns first color or pinkAccent fallback', () {
      final coordinator = BlobShaderCoordinator();
      final controller = BlobController();

      const gradient = LinearGradient(colors: [Colors.orange, Colors.teal]);
      expect(
        coordinator.getFallbackColor(controller, gradient, 0.0),
        Colors.orange,
      );

      const emptyGradient = LinearGradient(colors: []);
      expect(
        coordinator.getFallbackColor(controller, emptyGradient, 0.0),
        Colors.pinkAccent,
      );
    });

    test('markDirty flags static and colors dirty buffers', () {
      final coordinator = BlobShaderCoordinator();
      coordinator.markDirty(staticDirty: true, colorsDirty: true);
      // Verify no exception on markDirty and initial shader state
      expect(coordinator.shader, isNull);
      coordinator.dispose();
      expect(coordinator.shader, isNull);
    });

    test('updateDynamicUniforms catches uniform error and triggers onError (L185-L188)', () {
      final coordinator = BlobShaderCoordinator();
      final controller = BlobController();
      BlobRenderException? capturedError;

      BlobShaderCoordinator.debugOnUpdateDynamicUniforms = () {
        throw Exception('Simulated uniform failure');
      };

      try {
        coordinator.updateDynamicUniforms(
          controller: controller,
          widgetGradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
          cachedSize: const Size(200, 200),
          time: 1.0,
          onError: (err) {
            capturedError = err;
          },
        );

        expect(capturedError, isNotNull);
        expect(capturedError!.code, BlobErrorCode.renderFailed);
        expect(capturedError!.cause.toString(), contains('Simulated uniform failure'));
        expect(coordinator.shader, isNull);
      } finally {
        BlobShaderCoordinator.debugOnUpdateDynamicUniforms = null;
        coordinator.dispose();
        controller.dispose();
      }
    });
  });
}
