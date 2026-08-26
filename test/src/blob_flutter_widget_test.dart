import 'package:flutter/material.dart';
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
  });
}
