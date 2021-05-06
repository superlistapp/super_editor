# Super Editor

Super Editor is an open source, configurable, extensible text editor and document renderer for Flutter apps.

`super_editor` was initiated by [Superlist](https://superlist.com) and is being implemented and maintained by [SuperDeclarative!](https://superdeclarative.com), Superlist, and the contributors.

## Supported Platforms

Super Editor aims to support all platforms. For now, Super Editor supports the following:

**Supported**

Super Editor is actively developed against these platforms.

 * Mac OS
 * Web

**Unverified**

These platforms might work, but Super Editor is not developing against them.

 * Windows
 * Linux

**Not Yet Supported**

These platforms are explicitly not supported at this time because mobile input is fundamentally different than desktop input. 

 * Android
 * iOS

## Display an editor

Display a default text editor with the `Editor` widget:

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        // Display a visual, editable document.
        //
        // An Editor does not include any app bar controls or popup
        // controls. If you want such controls, you need to implement
        // them yourself.
        //
        // The standard editor displays and styles headers, paragraphs,
        // ordered and unordered lists, images, and horizontal rules. 
        // Paragraphs know how to display bold, italics, and strikethrough.
        // Key combinations are provided for bold (cmd+b) and italics (cmd+i).
        return Editor.standard(
            editor: _myDocumentEditor,
        );
    }
}
```

An `Editor` widget requires a `DocumentEditor`, which is a pure-Dart class that's responsible for applying changes to a `Document`. A `DocumentEditor`, in turn, requires a reference to the `Document` that it will alter. Specifically, a `DocumentEditor` requires a `MutableDocument`.

```dart
// A MutableDocument is an in-memory Document. Create the starting
// content that you want your editor to display.
//
// Your MutableDocument does not need to contain any content/nodes.
// In that case, your editor will initially display nothing.
final myDoc = MutableDocument(
  nodes: [
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is a header'),
      metadata: {
        'blockType': 'header1',
      },
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text:'This is the first paragraph'),
    ),
  ],
);

// With a MutableDocument, create a DocumentEditor, which knows how
// to apply changes to the MutableDocument.
final docEditor = DocumentEditor(document: myDoc);

// Next: pass the docEditor to your Editor widget.
```

The `Editor` widget can be customized.

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        return Editor.custom(
            editor: _myDocumentEditor,
            textStyleBuilder: /** INSERT CUSTOMIZATION **/ null,
            selectionStyle: /** INSERT CUSTOMIZATION **/ null,
            keyboardActions: /** INSERT CUSTOMIZATION **/ null,
            componentBuilders: /** INSERT CUSTOMIZATION **/ null,
        );
    }
}
```

If your app requires deeper customization than `Editor` provides, you can construct your own version of the `Editor` widget by using lower level tools within the `super_editor` package.

See the wiki for more information about how to customize an editor experience.

## Display a document renderer

TODO: implement static document rendering