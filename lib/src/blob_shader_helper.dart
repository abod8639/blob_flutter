import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'blob_exception.dart';

/// Helper class for loading the fragment shader asset and pushing static and
/// dynamic uniforms onto [ui.FragmentShader].
class BlobShaderHelper {
  /// Primary package asset path for fragment shader.
  static const String packageAssetPath =
      'packages/blob_flutter/shaders/blob.frag';

  /// Fallback local asset path for fragment shader (when developing inside package).
  static const String localAssetPath = 'shaders/blob.frag';

  /// Loads the [ui.FragmentProgram] from package assets or local assets.
  ///
  /// If loading fails, constructs a [BlobShaderException] with actionable troubleshooting
  /// advice, reports it via [FlutterError.reportError], invokes [onError] if provided,
  /// and returns `null`.
  static Future<ui.FragmentProgram?> loadProgram({
    void Function(BlobShaderException exception)? onError,
    bool silent = false,
    String? overrideAssetPath,
  }) async {
    final attemptedPaths = overrideAssetPath != null
        ? <String>[overrideAssetPath]
        : <String>[packageAssetPath, localAssetPath];
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final path in attemptedPaths) {
      try {
        return await ui.FragmentProgram.fromAsset(path);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
      }
    }

    final exception = BlobShaderException.assetLoadFailed(
      attemptedPaths: attemptedPaths,
      cause: lastError,
      stackTrace: lastStackTrace,
    );

    if (!silent) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: lastStackTrace,
          library: 'blob_flutter',
          context: ErrorDescription('while loading fragment shader for BlobFlutter'),
          informationCollector: () => [
            ErrorSummary('Fragment shader could not be loaded.'),
            ErrorDescription(
              'BlobFlutter attempted to load the shader from:\n'
              '  - $packageAssetPath\n'
              '  - $localAssetPath',
            ),
            ErrorHint(
              'To fix this issue:\n'
              '1. In your application pubspec.yaml, verify that shaders are declared:\n'
              '   flutter:\n'
              '     shaders:\n'
              '       - packages/blob_flutter/shaders/blob.frag\n'
              '2. Run `flutter pub get` and execute a FULL restart of the app (Hot Reload does not recompile shaders).\n'
              '3. If running in widget tests, shaders cannot be compiled without custom asset bundles. '
              'BlobFlutter will automatically fallback to high-performance CPU point rendering.',
            ),
          ],
        ),
      );
    }

    onError?.call(exception);
    return null;
  }

  /// Pushes static uniforms (resolution, gradient geometry, animation speed,
  /// wave intensity).
  static void pushStaticUniforms({
    required ui.FragmentShader shader,
    required Size size,
    required Gradient gradient,
    required bool isColorAnimated,
    required double colorAnimationSpeed,
    required double waveIntensity,
  }) {
    // 0-1: uResolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 19-22, 24: Gradient geometry
    pushGradientParams(shader: shader, gradient: gradient);

    // 23: uColorAnimationSpeed
    shader.setFloat(23, isColorAnimated ? colorAnimationSpeed : 0.0);

    // 25: uWaveIntensity
    shader.setFloat(25, waveIntensity);
  }

  /// Pushes uColor1-4 and uColorCount (indices 3-18, 26).
  static void pushColors({
    required ui.FragmentShader shader,
    required List<Color> colors,
    required bool isRainbowMode,
  }) {
    final int count = colors.length.clamp(1, 4);
    final c1 = colors[0];
    final c2 = count > 1 ? colors[1] : c1;
    final c3 = count > 2 ? colors[2] : c2;
    final c4 = count > 3 ? colors[3] : c3;

    // uColor1 (3-6)
    shader.setFloat(3, c1.r);
    shader.setFloat(4, c1.g);
    shader.setFloat(5, c1.b);
    shader.setFloat(6, c1.a);

    // uColor2 (7-10)
    shader.setFloat(7, c2.r);
    shader.setFloat(8, c2.g);
    shader.setFloat(9, c2.b);
    shader.setFloat(10, c2.a);

    // uColor3 (11-14)
    shader.setFloat(11, c3.r);
    shader.setFloat(12, c3.g);
    shader.setFloat(13, c3.b);
    shader.setFloat(14, c3.a);

    // uColor4 (15-18)
    shader.setFloat(15, c4.r);
    shader.setFloat(16, c4.g);
    shader.setFloat(17, c4.b);
    shader.setFloat(18, c4.a);

    // 26: uColorCount
    shader.setFloat(26, isRainbowMode ? 4.0 : count.toDouble());
  }

  /// Parses [gradient] and pushes gradient geometry + type uniforms.
  static void pushGradientParams({
    required ui.FragmentShader shader,
    required Gradient gradient,
  }) {
    double startX = 0.5, startY = 0.0;
    double endX = 0.5, endY = 1.0;
    double gradType = 0.0; // 0 = Linear, 1 = Radial, 2 = Sweep

    if (gradient is LinearGradient) {
      gradType = 0.0;
      final begin = gradient.begin.resolve(TextDirection.ltr);
      final end = gradient.end.resolve(TextDirection.ltr);
      startX = (begin.x + 1.0) / 2.0;
      startY = (begin.y + 1.0) / 2.0;
      endX = (end.x + 1.0) / 2.0;
      endY = (end.y + 1.0) / 2.0;
    } else if (gradient is RadialGradient) {
      gradType = 1.0;
      final center = gradient.center.resolve(TextDirection.ltr);
      startX = (center.x + 1.0) / 2.0;
      startY = (center.y + 1.0) / 2.0;
      endX = gradient.radius;
      endY = 0.0;
    } else if (gradient is SweepGradient) {
      gradType = 2.0;
      final center = gradient.center.resolve(TextDirection.ltr);
      startX = (center.x + 1.0) / 2.0;
      startY = (center.y + 1.0) / 2.0;
      endX = 0.0;
      endY = 0.0;
    }

    // 19-20: uGradientStart
    shader.setFloat(19, startX);
    shader.setFloat(20, startY);
    // 21-22: uGradientEnd
    shader.setFloat(21, endX);
    shader.setFloat(22, endY);
    // 24: uGradientType
    shader.setFloat(24, gradType);
  }
}
