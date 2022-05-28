<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845431-e83699df-5c6c-4e9c-90fc-c12277cc2f48.png" width="300" alt="Super Editor"><br>
  <span><b>Open source, configurable, extensible text editor and document renderer for Flutter.</b></span><br><br>
</p>

<img src="https://raw.githubusercontent.com/superlistapp/super_editor/main/super_editor/doc/marketing/readme-header.png" width="100%" alt="Super Editor">

`super_editor` was initiated by [Superlist](https://superlist.com) and is being implemented and maintained by the [Flutter Bounty Hunters](https://flutterbountyhunters.com), Superlist, and the contributors.

## Supported Platforms

Super Editor aims to support all platforms. For now, Super Editor supports the following:

**Supported**

Super Editor is actively developed against these platforms.

 * Mac OS
 * Web
 * Android
 * iOS

**Unverified**

These platforms might work, but Super Editor is not developing against them.

 * Windows
 * Linux

## Run the example implementation

Super Editor comes with an example implementation to showcase the core functionality. It also exposes example UI elements on how to interact with the Editor.
It currently supports MacOS and Web and will be expanded along the way, as we will support more platforms. You can run the example editor from the example directory:

```bash
cd example
flutter run -d macos
```

The example implementation is only a proof of concept. Expect separate packages to implement various UIs on top of the editor.


## Display an editor

Display a default text editor with the `SuperEditor` widget:

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        // Display a visual, editable document.
        //
        // A SuperEditor does not include any app bar controls or popup
        // controls. If you want such controls, you need to implement
        // them yourself.
        //
        // The standard editor displays and styles headers, paragraphs,
        // ordered and unordered lists, images, and horizontal rules. 
        // Paragraphs know how to display bold, italics, and strikethrough.
        // Key combinations are provided for bold (cmd+b) and italics (cmd+i).
        return SuperEditor.standard(
            editor: _myDocumentEditor,
        );
    }
}
```

A `SuperEditor` widget requires a `DocumentEditor`, which is a pure-Dart class that's responsible for applying changes to a `Document`. A `DocumentEditor`, in turn, requires a reference to the `Document` that it will alter. Specifically, a `DocumentEditor` requires a `MutableDocument`.

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
        'blockType': header1Attribution,
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

The `SuperEditor` widget can be customized.

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        return SuperEditor.custom(
            editor: _myDocumentEditor,
            selectionStyle: /** INSERT CUSTOMIZATION **/ null,
            stylesheet: defaultStylesheet.copyWith(
                addRulesAfter: [
                    // Add any custom document styles, for example, you might
                    // apply styles to a custom Task node type.
                    StyleRule(
                        const BlockSelector("task"),
                        (document, node) {
                            if (node is! TaskNode) {
                                return {};
                            }

                            return {
                                "padding": const CascadingPadding.only(top: 24),
                            };
                        },
                    )
                ],
            ),
            componentBuilders: [
              ...defaultComponentBuilders,
              // Add any of your own custom builders for document
              // components, e.g., paragraphs, images, list items.
            ],
        );
    }
}
```

If your app requires deeper customization than `SuperEditor` provides, you can construct your own version of the `SuperEditor` widget by using lower level tools within the `super_editor` package.

See the wiki for more information about how to customize an editor experience.
