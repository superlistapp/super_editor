import 'package:flutter/material.dart';

import 'package:super_editor/super_editor.dart';

/// Example that demonstrates the absolute minimum initialization that a developer must use to
/// display a `SuperEditor` experience, with a non-empty document.
class GettingStartedWithDocumentExample extends StatefulWidget {
  const GettingStartedWithDocumentExample({Key? key}) : super(key: key);

  @override
  State<GettingStartedWithDocumentExample> createState() => _GettingStartedWithDocumentExampleState();
}

class _GettingStartedWithDocumentExampleState extends State<GettingStartedWithDocumentExample> {
  late final DocumentEditor _editor;

  @override
  void initState() {
    super.initState();

    // In practice, your initial document structure probably comes from your server, or a database.
    // For the sake of this example, we instantiate a `MutableDocument` with hard-coded nodes.
    _editor = DocumentEditor(
      // You can instantiate a `MutableDocument` with `DocumentNode`s so that your document begins with content.
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
      body: SuperEditor(
        editor: _editor,
      ),
    );
  }
}
