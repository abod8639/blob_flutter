import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'blob_controller.dart';
import 'blob_exception.dart';
import 'blob_shader_helper.dart';

/// Coordinates GPU FragmentShader compilation, uniform buffer uploads,
/// dynamic color cycling (rainbow mode), and fallback gradient calculation.
class BlobShaderCoordinator {
  ui.FragmentShader? _shader;

  bool _shaderStaticDirty = true;
  bool _shaderColorsDirty = true;
  Gradient? _lastPushedGradient;

  final List<Color> _rainbowColors = List<Color>.filled(
    8,
    const Color(0xFFFFFFFF),
  );

  /// The active [ui.FragmentShader], if successfully compiled.
  ui.FragmentShader? get shader => _shader;

  /// Flags the shader uniform buffers as needing a full or partial refresh.
  void markDirty({bool staticDirty = true, bool colorsDirty = true}) {
    if (staticDirty) _shaderStaticDirty = true;
    if (colorsDirty) _shaderColorsDirty = true;
  }

  /// Asynchronously loads and initializes the particle fragment shader.
  Future<void> loadShader({
    required bool silent,
    String? overrideAssetPath,
    required void Function(BlobFlutterException error) onError,
    required VoidCallback onShaderLoaded,
  }) async {
    final program = await BlobShaderHelper.loadProgram(
      silent: silent,
      overrideAssetPath: overrideAssetPath,
      onError: onError,
    );

    if (program != null) {
      _shader = program.fragmentShader();
      _shaderStaticDirty = true;
      _shaderColorsDirty = true;
      onShaderLoaded();
    }
  }

  /// Resolves the effective [Gradient] from the controller or widget fallback.
  Gradient getEffectiveGradient(BlobController controller, Gradient widgetGradient) {
    return controller.gradient ?? widgetGradient;
  }

  /// Resolves the effective color palette, accounting for rainbow mode and time progression.
  List<Color> getEffectiveColors(
    BlobController controller,
    Gradient widgetGradient,
    double time,
  ) {
    if (controller.isRainbowMode) {
      final double h = (time * 40.0) % 360.0;
      for (int i = 0; i < 8; i++) {
        _rainbowColors[i] =
            HSVColor.fromAHSV(1.0, (h + i * 45.0) % 360.0, 0.85, 1.0).toColor();
      }
      return _rainbowColors;
    }
    final g = getEffectiveGradient(controller, widgetGradient);
    return g.colors.isNotEmpty
        ? g.colors
        : const [Colors.blueAccent, Colors.purpleAccent];
  }

  /// Resolves the fallback gradient used when fragment shaders are unsupported or failing.
  Gradient getEffectiveFallbackGradient(
    BlobController controller,
    Gradient widgetGradient,
    double time,
  ) {
    if (controller.isRainbowMode) {
      return SweepGradient(colors: getEffectiveColors(controller, widgetGradient, time));
    }
    final g = getEffectiveGradient(controller, widgetGradient);
    if (g.colors.length >= 2) {
      return g;
    } else if (g.colors.length == 1) {
      return LinearGradient(colors: [g.colors.first, g.colors.first]);
    }
    return const LinearGradient(
      colors: [Colors.blueAccent, Colors.purpleAccent],
    );
  }

  /// Primary color used for monochrome CPU particle fallback rendering.
  Color getFallbackColor(
    BlobController controller,
    Gradient widgetGradient,
    double time,
  ) {
    final colors = getEffectiveColors(controller, widgetGradient, time);
    return colors.isNotEmpty ? colors.first : Colors.pinkAccent;
  }

  /// Pushes static and dynamic uniforms to the GPU fragment shader.
  ///
  /// If any uniform push call throws (e.g., invalid uniform index or GPU
  /// context loss), the shader is automatically disabled and [onError] is
  /// called with a [BlobRenderException], causing the widget to fall back
  /// to CPU point rendering for subsequent frames.
  void updateDynamicUniforms({
    required BlobController controller,
    required Gradient widgetGradient,
    required Size cachedSize,
    required double time,
    void Function(BlobRenderException error)? onError,
  }) {
    final s = _shader;
    if (s == null) return;

    try {
      final currentGradient = getEffectiveGradient(controller, widgetGradient);
      if (currentGradient != _lastPushedGradient) {
        _lastPushedGradient = currentGradient;
        _shaderStaticDirty = true;
        _shaderColorsDirty = true;
      }

      if (_shaderStaticDirty) {
        BlobShaderHelper.pushStaticUniforms(
          shader: s,
          size: cachedSize,
          gradient: currentGradient,
          isColorAnimated: controller.isColorAnimated,
          colorAnimationSpeed: controller.colorAnimationSpeed,
          waveIntensity: controller.waveIntensity,
          centerOffset: controller.centerOffset,
          radius: controller.radius * controller.scale,
          alignment: controller.alignment,
        );
        _shaderStaticDirty = false;
      }

      // Index 2: uTime
      s.setFloat(2, time);

      if (controller.isRainbowMode) {
        BlobShaderHelper.pushColors(
          shader: s,
          colors: getEffectiveColors(controller, widgetGradient, time),
          isRainbowMode: true,
        );
      } else if (_shaderColorsDirty) {
        BlobShaderHelper.pushColors(
          shader: s,
          colors: getEffectiveColors(controller, widgetGradient, time),
          stops: currentGradient.stops,
          isRainbowMode: false,
        );
        _shaderColorsDirty = false;
      }
    } catch (err, st) {
      // Disable the shader so the widget falls back to CPU point rendering.
      _shader?.dispose();
      _shader = null;
      onError?.call(
        BlobRenderException.shaderUniformFailed(cause: err, stackTrace: st),
      );
    }
  }

  /// Releases GPU resources allocated for the shader.
  void dispose() {
    _shader?.dispose();
    _shader = null;
  }
}
