import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_flutter_widget.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';
import 'package:blob_flutter/src/blob_painter.dart';

void main() {
  group('BlobFlutter Widget Tests', () {
    testWidgets('renders CustomPaint with default settings and asserts on invalid parameters', (tester) async {
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
        () => BlobFlutter(animationSpeed: -0.1),
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

    testWidgets('renders successfully with static gradient and various gradient types', (tester) async {
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
    });

    testWidgets('renders successfully with unbounded width constraints (e.g. inside Row)', (tester) async {
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

    testWidgets('rebuilds and updates properties when parent widget updates', (tester) async {
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

      var inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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
                animationSpeed: 2.2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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
                particleCount: 500,
                controller: controller1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, controller1);
      expect(inputListener.controller.tapScaleFactor, 1.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 500,
                controller: controller2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, controller2);
      expect(inputListener.controller.tapScaleFactor, 3.0);
    });

    testWidgets('dynamic particleCount changes in controller reinitializes buffers cleanly', (tester) async {
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

    testWidgets('ticker increments frame generation index on frame pumps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
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

    testWidgets('renders successfully with unbounded height and unconstrained dimensions', (tester) async {
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

    testWidgets('dispatches touch interactions through onTouchesChanged to TouchManager', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                enableHover: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(BlobFlutter)));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(BlobFlutter)) + const Offset(20, 20));
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

    testWidgets('didUpdateWidget updates all properties and handles controller attachment/detachment', (tester) async {
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
                enableHover: false,
                enableDragRotation: false,
                enableHoverRotation: false,
                noiseType: BlobNoiseType.simplex,
                gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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
                enableHover: true,
                enableDragRotation: true,
                enableHoverRotation: true,
                noiseType: BlobNoiseType.harmonic,
                gradient: RadialGradient(colors: [Colors.green, Colors.yellow]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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
      expect(inputListener.controller.enableHover, true);
      expect(inputListener.controller.enableDragRotation, true);
      expect(inputListener.controller.enableHoverRotation, true);
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

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
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

      inputListener = tester.widget<BlobInputListener>(find.byType(BlobInputListener));
      expect(inputListener.controller, isNot(externalController));
      expect(inputListener.controller.particleCount, 180);
      expect(inputListener.controller.radius, 110);
    });

    testWidgets('initializes BlobWorker, executes isolate computation, and handles frame updates', (tester) async {
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
                particleCount: 50,
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

    testWidgets('handles worker disposal and null computation result gracefully', (tester) async {
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

    testWidgets('ticks on initial frame before fragment shader completes loading', (tester) async {
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
  });
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
