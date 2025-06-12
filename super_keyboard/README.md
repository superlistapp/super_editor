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
    builder: (context, keyboardGeometry) {
      // TODO: do something with the keyboard state and size.
      return const SizedBox();
    }
  );
}
```

Directly listen for changes to the keyboard state:
```dart
void startListeningToKeyboardState() {
  SuperKeyboard.instance.geometry.addListener(_onKeyboardChange);
}

void stopListeningToKeyboardState() {
  SuperKeyboard.instance.geometry.removeListener(_onKeyboardChange);
}

void _onKeyboardChange(MobileWindowGeometry geometry) {
  // TODO: do something with the new keyboard state and size.
}
```

**Note:** This plugin is limited by the APIs of the underlying platform. For example,
iOS does not provide any direct means of querying the keyboard height as it opens and
closes. Therefore, on iOS, while this plugin does notify clients about the keyboard
opening and closing, the reported keyboard height during those transitions won't match
the visual keyboard on screen.

Activate logs:
```dart
SuperKeyboard.startLogging();
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