<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845431-e83699df-5c6c-4e9c-90fc-c12277cc2f48.png" width="300" alt="Super Editor"><br>
  <span><b>Open source, configurable, extensible text editor and document renderer for Flutter.</b></span><br><br>
</p>

<p align="center"><b>Super Editor works with any backend. Plug yours in and go!</b></p><br>

<br>
<hr>
<br>

<p align="left" style="background: gray;">
  <b>A Note on Releases (June, 2024):</b><br>
We've been busy at work on core editor improvements like undo/redo, a stable editor pipeline, and useful editor reactions. These APIs have evolved a lot, so we haven't cut a standard release in a long time. We're still evolving those APIs right now.
  <br><br>
  Rest assured, Super Editor and the other projects in this repo are under regular development. We're still here and working hard.
  <br><br>
  We're now starting to publish developer releases of Super Editor so that the community can see what we've been working on.
  <br><br>
  As a reminder, your project doesn't need to use Pub to use Super Editor. You can depend directly on this GitHub repository. See the repositories top-level README for more details.
</p>

<br>
<hr>
<br>

<img src="https://raw.githubusercontent.com/superlistapp/super_editor/main/super_editor/doc/marketing/readme-header.png" width="100%" alt="Super Editor">
<br> 

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

These platforms probably work, but our verification on these platforms is spotty.

 * Windows
 * Linux

## Run the example implementation

Super Editor comes with an example implementation to showcase the core functionality. It also exposes example UI elements on how to interact with the Editor.
The example app should build and run on any platform. You can run the example editor from the example directory:

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
        // SuperEditor includes default magnifiers and popover toolbars for
        // iOS and Android, but does not include any popovers on desktop.
        // You can add your own, if desired.
        //
        // The standard editor displays and styles headers, paragraphs,
        // ordered and unordered lists, images, and horizontal rules. 
        // Paragraphs know how to display bold, italics, and strikethrough.
        // Key combinations are provided for bold (cmd+b) and italics (cmd+i).
        return SuperEditor(
            document: _document,
            composer: _composer,
            editor: _editor,
        );
    }
}
```

A `SuperEditor` widget requires a `Document`, which holds the rich text content, a `DocumentComposer`, which holds
the user's selection and the currently activated styles, and an `Editor`, which applies changes to the
`Document` and the `Composer`, such as inserting text when the user types.

```dart
class _MyAppState extends State<MyApp> {
    late final MutableDocument _document;
    late final MutableComposer _composer;
    late final Editor _editor;

    @override
    void initState() {
      super.initState();

      // A MutableDocument is an in-memory Document. Create the starting
      // content that you want your editor to display.
      //
      // To start with an empty document, create a MutableDocument with a
      // single ParagraphNode that holds an empty string.
      _document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText('This is a header'),
            metadata: {
              'blockType': header1Attribution,
            },
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText('This is the first paragraph'),
          ),
        ],
      );

      // A DocumentComposer holds the user's selection. Your editor will likely want
      // to observe, and possibly change the user's selection. Therefore, you should
      // hold onto your own DocumentComposer and pass it to your Editor.
      _composer = MutableDocumentComposer();
      
      // With a MutableDocument, create an Editor, which knows how to apply changes 
      // to the MutableDocument.
      _editor = createDefaultDocumentEditor(document: _document, composer: _composer);
    }

    void build(context) {
        return SuperEditor(
            document: _document,
            composer: _composer,
            editor: _editor,
        );
    }
}
```

The `SuperEditor` widget can be customized.

```dart
class _MyAppState extends State<MyApp> {
    void build(context) {
        return SuperEditor(
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
                                Styles.padding: const CascadingPadding.only(top: 24),
                            };
                        },
                    )
                ],
            ),
            componentBuilders: [
              // Add any of your own custom builders for document
              // components, e.g., paragraphs, images, list items.
              ...defaultComponentBuilders,
            ],
        );
    }
}
```

If your app requires deeper customization than `SuperEditor` provides, you can construct your own 
version of the `SuperEditor` widget by using lower level tools within the `super_editor` package.
