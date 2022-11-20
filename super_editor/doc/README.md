<p align="center"><img src="images/super_editor_logo.png" width="350"></p>

# Welcome to Super Editor
Super Editor is a toolkit for building custom document editing and document reading experiences.

The `SuperEditor` widget is a highly configurable document editing experience.

The `SuperReader` widget is a highly configurable document reading experience.

We don't believe in monolithic solutions, so if `SuperEditor` and `SuperReader` aren't the right tool for your document editing experience, we encourage you to use the tools and patterns within Super Editor to build your own custom experiences.

Super Editor is strictly a user interface tool. You can use Super Editor with any document transport format, any database, and any server. Some Super Editor customers have even implemented multiplayer document editing.

### Super Text Field
The Super Editor project also includes a custom text field implementation, called `SuperTextField`. Learn more in the [SuperTextField guides]().

---

## Developers and Funders
Super Editor was started as a collaboration between [Superlist]() and the [Flutter Bounty Hunters](). Superlist is the primary funder for Super Editor, with additional funding provided by [Turtle](), [Clearful]() and others. The Flutter Bounty Hunters build and maintain Super Editor.

---

## How Super Editor works
When you're ready to understand the big picture, check out the [Super Editor design docs]().

---

<img src="images/header.png">

## Getting Started
Add `super_editor` as a project dependency.

```yaml
dependencies:
  super_editor: ^0.2.3
```

To select a version other than the latest, check `super_editor`'s [changelog](https://pub.dev/packages/super_editor/changelog).

### Super Editor
To display a `SuperEditor` experience, initialize a `DocumentEditor` and pass it to a `SuperEditor` widget.

```dart
late final DocumentEditor _editor;

@override
void initState() {
  super.initState();

  // The SuperEditor widget requires a `DocumentEditor`, so that user interactions with
  // the SuperEditor widget can edit the document.
  _editor = DocumentEditor(
    // In practice, your initial document structure probably comes from your server, or a database.
    // For the sake of this example, we instantiate a `MutableDocument` with hard-coded nodes.
    document: MutableDocument(
      nodes: [
        ParagraphNode(
          // A unique ID for this node.
          id: DocumentEditor.createNodeId(),
          // The content within the header, possibly including style attributions.
          text: AttributedText(text: "Hello, World!"),
          metadata: {
            // Apply a "Header 1" attribution to all text in this paragraph
            "blockType": header1Attribution,
          },
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
              text:
                  "This document was initialized with content before it was rendered to the user. Now, you can edit the content of this document."),
        ),
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    // `SuperEditor` is a highly configurable document editor. This is the simplest possible SuperEditor
    // configuration. We pass a `DocumentEditor`, which `SuperEditor` uses internally to alter the
    // content of a `Document`.
    //
    // You should feel free to assemble your own implementation of a document editor, but first you
    // should see if you can configure `SuperEditor` to meet your needs. Check other examples to see
    // all the ways that you can configure `SuperEditor`.
    body: SuperEditor(
      editor: _editor,
    ),
  );
}
```

Take your Super Editor experience to the next level by visiting the [Super Editor guides](super-editor-guides/README)

### Super Reader
To display a `SuperReader` experience, initialize a `Document` and pass it to a `SuperReader` widget.

```dart
late final Document _document;

@override
void initState() {
  super.initState();

  // In practice, your document structure probably comes from your server, or a database.
  // For the sake of this example, we instantiate a `MutableDocument` with hard-coded nodes.
  _document = MutableDocument(
    nodes: [
      ParagraphNode(
        // A unique ID for this node.
        id: DocumentEditor.createNodeId(),
        // The content within the header, possibly including style attributions.
        text: AttributedText(text: "Hello, World!"),
        metadata: {
          // Apply a "Header 1" attribution to all text in this paragraph
          "blockType": header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
            text:
                "This document is displayed in a SuperReader widget. SuperReader is a read-only document experience. It's like SuperEditor, minus the editing capabilities."),
      ),
    ],
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    /// `SuperReader` is a highly configurable document reading experience. This is the simplest possible configuration
    /// of a `SuperReader`.
    ///
    /// Check other examples to see how to configure a `SuperReader`. Most `SuperEditor` configurations are also
    /// available on `SuperReader`. If you can't find a relevant `SuperReader` example, check the `SuperEditor`
    /// examples, too.
    body: SuperReader(
      document: _document,
    ),
  );
}
```

Take your Super Reader experience to the next level by visiting the [Super Reader guides]()