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

  /// Checks whether the application is running inside a Flutter test environment
  /// (e.g. `flutter_test`).
  static bool get isRunningInTest {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('TestWidgetsFlutterBinding') ||
        binding.contains('AutomatedTestWidgetsFlutterBinding') ||
        binding.contains('LiveTestWidgetsFlutterBinding') ||
        binding.contains('TestBinding');
  }

  /// Loads the [ui.FragmentProgram] from package assets or local assets.
  ///
  /// If loading fails, constructs a [BlobShaderException] with actionable troubleshooting
  /// advice, reports it via [FlutterError.reportError] (unless silenced or running in tests),
  /// invokes [onError] if provided, and returns `null`.
  static Future<ui.FragmentProgram?> loadProgram({
    void Function(BlobShaderException exception)? onError,
    bool? silent,
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

    final effectiveSilent = silent ?? isRunningInTest;
    if (!effectiveSilent) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: lastStackTrace,
          library: 'blob_flutter',
          context:
              ErrorDescription('while loading fragment shader for BlobFlutter'),
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

    // 35-38, 40: Gradient geometry
    pushGradientParams(shader: shader, gradient: gradient);

    // 39: uColorAnimationSpeed
    shader.setFloat(39, isColorAnimated ? colorAnimationSpeed : 0.0);

    // 41: uWaveIntensity
    shader.setFloat(41, waveIntensity);
  }

  /// Pushes uColor1-8, uColorCount, and uStops1-2 (indices 3-34, 42, 43-50).
  ///
  /// Supports up to 8 colors and their corresponding [stops]. If [colors] has
  /// more than 8 colors, it samples 8 colors and stops smoothly across the gradient palette.
  static void pushColors({
    required ui.FragmentShader shader,
    required List<Color> colors,
    List<double>? stops,
    required bool isRainbowMode,
  }) {
    pushColorsToSetter(
      setFloat: shader.setFloat,
      colors: colors,
      stops: stops,
      isRainbowMode: isRainbowMode,
    );
  }

  /// Low-level uniform pusher targeting a raw [setFloat] callback.
  /// Decouples uniform logic from [ui.FragmentShader] for zero-dependency unit testing.
  @visibleForTesting
  static void pushColorsToSetter({
    required void Function(int index, double value) setFloat,
    required List<Color> colors,
    List<double>? stops,
    required bool isRainbowMode,
  }) {
    if (colors.isEmpty) return;

    List<Color> effectiveColors = colors;
    List<double>? effectiveStops = stops;

    if (colors.length > 8) {
      effectiveColors = List<Color>.generate(8, (i) {
        final double index = i * (colors.length - 1) / 7.0;
        final int lower = index.floor();
        final int upper = index.ceil();
        if (lower == upper) return colors[lower];
        return Color.lerp(colors[lower], colors[upper], index - lower) ??
            colors[lower];
      });

      if (stops != null && stops.length == colors.length) {
        effectiveStops = List<double>.generate(8, (i) {
          final double index = i * (stops.length - 1) / 7.0;
          final int lower = index.floor();
          final int upper = index.ceil();
          if (lower == upper) return stops[lower];
          final t = index - lower;
          return stops[lower] + (stops[upper] - stops[lower]) * t;
        });
      }
    }

    final int count = effectiveColors.length.clamp(1, 8);
    final lastColor = effectiveColors[count - 1];

    for (int i = 0; i < 8; i++) {
      final c = i < count ? effectiveColors[i] : lastColor;
      final int baseIdx = 3 + i * 4;
      setFloat(baseIdx, c.r);
      setFloat(baseIdx + 1, c.g);
      setFloat(baseIdx + 2, c.b);
      setFloat(baseIdx + 3, c.a);
    }

    // 42: uColorCount
    setFloat(42, isRainbowMode ? 8.0 : count.toDouble());

    // 43-50: uStops1 (indices 43-46) and uStops2 (indices 47-50)
    final bool hasValidStops = !isRainbowMode &&
        effectiveStops != null &&
        effectiveStops.length >= count;

    double lastStop = 0.0;
    for (int i = 0; i < 8; i++) {
      double stopVal;
      if (isRainbowMode) {
        stopVal = i / 7.0;
      } else if (hasValidStops) {
        if (i < count) {
          stopVal = effectiveStops[i].clamp(0.0, 1.0);
          lastStop = stopVal;
        } else {
          stopVal = lastStop;
        }
      } else {
        stopVal = count > 1
            ? (i.clamp(0, count - 1) / (count - 1)).clamp(0.0, 1.0)
            : (i == 0 ? 0.0 : 1.0);
      }
      setFloat(43 + i, stopVal);
    }
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

    // 35-36: uGradientStart
    shader.setFloat(35, startX);
    shader.setFloat(36, startY);
    // 37-38: uGradientEnd
    shader.setFloat(37, endX);
    shader.setFloat(38, endY);
    // 40: uGradientType
    shader.setFloat(40, gradType);
  }
}
