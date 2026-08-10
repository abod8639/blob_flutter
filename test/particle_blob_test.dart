import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/blob_flutter.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';
import 'package:blob_flutter/src/blob_math.dart';
import 'package:blob_flutter/src/blob_painter.dart';

void main() {
  group('BlobMath Tests', () {
    test('generateFibonacciSphere generates unit sphere points and asserts invalid inputs', () {
      expect(
        () => BlobMath.generateFibonacciSphere(0),
        throwsAssertionError,
      );

      final samples = 100;
      final sphere = BlobMath.generateFibonacciSphere(samples);
      expect(sphere.length, samples * 3);

      // Verify that all points lie on the unit sphere (distance from origin is 1.0)
      for (int i = 0; i < samples; i++) {
        final x = sphere[i * 3];
        final y = sphere[i * 3 + 1];
        final z = sphere[i * 3 + 2];
        final actualDist = (x * x + y * y + z * z);
        expect(actualDist, closeTo(1.0, 0.0001));
      }
    });

    test('generateFibonacciSphere handles single sample case', () {
      final sphere = BlobMath.generateFibonacciSphere(1);
      expect(sphere.length, 3);
      expect(sphere[0], 0.0);
      expect(sphere[1], 0.0);
      expect(sphere[2], 0.0);
    });

    test('wrapTime keeps time wrapped within limits', () {
      expect(BlobMath.wrapTime(5.0), 5.0);

      // Multiple of the limit should wrap to 0.0
      final limit = BlobMath.twoPi * 100.0;
      expect(BlobMath.wrapTime(limit), closeTo(0.0, 0.0001));

      final hugeTime = limit + 3.5;
      expect(BlobMath.wrapTime(hugeTime), closeTo(3.5, 0.0001));
    });

    test('projectParticles projects points correctly and applies dispersion/touches', () {
      final count = 10;
      final baseSphere = BlobMath.generateFibonacciSphere(count);
      final projectedBase = Float32List(count * 2);
      final projectedWithDispersion = Float32List(count * 2);
      final projectedWithTouches = Float32List(count * 2);

      // 1. Project base points
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.0,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: const [],
        baseSphere: baseSphere,
        projectedPoints: projectedBase,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // Verify centered projection
      for (int i = 0; i < count; i++) {
        expect(projectedBase[i * 2], isNot(0.0));
        expect(projectedBase[i * 2 + 1], isNot(0.0));
      }

      // 2. Project with uniform dispersion
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: const [],
        baseSphere: baseSphere,
        projectedPoints: projectedWithDispersion,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // Verify that dispersion pushes points further from center
      for (int i = 0; i < count; i++) {
        final distBaseX = (projectedBase[i * 2] - 200.0).abs();
        final distDispX = (projectedWithDispersion[i * 2] - 200.0).abs();
        expect(distDispX, greaterThanOrEqualTo(distBaseX));
      }

      // 3. Project with active touches
      BlobMath.projectParticles(
        count: count,
        radius: 100.0,
        blobiness: 1.0,
        dispersion: 0.5,
        rotationX: 0.0,
        rotationY: 0.0,
        time: 1.0,
        viewportWidth: 400.0,
        viewportHeight: 400.0,
        activeTouches: const [Offset(200, 200)],
        baseSphere: baseSphere,
        projectedPoints: projectedWithTouches,
        autoRotationSpeed: 0.5,
        noiseFrequency: 1.0,
        viewDistance: 2.0,
      );

      // Verify touch push operates
      for (int i = 0; i < count * 2; i++) {
        expect(projectedWithTouches[i], isNot(0.0));
      }
    });
  });

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

      // Check if BlobFlutter widget is built
      expect(find.byType(BlobFlutter), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      // Verify assertion for invalid particleCount
      expect(
        () => BlobFlutter(particleCount: 0),
        throwsAssertionError,
      );

      // Verify assertion for invalid tapScaleFactor
      expect(
        () => BlobFlutter(tapScaleFactor: -0.1),
        throwsAssertionError,
      );

      // Verify assertions for invalid color parameters
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
      expect(find.byType(CustomPaint), findsOneWidget);

      // Test with RadialGradient
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

      // Test with SweepGradient
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
                BlobFlutter(),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      final RenderBox renderBox = tester.renderObject(find.byType(BlobFlutter));
      expect(renderBox.size.width, 300.0); // radius (150) * 2.0
      // Height should be the height of the Scaffold body in tests (typically 600.0)
      expect(renderBox.size.height, 600.0);
    });

    testWidgets('renders successfully with completely unbounded constraints (inside UnconstrainedBox)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnconstrainedBox(
              child: BlobFlutter(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(BlobFlutter), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      final RenderBox renderBox = tester.renderObject(find.byType(BlobFlutter));
      expect(renderBox.size.width, 300.0); // radius (150) * 2.0
      expect(renderBox.size.height, 300.0); // radius (150) * 2.0
    });

    testWidgets('handles dynamic tapScaleFactor updates', (tester) async {
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

      // Rebuild with controller2
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

      var customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final firstGen = (customPaint.painter as BlobPainter).generation;

      // Pump a few frames with time elapsed
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final secondGen = (customPaint.painter as BlobPainter).generation;

      expect(secondGen, greaterThan(firstGen));
    });
  });

  group('BlobController Tests', () {
    test('initial values and custom constructor parameters', () {
      final controller = BlobController(
        dampingFactor: 0.9,
        tapScaleFactor: 2.0,
        isColorAnimated: false,
        colorAnimationSpeed: 2.5,
        waveIntensity: 0.5,
        gradient: const RadialGradient(colors: [Colors.red, Colors.blue]),
      );
      expect(controller.dampingFactor, 0.9);
      expect(controller.tapScaleFactor, 2.0);
      expect(controller.blobiness, 1.0);
      expect(controller.speed, 1.0);
      expect(controller.dispersion, 0.0);
      expect(controller.autoRotationSpeed, 0.5);
      expect(controller.noiseFrequency, 1.0);
      expect(controller.viewDistance, 2.0);
      expect(controller.isColorAnimated, false);
      expect(controller.colorAnimationSpeed, 2.5);
      expect(controller.waveIntensity, 0.5);
      expect(controller.gradient, isA<RadialGradient>());
    });

    test('constructor asserts on invalid parameters', () {
      expect(() => BlobController(dampingFactor: -0.1), throwsAssertionError);
      expect(() => BlobController(dampingFactor: 1.1), throwsAssertionError);
      expect(() => BlobController(tapScaleFactor: -0.5), throwsAssertionError);
      expect(() => BlobController(colorAnimationSpeed: -0.1), throwsAssertionError);
      expect(() => BlobController(waveIntensity: -0.1), throwsAssertionError);
    });

    test('property setters clamp inputs correctly', () {
      final controller = BlobController();

      controller.setColorAnimationSpeed(15.0); // clamped to 10.0
      expect(controller.colorAnimationSpeed, 10.0);
      controller.setColorAnimationSpeed(-2.0); // clamped to 0.0
      expect(controller.colorAnimationSpeed, 0.0);

      controller.setWaveIntensity(8.0); // clamped to 5.0
      expect(controller.waveIntensity, 5.0);
      controller.setWaveIntensity(-1.0); // clamped to 0.0
      expect(controller.waveIntensity, 0.0);

      controller.setIsColorAnimated(false);
      expect(controller.isColorAnimated, false);

      const grad = SweepGradient(colors: [Colors.green, Colors.yellow]);
      controller.setGradient(grad);
      expect(controller.gradient, grad);

      controller.setBlobiness(6.0); // clamped to 5.0
      expect(controller.blobiness, 5.0);
      controller.setBlobiness(-1.0); // clamped to 0.0
      expect(controller.blobiness, 0.0);

      controller.setSpeed(12.0); // clamped to 10.0
      expect(controller.speed, 10.0);
      controller.setSpeed(-2.0); // clamped to 0.0
      expect(controller.speed, 0.0);

      controller.setDispersion(4.0); // clamped to 3.0
      expect(controller.dispersion, 3.0);
      controller.setDispersion(-0.5); // clamped to 0.0
      expect(controller.dispersion, 0.0);

      controller.setDampingFactor(1.5); // clamped to 1.0
      expect(controller.dampingFactor, 1.0);
      controller.setDampingFactor(-0.2); // clamped to 0.0
      expect(controller.dampingFactor, 0.0);

      controller.setTapScaleFactor(6.0);
      expect(controller.tapScaleFactor, 6.0);
      controller.setTapScaleFactor(-1.0); // clamped to 0.0
      expect(controller.tapScaleFactor, 0.0);

      controller.setAutoRotationSpeed(4.0); // clamped to 3.0
      expect(controller.autoRotationSpeed, 3.0);
      controller.setAutoRotationSpeed(-4.0); // clamped to -3.0
      expect(controller.autoRotationSpeed, -3.0);

      controller.setNoiseFrequency(6.0); // clamped to 5.0
      expect(controller.noiseFrequency, 5.0);
      controller.setNoiseFrequency(0.05); // clamped to 0.1
      expect(controller.noiseFrequency, 0.1);

      controller.setViewDistance(6.0); // clamped to 5.0
      expect(controller.viewDistance, 5.0);
      controller.setViewDistance(0.5); // clamped to 0.8
      expect(controller.viewDistance, 0.8);
    });

    test('notifies listeners when properties are updated', () {
      final controller = BlobController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setBlobiness(2.0);
      expect(notifyCount, 1);

      // Updating with same value should NOT notify
      controller.setBlobiness(2.0);
      expect(notifyCount, 1);

      controller.setSpeed(2.0);
      expect(notifyCount, 2);

      controller.setDispersion(1.0);
      expect(notifyCount, 3);

      controller.setDampingFactor(0.85);
      expect(notifyCount, 4);

      controller.setTapScaleFactor(3.0);
      expect(notifyCount, 5);

      controller.setAutoRotationSpeed(1.0);
      expect(notifyCount, 6);

      controller.setNoiseFrequency(2.0);
      expect(notifyCount, 7);

      controller.setViewDistance(3.0);
      expect(notifyCount, 8);

      controller.addRotationImpulse(const Offset(10, 10));
      expect(notifyCount, 9);

      controller.resetRotation();
      expect(notifyCount, 10);
    });

    test('addRotationImpulse, applyDamping, and snapping rotation logic', () {
      final controller = BlobController(dampingFactor: 0.9);
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      // applyDamping returns false when there is no rotation
      expect(controller.applyDamping(), false);

      controller.addRotationImpulse(const Offset(10.0, 20.0));
      expect(controller.rotationX, 20.0 * 0.005);
      expect(controller.rotationY, 10.0 * 0.005);

      // applyDamping returns true when rotation is active
      expect(controller.applyDamping(), true);
      expect(controller.rotationX, closeTo((20.0 * 0.005) * 0.9, 0.0001));

      // Test snapping of small values to 0.0
      controller.addRotationImpulse(const Offset(0.01, 0.01)); // tiny impulse
      controller.setDampingFactor(0.1); // high decay
      controller.applyDamping();
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      // Test no decay when dampingFactor is 1.0
      final controllerNoDecay = BlobController(dampingFactor: 1.0);
      controllerNoDecay.addRotationImpulse(const Offset(10.0, 20.0));
      controllerNoDecay.applyDamping();
      expect(controllerNoDecay.rotationX, 20.0 * 0.005);
      expect(controllerNoDecay.rotationY, 10.0 * 0.005);

      // Test instant decay when dampingFactor is 0.0
      final controllerInstantDecay = BlobController(dampingFactor: 0.0);
      controllerInstantDecay.addRotationImpulse(const Offset(10.0, 20.0));
      controllerInstantDecay.applyDamping();
      expect(controllerInstantDecay.rotationX, 0.0);
      expect(controllerInstantDecay.rotationY, 0.0);
    });
  });

  group('BlobInputListener Widget Tests', () {
    testWidgets('detects pointer gestures and updates controller values', (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              onTouchesChanged: (t) {
                touches = t;
              },
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      // Perform a pan/drag gesture
      final gesture = await tester.startGesture(const Offset(100, 100));
      await gesture.moveBy(const Offset(20, 30));
      await tester.pump();

      // Rotation impulse applied
      expect(controller.rotationX, isNot(0.0));
      expect(controller.rotationY, isNot(0.0));

      // Touch position tracked
      expect(touches.length, 1);
      expect(touches.first, const Offset(120, 130));

      await gesture.up();
      await tester.pump();

      expect(touches.isEmpty, true);
    });

    testWidgets('applies tapScaleFactor to dispersion output', (tester) async {
      final controller = BlobController(tapScaleFactor: 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              onTouchesChanged: (_) {},
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      // 1 finger touch -> base dispersion is 0.4 + 0.2 * 1 = 0.6
      // Multiplying by tapScaleFactor (0.5) should yield 0.3
      expect(controller.dispersion, closeTo(0.3, 0.0001));

      await gesture.up();
      await tester.pump();
      expect(controller.dispersion, 0.0);
    });

    testWidgets('mouse hover triggers subtle rotation impulse when no active touches', (tester) async {
      final controller = BlobController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (_) {},
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Create a hover gesture
      final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await tester.pump();

      // Reset controller rotation to test the delta
      controller.resetRotation();

      // Move mouse pointer (triggers onHover)
      await gesture.moveTo(const Offset(60, 80));
      await tester.pump();

      // Delta is (10, 30).
      // rotationX should increase by delta.dy * 0.3 * 0.005 = 30 * 0.0015 = 0.045
      // rotationY should increase by delta.dx * 0.3 * 0.005 = 10 * 0.0015 = 0.015
      expect(controller.rotationX, closeTo(0.045, 0.0001));
      expect(controller.rotationY, closeTo(0.015, 0.0001));

      await gesture.removePointer();
    });

    testWidgets('enableHover triggers particle interaction and dispersion without clicking', (tester) async {
      final controller = BlobController(enableHover: true);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                enableHover: true,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Create mouse hover
      final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await tester.pump();

      // Move mouse pointer over widget
      await gesture.moveTo(const Offset(80, 80));
      await tester.pump();

      // Verify active touches and dispersion are populated without clicking
      expect(touches.length, 1);
      expect(touches.first, const Offset(80, 80));
      expect(controller.dispersion, greaterThan(0.0));

      // Move mouse outside widget
      await gesture.moveTo(const Offset(300, 300));
      await tester.pump();

      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);

      await gesture.removePointer();
    });

    testWidgets('pointer cancel removes touch points and resets dispersion', (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              onTouchesChanged: (t) {
                touches = t;
              },
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      // Start gesture
      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      expect(touches.length, 1);
      expect(controller.dispersion, greaterThan(0.0));

      // Cancel gesture
      await gesture.cancel();
      await tester.pump();

      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);
    });
  });

  group('BlobPainter Tests', () {
    test('shouldRepaint detects changes correctly', () {
      final positions1 = Float32List(10);
      final positions2 = Float32List(10);
      final painter1 = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterSame = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterDiffGen = BlobPainter(
        positions: positions1,
        generation: 2,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );

      final painterDiffSize = BlobPainter(
        positions: positions1,
        generation: 1,
        pointSize: 3.0,
        fallbackColor: Colors.red,
      );

      final painterDiffColor = BlobPainter(
        positions: positions2,
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.blue,
      );

      expect(painter1.shouldRepaint(painterSame), false);
      expect(painter1.shouldRepaint(painterDiffGen), true);
      expect(painter1.shouldRepaint(painterDiffSize), true);
      expect(painter1.shouldRepaint(painterDiffColor), true);
    });

    test('paint method skips when positions are empty', () {
      final canvas = _MockCanvas();
      final painter = BlobPainter(
        positions: Float32List(0),
        generation: 1,
        pointSize: 2.0,
        fallbackColor: Colors.red,
      );
      painter.paint(canvas, Size.zero);
      expect(canvas.drawRawPointsCallCount, 0);
    });

    test('paint method draws points on canvas with fallback color when shader is null', () {
      final canvas = _MockCanvas();
      final positions = Float32List.fromList([10.0, 20.0, 30.0, 40.0]);
      final painter = BlobPainter(
        positions: positions,
        generation: 1,
        pointSize: 3.0,
        fallbackColor: Colors.green,
      );
      painter.paint(canvas, Size.zero);

      expect(canvas.drawRawPointsCallCount, 1);
      expect(canvas.pointMode, ui.PointMode.points);
      expect(canvas.points, positions);
      expect(canvas.paint?.strokeWidth, 3.0);
      expect(canvas.paint?.strokeCap, StrokeCap.round);
      expect(canvas.paint?.isAntiAlias, true);
      expect(canvas.paint?.color, Colors.green);
      expect(canvas.paint?.shader, isNull);
    });
  });

  group('BlobNoiseType & Procedural Noise Algorithms Tests', () {
    test('BlobMath projects particles correctly for all BlobNoiseType algorithms', () {
      final sphere = BlobMath.generateFibonacciSphere(100);
      final projected = Float32List(100 * 2);

      for (final noiseType in BlobNoiseType.values) {
        BlobMath.projectParticles(
          count: 100,
          radius: 100.0,
          blobiness: 1.5,
          dispersion: 0.2,
          rotationX: 0.5,
          rotationY: 0.5,
          time: 2.5,
          viewportWidth: 400.0,
          viewportHeight: 400.0,
          activeTouches: const [],
          baseSphere: sphere,
          projectedPoints: projected,
          autoRotationSpeed: 0.5,
          noiseFrequency: 1.2,
          viewDistance: 2.0,
          noiseType: noiseType,
        );

        for (int i = 0; i < projected.length; i++) {
          expect(projected[i].isNaN, false, reason: 'NaN found in $noiseType at index $i');
          expect(projected[i].isInfinite, false, reason: 'Infinity found in $noiseType at index $i');
        }
      }
    });

    test('BlobMath.fastSimplex3D returns deterministic bounded values', () {
      final val1 = BlobMath.fastSimplex3D(0.5, 0.5, 0.5);
      final val2 = BlobMath.fastSimplex3D(0.5, 0.5, 0.5);
      expect(val1, val2); // Deterministic
      expect(val1 >= -2.0 && val1 <= 2.0, true);
    });

    test('BlobController handles setNoiseType and notifies listeners', () {
      final controller = BlobController(noiseType: BlobNoiseType.harmonic);
      expect(controller.noiseType, BlobNoiseType.harmonic);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setNoiseType(BlobNoiseType.spiky);
      expect(controller.noiseType, BlobNoiseType.spiky);
      expect(notifyCount, 1);

      // No-op does not notify
      controller.setNoiseType(BlobNoiseType.spiky);
      expect(notifyCount, 1);

      controller.setNoiseType(BlobNoiseType.simplex);
      expect(controller.noiseType, BlobNoiseType.simplex);
      expect(notifyCount, 2);
    });

    testWidgets('BlobFlutter widget accepts noiseType and responds to changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 200,
                noiseType: BlobNoiseType.fractal,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(BlobFlutter), findsOneWidget);

      // Rebuild with different noiseType
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: BlobFlutter(
                particleCount: 200,
                noiseType: BlobNoiseType.vortex,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(BlobFlutter), findsOneWidget);
    });
  });
}

class _MockCanvas extends Fake implements Canvas {
  int drawRawPointsCallCount = 0;
  ui.PointMode? pointMode;
  Float32List? points;
  Paint? paint;

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    drawRawPointsCallCount++;
    this.pointMode = pointMode;
    this.points = points;
    this.paint = paint;
  }
}
