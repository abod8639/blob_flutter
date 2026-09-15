import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Manages global-to-local touch coordinate transformations and message
/// encoding for background worker communication, caching results to avoid
/// redundant work.
class BlobTouchManager {
  List<Offset> _activeTouches = const [];
  List<Offset> _localTouches = const [];
  List<Offset> _lastGlobalTouches = const [];
  Float32List _encodedTouches = Float32List(0);

  List<Offset> get activeTouches => _activeTouches;
  List<Offset> get localTouches => _localTouches;
  Float32List get localTouchesFlat => _encodedTouches;
  Float32List get encodedTouches => _encodedTouches;

  void updateActiveTouches(List<Offset> touches) {
    _activeTouches = touches;
  }

  RenderBox? _cachedBox;

  /// Recomputes [_localTouches] and [_encodedTouches] only when global touch
  /// positions actually change.
  void updateLocalTouches(BuildContext context) {
    if (_activeTouches.isEmpty) {
      if (_localTouches.isNotEmpty) {
        _localTouches = const [];
        _lastGlobalTouches = const [];
        _encodedTouches = Float32List(0);
      }
      return;
    }

    if (_offsetListEquals(_activeTouches, _lastGlobalTouches)) return;
    _lastGlobalTouches = List<Offset>.of(_activeTouches);

    RenderBox? box = _cachedBox;
    if (box == null || !box.attached) {
      try {
        final ro = context.findRenderObject();
        if (ro is RenderBox && ro.attached) {
          box = ro;
          _cachedBox = box;
        } else {
          box = null;
        }
      } catch (_) {
        box = null;
      }
    }

    final int count = _activeTouches.length;
    final List<Offset> localList = List<Offset>.generate(
      count,
      (i) => box != null ? box.globalToLocal(_activeTouches[i]) : _activeTouches[i],
      growable: false,
    );
    _localTouches = localList;

    final buf = Float32List(count * 2);
    for (int i = 0; i < count; i++) {
      buf[i * 2] = localList[i].dx;
      buf[i * 2 + 1] = localList[i].dy;
    }
    _encodedTouches = buf;
  }

  static bool _offsetListEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
