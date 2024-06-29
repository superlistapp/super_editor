import 'package:feather/deltas/deltas_display.dart';
import 'package:feather/editor/editor.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

class FeatherApp extends StatelessWidget {
  const FeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Feather',
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Editor _editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;

  bool _showDeltas = true;

  @override
  void initState() {
    super.initState();

    _document = createDocumentWithVaryingStyles();
    // _document = createStandardSuperEditorDocument();
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        (request) => request is ConvertTextBlockToFormatRequest //
            ? ConvertTextBlockToFormatCommand(request.blockFormat)
            : null,
        (request) => request is ToggleInlineFormatRequest //
            ? ToggleInlineFormatCommand(request.inlineFormat)
            : null,
        (request) => request is ToggleTextBlockFormatRequest //
            ? ToggleTextBlockFormatCommand(request.blockFormat)
            : null,
        (request) => request is ClearSelectedStylesRequest //
            ? const ClearSelectedStylesCommand()
            : null,
        ...defaultRequestHandlers,
      ],
      reactionPipeline: List.from(defaultEditorReactions),
    );

    _editor.addListener(FunctionalEditListener((changeList) {
      if (changeList.whereType<DocumentEdit>().isEmpty) {
        return;
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Row(
          children: [
            Expanded(
              child: FeatherEditor(
                  editor: _editor,
                  onShowDeltasChange: (bool showDeltas) {
                    setState(() {
                      _showDeltas = showDeltas;
                    });
                  }),
            ),
            if (_showDeltas) //
              SizedBox(
                width: 400,
                child: DeltasDisplay(editor: _editor),
              ),
          ],
        ),
      ),
    );
  }
}

MutableDocument createDocumentWithVaryingStyles() {
  return deserializeMarkdownToDocument('''# Header 1
This is regular text right below header 1.
## Header 2
This is regular text right below header 1.
### Header 3
#### Header 4
##### Header 5
###### Header 6
Some **bold** text.

> This is a blockquote.

* This is a list item.

```
This is a code block.
```
''');
}

MutableDocument createStandardSuperEditorDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: "1",
        imageUrl: 'https://i.ibb.co/5nvRdx1/flutter-horizon.png',
        expectedBitmapSize: const ExpectedSize(1911, 630),
        metadata: const SingleColumnLayoutComponentStyles(
          width: double.infinity,
          padding: EdgeInsets.zero,
        ).toMetadata(),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Welcome to Super Editor 💙 🚀'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Super Editor is a toolkit to help you build document editors, document layouts, text fields, and more.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Ready-made solutions 📦'),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          'SuperEditor is a ready-made, configurable document editing experience.',
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          'SuperTextField is a ready-made, configurable text field.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Quickstart 🚀'),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('To get started with your own editing experience, take the following steps:'),
      ),
      TaskNode(
        id: Editor.createNodeId(),
        isComplete: false,
        text: AttributedText(
          'Create and configure your document, for example, by creating a new MutableDocument.',
        ),
      ),
      TaskNode(
        id: Editor.createNodeId(),
        isComplete: false,
        text: AttributedText(
          "If you want programmatic control over the user's selection and styles, create a DocumentComposer.",
        ),
      ),
      TaskNode(
        id: Editor.createNodeId(),
        isComplete: false,
        text: AttributedText(
          "Build a SuperEditor widget in your widget tree, configured with your Document and (optionally) your DocumentComposer.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Now, you're off to the races! SuperEditor renders your document, and lets you select, insert, and delete content.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Explore the toolkit 🔎'),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Use MutableDocument as an in-memory representation of a document.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Implement your own document data store by implementing the Document api.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Implement your down DocumentLayout to position and size document components however you'd like.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          "Use SuperSelectableText to paint text with selection boxes and a caret.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Use AttributedText to quickly and easily apply metadata spans to a string.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          "We hope you enjoy using Super Editor. Let us know what you're building, and please file issues for any bugs that you find.",
        ),
      ),
    ],
  );
}
