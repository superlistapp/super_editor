import 'package:flutter/material.dart';

import 'package:super_editor/super_editor.dart';

/// Example that demonstrates the absolute minimum initialization that a developer must use to
/// display a `SuperReader` experience.
class GettingStartedExample extends StatefulWidget {
  const GettingStartedExample({Key? key}) : super(key: key);

  @override
  State<GettingStartedExample> createState() => _GettingStartedExampleState();
}

class _GettingStartedExampleState extends State<GettingStartedExample> {
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
}
