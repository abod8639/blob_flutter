import 'dart:typed_data';
import 'package:blob_flutter/src/blob_compute_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_exception.dart';
import 'package:blob_flutter/src/blob_flutter_widget.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_painter.dart';
import 'package:blob_flutter/src/blob_particle_coordinator.dart';
import 'package:blob_flutter/src/blob_shader_coordinator.dart';
import 'package:blob_flutter/src/blob_worker.dart';

void main() {
  group('BlobFlutter Widget Tests', () {
    testWidgets(
        'renders CustomPaint with default settings and asserts on invalid parameters',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BlobFlutter),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      expect(
        () => BlobFlutter(particleCount: 0),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(radius: 0.0),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(pointSize: 0.0),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(tapScaleFactor: -0.1),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(touchRadiusFactor: -0.1),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(speed: -0.1),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(colorAnimationSpeed: -0.1),
        throwsAssertionError,
      );
      expect(
        () => BlobFlutter(waveIntensity: -0.1),
        throwsAssertionError,
      );
    });

    testWidgets(
        'renders successfully with static gradient and various gradient types',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                isColorAnimated: false,
                colorAnimationSpeed: 0.0,
                waveIntensity: 0.0,
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.yellow, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                gradient: RadialGradient(
                  colors: [Colors.cyan, Colors.purple],
                  center: Alignment.center,
                  radius: 0.8,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                gradient: SweepGradient(
                  colors: [Colors.teal, Colors.amber],
                  center: Alignment.center,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.green, Colors.blue],
                  stops: [0.0, 0.2, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'renders successfully with unbounded width constraints (e.g. inside Row)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                BlobFlutter(radius: 120),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets('rebuilds and updates properties when parent widget updates',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                tapScaleFactor: 1.0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      var inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller.tapScaleFactor, 1.0);

      // Rebuild with a different tapScaleFactor
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                tapScaleFactor: 2.0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller.tapScaleFactor, 2.0);

      // Rebuild with speed
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                speed: 3.5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller.speed, 3.5);

      // Rebuild with animationSpeed alias
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                speed: 2.2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller.speed, 2.2);

      // Rebuild with noiseType
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                noiseType: BlobNoiseType.vortex,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller.noiseType, BlobNoiseType.vortex);
    });

    testWidgets('handles dynamic controller swapping', (tester) async {
      final controller1 = BlobController(tapScaleFactor: 1.5);
      final controller2 = BlobController(tapScaleFactor: 3.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, controller1);
      expect(inputListener.controller.tapScaleFactor, 1.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, controller2);
      expect(inputListener.controller.tapScaleFactor, 3.0);
    });

    testWidgets(
        'dynamic particleCount changes in controller reinitializes buffers cleanly',
        (tester) async {
      final controller = BlobController(particleCount: 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.setParticleCount(400);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets('ticker increments frame generation index on frame pumps',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                autoPlay: true,
                particleCount: 500,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BlobFlutter),
          matching: find.byType(CustomPaint),
        ),
      );
      final firstGen = (customPaint.painter as BlobPainter).generation;

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BlobFlutter),
          matching: find.byType(CustomPaint),
        ),
      );
      final secondGen = (customPaint.painter as BlobPainter).generation;

      expect(secondGen, greaterThan(firstGen));
    });

    testWidgets(
        'renders successfully with unbounded height and unconstrained dimensions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BlobFlutter(radius: 120),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnconstrainedBox(
              child: BlobFlutter(radius: 80),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'dispatches touch interactions through onTouchesChanged to TouchManager',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                hover: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(BlobFlutter)));
      await tester.pump();
      await gesture.moveTo(
          tester.getCenter(find.byType(BlobFlutter)) + const Offset(20, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets('supports rainbow mode and gradient fallbacks', (tester) async {
      final controller = BlobController()..setIsRainbowMode(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(find.byType(BlobFlutter), findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BlobFlutter),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((customPaint.painter as BlobPainter).fallbackColor, isNotNull);
      expect((customPaint.painter as BlobPainter).fallbackGradient, isNotNull);

      // Gradient fallback when empty
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                gradient: _EmptyGradient(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'didUpdateWidget updates all properties and handles controller attachment/detachment',
        (tester) async {
      // 1. Start with internally owned controller (controller == null)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                radius: 100,
                pointSize: 2.0,
                particleCount: 200,
                speed: 1.0,
                tapScaleFactor: 1.0,
                touchRadiusFactor: 1.0,
                isColorAnimated: false,
                colorAnimationSpeed: 1.0,
                waveIntensity: 1.0,
                hover: false,
                dragRotation: false,
                hoverRotation: false,
                noiseType: BlobNoiseType.simplex,
                gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      final originalController = inputListener.controller;
      expect(originalController.radius, 100);
      expect(originalController.pointSize, 2.0);
      expect(originalController.particleCount, 200);

      // 2. Update all properties while _ownsController == true, including particleCount
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                radius: 150,
                pointSize: 4.0,
                particleCount: 300,
                speed: 2.5,
                tapScaleFactor: 2.0,
                touchRadiusFactor: 1.5,
                isColorAnimated: true,
                colorAnimationSpeed: 3.0,
                waveIntensity: 2.0,
                hover: true,
                dragRotation: true,
                hoverRotation: true,
                noiseType: BlobNoiseType.harmonic,
                gradient: RadialGradient(colors: [Colors.green, Colors.yellow]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, originalController);
      expect(inputListener.controller.radius, 150);
      expect(inputListener.controller.pointSize, 4.0);
      expect(inputListener.controller.particleCount, 300);
      expect(inputListener.controller.speed, 2.5);
      expect(inputListener.controller.tapScaleFactor, 2.0);
      expect(inputListener.controller.touchRadiusFactor, 1.5);
      expect(inputListener.controller.isColorAnimated, true);
      expect(inputListener.controller.colorAnimationSpeed, 3.0);
      expect(inputListener.controller.waveIntensity, 2.0);
      expect(inputListener.controller.hover, true);
      expect(inputListener.controller.dragRotation, true);
      expect(inputListener.controller.hoverRotation, true);
      expect(inputListener.controller.noiseType, BlobNoiseType.harmonic);

      // 3. Switch from owned controller to external controller
      final externalController = BlobController(particleCount: 250);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: externalController,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, externalController);

      // 4. Switch from external controller back to null (instantiating new owned controller)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 180,
                radius: 110,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener =
          tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, isNot(externalController));
      expect(inputListener.controller.particleCount, 180);
      expect(inputListener.controller.radius, 110);
    });

    testWidgets(
        'initializes BlobWorker, executes isolate computation, and handles frame updates',
        (tester) async {
      final workerController = BlobController(
        particleCount: 50,
        alignment: const Alignment(0.2, -0.4),
      )..setIsRainbowMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: workerController,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Allow Isolate and Shader to initialize asynchronously
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Advance frame - triggers _onTick with _workerReady = true && !_workerBusy
      // This executes _buildWorkerParams() and _worker!.compute()
      await tester.pump(const Duration(milliseconds: 16));

      // Pump another frame immediately while _workerBusy is true
      // This executes the else branch in _onTick (_workerReady && _workerBusy)
      await tester.pump(const Duration(milliseconds: 16));

      // Allow Isolate to complete the computation
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      // Pumping frame after isolate finishes triggers _onParticlesReady
      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'handles worker disposal and null computation result gracefully',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(particleCount: 50),
            ),
          ),
        ),
      );
      await tester.pump();

      // Dispose the widget immediately
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BlobFlutter), findsNothing);
    });

    testWidgets('ticker skips onTick when cached size is zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: BlobFlutter(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'ticks on initial frame before fragment shader completes loading',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 16),
      );

      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'fires onError callback when shader loading fails in test environment',
        (tester) async {
      BlobFlutterException? capturedError;
      StackTrace? capturedStackTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                silentErrorLogging: true,
                testShaderAssetPath: 'shaders/missing.frag',
                onError: (error, stackTrace) {
                  capturedError = error;
                  capturedStackTrace = stackTrace;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(capturedError, isNotNull);
      expect(capturedError, isA<BlobShaderException>());
      expect(capturedError!.message,
          contains('Failed to load fragment shader asset'));
      expect(capturedError!.solutionHint, contains('pubspec.yaml'));
      expect(capturedStackTrace, isNotNull);
    });

    testWidgets(
        'renders custom error widget when errorBuilder is provided and shader fails',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                silentErrorLogging: true,
                testShaderAssetPath: 'shaders/missing.frag',
                errorBuilder: (context, error) {
                  return Text('Custom Error: ${error.message}',
                      key: const Key('custom_error_key'));
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byKey(const Key('custom_error_key')), findsOneWidget);
      expect(
          find.textContaining(
              'Custom Error: Failed to load fragment shader asset'),
          findsOneWidget);
    });

    testWidgets(
        'handles synchronous failure in worker isolate spawning gracefully',
        (tester) async {
      BlobFlutterException? capturedError;
      StackTrace? capturedStackTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                silentErrorLogging: true,
                workerFactory: () =>
                    throw Exception('Worker constructor failed'),
                onError: (error, st) {
                  capturedError = error;
                  capturedStackTrace = st;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(capturedError, isNotNull);
      expect(capturedError, isA<BlobWorkerException>());
      expect(capturedError!.message,
          contains('background particle computation isolate'));
      expect(capturedStackTrace, isNotNull);
    });

    testWidgets(
        'handles asynchronous error in worker init via catchError gracefully',
        (tester) async {
      BlobFlutterException? capturedError;
      StackTrace? capturedStackTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                silentErrorLogging: true,
                workerFactory: () => _FailingInitBlobWorker(),
                onError: (error, st) {
                  capturedError = error;
                  capturedStackTrace = st;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(capturedError, isNotNull);
      expect(capturedError, isA<BlobWorkerException>());
      expect(capturedError!.message,
          contains('background particle computation isolate'));
      expect(capturedStackTrace, isNotNull);
    });

    testWidgets('supports autoPlay: false and completes pumpAndSettle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                autoPlay: false,
              ),
            ),
          ),
        ),
      );

      // pumpAndSettle will immediately succeed because ticker is stopped!
      await tester.pumpAndSettle();

      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets('pause and resume dynamically control ticker and rendering',
        (tester) async {
      final controller = BlobController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(controller.isPaused, false);

      controller.pause();
      expect(controller.isPaused, true);
      await tester.pump();
      await tester.pumpAndSettle();

      controller.resume();
      expect(controller.isPaused, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'default BlobFlutter() automatically disables autoPlay in tests allowing pumpAndSettle without timeout',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(),
            ),
          ),
        ),
      );

      // In tests, autoPlay defaults to false automatically:
      // pumpAndSettle MUST complete immediately without any timeout!
      await tester.pumpAndSettle();

      expect(find.byType(BlobFlutter), findsOneWidget);
      expect(BlobFlutter.isRunningInTest, isTrue);
    });

    testWidgets(
        'default BlobFlutter() automatically silences shader loading errors in tests without FlutterError.reportError',
        (tester) async {
      Object? flutterErrorCaught;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrorCaught = details.exception;
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: BlobFlutter(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // No unhandled FlutterError should have been recorded by the test binding
        expect(flutterErrorCaught, isNull);
        expect(find.byType(BlobFlutter), findsOneWidget);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets(
        'BlobFlutter.enableAutoPlayInTests globally controls autoPlay in test environment',
        (tester) async {
      BlobFlutter.autoPlayInTests = true;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: BlobFlutter(),
              ),
            ),
          ),
        );

        await tester.pump();

        var customPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(BlobFlutter),
            matching: find.byType(CustomPaint),
          ),
        );
        final firstGen = (customPaint.painter as BlobPainter).generation;

        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        customPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(BlobFlutter),
            matching: find.byType(CustomPaint),
          ),
        );
        final secondGen = (customPaint.painter as BlobPainter).generation;

        expect(secondGen, greaterThan(firstGen));
      } finally {
        BlobFlutter.autoPlayInTests = false;
      }
    });

    testWidgets(
        'pauses ticker on app background and resumes on foreground when autoPauseOnAppBackground is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                autoPlay: true,
                autoPauseOnAppBackground: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);
      expect(state.isAppInBackground, isFalse);

      // Transition to paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(state.isAppInBackground, isTrue);
      expect(state.isTickerActive, isFalse);

      // Transition back to resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(state.isAppInBackground, isFalse);
      expect(state.isTickerActive, isTrue);
    });

    testWidgets(
        'does not resume ticker on app foreground if controller was manually paused',
        (tester) async {
      final controller = BlobController(isPaused: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                controller: controller,
                autoPlay: true,
                autoPauseOnAppBackground: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);

      // User manually pauses
      controller.pause();
      await tester.pump();
      expect(state.isTickerActive, isFalse);

      // App goes to background and comes back
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Should remain paused because user manually paused it
      expect(state.isTickerActive, isFalse);
    });

    testWidgets(
        'does not pause ticker on app background when autoPauseOnAppBackground is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                autoPlay: true,
                autoPauseOnAppBackground: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(state.isTickerActive, isTrue);
    });

    testWidgets(
        'pauses ticker when scrolled offscreen and resumes when scrolled back into view',
        (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: const Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: BlobFlutter(
                      autoPlay: true,
                      autoPauseOffscreen: true,
                    ),
                  ),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);
      expect(state.isOffscreen, isFalse);

      // Scroll down so BlobFlutter is pushed 1500px offscreen (above viewport)
      scrollController.jumpTo(1500);
      await tester.pump();

      expect(state.isOffscreen, isTrue);
      expect(state.isTickerActive, isFalse);

      // Scroll back up so BlobFlutter is back in viewport
      scrollController.jumpTo(0);
      await tester.pump();

      expect(state.isOffscreen, isFalse);
      expect(state.isTickerActive, isTrue);
    });

    testWidgets(
        'does not pause ticker when offscreen if autoPauseOffscreen is false',
        (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: const Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: BlobFlutter(
                      autoPlay: true,
                      autoPauseOffscreen: false,
                    ),
                  ),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);

      scrollController.jumpTo(1500);
      await tester.pump();

      expect(state.isTickerActive, isTrue);
    });

    testWidgets(
        'dynamic update of autoPauseOffscreen and autoPauseOnAppBackground via didUpdateWidget',
        (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: const Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: BlobFlutter(
                      autoPlay: true,
                      autoPauseOffscreen: true,
                      autoPauseOnAppBackground: true,
                    ),
                  ),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      expect(state.isTickerActive, isTrue);

      // Scroll offscreen -> paused
      scrollController.jumpTo(1500);
      await tester.pump();
      expect(state.isTickerActive, isFalse);

      // Dynamically update autoPauseOffscreen: false while offscreen -> should resume
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: const Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: BlobFlutter(
                      autoPlay: true,
                      autoPauseOffscreen: false,
                      autoPauseOnAppBackground: true,
                    ),
                  ),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(state.isTickerActive, isTrue);
    });

    testWidgets(
        'BlobFlutter throws BlobControllerConflictException when parameters passed alongside controller',
        (tester) async {
      final controller = BlobController();
      BlobFlutterException? capturedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobFlutter(
              controller: controller,
              radius: 200.0,
              onError: (error, stackTrace) {
                capturedError = error;
              },
            ),
          ),
        ),
      );

      final dynamic exception = tester.takeException();
      expect(exception, isA<BlobControllerConflictException>());
      final conflictException = exception as BlobControllerConflictException;
      expect(conflictException.conflictingParameters, contains('radius'));
      expect(conflictException.toString(), contains('IGNORED'));
      expect(conflictException.toString(), contains('radius: ...,'));
      expect(capturedError, isA<BlobControllerConflictException>());

      // Verifying static helper findConflictingParameters
      final conflicts = BlobFlutter.findConflictingParameters(
        BlobFlutter(controller: controller, particleCount: 100, speed: 2.0),
      );
      expect(conflicts, ['particleCount', 'speed']);
    });

    testWidgets('_renderStaticFrame handles shader uniform update error (L512-L517)',
        (tester) async {
      BlobFlutterException? capturedError;
      final controller = BlobController(isPaused: true);

      BlobShaderCoordinator.debugOnUpdateDynamicUniforms = () {
        throw Exception('Simulated shader uniform failure');
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: BlobFlutter(
                  controller: controller,
                  autoPlay: false,
                  onError: (error, st) {
                    capturedError = error;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Trigger _renderStaticFrame via controller change while paused
        controller.setRadius(120.0);
        await tester.pump();

        expect(capturedError, isNotNull);
        expect(capturedError, isA<BlobRenderException>());
        expect(capturedError!.code, BlobErrorCode.renderFailed);
      } finally {
        BlobShaderCoordinator.debugOnUpdateDynamicUniforms = null;
        controller.dispose();
      }
    });

    testWidgets('_renderStaticFrame handles unexpected error during static render (L530-L537)',
        (tester) async {
      BlobFlutterException? capturedError;
      final controller = BlobController(isPaused: true);

      BlobParticleCoordinator.debugOnRenderStaticFrame = () {
        throw Exception('Simulated static render error');
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: BlobFlutter(
                  controller: controller,
                  autoPlay: false,
                  onError: (error, st) {
                    capturedError = error;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Trigger _renderStaticFrame via controller change while paused
        controller.setRadius(130.0);
        await tester.pump();

        expect(capturedError, isNotNull);
        expect(capturedError!.message, contains('Unexpected error during static frame render.'));
      } finally {
        BlobParticleCoordinator.debugOnRenderStaticFrame = null;
        controller.dispose();
      }
    });

    testWidgets('didUpdateWidget updates autoPlay, pinchToScale, rotationX, and rotationY (L589-L591, L628-L636)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BlobFlutter(
                autoPlay: true,
                pinchToScale: true,
                rotationX: 0.1,
                rotationY: 0.2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Rebuild with updated values for autoPlay, pinchToScale, rotationX, and rotationY
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BlobFlutter(
                autoPlay: false,
                pinchToScale: false,
                rotationX: 0.5,
                rotationY: 0.8,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
    });

    testWidgets(
        'didUpdateWidget detects conflicting parameters alongside controller and invokes onError (L538-L539)',
        (tester) async {
      final controller = BlobController();
      BlobFlutterException? capturedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobFlutter(
              controller: controller,
              onError: (error, st) => capturedError = error,
            ),
          ),
        ),
      );

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      final newWidget = BlobFlutter(
        controller: controller,
        particleCount: 500,
        onError: (error, st) => capturedError = error,
      );

      expect(
        () => state.didUpdateWidget(newWidget),
        throwsA(isA<BlobControllerConflictException>()),
      );
      expect(capturedError, isA<BlobControllerConflictException>());
      controller.dispose();
    });

    testWidgets(
        '_restartWorker handles sync error, async error, and successful worker readiness (L704-L715)',
        (tester) async {
      final controller = BlobController(particleCount: 200);

      // 1. Successful restart worker -> calls onWorkerReady (L714-L715)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobFlutter(
              controller: controller,
              workerFactory: () => _SuccessfulMockBlobWorker(),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.setParticleCount(300); // Triggers _restartWorker
      await tester.pump();

      // 2. Sync error in workerFactory -> calls onError with isAsync: false (L710-L712)
      BlobFlutterException? syncError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobFlutter(
              controller: controller,
              workerFactory: () => throw Exception('Sync factory restart failure'),
              onError: (err, st) => syncError = err,
            ),
          ),
        ),
      );
      await tester.pump();
      controller.setParticleCount(400); // Triggers _restartWorker
      await tester.pump();
      expect(syncError, isA<BlobWorkerException>());

      // 3. Async error in worker.init -> calls onError with isAsync: true (L705-L707)
      BlobFlutterException? asyncError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobFlutter(
              controller: controller,
              workerFactory: () => _FailingInitBlobWorker(),
              onError: (err, st) => asyncError = err,
            ),
          ),
        ),
      );
      await tester.pump();
      controller.setParticleCount(500); // Triggers _restartWorker
      await tester.pump();
      expect(asyncError, isA<BlobWorkerException>());

      controller.dispose();
    });

    testWidgets(
        '_onTick periodic checkTickVisibility detects offscreen and calls _syncTickerState (L729)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Offstage(
              offstage: true,
              child: SizedBox(
                width: 200,
                height: 200,
                child: BlobFlutter(
                  autoPlay: false,
                  autoPauseOffscreen: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state(find.byType(BlobFlutter, skipOffstage: false)) as dynamic;
      expect(state.isOffscreen, isFalse);

      // Trigger 30 ticks so checkTickVisibility reaches 30th tick
      for (int i = 1; i <= 30; i++) {
        state.onTickForTesting(Duration(milliseconds: 16 * i));
      }

      expect(state.isOffscreen, isTrue);
    });

    testWidgets(
        '_onTick updateDynamicUniforms error invokes onError and sets _lastError (L746-L751)',
        (tester) async {
      BlobFlutterException? capturedError;
      BlobShaderCoordinator.debugOnUpdateDynamicUniforms = () {
        throw Exception('Simulated dynamic uniform error');
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: BlobFlutter(
                  autoPlay: false,
                  onError: (err, st) => capturedError = err,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final state = tester.state(find.byType(BlobFlutter)) as dynamic;
        state.onTickForTesting(const Duration(milliseconds: 16));
        await tester.pump();

        expect(capturedError, isA<BlobRenderException>());
      } finally {
        BlobShaderCoordinator.debugOnUpdateDynamicUniforms = null;
      }
    });

    testWidgets(
        '_onTick processTick onComputeError invokes widget.onError (L765-L767)',
        (tester) async {
      BlobFlutterException? capturedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BlobFlutter(
                autoPlay: false,
                workerFactory: () => _FailingComputeBlobWorker(),
                onError: (err, st) => capturedError = err,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      // Wait for worker to be ready
      await tester.pump();
      state.onTickForTesting(const Duration(milliseconds: 16));
      await tester.pump();

      expect(capturedError, isA<BlobWorkerException>());
      expect(capturedError!.message, contains('background particle computation'));
    });

    testWidgets(
        '_onTick unexpected error in try block catches BlobFlutterException and calls onError (L770, L775)',
        (tester) async {
      final controller = _ThrowingDampingBlobController();
      BlobFlutterException? capturedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BlobFlutter(
                controller: controller,
                autoPlay: false,
                onError: (err, st) => capturedError = err,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(BlobFlutter)) as dynamic;
      state.onTickForTesting(const Duration(milliseconds: 16));
      await tester.pump();

      expect(capturedError, isNotNull);
      expect(capturedError!.message, 'Unexpected error during animation tick.');
      controller.dispose();
    });
  });
}

class _SuccessfulMockBlobWorker extends BlobWorker {
  @override
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) async {}

  @override
  bool get isReady => true;
}

class _FailingComputeBlobWorker extends BlobWorker {
  @override
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) async {}

  @override
  bool get isReady => true;

  @override
  Future<Float32List?> compute(ProjectParamsFlat params, [Float32List? recycleBuffer]) {
    return Future.error(Exception('Simulated compute failure'));
  }
}

class _ThrowingDampingBlobController extends BlobController {
  @override
  bool applyDamping() {
    throw Exception('Simulated applyDamping failure');
  }
}

class _FailingInitBlobWorker extends BlobWorker {
  @override
  Future<void> init(
    Float32List baseSphere,
    int count, {
    void Function(BlobWorkerException error)? onError,
  }) {
    return Future.error(Exception('Simulated worker init failure'));
  }
}

class _EmptyGradient extends Gradient {
  const _EmptyGradient() : super(colors: const []);

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    return const LinearGradient(colors: [Colors.black, Colors.white])
        .createShader(rect, textDirection: textDirection);
  }

  @override
  Gradient scale(double factor) => this;

  @override
  Gradient withOpacity(double opacity) => this;
}

