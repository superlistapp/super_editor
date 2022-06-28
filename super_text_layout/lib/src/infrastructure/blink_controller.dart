import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Controls the visibility of something that blinks.
///
/// A [BlinkController] maintains a timer that alters [opacity] based
/// on a [flashPeriod]. The blinking can be enabled or disabled, and
/// the opacity can be immediately reset to opaque with [jumpToOpaque()].
class BlinkController with ChangeNotifier {
  // Controls whether or not all BlinkControllers animate. This is intended
  // to be used by tests to disable animations so that pumpAndSettle() doesn't
  // time out.
  @visibleForTesting
  static bool indeterminateAnimationsEnabled = true;

  BlinkController({
    required TickerProvider tickerProvider,
    Duration flashPeriod = const Duration(milliseconds: 500),
  }) : _flashPeriod = flashPeriod {
    _ticker = tickerProvider.createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  late final Ticker _ticker;
  final Duration _flashPeriod;
  Duration _lastBlinkTime = Duration.zero;

  bool _isBlinkingEnabled = true;
  set isBlinkingEnabled(bool newValue) {
    if (newValue == _isBlinkingEnabled) {
      return;
    }

    _isBlinkingEnabled = newValue;
    if (!_isBlinkingEnabled) {
      stopBlinking();
    }
    notifyListeners();
  }

  bool _isVisible = true;
  double get opacity => _isVisible ? 1.0 : 0.0;

  void startBlinking() {
    if (!indeterminateAnimationsEnabled) {
      // Never animate a blink when the app/test wants to avoid
      // indeterminate animations.
      return;
    }

    _ticker
      ..stop()
      ..start();
    _lastBlinkTime = Duration.zero;
    notifyListeners();
  }

  void stopBlinking() {
    _isVisible = true; // If we're not blinking then we need to be visible
    _ticker.stop();
    notifyListeners();
  }

  /// Make the object completely opaque, and restart the blink timer.
  void jumpToOpaque() {
    stopBlinking();

    if (!_isBlinkingEnabled) {
      return;
    }

    startBlinking();
  }

  void _onTick(Duration elapsedTime) {
    if (elapsedTime - _lastBlinkTime >= _flashPeriod) {
      _blink();
      _lastBlinkTime = elapsedTime;
    }
  }

  void _blink() {
    _isVisible = !_isVisible;
    notifyListeners();
  }
}
