import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

/// A clock, which is used by the Super Editor spellcheck system to schedule spellchecks,
/// such as shortly after a use has stopped typing.
///
/// This implementation of a clock exists primarily so that spellcheck delays can be run in
/// widget tests. This clock defaults to using [Timer]s for production performance, however it can be
/// configured to use a [Ticker] and post frame callbacks for testing purposes.
abstract class SpellcheckClock {
  /// Creates a [SpellcheckClock] that monitors time with [Timer]s, which is ideal for production,
  /// so that frames aren't needlessly pumped by something like a [Ticker].
  factory SpellcheckClock.forProduction() {
    return _TimerSpellcheckClock();
  }

  /// Creates a [SpellcheckClock] that simulates time passage with post frame callbacks, and forces frame pumping
  /// with a [Ticker], both of which are important behaviors within widget tests.
  static WidgetTestSpellcheckClock forTesting(TickerProvider tickerProvider, [DateTime? startTime]) {
    return WidgetTestSpellcheckClock(tickerProvider, startTime);
  }

  void dispose();

  /// The current time, according to this [StopwatchClock].
  DateTime get now;

  /// Runs [callback] at the given [time], or as close to it at this [StopwatchClock] can monitor.
  SpellcheckAlarm createAlarm(DateTime time, VoidCallback callback);

  /// Runs [callback] after a delay of [duration], or as close to it as this [StopwatchClock] can monitor.
  SpellcheckTimer createTimer(Duration duration, VoidCallback callback);
}

abstract class SpellcheckAlarm {
  bool get isActive;

  DateTime get time;

  void cancel();
}

abstract class SpellcheckTimer {
  bool get isActive;

  Duration get duration;

  void cancel();
}

/// A [SpellcheckClock] that uses [Timer]s to monitor the passage of time.
class _TimerSpellcheckClock implements SpellcheckClock {
  _TimerSpellcheckClock() : _clock = const Clock();

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  final Clock _clock;

  final _timers = <Timer>{};

  @override
  DateTime get now => _clock.now();

  @override
  SpellcheckAlarm createAlarm(DateTime time, VoidCallback callback) {
    final timeNow = now;
    if (time.compareTo(timeNow) < 0) {
      throw Exception(
        "Tried to schedule a callback for time $time, but the current time has already passed that: $now",
      );
    }

    final timer = Timer(time.difference(timeNow), _createTimerCallback(callback));
    _timers.add(timer);

    return _TimerSpellcheckAlarm(timer, time, _clearExpiredTimers);
  }

  @override
  SpellcheckTimer createTimer(Duration duration, VoidCallback callback) {
    final timer = Timer(duration, _createTimerCallback(callback));
    _timers.add(timer);

    return _TimerSpellcheckTimer(timer, duration, _clearExpiredTimers);
  }

  VoidCallback _createTimerCallback(VoidCallback realCallback) {
    return () {
      _timers.removeWhere((timer) => !timer.isActive);
      realCallback();
    };
  }

  void _clearExpiredTimers() {
    _timers.removeWhere((timer) => !timer.isActive);
  }
}

class _TimerSpellcheckAlarm implements SpellcheckAlarm {
  _TimerSpellcheckAlarm(this._timer, this.time, this._onCancel);

  final Timer _timer;
  final VoidCallback _onCancel;

  @override
  final DateTime time;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() {
    _timer.cancel();
    _onCancel();
  }
}

class _TimerSpellcheckTimer implements SpellcheckTimer {
  _TimerSpellcheckTimer(this._timer, this.duration, this._onCancel);

  final Timer _timer;
  final VoidCallback _onCancel;

  @override
  final Duration duration;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() {
    _timer.cancel();
    _onCancel();
  }
}

/// A [SpellcheckClock] that users a [Ticker] and post frame callbacks to simulate the passage of
/// time, and notify alarms and timers.
///
/// The simulated time in a [WidgetTestSpellcheckClock] moves forward on every Flutter frame, by whatever
/// amount of time is reported by Flutter. In a widget test, these post frame callbacks should report whatever
/// time was specified in a call to `pump()`. Or, if `pumpAndSettle()` is used, each internal pump should report
/// a small passage of time, reflecting a simulated frame time.
///
/// As long as there's at least one registered alarm or timer, this clock also registers a [Ticker] so that
/// Flutter keeps pumping frames. This is important because the simulated time only moves forward as long as Flutter
/// pumps frames, so if frames stop pumping, time stops moving. This [Ticker] start/stop behavior happens
/// automatically within this clock.
///
/// ## Manually Stopping the Ticker
/// There's an edge case in tests where a developer might need to explicitly turn off the [Ticker] in this
/// clock. Consider the following test code, which types a character and then verifies that spell check only
/// runs after a delay:
///
///     await tester.insertImeText("F");
///     expect(spellchecker.lastSubmission, null);
///
///     await tester.pump(const Duration(seconds: 1));
///     expect(spellchecker.lastSubmission, "F");
///
/// In the example above, we want to make sure that spell check doesn't run immediately after
/// inserting "F". Instead, we expect spell check to run a second later. Therefore, within the spell
/// check system is a [SpellcheckClock] that's waiting for one second to pass.
///
/// But the call to `insertImeText()` includes a call to `pumpAndSettle()`. Because of the
/// [WidgetTestSpellcheckClock], `pumpAndSettle()` will keep pumping over and over until one second
/// of simulated time has passed, then run spell check, then return. As a result, we can't verify
/// that spell check **didn't** run immediately, because the `pumpAndSettle()` didn't return until
/// after running the spell check timer.
///
/// To work around these situations where `pumpAndSettle()` is outside your control, this clock
/// has [pauseAutomaticFramePumping] and [resumeAutomaticFramePumping]. When paused, this clock stops
/// pumping frames with its [Ticker]. As a result, calls to `pumpAndSettle()` aren't held up by any
/// alarms or timers. When the immediate test expectations are done, calling [resumeAutomaticFramePumping]
/// will once again start pumping frames with its [Ticker], continuing as before.
///
/// When this clock pauses its [Ticker], it still listens to post frame callbacks. Therefore, calls to
/// `pumpAndSettle()` and `pump()` will continue to move the simulated time forward.
class WidgetTestSpellcheckClock implements SpellcheckClock {
  /// Creates a [SpellcheckClock] that begins with a [startTime] and then adds time to it for every frame
  /// that Flutter pumps in a test.
  ///
  /// The amount of time added to this clock in a given frame is equal to whatever frame time Flutter reports
  /// to a post frame callback.
  WidgetTestSpellcheckClock(TickerProvider tickerProvider, [DateTime? startTime]) : _tickerProvider = tickerProvider {
    _startTime = startTime ?? DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isFramePumpingPaused = true;
    _ticker?.dispose();
    _tickerAlarmsAndTimers.clear();
  }

  var _isDisposed = false;

  /// The simulated time when this clock was created.
  ///
  /// For example, a test might want to always begin at 9PM on June 2nd. That would be the [_startTime].
  late final DateTime _startTime;

  /// The epoch timestamp reported by Flutter on our very first frame, which is then used to
  /// calculate elapsed time from that point forward.
  Duration? _frameReferenceTime;

  /// The simulated duration since the creation of this clock, which is calculated by taking the latest
  /// Flutter epoch timestamp from a post frame callback, and subtracting [_frameReferenceTime].
  var _elapsedTime = Duration.zero;

  final TickerProvider? _tickerProvider;
  Ticker? _ticker;
  var _isFramePumpingPaused = false;

  final _tickerAlarmsAndTimers = <_WidgetTestSpellcheckTimeEvent>{};

  /// The current time, according to this [StopwatchClock].
  @override
  DateTime get now => _startTime.add(_elapsedTime);

  /// Runs [callback] at the given [time], or as close to it at this [StopwatchClock] can monitor.
  @override
  SpellcheckAlarm createAlarm(DateTime time, VoidCallback callback) {
    final timeNow = now;
    if (time.compareTo(timeNow) < 0) {
      throw Exception(
        "Tried to schedule a callback for time $time, but the current time has already passed that: $now",
      );
    }

    _ticker ??= _tickerProvider!.createTicker(_onTick);

    final alarm = _WidgetTestSpellcheckTimeEvent.alarm(
      time,
      callback,
      _clearExpiredAlarmsAndTimers,
    );
    _tickerAlarmsAndTimers.add(alarm);

    _startPumpingFramesIfNeeded();

    return alarm;
  }

  /// Runs [callback] after a delay of [duration], or as close to it as this [StopwatchClock] can monitor.
  @override
  SpellcheckTimer createTimer(Duration duration, VoidCallback callback) {
    _ticker ??= _tickerProvider!.createTicker(_onTick);

    final timer = _WidgetTestSpellcheckTimeEvent.timer(
      now,
      duration,
      callback,
      _clearExpiredAlarmsAndTimers,
    );
    _tickerAlarmsAndTimers.add(timer);

    _startPumpingFramesIfNeeded();

    return timer;
  }

  void _clearExpiredAlarmsAndTimers() {
    _tickerAlarmsAndTimers.removeWhere((timeEvent) => !timeEvent.isActive);
  }

  /// Stops this clock from scheduling more frames, even if alarms and timers are scheduled.
  ///
  /// Pausing frames is useful in situations where a `pumpAndSettle()` is unavoidable, but you
  /// don't want this clock to keep pumping frames until the alarms and timers go off.
  void pauseAutomaticFramePumping() {
    _isFramePumpingPaused = true;
    if (true != _ticker?.isActive) {
      return;
    }

    _ticker!.stop();
  }

  /// Starts pumping frames again, after an earlier call to [pauseAutomaticFramePumping].
  ///
  /// Only starts pumping frames if at least one alarm or timer is pending.
  void resumeAutomaticFramePumping() {
    _isFramePumpingPaused = false;
    if (_ticker == null || _ticker!.isActive || _tickerAlarmsAndTimers.isEmpty) {
      return;
    }

    _ticker!.start();
  }

  void _startPumpingFramesIfNeeded() {
    if (!_isFramePumpingPaused && _ticker != null && !_ticker!.isActive && _tickerAlarmsAndTimers.isNotEmpty) {
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsedTime) {
    // No-op: The Ticker only ticks to ensure that `pumpAndSettle()` keeps running when
    //        we have outstanding alarms and timers.
  }

  void _onFrame(Duration timeStamp) {
    if (_frameReferenceTime == null) {
      _frameReferenceTime = timeStamp;
    } else {
      _elapsedTime += timeStamp - _frameReferenceTime!;
    }

    // Run all alarms and timers that have reached their goal time.
    final nowTime = now;
    final toRemove = <_WidgetTestSpellcheckTimeEvent>{};
    final alarmsAndTimersCopy = Set.from(_tickerAlarmsAndTimers);
    for (final alarmOrTimer in alarmsAndTimersCopy) {
      if (alarmOrTimer.time.compareTo(nowTime) <= 0) {
        alarmOrTimer.execute();
        toRemove.add(alarmOrTimer);
      }
    }

    // Remove all expired alarms and timers.
    _tickerAlarmsAndTimers.removeAll(toRemove);

    // If we have no more alarms or timers waiting, then stop the ticker, so that
    // calls to `pumpAndSettle()` can finish.
    if (_tickerAlarmsAndTimers.isEmpty) {
      _ticker?.stop();
    }

    if (!_isDisposed) {
      // Always register another post frame callback. This won't cause a frame to be scheduled,
      // but it ensures that we're made aware of the next frame, whenever it arrives.
      //
      // In our simulated time logic, we add Flutter's reported frame time to the current time. This
      // is what causes our internal simulated time to move forward. By doing this on every frame, we
      // ensure that our simulated time increases on every frame, which should eventually trigger any
      // pending alarms and/or timers, even when `pumpAndSettle()` is called.
      //
      // This automatic time increase should also tend to keep the simulated time in line with other
      // simulated timing in tests. Without this, other aspects of test might `pump()` some amount of
      // time into the future, while our simulated time remains in the past. While we can't expect this
      // clock to magically match other unrelated clocks in a widget test, it's desirable that this clock
      // roughly move forward at a similar rate to other clocks.
      WidgetsBinding.instance.addPostFrameCallback(_onFrame);
    }
  }
}

class _WidgetTestSpellcheckTimeEvent implements SpellcheckAlarm, SpellcheckTimer {
  _WidgetTestSpellcheckTimeEvent.alarm(DateTime alarmTime, this._onAlarmOrTimer, this._onCancel) {
    _startTime = DateTime.now();
    duration = alarmTime.difference(_startTime);
  }

  _WidgetTestSpellcheckTimeEvent.timer(this._startTime, this.duration, this._onAlarmOrTimer, this._onCancel) {
    time = _startTime.add(duration);
  }

  late final DateTime _startTime;
  final VoidCallback _onAlarmOrTimer;
  final VoidCallback _onCancel;
  var _isActive = true;

  @override
  late final DateTime time;

  @override
  late final Duration duration;

  @override
  bool get isActive => _isActive;

  void execute() {
    _onAlarmOrTimer();
    _isActive = false;
  }

  @override
  void cancel() {
    _isActive = false;
    _onCancel();
  }

  @override
  String toString() => "[_WidgetTestSpellcheckTimeEvent] - start: $_startTime, alarm time: $time ($hashCode)";
}
