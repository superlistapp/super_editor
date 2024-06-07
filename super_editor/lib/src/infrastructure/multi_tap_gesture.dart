import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const kTapMinTime = Duration(milliseconds: 40);
const kTapTimeout = Duration(milliseconds: 300);

/// Recognizes when the user has tapped the screen at the same location one,
/// two, and three times.
///
/// Reports all gestures in a sequence when [reportPrecedingGestures] is `true`,
/// e.g., single-tap followed by double-tap followed by triple-tap. When
/// [reportPrecedingGestures] is `false`, only the final gesture is reported,
/// e.g., a triple-tap without a single-tap or double-tap.
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
    Set<PointerDeviceKind>? supportedDevices,
    this.reportPrecedingGestures = true,
  }) : super(debugOwner: debugOwner, supportedDevices: supportedDevices);

  /// If `true`, reports the gestures that lead up to the final
  /// gesture, e.g., reports a single-tap before reporting a double-tap.
  ///
  /// If `false`, only reports the final gesture, e.g., reports double-tap,
  /// but not the single-tap that preceded it.
  final bool reportPrecedingGestures;

  GestureTapDownCallback? onTapDown;
  GestureTapUpCallback? onTapUp;
  GestureDoubleTapCallback? onTap;
  GestureTapCancelCallback? onTapCancel;

  GestureTapDownCallback? onDoubleTapDown;
  GestureTapUpCallback? onDoubleTapUp;
  GestureDoubleTapCallback? onDoubleTap;
  GestureTapCancelCallback? onDoubleTapCancel;

  GestureTapDownCallback? onTripleTapDown;
  GestureTapUpCallback? onTripleTapUp;
  GestureDoubleTapCallback? onTripleTap;
  GestureTapCancelCallback? onTripleTapCancel;

  /// Callback that's invoked when this gesture recognizer
  /// exceeds the timeout between taps and stops looking for
  /// a gesture.
  ///
  /// If a triple-tap occurs, the timeout never executes because
  /// a triple tap is the final possible gesture in the sequence.
  ///
  /// If a single tap or double tap occurs, without making it to
  /// a final triple tap, the timeout will be invoked. This means
  /// that if a user taps one time, and only intends to tap one time,
  /// then this timeout is still invoked. The timeout doesn't mean
  /// that no gesture occurred, it only means that the user didn't
  /// triple tap. This timeout is provided so that clients can
  /// take an action after a single tap or double tap without worrying
  /// about yet another gesture being reported shortly thereafter.
  VoidCallback? onTimeout;

  Timer? _tapTimer;
  _TapTracker? _firstTap;
  TapDownDetails? _firstTapDownDetails;
  TapUpDetails? _firstTapUpDetails;
  _TapTracker? _secondTap;
  TapDownDetails? _secondTapDownDetails;
  TapUpDetails? _secondTapUpDetails;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      if (event.buttons != kPrimaryButton) {
        return false;
      }
    }
    return event.buttons == kPrimaryButton && super.isPointerAllowed(event);
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
        _secondTapDownDetails = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        if (reportPrecedingGestures) {
          invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(_secondTapDownDetails!));
        }
      }
    } else if (onTapDown != null) {
      _firstTapDownDetails = TapDownDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(event.pointer),
      );
      if (reportPrecedingGestures) {
        invokeCallback<void>('onTapDown', () => onTapDown!(_firstTapDownDetails!));
      }
    }

    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      tapMinTime: kTapMinTime,
    );
    _trackers[event.pointer] = tracker;
    if (event.transform != null) {
      tracker.startTrackingPointer(_handleEvent, event.transform!);
    }
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      // print("_handleEvent() - pointer up - _firstTap: $_firstTap, _secondTap: $_secondTap");
      if (_firstTap == null) {
        _registerFirstTap(event, tracker);
      } else if (_secondTap == null) {
        _registerSecondTap(event, tracker);
      } else {
        _registerThirdTap(event, tracker);
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
    // If tracker is still null, check if this is the second tap tracker
    if (tracker == null && _secondTap != null && _secondTap!.pointer == pointer) {
      tracker = _secondTap;
    }
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _reject(tracker);
    }
  }

  void _reject(_TapTracker tracker) {
    if (!_trackers.containsKey(tracker.pointer)) {
      return;
    }

    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);

    if (_firstTap == null && _firstTapDownDetails != null) {
      // The user tapped down and then another recognizer won the arena. For example, in an app with both a
      // TapSequenceGestureRecognizer and a HorizontalDragGestureRecognizer, when the user taps down and
      // then drags horizontally, the onTapDown event is fired, and after that the HorizontalDragGestureRecognizer
      // declares itself as the winner. Invoke onTapCancel to cancel the gesture.
      _notifyListenersOfCancellation();
      if (_trackers.isEmpty) {
        _reset();
      }
      return;
    }

    if (tracker == _secondTap) {
      // A double tap was registered and we were defeated on the gesture arena after that. Reset
      // to clean up the tap trackers.
      _reset();
      return;
    }

    if (tracker == _firstTap) {
      // A tap up was registered and we were defeated on the gesture arena after that. Reset
      // to clean up the tap trackers.
      _reset();
      return;
    }

    if (_firstTap != null || _secondTap != null) {
      // We have a single or double tap registered, but the tracker isn't related to any of them.
      // It's not clear what this situation means.
      _notifyListenersOfCancellation();
      if (_trackers.isEmpty) {
        _reset();
      }
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _onTapTimeout() {
    // If we weren't reporting gestures as they came in, report
    // the final gesture that took place.
    if (!reportPrecedingGestures) {
      if (_secondTap != null) {
        if (onDoubleTapDown != null) {
          invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(_secondTapDownDetails!));
        }
        if (onDoubleTapUp != null) {
          invokeCallback<void>('onDoubleTapUp', () => onDoubleTapUp!(_secondTapUpDetails!));
        }
        if (onDoubleTap != null) {
          invokeCallback<void>('onDoubleTap', onDoubleTap!);
        }
      } else if (_firstTap != null) {
        if (onTapDown != null) {
          invokeCallback<void>('onTapDown', () => onTapDown!(_firstTapDownDetails!));
        }
        if (onTapUp != null) {
          invokeCallback<void>('onTapUp', () => onTapUp!(_firstTapUpDetails!));
        }
        if (onTap != null) {
          invokeCallback<void>('onTap', onTap!);
        }
      }
    }

    if (onTimeout != null) {
      invokeCallback<void>('onTimeout', onTimeout!);
    }

    _reset();
  }

  void _reset() {
    _stopTapTimer();
    if (_secondTap != null) {
      if (_trackers.isNotEmpty) {
        _notifyListenersOfCancellation();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _secondTap!;
      _secondTap = null;
      _reject(tracker);
      GestureBinding.instance.gestureArena.release(tracker.pointer);
    }
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) {
        _notifyListenersOfCancellation();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();

    _firstTapDownDetails = null;
  }

  void _registerFirstTap(PointerEvent event, _TapTracker tracker) {
    _startTapTimer();
    _checkUp(event, tracker.initialButtons);
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(PointerEvent event, _TapTracker tracker) {
    _startTapTimer();
    _checkUp(event, tracker.initialButtons);
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _secondTap = tracker;
  }

  void _registerThirdTap(PointerEvent event, _TapTracker tracker) {
    _secondTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(event, tracker.initialButtons);
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
    _tapTimer ??= Timer(kTapTimeout, _onTapTimeout);
  }

  void _stopTapTimer() {
    if (_tapTimer != null) {
      _tapTimer!.cancel();
      _tapTimer = null;
    }
  }

  void _checkUp(PointerEvent event, int buttons) {
    assert(buttons == kPrimaryButton);
    if (_firstTap == null && _secondTap == null) {
      _firstTapUpDetails = TapUpDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(event.pointer),
      );
      if (onTapUp != null && reportPrecedingGestures) {
        invokeCallback<void>('onTapUp', () => onTapUp!(_firstTapUpDetails!));
      }
      if (onTap != null && reportPrecedingGestures) {
        invokeCallback<void>('onTap', onTap!);
      }
    } else if (_firstTap != null && _secondTap == null) {
      _secondTapUpDetails = TapUpDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(event.pointer),
      );
      if (onDoubleTapUp != null && reportPrecedingGestures) {
        invokeCallback<void>('onDoubleTapUp', () => onDoubleTapUp!(_secondTapUpDetails!));
      }
      if (onDoubleTap != null && reportPrecedingGestures) {
        invokeCallback<void>('onDoubleTap', onDoubleTap!);
      }
    } else if (_secondTap != null) {
      if (onTripleTapUp != null) {
        final TapUpDetails details = TapUpDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>('onTripleTapUp', () => onTripleTapUp!(details));
      }
      if (onTripleTap != null) {
        invokeCallback<void>('onTripleTap', onTripleTap!);
      }
    }
  }

  void _notifyListenersOfCancellation() {
    if (_secondTap != null) {
      if (onTripleTapCancel != null) {
        invokeCallback<void>('onTripleTapCancel', onTripleTapCancel!);
      }
      return;
    }

    if (_firstTap != null) {
      if (onDoubleTapCancel != null) {
        invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
      }
      return;
    }

    if (_firstTapDownDetails != null) {
      if (onTapCancel != null) {
        invokeCallback<void>('onTapCancel', onTapCancel!);
      }
      return;
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
    required this.event,
    required this.entry,
    required Duration tapMinTime,
  })  : pointer = event.pointer,
        _initialGlobalPosition = event.position,
        initialButtons = event.buttons,
        _tapMinTimeCountdown = _CountdownZoned(duration: tapMinTime);

  final PointerDownEvent event;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _tapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4 transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _tapMinTimeCountdown.timeout;
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
