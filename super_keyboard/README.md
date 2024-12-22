# Super Keyboard
A plugin that reports keyboard visibility and size.

## Support Platforms
This plugin supports iOS and Android.

## Unified API
For users that don't care about differences between how iOS and Android report
keyboard information, the easiest way to use `super_keyboard` is through the
unified (lowest common denominator) API.

Build a widget subtree based on the keyboard state:
```dart
@override
Widget build(BuildContext context) {
  return SuperKeyboardBuilder(
    builder: (context, keyboardState) {
      // TODO: do something with the keyboard state.
      return const SizedBox();
    }
  );
}
```

Directly listen for changes to the keyboard state:
```dart
void startListeningToKeyboardState() {
  SuperKeyboard.instance.state.addListener(_onKeyboardStateChange);
}

void stopListeningToKeyboardState() {
  SuperKeyboard.instance.state.removeListener(_onKeyboardStateChange);
}

void _onKeyboardStateChange(KeyboardState newState) {
  // TODO: do something with the new keyboard state.
}
```

Activate logs:
```dart
SuperKeyboard.initLogs();
```

## iOS and Android
Platform-specific APIs are also available. The unified `SuperKeyboard` API
delegates to the platform-specific APIs under the hood.

iOS is available in `SuperKeyboardIOS`.

Android is available in `SuperKeyboardAndroid`.

Per-platform APIs are made available because each platform reports keyboard
state and height in different ways. Those reporting methods may, or may not
be compatible with each in general. Also, one platform might report more
keyboard information than the other. We want to provide the maximum information
possible to users, which can't be done with a lowest common denominator API.