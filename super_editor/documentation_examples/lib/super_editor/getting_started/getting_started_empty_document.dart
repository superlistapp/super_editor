import 'package:flutter/material.dart';

import 'package:super_editor/super_editor.dart';

/// Example that demonstrates the absolute minimum initialization that a developer must use to
/// display a `SuperEditor` experience.
class GettingStartedEmptyDocumentExample extends StatefulWidget {
  const GettingStartedEmptyDocumentExample({Key? key}) : super(key: key);

  @override
  State<GettingStartedEmptyDocumentExample> createState() => _GettingStartedEmptyDocumentExampleState();
}

class _GettingStartedEmptyDocumentExampleState extends State<GettingStartedEmptyDocumentExample> {
  late final DocumentEditor _editor;

  @override
  void initState() {
    super.initState();

    // The SuperEditor widget requires a `DocumentEditor`, so that user interactions with
    // the SuperEditor widget can edit the document.
    _editor = DocumentEditor(
      // A `DocumentEditor` edits a `Document`. A `MutableDocument` is an in-memory document.
      // `MutableDocument` is the only implementation of `Document` that's available in super_editor,
      // you can implement your own version to support your desired transport format and/or backend.
      document: MutableDocument(nodes: []),
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
}
