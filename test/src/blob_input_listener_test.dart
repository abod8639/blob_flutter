import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';

void main() {
  group('BlobInputListener Widget Tests', () {
    testWidgets('does not rotate on drag by default unless enableDragRotation is true', (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await gesture.moveBy(const Offset(20, 30));
      await tester.pump();

      // By default, rotation is disabled on drag
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);
      expect(touches.length, 1);

      await gesture.up();
      await tester.pump();
      expect(touches.isEmpty, true);

      // Now enable drag rotation and test
      controller.setEnableDragRotation(true);
      final gesture2 = await tester.startGesture(const Offset(100, 100));
      await gesture2.moveBy(const Offset(20, 30));
      await tester.pump();

      expect(controller.rotationX, isNot(0.0));
      expect(controller.rotationY, isNot(0.0));
      await gesture2.up();
    });

    testWidgets('applies tapScaleFactor and multi-touch counts to dispersion output', (tester) async {
      final controller = BlobController(tapScaleFactor: 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (_) {},
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      // 1 finger touch -> base dispersion is (0.4 + 0.2 * 1) = 0.6
      // Multiplying by tapScaleFactor (0.5) should yield 0.3
      expect(controller.dispersion, closeTo(0.3, 0.0001));

      await gesture.up();
      await tester.pump();
      expect(controller.dispersion, 0.0);
    });

    testWidgets('mouse hover triggers rotation impulse only when enableHoverRotation is true', (tester) async {
      final controller = BlobController(enableHoverRotation: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (_) {},
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(80, 80));
      await tester.pump();

      expect(controller.rotationX, isNot(0.0));
      expect(controller.rotationY, isNot(0.0));

      await gesture.removePointer();
    });

    testWidgets('mouse hover triggers dispersion and touches callback when enableHover is true', (tester) async {
      final controller = BlobController();
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
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await tester.pump();

      expect(touches.length, 1);
      expect(touches.first, const Offset(50, 50));
      expect(controller.dispersion, closeTo(0.5, 0.0001));

      // Moving mouse out clears hover
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
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      expect(touches.length, 1);
      expect(controller.dispersion, greaterThan(0.0));

      await gesture.cancel();
      await tester.pump();

      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);
    });

    testWidgets('didUpdateWidget clears hover position if hover becomes disabled', (tester) async {
      final controller = BlobController();
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
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await tester.pump();
      expect(touches.isNotEmpty, true);

      // Rebuild with enableHover = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                enableHover: false,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(touches.isEmpty, true);
      await gesture.removePointer();
    });
  });
}
