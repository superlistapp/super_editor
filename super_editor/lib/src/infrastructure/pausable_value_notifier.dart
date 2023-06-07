import 'package:flutter/foundation.dart';

/// A [ValueNotifier], which allows clients to pause new value notifications.
///
/// When paused, the [value] property returns whatever the value was when this
/// [PausableValueNotifier] was paused, regardless of the latest values that was
/// set on this [PausableValueNotifier].
///
/// Pausing notifications is useful when a series of changes might occur in
/// rapid succession, and only the final value is relevant to listeners.
///
/// For example, consider a user's selection in an editor. A single user interaction
/// might result in any number of commands and reactions executing, which might alter
/// the user's selection multiple times within a single frame of execution. None of
/// these intermediate selection values are relevant to the rest of the editor. In fact,
/// if the rest of the editor was notified of these transient selection values, then the
/// rest of the editor might do things that it shouldn't do, and cause the editor to
/// enter an inconsistent state.
///
/// Instead, a [PausableValueNotifier] lets the editor pipeline disable notifications
/// as it runs the pipeline, and then re-enable notifications when all commands and
/// reactions are done executing.
class PausableValueNotifier<T> extends ValueNotifier<T> {
  PausableValueNotifier(T value) : super(value);

  bool _isPaused = false;

  late T _currentValueDuringPause;

  @override
  T get value => _isPaused ? _currentValueDuringPause : super.value;

  @override
  set value(T newValue) {
    if (_isPaused) {
      _currentValueDuringPause = newValue;
    } else {
      super.value = newValue;
    }
  }

  void pauseNotifications() {
    _isPaused = true;
    _currentValueDuringPause = super.value;
  }

  void resumeNotifications() {
    _isPaused = false;
    super.value = _currentValueDuringPause;
  }
}
