import 'package:example/spikes/editor_input_delegation/document/document_editor.dart';
import 'package:example/spikes/editor_input_delegation/document/rich_text_document.dart';
import 'package:example/spikes/editor_input_delegation/editable_document.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;

/// Editor for a `RichTextDocument`.
///
/// An `Editor` places document content within a scrollable and
/// adds any further chrome or overlays that are desired.
class Editor extends StatefulWidget {
  const Editor({
    Key key,
    this.initialDocument,
    this.showDebugPaint = false,
  }) : super(key: key);

  final RichTextDocument initialDocument;
  final showDebugPaint;

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return EditableDocument(
      document: widget.initialDocument,
      editor: DocumentEditor(),
      showDebugPaint: widget.showDebugPaint,
    );
  }
}
