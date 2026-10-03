import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_visibility_manager.dart';

class _ThrowingScrollPosition extends ScrollPositionWithSingleContext {
  bool shouldThrow = false;

  _ThrowingScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  @override
  void removeListener(VoidCallback listener) {
    if (shouldThrow) {
      throw Exception('Simulated removeListener failure');
    }
    super.removeListener(listener);
  }
}

class _ThrowingScrollController extends ScrollController {
  _ThrowingScrollPosition? throwingPosition;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    final pos = _ThrowingScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
    throwingPosition = pos;
    return pos;
  }
}

class _DummyRenderBox extends RenderBox {
  _DummyRenderBox() {
    attach(PipelineOwner());
    layout(const BoxConstraints.tightFor(width: 50, height: 50));
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }
}

class _ViewlessBuildContext extends Fake implements BuildContext {
  final RenderBox _box = _DummyRenderBox();

  @override
  RenderObject? findRenderObject() => _box;

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
          {Object? aspect}) =>
      null;

  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<
          T extends InheritedWidget>() =>
      null;
}

class _ThrowingRenderBox extends RenderBox {
  _ThrowingRenderBox() {
    attach(PipelineOwner());
    layout(const BoxConstraints.tightFor(width: 50, height: 50));
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    throw Exception('Simulated transform failure');
  }
}

class _CustomRenderObjectContext extends Fake implements BuildContext {
  final BuildContext _inner;
  final RenderObject _customRenderObject;
  _CustomRenderObjectContext(this._inner, this._customRenderObject);

  @override
  RenderObject? findRenderObject() => _customRenderObject;

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
          {Object? aspect}) =>
      _inner.dependOnInheritedWidgetOfExactType<T>(aspect: aspect);

  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<
          T extends InheritedWidget>() =>
      _inner.getElementForInheritedWidgetOfExactType<T>();

  @override
  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
          {Object? aspect}) =>
      _inner.dependOnInheritedElement(ancestor, aspect: aspect);
}

void main() {
  group('BlobVisibilityManager Unit & Widget Tests', () {
    testWidgets(
        'removes scroll listener when scroll position changes or detaches (L45)',
        (tester) async {
      final manager = BlobVisibilityManager(onStateChanged: () {});

      final scrollController1 = ScrollController();
      final scrollController2 = ScrollController();

      // Step 1: Attach inside first scrollable
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController1,
              child: Builder(
                builder: (context) {
                  manager.updateDependencies(
                    context: context,
                    autoPauseOffscreen: true,
                  );
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Step 2: Rebuild with different scroll position / controller (hits line 45: removeListener)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController2,
              child: Builder(
                builder: (context) {
                  manager.updateDependencies(
                    context: context,
                    autoPauseOffscreen: true,
                  );
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Step 3: Rebuild with null scrollable (hits line 45: removeListener when detached)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                manager.updateDependencies(
                  context: context,
                  autoPauseOffscreen: true,
                );
                return const SizedBox(width: 100, height: 100);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      manager.dispose();
      scrollController1.dispose();
      scrollController2.dispose();
    });

    testWidgets(
        'checkTickVisibility triggers offscreen state on 30th tick when not visible (L122-L129)',
        (tester) async {
      bool stateChanged = false;
      final manager =
          BlobVisibilityManager(onStateChanged: () => stateChanged = true);

      // Mount an offscreen widget (placed far below the screen viewport)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 5000.0, // far offscreen
                  left: 0.0,
                  child: Builder(
                    builder: (context) {
                      return const SizedBox(
                          key: ValueKey('offscreen_box'),
                          width: 100,
                          height: 100);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final offscreenContext =
          tester.element(find.byKey(const ValueKey('offscreen_box')));

      // First 29 ticks return false
      for (int i = 0; i < 29; i++) {
        final result = manager.checkTickVisibility(
          context: offscreenContext,
          autoPauseOffscreen: true,
        );
        expect(result, isFalse);
      }

      expect(manager.isOffscreen, isFalse);

      // 30th tick triggers lines 122-129
      final result30 = manager.checkTickVisibility(
        context: offscreenContext,
        autoPauseOffscreen: true,
      );
      expect(result30, isTrue);
      expect(manager.isOffscreen, isTrue);
      expect(stateChanged, isTrue);

      manager.dispose();
    });

    testWidgets(
        'handleWidgetUpdated handles toggling autoPauseOffscreen and autoPauseOnAppBackground (L155-L171)',
        (tester) async {
      int stateChangeCount = 0;
      final manager =
          BlobVisibilityManager(onStateChanged: () => stateChangeCount++);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const SizedBox(
                  key: ValueKey('test_box'), width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byKey(const ValueKey('test_box')));

      // 1. Toggle autoPauseOffscreen from false -> true (hits line 160: else checkVisibility)
      manager.handleWidgetUpdated(
        context: context,
        oldAutoPauseOffscreen: false,
        newAutoPauseOffscreen: true,
        oldAutoPauseOnAppBackground: true,
        newAutoPauseOnAppBackground: true,
      );
      expect(stateChangeCount, 1);

      // 2. Toggle autoPauseOnAppBackground from true -> false (hits line 167: _isAppInBackground = false)
      manager.handleWidgetUpdated(
        context: context,
        oldAutoPauseOffscreen: true,
        newAutoPauseOffscreen: true,
        oldAutoPauseOnAppBackground: true,
        newAutoPauseOnAppBackground: false,
      );
      expect(stateChangeCount, 2);
      expect(manager.isAppInBackground, isFalse);

      manager.dispose();
    });

    testWidgets(
        'checkVisibility returns early when autoPauseOffscreen is false (L67)',
        (tester) async {
      bool stateChanged = false;
      final manager =
          BlobVisibilityManager(onStateChanged: () => stateChanged = true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const SizedBox(
                    key: ValueKey('test_box'), width: 100, height: 100);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byKey(const ValueKey('test_box')));
      manager.checkVisibility(context: context, autoPauseOffscreen: false);

      expect(stateChanged, isFalse);
      expect(manager.isOffscreen, isFalse);

      manager.dispose();
    });

    testWidgets(
        '_updateScrollListener catches exception when removeListener fails during scroll position update (L47)',
        (tester) async {
      final controller1 = _ThrowingScrollController();
      final controller2 = ScrollController();
      final manager = BlobVisibilityManager(onStateChanged: () {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller1,
                    child: Builder(
                      builder: (c1) =>
                          const SizedBox(key: ValueKey('scroll1'), height: 100),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller2,
                    child: Builder(
                      builder: (c2) =>
                          const SizedBox(key: ValueKey('scroll2'), height: 100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final context1 = tester.element(find.byKey(const ValueKey('scroll1')));
      final context2 = tester.element(find.byKey(const ValueKey('scroll2')));

      manager.updateDependencies(
        context: context1,
        autoPauseOffscreen: false,
      );

      // Enable throwing specifically when removing the listener on oldPosition
      controller1.throwingPosition?.shouldThrow = true;

      // Updating dependencies with context2 triggers _updateScrollListener -> removeListener on oldPosition
      expect(
        () => manager.updateDependencies(
          context: context2,
          autoPauseOffscreen: false,
        ),
        returnsNormally,
      );

      controller1.throwingPosition?.shouldThrow = false;
      manager.dispose();
      controller1.dispose();
      controller2.dispose();
    });

    test(
        'isRenderObjectVisible returns true when View.maybeOf(context) is null (L84)',
        () {
      final manager = BlobVisibilityManager(onStateChanged: () {});
      final context = _ViewlessBuildContext();

      final isVisible = manager.isRenderObjectVisible(context);
      expect(isVisible, isTrue);

      manager.dispose();
    });

    testWidgets(
        'isRenderObjectVisible catches exception during coordinate transform and returns true (L108-L110)',
        (tester) async {
      final manager = BlobVisibilityManager(onStateChanged: () {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const SizedBox(
                  key: ValueKey('test_box'),
                  width: 100,
                  height: 100,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final innerContext =
          tester.element(find.byKey(const ValueKey('test_box')));
      final throwingBox = _ThrowingRenderBox();
      final customContext =
          _CustomRenderObjectContext(innerContext, throwingBox);

      final isVisible = manager.isRenderObjectVisible(customContext);
      expect(isVisible, isTrue);

      manager.dispose();
    });

    testWidgets(
        'dispose catches exception when removeListener fails (L180)',
        (tester) async {
      final controller = _ThrowingScrollController();
      final manager = BlobVisibilityManager(onStateChanged: () {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Builder(
                builder: (context) {
                  manager.updateDependencies(
                    context: context,
                    autoPauseOffscreen: true,
                  );
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.throwingPosition?.shouldThrow = true;
      // Calling dispose while _scrollPosition is attached to ThrowingScrollPosition hits line 180
      expect(() => manager.dispose(), returnsNormally);

      controller.throwingPosition?.shouldThrow = false;
      controller.dispose();
    });
  });
}
