```dart
@override
Widget build(BuildContext context) {
  return SuperKeyboardBuilder(
    builder: (builderContext, keyboardState) {
      return Center(
        child: Text("Keyboard state: $keyboardState"),
      );
    }
  );
}
```