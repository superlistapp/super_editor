---
title: Super Keyboard Android
navOrder: 3
---
This guide describes details about the Android-specific Super Keyboard
capabilities. If you don't care about specific platforms, use the
[unified API](/guides/unified-api).

If you care about the underlying platform, then you probably care about
the platform-specific details. This guide begins by describing how keyboards
work on Android, and how their state is communicated to an app. After that,
this guide describes the Flutter APIs that are made available by `super_keyboard`
to listen and query that state.

## Keyboards on Phones
Through most of Android's history, the software keyboard behaved in a basic
way. It was mounted to the bottom of the screen, and it could open and close.

Today, Android has added the concept of "scribbling" to enter text. In this
case the keyboard is replaced by a small toolbar on the side of the window. It's
also possible that some versions of Android choose to show a different looking
toolbar in some other location.

TODO: diagram of keyboard opening and closing, and scribble

The `super_keyboard` plugin only reports details about the mounted keyboard.

## Keyboards on Tablets
TODO

## How Android Reports Keyboard State
Android doesn't send explicit notifications about keyboard changes. Instead,
We need to listen to two different notifications to infer when the keyboard
changes state.

### New Window Inset Notifications
Android sends notifications when the window insets change. The keyboard is
part of those insets. Android explicitly provides a query for the insets that
tells the app whether the keyboard is visible or not.

```kotlin
override fun onApplyWindowInsets(v: View, insets: WindowInsetsCompat): WindowInsetsCompat {
  val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())

  // Note: We only identify opening/closing here. The opened/closed completion
  //       is identified by the window insets animation callback.
  if (imeVisible && keyboardState != KeyboardState.Opening && keyboardState != KeyboardState.Open) {
    channel.invokeMethod("keyboardOpening", null)
    keyboardState = KeyboardState.Opening
  } else if (!imeVisible && keyboardState != KeyboardState.Closing && keyboardState != KeyboardState.Closed) {
    channel.invokeMethod("keyboardClosing", null)
    keyboardState = KeyboardState.Closing
  }

  return insets
}
```

The `onApplyWindowInsets` can only dependably tell us when the keyboard starts
opening and closing. When that happens, the `super_keyboard` plugin sends those
messages to Flutter.

### Window Insets Animation
Android animates window insets. Android reports the phases of those
animations to apps that are interested. The `super_keyboard` plugin
listens to those animations to determine when the keyboard becomes
fully open, or fully closed. The `super_keyboard` plugin also uses
those notifications to report the keyboard height as it animates.

```kotlin
ViewCompat.setWindowInsetsAnimationCallback(
  mainView!!,
  object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {
    override fun onPrepare(animation: WindowInsetsAnimationCompat) {}

    override fun onStart(
      animation: WindowInsetsAnimationCompat,
      bounds: WindowInsetsAnimationCompat.BoundsCompat
    ): WindowInsetsAnimationCompat.BoundsCompat { return bounds; }

    override fun onProgress(
      insets: WindowInsetsCompat,
      runningAnimations: MutableList<WindowInsetsAnimationCompat>
    ): WindowInsetsCompat {
      val imeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom

      channel.invokeMethod("onProgress", mapOf(
        "keyboardHeight" to imeHeight,
      ))

      return insets
    }

    override fun onEnd(
      animation: WindowInsetsAnimationCompat
    ) {
      // Report whether the keyboard has fully opened or fully closed.
      if (keyboardState == KeyboardState.Opening) {
        channel.invokeMethod("keyboardOpened", null)
      } else if (keyboardState == KeyboardState.Closing) {
        channel.invokeMethod("keyboardClosed", null)
      }
    }
  }
```

## Widget Builder Notifications
To build a subtree every time the keyboard state changes, you can use
an Android-specific builder:

```dart
@override
Widget build(BuildContext context) {
  return SuperKeyboardAndroidBuilder(
    builder: (builderContext, keyboardState) {
      return Center(
        child: Text("Keyboard state: $keyboardState"),
      );
    }
  );
}
```

If all you need is a builder, there's no real benefit to using a `SuperKeyboardAndroidBuilder`
over a unified `SuperKeyboardBuilder`. The Android version is provided in case users want
to exclusively choose Android integration.
