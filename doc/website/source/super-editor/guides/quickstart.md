---
title: Super Editor Quickstart
contentRenderers: ["jinja", "markdown"]
---
# Super Editor Quickstart
Super Editor comes with sane defaults to help you get started with an editor experience, quickly. These defaults include support for images, list items, blockquotes, and horizontal rules, as well as selection gestures, and various keyboard shortcuts.

Drop in the default editor and start editing.

## Add <code>super_editor</code> to your project
To use <code>super_editor</code>, add a dependency in your <code>pubspec.yaml</code>.

```yaml
dependencies:
  super_editor: {{ pub.super_editor.version }}
```

## Display an editor
A visual editor first requires a logical editor. A logical editor holds an underlying document, which the user edits, and a composer to manage the user's selection.

Initialize the logical editor.

```dart
class MyApp extends StatefulWidget {
    State<MyApp> createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
    late final Editor _editor;
    late final MutableDocument _document;
    late final MutableDocumentComposer _composer;
    
    void initState() {
        super.initState();
    
        _document = MutableDocument.empty();
    
        _composer = MutableDocumentComposer();
    
        _editor = Editor();
    }
    
    void dispose() {
        _editor.dispose();
        _composer.dispose();
        _document.dispose();
    
        super.dispose();
    }
}
```
    
With the logical pieces ready, you can now display a visual editor. Build a <code>SuperEditor</code> widget and return it from your <code>build()</code> method.
    
```dart
class _MyApp extends State<MyApp> {
    // ...
  
    Widget build(BuildContext context) {
      return SuperEditor(
          editor: _editor,
      );
    }
}
```

That's all it takes to get started with your very own editor. Run your app, tap in the editor, and start typing!

The next step is configuration. Check out the other guides for more help.