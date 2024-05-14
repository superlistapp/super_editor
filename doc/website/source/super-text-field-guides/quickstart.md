---
title: Super Text Field Quickstart
contentRenderers: ["jinja", "markdown"]
---
# Super Text Field Quickstart
Few steps are required to start using `SuperTextField`.

## Add <code>super_editor</code> to your project
To use <code>SuperTextField</code>, add a dependency in your <code>pubspec.yaml</code>.

```yaml
dependencies:
  super_editor: {{ pub.super_editor.version }}
```

## Display a text field

To display a `SuperTextField` without any decoration, simply return a `SuperTextField` from your build method.

```dart
class MyApp extends StatefulWidget {
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return SuperTextField();
  }
}
```

`SuperTextField` doesn't impose any decoration. An easy way to provide the text field's decoration is to wrap it with a `DecoratedBox`.

```dart
class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
       decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: SuperTextField(),
    );
  }
}               
```

Any widget can be used as the text field's hint. Provide a `hintBuilder` to construct the hint and a `hintBehavior` to configure when the hint should be displayed.

```dart
class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: SuperTextField(
        // ...
        (context) => const Text(
          'enter some text',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        hintBehavior: HintBehavior.displayHintUntilTextEntered,
        // ...
      ),
    );
  }
}
```

## Manage the text field's text

To inspect or modify the text field's text, create an `AttributedTextEditingController` and pass it to `SuperTextField`.

```dart
class MyAppState extends State<MyApp> {
  // ...
  final _controller = AttributedTextEditingController(
    text: AttributedText('My Text'),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: SuperTextField(
        // ...
        textController: _textFieldController,
        // ...
      ),
    );
  }
}
```

Changing the text in the `AttributedTextEditingController` causes the text field to rebuild itself.

## Style the text
`SuperTextField` allows full control over how the text is styled. To customize the style, create a method to resolve the `TextStyle` for a span of text and pass it to `SuperTextField`.

```dart
TextStyle myStyleBuilder(Set<Attribution> attributions) {
  TextStyle textStyle = const TextStyle(
    color: Colors.black,
    fontSize: 14,
  );

  if (attributions.contains(myCustomAttribution)) {
    textStyle = textStyle.copyWith(
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
  }

  // Inspect other attributions.

  return textStyle;
}

/// An attribution that can be applied to portions of the text.
const myCustomAttribution = NamedAttribution('brand');

class MyAppState extends State<MyApp> {
  // ...

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: SuperTextField(
        // ...
        textStyleBuilder: myStyleBuilder,
        // ...
      ),
    );
  }
}
```

## Unfocusing the field when tapping outside

Provide a `FocusNode` to `SuperTextField`.

```dart
class MyAppState extends State<MyApp> {
  // ...
  final FocusNode _focusNode = FocusNode();  
  // ...

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: SuperTextField(
        // ...
        focusNode: _focusNode,
        // ...
      ),
    );
  }
}
```

Wrap `SuperTextField` with a `TapRegion` and provide the same group id to both of them.

```dart
class MyAppState extends State<MyApp> {
  // ...
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: TapRegion(
        groupId: 'my-group',
        child: SuperTextField(
          // ...        
          tapRegionGroupId: 'my-group',
          // ...
        ),
      ),
    );
  }
}
```

Unfocus the text field in the `onTapOutside` callback.

```dart
class MyAppState extends State<MyApp> {
  // ...
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // ...
      child: TapRegion(
        onTapOutside: (_) {
          // Remove focus from text field when the user
          // taps anywhere else.
          _focusNode.unfocus();
        }
        // ...
      ),
    );
  }
}        
```