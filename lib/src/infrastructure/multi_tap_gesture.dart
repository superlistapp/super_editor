import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const Duration kTapMinTime = Duration(milliseconds: 40);

/// Recognizes when the user has tapped the screen at the same location one,
/// two, and three times.
///
/// Each tap is reported as soon as it occurs. One particular tap sequence,
/// e.g., a double-tap, does not prevent callbacks for other tap sequences,
/// e.g., a single-tap or triple-tap.
///
/// This implementation is based on Flutter's `DoubleTapGestureRecognizer`
/// implementation. I don't know how correct this implementation is, but
/// it seems to work where it's used.
class TapSequenceGestureRecognizer extends GestureRecognizer {
  /// Create a gesture recognizer for double and triple taps.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.kind}
  TapSequenceGestureRecognizer({
    Object? debugOwner,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner, kind: kind);

  GestureTapDownCallback? onTapDown;
  GestureDoubleTapCallback? onTap;
  GestureTapCancelCallback? onTapCancel;

  GestureTapDownCallback? onDoubleTapDown;
  GestureDoubleTapCallback? onDoubleTap;
  GestureTapCancelCallback? onDoubleTapCancel;

  GestureTapDownCallback? onTripleTapDown;
  GestureDoubleTapCallback? onTripleTap;
  GestureTapCancelCallback? onTripleTapCancel;

  Timer? _tripleTapTimer;
  _TapTracker? _firstTap;
  _TapTracker? _secondTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onTripleTapDown == null && onTripleTap == null && onTripleTapCancel == null) return false;
          break;
        default:
          return false;
      }
    }
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_secondTap != null) {
      if (!_secondTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_secondTap!.hasElapsedMinTime() || !_secondTap!.hasSameButton(event)) {
        // Restart when the third tap is too close to the second (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else if (onTripleTapDown != null) {
        final TapDownDetails details = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>('onTripleTapDown', () => onTripleTapDown!(details));
      }
    } else if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else if (onDoubleTapDown != null) {
        final TapDownDetails details = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
      }
    } else if (onTapDown != null) {
      final TapDownDetails details = TapDownDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(event.pointer),
      );
      invokeCallback<void>('onTapDown', () => onTapDown!(details));
    }

    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance!.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kTapMinTime,
    );
    _trackers[event.pointer] = tracker;
    if (event.transform != null) {
      tracker.startTrackingPointer(_handleEvent, event.transform!);
    }
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(tracker);
      } else if (_secondTap == null) {
        _registerSecondTap(tracker);
      } else {
        _registerThirdTap(tracker);
      }
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        _reject(tracker);
      }
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _TapTracker? tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null && _firstTap != null && _firstTap!.pointer == pointer) {
      tracker = _firstTap;
    }
    // If tracker is still null, check if this is the first tap tracker
    if (tracker == null && _secondTap != null && _secondTap!.pointer == pointer) {
      tracker = _secondTap;
    }
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _reject(tracker);
    }
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null || _secondTap != null) {
      if (tracker == _firstTap || tracker == _secondTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) {
          _reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    _stopTapTimer();
    if (_secondTap != null) {
      if (_trackers.isNotEmpty) {
        _checkCancel();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _secondTap!;
      _secondTap = null;
      _reject(tracker);
      GestureBinding.instance!.gestureArena.release(tracker.pointer);
    }
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) {
        _checkCancel();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance!.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startTapTimer();
    _checkUp(tracker.initialButtons);
    GestureBinding.instance!.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    _startTapTimer();
    _checkUp(tracker.initialButtons);
    GestureBinding.instance!.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _secondTap = tracker;
  }

  void _registerThirdTap(_TapTracker tracker) {
    _secondTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(tracker.initialButtons);
    _reset();
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startTapTimer() {
    _tripleTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopTapTimer() {
    if (_tripleTapTimer != null) {
      _tripleTapTimer!.cancel();
      _tripleTapTimer = null;
    }
  }

  void _checkUp(int buttons) {
    assert(buttons == kPrimaryButton);
    if (_firstTap == null && _secondTap == null && onTap != null) {
      invokeCallback<void>('onTap', onTap!);
    }
    if (_firstTap != null && _secondTap == null && onDoubleTap != null) {
      invokeCallback<void>('onDoubleTap', onDoubleTap!);
    }
    if (_secondTap != null && onTripleTap != null) {
      invokeCallback<void>('onTripleTap', onTripleTap!);
    }
  }

  void _checkCancel() {
    if (_firstTap == null && onTapCancel != null) {
      invokeCallback<void>('onTapCancel', onTapCancel!);
    }
    if (_firstTap != null && _secondTap == null && onDoubleTapCancel != null) {
      invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
    }
    if (_secondTap != null && onTripleTapCancel != null) {
      invokeCallback<void>('onTripleTapCancel', onTripleTapCancel!);
    }
  }

  @override
  String get debugDescription => 'triple tap';
}

typedef GestureDoubleTapCallback = void Function();

/// TapTracker helps track individual tap sequences as part of a
/// larger gesture.
class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
  })   : pointer = event.pointer,
        _initialGlobalPosition = event.position,
        initialButtons = event.buttons,
        _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4 transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance!.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance!.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

/// CountdownZoned tracks whether the specified duration has elapsed since
/// creation, honoring [Zone].
class _CountdownZoned {
  _CountdownZoned({required Duration duration}) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}
