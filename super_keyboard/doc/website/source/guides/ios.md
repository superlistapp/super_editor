---
title: Super Keyboard iOS
navOrder: 2
---
This guide describes details about the iOS-specific Super Keyboard
capabilities. If you don't care about specific platforms, use the
[unified API](/guides/unified-api).

If you care about the underlying platform, then you probably care about
the platform-specific details. This guide begins by describing how keyboards
work on iOS, and how their state is communicated to an app. After that,
this guide describes the Flutter APIs that are made available by `super_keyboard`
to listen and query that state.

## Keyboards on iPhone
Software keyboards on an iPhone operate in a fairly obvious manner. The
keyboard is mounted to the bottom of the screen. It animates open, and
animates closed.

<img src="/images/ios/iphone-keyboards.png">

iOS notifies apps when the keyboard is about to open, did open, is about 
to close, and did close.

## Keyboards on iPad
Software keyboards on an iPad are more complicated than an iPhone. The
keyboard on an iPad has three modalities:

 * Mounted: Like an iPhone.
 * Minimized: Replaced with a little bar at the bottom of the screen.
 * Floating: Small keyboard that can be dragged around the screen.

The `super_keyboard` plugin only reports information about the mounted
and minimized toolbars.

<img src="/images/ios/ipad-keyboards.png">

<div class="warning">
<p><b>WARNING:</b> We've discovered, empirically, that the keyboard notifications are not always
sent in the expected order, or at the expected time.</p>

<p>For example: A text field has focus, and the iPad keyboard is minimized to
a small bar. The user then taps outside the text field to close the keyboard.
The minimized keyboard fades out, and only after completely fading away does
iOS send the `keyboardWillHideNotification`. That notification should have
been sent before the minimized keyboard began to fade out. But it was sent after.
This is likely a bug in iOS, and there may be other similar bugs.</p>
</div>

## How iOS Reports Keyboard State
iOS sends explicit notifications when the software keyboard changes
state.

```swift
// Opening.
NotificationCenter.default.addObserver(
  self, 
  selector: #selector(keyboardWillShow(_:)), 
  name: UIResponder.keyboardWillShowNotification, 
  object: nil
)
NotificationCenter.default.addObserver(
  self, 
  selector: #selector(keyboardDidShow(_:)), 
  name: UIResponder.keyboardDidShowNotification, 
  object: nil
)
    
// Closing.
NotificationCenter.default.addObserver(
  self, 
  selector: #selector(keyboardWillHide(_:)), 
  name: UIResponder.keyboardWillHideNotification, 
  object: nil
)
NotificationCenter.default.addObserver(
  self, 
  selector: #selector(keyboardDidHide(_:)), 
  name: UIResponder.keyboardDidHideNotification, 
  object: nil
)
```

Each iOS keyboard notification is forwarded directly into Flutter. You
can register listeners for each of the standard iOS notifications:

```dart
final SuperKeyboardIOSListener _myIOSListener = MyIOSListener();

void startListeningToKeyboardState() {
  SuperKeyboardIOS.instance.state.addListener(_myIOSListener);
}

void stopListeningToKeyboardState() {
  SuperKeyboardIOS.instance.state.removeListener(_myIOSListener);
}

class MyIOSListener implements SuperKeyboardIOSListener {
  void onKeyboardWillShow() {
    // TODO:Do something before the keyboard opens.
  }
  
  void onKeyboardDidShow() {
    // TODO:Do something after the keyboard opened.
  }
  
  void onKeyboardWillHide() {
    // TODO:Do something before the keyboard closes.
  }
  
  void onKeyboardDidHide(){
    // TODO:Do something after the keyboard closed.
  }
}
```

## Widget Builder Notifications
To build a subtree every time the keyboard state changes, you can use
an iOS-specific builder:

```dart
@override
Widget build(BuildContext context) {
  return SuperKeyboardIOSBuilder(
    builder: (builderContext, keyboardState) {
      return Center(
        child: Text("Keyboard state: $keyboardState"),
      );
    }
  );
}
```

If all you need is a builder, there's no real benefit to using a `SuperKeyboardIOSBuilder`
over a unified `SuperKeyboardBuilder`. The iOS version is provided in case users want
to exclusively choose iOS integration.

## Keyboard Height
iOS explicitly reports keyboard state changes, and it explicitly reports
the final size of the keyboard. But iOS doesn't report the actual keyboard
size as it opens and closes.

We haven't figured out how to correctly poll or predict actual keyboard
height. Therefore, at this time, the iOS implementation doesn't report a
keyboard height.

For now, to query the keyboard height on iOS, use Flutter's `MediaQuery`:

```dart
@override
Widget build(BuildContext context) {
  final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
  
  // TODO: Do something with the keyboard height.
  return const SizedBox();
}
```
