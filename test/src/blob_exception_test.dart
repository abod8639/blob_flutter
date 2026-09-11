import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/blob_flutter.dart';
import 'package:blob_flutter/src/blob_shader_helper.dart';

void main() {
  group('BlobException Tests', () {
    test(
        'BlobFlutterException formats toString() with clear diagnostic banner and hints',
        () {
      final exception = BlobFlutterException(
        message: 'Something went wrong with blob setup.',
        details: 'Invalid buffer size detected.',
        solutionHint:
            'Verify particle count is within [10, 100000].\nReset controller buffer.',
        cause: Exception('Original buffer error'),
      );

      final str = exception.toString();
      expect(str, contains('[BlobFlutter Exception]'));
      expect(str, contains('Message: Something went wrong with blob setup.'));
      expect(str, contains('Details: Invalid buffer size detected.'));
      expect(
          str, contains('Underlying Cause: Exception: Original buffer error'));
      expect(str, contains('How to fix:'));
      expect(str, contains('Verify particle count is within [10, 100000].'));
      expect(str, contains('Reset controller buffer.'));
    });

    test(
        'BlobShaderException.assetLoadFailed populates attempted paths and actionable steps',
        () {
      final exception = BlobShaderException.assetLoadFailed(
        attemptedPaths: [
          'packages/blob_flutter/shaders/blob.frag',
          'shaders/blob.frag',
        ],
        cause: Exception('Asset not found'),
      );

      expect(
          exception.message, contains('Failed to load fragment shader asset'));
      expect(exception.details,
          contains('packages/blob_flutter/shaders/blob.frag'));
      expect(exception.details, contains('shaders/blob.frag'));
      expect(exception.solutionHint, contains('pubspec.yaml'));
      expect(exception.solutionHint, contains('flutter pub get'));
      expect(exception.cause, isNotNull);

      final str = exception.toString();
      expect(str, contains('pubspec.yaml'));
    });

    test(
        'BlobWorkerException.spawnFailed provides isolate fallback information',
        () {
      final exception = BlobWorkerException.spawnFailed(
        cause: Exception('Isolate error'),
      );

      expect(exception.message,
          contains('background particle computation isolate'));
      expect(exception.solutionHint, contains('main-thread particle math'));
      expect(exception.cause, isNotNull);
    });

    test(
        'BlobParameterException.outOfRange populates parameter name, value, and example fix',
        () {
      final exception = BlobParameterException.outOfRange(
        parameterName: 'particleCount',
        invalidValue: -5,
        validRange: 'particleCount > 0',
        exampleFix: 'BlobFlutter(particleCount: 5000)',
      );

      expect(exception.parameterName, 'particleCount');
      expect(exception.invalidValue, -5);
      expect(exception.message, contains("'particleCount'"));
      expect(exception.details, contains('-5'));
      expect(exception.details, contains('particleCount > 0'));
      expect(
          exception.solutionHint, contains('BlobFlutter(particleCount: 5000)'));
    });

    test(
        'BlobParameterException.outOfRange formats solutionHint without exampleFix',
        () {
      final exception = BlobParameterException.outOfRange(
        parameterName: 'radius',
        invalidValue: -10,
        validRange: 'radius > 0.0',
        exampleFix: null,
      );

      expect(
          exception.solutionHint,
          contains(
              'Provide a valid value matching the criteria: radius > 0.0.'));
    });

    test(
        'BlobShaderHelper.loadProgram calls onError with BlobShaderException when assets missing',
        () async {
      BlobShaderException? capturedException;

      final program = await BlobShaderHelper.loadProgram(
        silent: true,
        overrideAssetPath: 'shaders/missing_blob.frag',
        onError: (e) {
          capturedException = e;
        },
      );

      expect(program, isNull);
      expect(capturedException, isNotNull);
      expect(capturedException!.attemptedPaths,
          contains('shaders/missing_blob.frag'));
      expect(capturedException!.solutionHint, contains('pubspec.yaml'));
    });

    test(
        'BlobShaderHelper.loadProgram reports error via FlutterError.reportError when silent is false',
        () async {
      FlutterErrorDetails? reportedDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedDetails = details;
      };

      try {
        final program = await BlobShaderHelper.loadProgram(
          silent: false,
          overrideAssetPath: 'shaders/missing_shader.frag',
        );

        expect(program, isNull);
        expect(reportedDetails, isNotNull);
        expect(reportedDetails!.exception, isA<BlobShaderException>());
        expect(reportedDetails!.informationCollector, isNotNull);
        final diagnostics = reportedDetails!.informationCollector!().toList();
        expect(diagnostics.length, 3);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  });
}
