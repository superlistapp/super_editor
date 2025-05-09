import 'dart:async';

import 'package:flutter/scheduler.dart';

class TimerProvider {
  const TimerProvider();

  Timer createTimer(Duration duration, VoidCallback callback) => Timer(duration, callback);
}

class TickerTimerProvider implements TimerProvider {
  TickerTimerProvider(this._tickerProvider);

  final TickerProvider _tickerProvider;

  @override
  Timer createTimer(Duration duration, VoidCallback callback) {
    return TickerTimer(_tickerProvider, duration, callback);
  }
}

class TickerTimer implements Timer {
  TickerTimer(TickerProvider tickerProvider, this._duration, this._callback) {
    _ticker = tickerProvider.createTicker(_onTick)..start();
  }

  late final Ticker _ticker;
  final Duration _duration;
  final VoidCallback _callback;

  var _isWaiting = true;
  var _isCanceled = false;

  @override
  void cancel() {
    _isCanceled = true;
    _ticker.stop();
  }

  @override
  bool get isActive => _isWaiting && !_isCanceled;

  @override
  int get tick => _isWaiting ? 0 : 1; // <- we don't currently support a period version.

  void _onTick(Duration elapsedTime) {
    if (elapsedTime < _duration) {
      return;
    }

    _isWaiting = false;
    if (_isCanceled) {
      return;
    }

    // We've triggered the Timer duration. Executed the callback.
    _callback();
  }
}
