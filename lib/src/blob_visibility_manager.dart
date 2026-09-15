import 'package:flutter/material.dart';

/// Manages viewport visibility and application lifecycle tracking for [BlobFlutter].
///
/// Automatically pauses tickers and computation when:
/// - The widget scrolls offscreen outside the visible viewport (with a 50px buffer).
/// - The application transitions to the background ([AppLifecycleState.paused],
///   [AppLifecycleState.inactive], or [AppLifecycleState.hidden]).
class BlobVisibilityManager {
  /// Callback triggered whenever visibility or background state changes.
  final VoidCallback onStateChanged;

  bool _isAppInBackground = false;
  bool _isOffscreen = false;
  ScrollPosition? _scrollPosition;
  int _visibilityTickCounter = 0;
  VoidCallback? _scrollListener;

  /// Whether the widget has detected that the application is in background/inactive state.
  bool get isAppInBackground => _isAppInBackground;

  /// Whether the widget has detected that it is currently outside the screen viewport.
  bool get isOffscreen => _isOffscreen;

  BlobVisibilityManager({required this.onStateChanged});

  /// Updates scroll listener and performs initial visibility check after frame layout.
  void updateDependencies({
    required BuildContext context,
    required bool autoPauseOffscreen,
  }) {
    _updateScrollListener(context, autoPauseOffscreen);
    if (autoPauseOffscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkVisibility(
            context: context, autoPauseOffscreen: autoPauseOffscreen);
      });
    }
  }

  void _updateScrollListener(BuildContext context, bool autoPauseOffscreen) {
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      if (_scrollPosition != null && _scrollListener != null) {
        try {
          _scrollPosition!.removeListener(_scrollListener!);
        } catch (_) {}
      }
      _scrollPosition = newPosition;
      if (_scrollPosition != null) {
        _scrollListener = () => _onScrollUpdated(context, autoPauseOffscreen);
        _scrollPosition!.addListener(_scrollListener!);
      }
    }
  }

  void _onScrollUpdated(BuildContext context, bool autoPauseOffscreen) {
    if (!autoPauseOffscreen) return;
    checkVisibility(context: context, autoPauseOffscreen: autoPauseOffscreen);
  }

  /// Checks if the widget's render object overlaps the screen viewport.
  void checkVisibility({
    required BuildContext context,
    required bool autoPauseOffscreen,
  }) {
    if (!autoPauseOffscreen) return;
    final visible = isRenderObjectVisible(context);
    final isOff = !visible;
    if (isOff != _isOffscreen) {
      _isOffscreen = isOff;
      onStateChanged();
    }
  }

  /// Evaluates whether the widget's render object is inside or overlapping the screen bounds.
  bool isRenderObjectVisible(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return true;
    if (renderObject is! RenderBox) return true;
    if (!renderObject.hasSize || renderObject.size.isEmpty) return true;

    final view = View.maybeOf(context);
    if (view == null) return true;
    final physicalSize = view.physicalSize;
    final pixelRatio = view.devicePixelRatio;
    if (pixelRatio <= 0.0 || physicalSize.isEmpty) return true;
    final screenSize = physicalSize / pixelRatio;

    try {
      final translation = renderObject.getTransformTo(null).getTranslation();
      final rect = Rect.fromLTWH(
        translation.x,
        translation.y,
        renderObject.size.width,
        renderObject.size.height,
      );

      // Pre-wake buffer of 50 logical pixels so animation wakes up slightly before entering viewport
      final screenBounds = Rect.fromLTWH(
        -50.0,
        -50.0,
        screenSize.width + 100.0,
        screenSize.height + 100.0,
      );

      return rect.overlaps(screenBounds);
    } catch (_) {
      return true;
    }
  }

  /// Periodic visibility check invoked every 30 animation ticks.
  ///
  /// Returns `true` if the widget has just become offscreen.
  bool checkTickVisibility({
    required BuildContext context,
    required bool autoPauseOffscreen,
  }) {
    if (!autoPauseOffscreen) return false;

    _visibilityTickCounter++;
    if (_visibilityTickCounter >= 30) {
      _visibilityTickCounter = 0;
      if (!isRenderObjectVisible(context)) {
        _isOffscreen = true;
        onStateChanged();
        return true;
      }
    }
    return false;
  }

  /// Handles application lifecycle state transitions.
  void handleAppLifecycleState(
    AppLifecycleState state, {
    required bool autoPauseOnAppBackground,
  }) {
    if (!autoPauseOnAppBackground) return;
    final isBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (isBackground != _isAppInBackground) {
      _isAppInBackground = isBackground;
      onStateChanged();
    }
  }

  /// Handles updates when widget properties change in `didUpdateWidget`.
  void handleWidgetUpdated({
    required BuildContext context,
    required bool oldAutoPauseOffscreen,
    required bool newAutoPauseOffscreen,
    required bool oldAutoPauseOnAppBackground,
    required bool newAutoPauseOnAppBackground,
  }) {
    if (oldAutoPauseOffscreen != newAutoPauseOffscreen) {
      if (!newAutoPauseOffscreen) {
        _isOffscreen = false;
      } else {
        checkVisibility(
            context: context, autoPauseOffscreen: newAutoPauseOffscreen);
      }
      onStateChanged();
    }

    if (oldAutoPauseOnAppBackground != newAutoPauseOnAppBackground) {
      if (!newAutoPauseOnAppBackground) {
        _isAppInBackground = false;
      }
      onStateChanged();
    }
  }

  /// Disposes scroll listeners and references.
  void dispose() {
    if (_scrollPosition != null && _scrollListener != null) {
      try {
        _scrollPosition!.removeListener(_scrollListener!);
      } catch (_) {}
    }
    _scrollPosition = null;
    _scrollListener = null;
  }
}
