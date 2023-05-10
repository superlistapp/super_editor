import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that allows clients to send a change signal to listeners.
///
/// The difference between [SignalNotifier] and other listenables, like `ValueNotifier`
/// is that [SignalNotifier] doesn't hold a value, it only notifies listener that
/// something has changed.
class SignalNotifier extends ChangeNotifier {
  @override
  // ignore: unnecessary_overrides
  void notifyListeners() {
    super.notifyListeners();
  }
}
