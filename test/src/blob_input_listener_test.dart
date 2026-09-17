import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';

void main() {
  group('BlobInputListener Widget Tests', () {
    testWidgets(
        'does not rotate on drag by default unless enableDragRotation is true',
        (tester) async {
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
      controller.setDragRotation(true);
      final gesture2 = await tester.startGesture(const Offset(100, 100));
      await gesture2.moveBy(const Offset(20, 30));
      await tester.pump();

      expect(controller.rotationX, isNot(0.0));
      expect(controller.rotationY, isNot(0.0));
      await gesture2.up();
    });

    testWidgets(
        'applies tapScaleFactor and multi-touch counts to dispersion output',
        (tester) async {
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

    testWidgets(
        'mouse hover triggers rotation impulse only when hoverRotation is true',
        (tester) async {
      final controller = BlobController(hoverRotation: true);

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

      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(80, 80));
      await tester.pump();

      expect(controller.rotationX, isNot(0.0));
      expect(controller.rotationY, isNot(0.0));

      await gesture.removePointer();
    });

    testWidgets(
        'mouse hover triggers dispersion and touches callback when hover is true',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(60, 60));
      await tester.pump();

      expect(touches.length, 1);
      expect(touches.first, const Offset(60, 60));
      expect(controller.dispersion, closeTo(0.5, 0.0001));

      // Moving mouse out clears hover
      await gesture.moveTo(const Offset(300, 300));
      await tester.pump();
      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);

      await gesture.removePointer();
    });

    testWidgets('pointer cancel removes touch points and resets dispersion',
        (tester) async {
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

    testWidgets(
        'didUpdateWidget clears hover position if hover becomes disabled',
        (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) {
                  touches = t;
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(60, 60));
      await tester.pump();
      expect(touches.isNotEmpty, true);

      // Rebuild with hover = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: false,
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

    testWidgets(
        'pinch-to-scale gesture scales the blob when pinchToScale is true',
        (tester) async {
      final controller = BlobController(pinchToScale: true);
      controller.setScale(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (_) {},
                child: Container(width: 300, height: 300, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final touch1 = await tester.startGesture(const Offset(100, 100));
      final touch2 = await tester.startGesture(const Offset(200, 100));
      await tester.pump();

      await touch2.moveTo(const Offset(280, 100));
      await tester.pump();

      expect(controller.scale, greaterThan(1.0));

      await touch1.up();
      await touch2.up();
      await tester.pump();
    });

    testWidgets(
        'multi-touch falls back to drag rotation when enablePinchToScale is false',
        (tester) async {
      final controller =
          BlobController(pinchToScale: false, dragRotation: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                onTouchesChanged: (_) {},
                child: Container(width: 300, height: 300, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final touch1 = await tester.startGesture(const Offset(100, 100));
      final touch2 = await tester.startGesture(const Offset(200, 100));
      await tester.pump();

      await touch2.moveTo(const Offset(250, 130));
      await tester.pump();

      expect(controller.rotationX != 0.0 || controller.rotationY != 0.0, true);

      await touch1.up();
      await touch2.up();
      await tester.pump();
    });

    testWidgets(
        'mouse drag and release updates hover position to release position, not initial position',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) {
                  touches = List.of(t);
                },
                child: Container(width: 300, height: 300, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      // 1. Initial hover at (50, 50)
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(50, 50));
      await tester.pump();
      expect(touches.single, const Offset(50, 50));

      // 2. Mouse down at (50, 50)
      await gesture.down(const Offset(50, 50));
      await tester.pump();
      expect(touches.single, const Offset(50, 50));

      // 3. Mouse move/drag to (150, 150)
      await gesture.moveTo(const Offset(150, 150));
      await tester.pump();
      expect(touches.single, const Offset(150, 150));

      // 4. Mouse up / release at (150, 150)
      await gesture.up();
      await tester.pump();

      // Must remain at the released position (150, 150), NOT snap back to initial (50, 50)
      expect(touches.single, const Offset(150, 150));
      expect(controller.dispersion, closeTo(0.5, 0.0001));

      await gesture.removePointer();
    });

    testWidgets(
        'mouse drag and release outside widget bounds clears hover position',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) {
                  touches = List.of(t);
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(50, 50));
      await tester.pump();
      expect(touches.single, const Offset(50, 50));

      await gesture.down(const Offset(50, 50));
      await tester.pump();

      // Drag outside widget bounds (widget is 200x200 at topLeft)
      await gesture.moveTo(const Offset(400, 400));
      await tester.pump();
      expect(touches.single, const Offset(400, 400));

      // Release outside bounds
      await gesture.up();
      await tester.pump();

      // Hover position should be cleared and dispersion reset to 0
      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);

      await gesture.removePointer();
    });

    testWidgets(
        'touch device release clears hover position and resets dispersion',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) {
                  touches = List.of(t);
                },
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      // Touch gesture (kind: touch)
      final TestGesture gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.touch);
      await gesture.down(const Offset(50, 50));
      await tester.pump();
      expect(touches.single, const Offset(50, 50));

      await gesture.moveTo(const Offset(100, 100));
      await tester.pump();
      expect(touches.single, const Offset(100, 100));

      await gesture.up();
      await tester.pump();

      // Touch release should never leave ghost hover points
      expect(touches.isEmpty, true);
      expect(controller.dispersion, 0.0);
    });

    testWidgets(
        'does not rebuild BlobInputListener when rotation impulse or dispersion changes',
        (tester) async {
      final controller = BlobController(
        dragRotation: true,
        pinchToScale: true,
      );

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

      expect(find.byType(GestureDetector), findsOneWidget);

      // Add rotation impulse and dispersion without changing structural flags
      controller.addRotationImpulse(const Offset(10, 20));
      controller.setDispersion(0.5);
      await tester.pump();

      // GestureDetector is still present and unchanged
      expect(find.byType(GestureDetector), findsOneWidget);

      // Changing structural configuration flags updates the tree
      controller.setDragRotation(false);
      controller.setPinchToScale(false);
      await tester.pump();

      // GestureDetector is unmounted when scale and drag rotation are both disabled
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets(
        'mouse pointer up falls back to event.position when renderObject is not attached (L106)',
        (tester) async {
      final controller = BlobController(hover: true);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              hover: true,
              onTouchesChanged: (t) => touches = t,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(100, 100));
      await gesture.down(const Offset(100, 100));
      await tester.pump();

      BlobInputListener.debugFindRenderObject = (_) => null;
      try {
        await gesture.up();
        await tester.pump();
        expect(touches.length, 1);
        expect(touches[0], const Offset(100, 100));
      } finally {
        BlobInputListener.debugFindRenderObject = null;
        await gesture.removePointer();
      }
    });

    testWidgets(
        'updating interactive from true to false clears touches and resets dispersion (L118-L125)',
        (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      Widget buildTree({required bool interactive}) {
        return MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              interactive: interactive,
              onTouchesChanged: (t) => touches = t,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(interactive: true));

      // Start a touch so _touchPoints is not empty
      final gesture = await tester.startGesture(const Offset(50, 50));
      await tester.pump();
      expect(touches.length, 1);
      expect(controller.dispersion, greaterThan(0.0));

      // Now update widget with interactive: false
      await tester.pumpWidget(buildTree(interactive: false));
      await tester.pump();

      expect(touches, isEmpty);
      expect(controller.dispersion, 0.0);

      await gesture.up();
    });

    testWidgets(
        'updating interactive from true to false clears active hover (L118-L125)',
        (tester) async {
      final controller = BlobController(hover: true);
      List<Offset> touches = [];

      Widget buildTree({required bool interactive}) {
        return MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              hover: true,
              interactive: interactive,
              onTouchesChanged: (t) => touches = t,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(interactive: true));

      final gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(50, 50));
      await gesture.moveTo(const Offset(60, 60));
      await tester.pump();
      expect(touches.length, 1);

      await tester.pumpWidget(buildTree(interactive: false));
      await tester.pump();

      expect(touches, isEmpty);
      expect(controller.dispersion, 0.0);

      await gesture.removePointer();
    });

    testWidgets(
        'touch release followed immediately by synthetic hover does not leave ghost hover points',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) => touches = List.of(t),
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      // 1. Touch down and move
      final touch = await tester.startGesture(const Offset(50, 50), kind: ui.PointerDeviceKind.touch);
      await tester.pump();
      expect(touches.single, const Offset(50, 50));
      expect(controller.dispersion, greaterThan(0.0));

      // 2. Touch release
      await touch.up();
      await tester.pump();
      expect(touches, isEmpty);
      expect(controller.dispersion, 0.0);

      // 3. Browser fires synthetic mouse hover at the touch position immediately after touch release
      final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(50, 50));
      await mouse.moveTo(const Offset(50, 50));
      await tester.pump();

      // Synthetic hover MUST be ignored; touches remain empty and dispersion stays 0
      expect(touches, isEmpty);
      expect(controller.dispersion, 0.0);

      await mouse.removePointer();
    });

    testWidgets(
        'direct touch hover events are ignored to prevent touchscreen ghosting',
        (tester) async {
      final controller = BlobController(tapScaleFactor: 1.0);
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BlobInputListener(
                controller: controller,
                hover: true,
                onTouchesChanged: (t) => touches = List.of(t),
                child: Container(width: 200, height: 200, color: Colors.black),
              ),
            ),
          ),
        ),
      );

      // Attempt to send a hover event with kind == touch
      final touchHover = await tester.createGesture(kind: ui.PointerDeviceKind.touch);
      await touchHover.addPointer(location: const Offset(80, 80));
      await touchHover.moveTo(const Offset(80, 80));
      await tester.pump();

      expect(touches, isEmpty);
      expect(controller.dispersion, 0.0);

      await touchHover.removePointer();
    });
  });
}

