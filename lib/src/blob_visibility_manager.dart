import 'package:flutter/material.dart';

/// Manages viewport visibility, navigation route awareness, and application lifecycle tracking for [BlobFlutter].
///
/// Automatically pauses tickers and computation when:
/// - The widget scrolls offscreen outside the visible viewport (with a 50px buffer).
/// - The application transitions to the background ([AppLifecycleState.paused],
///   [AppLifecycleState.inactive], or [AppLifecycleState.hidden]).
/// - The navigation route hosting the widget is covered, pushed over, or inactive.
class BlobVisibilityManager implements RouteAware {
  /// Callback triggered whenever visibility or background state changes.
  final VoidCallback onStateChanged;

  bool _isAppInBackground = false;
  bool _isOffscreen = false;
  bool _isRouteHidden = false;
  ScrollPosition? _scrollPosition;
  int _visibilityTickCounter = 0;
  VoidCallback? _scrollListener;

  ModalRoute<dynamic>? _modalRoute;
  Animation<double>? _secondaryAnimation;
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;

  /// Whether the widget has detected that the application is in background/inactive state.
  bool get isAppInBackground => _isAppInBackground;

  /// Whether the widget has detected that it is currently outside the screen viewport.
  bool get isOffscreen => _isOffscreen;

  /// Whether the widget's hosting route is currently hidden or covered by another route.
  bool get isRouteHidden => _isRouteHidden;

  BlobVisibilityManager({required this.onStateChanged});

  /// Updates scroll and route listeners, performing initial visibility checks after layout.
  void updateDependencies({
    required BuildContext context,
    required bool autoPauseOffscreen,
    bool autoPauseOnRouteChange = true,
    RouteObserver<ModalRoute<dynamic>>? routeObserver,
  }) {
    _updateScrollListener(context, autoPauseOffscreen);
    _updateRouteDependencies(
      context: context,
      autoPauseOnRouteChange: autoPauseOnRouteChange,
      routeObserver: routeObserver,
    );
    if (autoPauseOffscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkVisibility(
            context: context, autoPauseOffscreen: autoPauseOffscreen);
      });
    }
  }

  void _updateRouteDependencies({
    required BuildContext context,
    required bool autoPauseOnRouteChange,
    required RouteObserver<ModalRoute<dynamic>>? routeObserver,
  }) {
    if (!autoPauseOnRouteChange) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = null;
      _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatus);
      _secondaryAnimation = null;
      _modalRoute = null;
      if (_isRouteHidden) {
        _isRouteHidden = false;
        onStateChanged();
      }
      return;
    }

    final newRoute = ModalRoute.of(context);
    if (newRoute != _modalRoute) {
      _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatus);
      _modalRoute = newRoute;
      _secondaryAnimation = newRoute?.secondaryAnimation;
      _secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatus);

      if (_routeObserver != null && _modalRoute != null) {
        _routeObserver!.subscribe(this, _modalRoute!);
      }
    }

    if (routeObserver != _routeObserver) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = routeObserver;
      if (_routeObserver != null && _modalRoute != null) {
        _routeObserver!.subscribe(this, _modalRoute!);
      }
    }

    _evaluateRouteVisibility(autoPauseOnRouteChange: autoPauseOnRouteChange);
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    _evaluateRouteVisibility(autoPauseOnRouteChange: true);
  }

  void _evaluateRouteVisibility({required bool autoPauseOnRouteChange}) {
    if (!autoPauseOnRouteChange || _modalRoute == null) {
      if (_isRouteHidden) {
        _isRouteHidden = false;
        onStateChanged();
      }
      return;
    }

    // A route is covered if it is not current and secondaryAnimation is completed or not in forward transition
    final isCovered = !_modalRoute!.isCurrent &&
        (_secondaryAnimation == null ||
            _secondaryAnimation!.status != AnimationStatus.forward);

    if (isCovered != _isRouteHidden) {
      _isRouteHidden = isCovered;
      onStateChanged();
    }
  }

  // ── RouteAware Callbacks ───────────────────────────────────────────────────

  @override
  void didPush() {
    _evaluateRouteVisibility(autoPauseOnRouteChange: true);
  }

  @override
  void didPop() {}

  @override
  void didPushNext() {
    if (!_isRouteHidden) {
      _isRouteHidden = true;
      onStateChanged();
    }
  }

  @override
  void didPopNext() {
    if (_isRouteHidden) {
      _isRouteHidden = false;
      onStateChanged();
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

  /// Evaluates whether the widget's render object is inside or overlapping the screen bounds,
  /// and not concealed beneath an opaque route on the navigation stack.
  bool isRenderObjectVisible(BuildContext context) {
    if (_isRouteHidden) return false;

    final route = _modalRoute ?? ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      final secAnim = _secondaryAnimation ?? route.secondaryAnimation;
      if (secAnim == null || secAnim.status != AnimationStatus.forward) {
        return false;
      }
    }

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
    bool oldAutoPauseOnRouteChange = true,
    bool newAutoPauseOnRouteChange = true,
    RouteObserver<ModalRoute<dynamic>>? oldRouteObserver,
    RouteObserver<ModalRoute<dynamic>>? newRouteObserver,
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

    if (oldAutoPauseOnRouteChange != newAutoPauseOnRouteChange ||
        oldRouteObserver != newRouteObserver) {
      _updateRouteDependencies(
        context: context,
        autoPauseOnRouteChange: newAutoPauseOnRouteChange,
        routeObserver: newRouteObserver,
      );
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

    _routeObserver?.unsubscribe(this);
    _routeObserver = null;
    _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatus);
    _secondaryAnimation = null;
    _modalRoute = null;
  }
}
