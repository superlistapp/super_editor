import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;

import 'core/document/rich_text_document.dart';
import 'core/document/document_editor.dart';
import 'editable_document.dart';

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
      editor: DocumentEditor(
        document: widget.initialDocument,
      ),
      showDebugPaint: widget.showDebugPaint,
    );
  }
}
