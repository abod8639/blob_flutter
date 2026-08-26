import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_touch_manager.dart';

void main() {
  group('BlobTouchManager Tests', () {
    test('initial state has empty lists and empty Float32List', () {
      final manager = BlobTouchManager();
      expect(manager.activeTouches, isEmpty);
      expect(manager.localTouches, isEmpty);
      expect(manager.localTouchesFlat, isEmpty);
      expect(manager.encodedTouches, isEmpty);
    });

    test('updateActiveTouches updates active touches list', () {
      final manager = BlobTouchManager();
      final touches = [const Offset(10, 20), const Offset(30, 40)];
      manager.updateActiveTouches(touches);
      expect(manager.activeTouches, touches);
    });

    testWidgets('updateLocalTouches transforms coordinates and encodes Float32List with RenderBox', (tester) async {
      final manager = BlobTouchManager();
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 50.0, top: 100.0),
                child: Builder(
                  builder: (context) {
                    savedContext = context;
                    return const SizedBox(width: 200, height: 200);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Global coordinates: (60, 120) and (150, 250)
      // Local coordinates should be: (60 - 50, 120 - 100) = (10, 20) and (150 - 50, 250 - 100) = (100, 150)
      manager.updateActiveTouches([
        const Offset(60, 120),
        const Offset(150, 250),
      ]);

      manager.updateLocalTouches(savedContext);

      expect(manager.localTouches.length, 2);
      expect(manager.localTouches[0], const Offset(10, 20));
      expect(manager.localTouches[1], const Offset(100, 150));

      final Float32List encoded = manager.encodedTouches;
      expect(encoded.length, 4);
      expect(encoded[0], 10.0);
      expect(encoded[1], 20.0);
      expect(encoded[2], 100.0);
      expect(encoded[3], 150.0);
      expect(manager.localTouchesFlat, encoded);

      // Verify caching: calling updateLocalTouches again does not reallocate encodedTouches
      final prevBuffer = manager.encodedTouches;
      manager.updateLocalTouches(savedContext);
      expect(identical(manager.encodedTouches, prevBuffer), true);

      // Clear touches
      manager.updateActiveTouches([]);
      manager.updateLocalTouches(savedContext);
      expect(manager.localTouches, isEmpty);
      expect(manager.encodedTouches, isEmpty);
    });

    testWidgets('updateLocalTouches falls back to global touches when RenderBox is unattached', (tester) async {
      final manager = BlobTouchManager();
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              savedContext = context;
              return const Placeholder();
            },
          ),
        ),
      );

      // Before pump or when unattached
      manager.updateActiveTouches([const Offset(45, 90)]);
      manager.updateLocalTouches(savedContext);

      expect(manager.localTouches.length, 1);
      expect(manager.encodedTouches.length, 2);
    });
  });
}
