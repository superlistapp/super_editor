---
title: Super Editor Quickstart
contentRenderers: ["jinja", "markdown"]
---

# Super Editor Quickstart

Super Editor comes with sane defaults to help you get quickly started with an editor experience. These defaults include support for images, list items, blockquotes, and horizontal rules, as well as selection gestures and various keyboard shortcuts.

Drop in the default editor and start editing.

## Add <code>super_editor</code> to your project

To use <code>super_editor</code>, add a dependency in your <code>pubspec.yaml</code>.

```yaml
dependencies:
  super_editor: ^0.3.0
```

## Display an editor

Super Editor is both the visual editor that users see and interact with, as well as the logical editor that handles those interactions behind the scenes. 

Start by initializing the logical editor and its required components:

```dart
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

class MyEditorPage extends StatefulWidget {
  const MyEditorPage({super.key});

  @override
  State<MyEditorPage> createState() => _MyEditorPageState();
}

class _MyEditorPageState extends State<MyEditorPage> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  @override
  void initState() {
    super.initState();
    _document = MutableDocument.empty();
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    _document.dispose();
    super.dispose();
  }

  // More to come...
}
```

Here are a few points to note:

- The logical editor holds an underlying document and a composer to manage the user's selection.
- The document, <code>MutableDocument</code>, contains a list of nodes for content like text, images, and so on, which users can edit. In this case, you're starting with an empty list.
- <code>createDefaultDocumentEditor</code> is a convenience method from <code>super_editor</code> to give you some of those sane defaults mentioned earlier.
    
With the logical pieces ready, you can now display a visual editor. Add a <code>build()</code> method that returns a <code>SuperEditor</code> widget with its logical editor:
    
```dart
@override
Widget build(BuildContext context) {
  return SuperEditor(
    editor: _editor,
  );
}
```

That's all it takes to get started with your very own editor. Run your app, tap in the editor, and start typing!

Check out the other guides for more help.