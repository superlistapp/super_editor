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