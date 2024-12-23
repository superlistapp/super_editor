---
title: Unified API
navOrder: 1
contentRenderers:
  - jinja
  - markdown
---
The `super_keyboard` plugin includes something called a "unified API". A unified
API is a "lowest common denominator" API, which applies equally to all supported
platforms. In this case, those platforms are Android and iOS.

Unified APIs are useful when you want access to functionality that works the
same way across platforms, and you don't care about any platform differences.

In `super_keyboard`, the unified API is defined in the `SuperKeyboard` class.
The `SuperKeyboard` class is a singleton. It can be accessed from anywhere in
your code.

```dart
final superKeyboard = SuperKeyboard.instance;
```

You can listen directly to `SuperKeyboard` for keyboard state changes:

{{ components.codeSampleDirectListening() }}

If you only care about the keyboard state within a widget subtree, you can
build a subtree every time the keyboard state changes, by using the provided
builder:

{{ components.codeSampleBuilder() }}