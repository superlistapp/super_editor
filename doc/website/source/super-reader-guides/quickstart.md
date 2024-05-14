---
title: Super Reader Quickstart
contentRenderers: ["jinja", "markdown"]
---
# Super Reader Quickstart
Super Reader comes with sane defaults to help you get started with a reading experience, quickly. These defaults include support for images, list items, blockquotes, and horizontal rules, as well as selection gestures, and various keyboard shortcuts.

Drop in the default reader and start viewing documents.

## Add <code>super_editor</code> to your project

To use <code>SuperReader</code>, add a dependency in your <code>pubspec.yaml</code>.

```yaml
dependencies:
  super_editor: {{ pub.super_editor.version }}
```

## Display a reader

A `SuperReader` requires a `Document` to be displayed. Optionally, provide a `ValueNotifier` to change the underlying selection, or to listen for selection changes.

Initialize the `Document` and the selection notifier.

```dart
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _document = MutableDocument.empty();
  final _selection = ValueNotifier<DocumentSelection?>(null);
}
```

Then, build a `SuperReader` widget and return it from your `build()` method.

```dart
class _MyApp extends State<MyApp> {
  // ...

  Widget build(BuildContext context) {
    return SuperReader(
      document: _document,
      selection: _selection,
    );
  }
}
```
