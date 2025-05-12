---
title: Super Editor Quickstart
contentRenderers: ["jinja", "markdown"]
---
# Super Editor Quickstart
Super Editor comes with sane defaults to help you get started with an editor experience, quickly. These defaults include support for images, list items, blockquotes, and horizontal rules, as well as selection gestures, and various keyboard shortcuts.

Drop in the default editor and start editing.

## Add <code>super_editor</code> to your project
To use <code>super_editor</code>, add a dependency in your <code>pubspec.yaml</code>.

Currently, `super_editor` is working on a number of core features. As a result, we have some
unusual guidance for selecting your version of `super_editor`.

If your team is OK with it, we recommend depending on the latest version of `super_editor` on
GitHub.

If your app compiles against Flutter `stable`, add the following `super_editor` dependency:
```yaml
dependencies:
  super_editor:
    git:
      url: https://github.com/superlistapp/super_editor
      path: super_editor
      ref: stable
```

If your app compiles against Flutter `master`, add the following `super_editor` dependency:
```yaml
dependencies:
  super_editor:
    git:
      url: https://github.com/superlistapp/super_editor
      path: super_editor
      ref: main
```

If you'd like more stability than a direct dependency on GitHub, use the latest dev preview build
on Pub. The following is an example - check for the latest pre-release version at
[https://pub.dev/packages/super_editor/versions](https://pub.dev/packages/super_editor/versions)
```yaml
dependencies:
  super_editor: 0.3.0-dev.23
```

The final option, which we don't recommend, is to depend upon the latest standard
version on Pub. This version hasn't been updated in a very long time, but it's available
if you want it.
```yaml
dependencies:
  super_editor: {{ pub.super_editor.version }}
```

## Display an editor
A Super Editor requires two pieces:

1. `Editor`: A logical editor, which includes a `Document` and a `DocumentComposer`.
2. `SuperEditor`: A widget that renders and interacts with the `Editor`.

The following example demonstrates the minimal setup for a Super Editor experience.

```dart
class MyApp extends StatefulWidget {
    State<MyApp> createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
    late final Editor _editor;
    
    void initState() {
        super.initState();
    
        _editor = createDefaultDocumentEditor(
          document: MutableDocument.empty(),
          composer: MutableDocumentComposer(),
        );
    }
    
    void dispose() {
        _editor.dispose();
        super.dispose();
    }

    Widget build(BuildContext context) {
      return SuperEditor(
        editor: _editor,
      );
    }
}
```

That's all it takes to get started with your very own editor. Run your app, tap in the editor, and start typing!

The next step is configuration. Check out the other guides for more help.