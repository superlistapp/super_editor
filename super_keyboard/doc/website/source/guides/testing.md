---
title: Testing
navOrder: 4
contentRenderers:
  - jinja
  - markdown
---
The `super_keyboard` plugin provides testing utilities for apps that use
the unified API (meaning `SuperKeyboard.instance`).

## Simulate a Software Keyboard in Widget Tests
Any app with a widget layout that cares about the keyboard state, probably
cares about those details in widget tests, too. The problem with widget tests
is that they don't run on a real device, so no software keyboard exists during
the test. The `super_keyboard` plugin provides a widget to simulate a software
keyboard.

To simulate a software keyboard mounted to the bottom of the screen, wrap your
test widget tree with a `SoftwareKeyboardHeightSimulator`:

```dart
testWidgets("my widget test", (tester) async {
  await tester.pumpWidget(
    SoftwareKeyboardHeightSimulator(
      tester: tester,
      child: MaterialApp(...),
    ),
  );
});
```

The `SoftwareKeyboardHeightSimulator` widget offers a few properties to
customize its use.

When you tap on a `TextField` in a widget test, or any other widget that
normally opens the keyboard, the `SoftwareKeyboardHeightSimulator` will
send the same plugin messages as the real platforms, and it will add `MediaQuery`
bottom insets to simulate a keyboard that's opening or closing.

### How it Works
When you tap on a `TextField`, or give focus to any similar widget, Flutter
sends a message on a platform channel called "TextInput". For example, Flutter
might send "TextInput.show" to tell the platform to "show the keyboard".

The `SoftwareKeyboardHeightSimulator` intercepts these messages, and reacts
accordingly. When Flutter says "TextInput.show", `SoftwareKeyboardHeightSimulator`
tells all of its listeners that the keyboard changed state to `KeyboardState.opening`,
and it also starts an animation that grows the `MediaQuery` bottom insets, just
like when a real software keyboard appears.

### How to use it
Simulating the software keyboard is primarily intended for layouts that want
to position widgets immediately above the keyboard. By simulating a keyboard
opening and closing, apps can verify that widgets appear at the bottom of the
screen when the keyboard is closed, above the keyboard when it's open, and that
those widgets move up and down with the keyboard as the keyboard opens and closes.