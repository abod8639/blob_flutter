import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/blob_flutter.dart';
import 'package:blob_flutter/src/blob_input_listener.dart';

void main() {
  group('Gesture Arena Hijacking & Touch Pass-Through Tests', () {
    testWidgets(
        'interactive: false ignores all touch events and does not disperse particles',
        (tester) async {
      final controller = BlobController();
      List<Offset> touches = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobInputListener(
              controller: controller,
              interactive: false,
              onTouchesChanged: (t) => touches = t,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      expect(controller.dispersion, 0.0);
      expect(touches.isEmpty, true);

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
        'hitTestBehavior: translucent permits taps to pass to buttons beneath in a Stack',
        (tester) async {
      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 50,
                  top: 50,
                  width: 100,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => buttonTapped = true,
                    child: const Text('Underneath'),
                  ),
                ),
                Positioned.fill(
                  child: BlobFlutter(
                    radius: 100,
                    hitTestBehavior: HitTestBehavior.translucent,
                    interactive: true,
                    dragRotation: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the location where the button is located (Offset(100, 75))
      await tester.tapAt(const Offset(100, 75));
      await tester.pump();

      expect(buttonTapped, isTrue,
          reason:
              'Translucent hitTestBehavior must permit taps to reach underlying widgets in a Stack');
    });

    testWidgets(
        'interactive: false completely passes touches to widgets beneath in Stack',
        (tester) async {
      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 50,
                  top: 50,
                  width: 100,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => buttonTapped = true,
                    child: const Text('Underneath'),
                  ),
                ),
                Positioned.fill(
                  child: BlobFlutter(
                    radius: 100,
                    interactive: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tapAt(const Offset(100, 75));
      await tester.pump();

      expect(buttonTapped, isTrue);
    });

    testWidgets(
        'ListView scrolling is not hijacked when enableDragRotation and enablePinchToScale are false',
        (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemCount: 20,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SizedBox(
                    height: 300,
                    child: BlobFlutter(
                      radius: 80,
                      dragRotation: false,
                      pinchToScale: false,
                    ),
                  );
                }
                return SizedBox(
                  height: 100,
                  child: Text('Item $index'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(scrollController.offset, 0.0);

      // Drag up over the BlobFlutter widget
      await tester.drag(find.byType(BlobFlutter), const Offset(0, -200));
      await tester.pump();

      expect(scrollController.offset, greaterThan(100.0),
          reason:
              'ListView must scroll smoothly when DragRotation and PinchToScale are disabled');
    });
  });
}
