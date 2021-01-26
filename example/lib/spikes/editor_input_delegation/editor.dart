import 'package:example/spikes/editor_input_delegation/editable_document.dart';
import 'package:flutter/material.dart' hide SelectableText;

import 'editor_layout_model.dart';

class Editor extends StatefulWidget {
  const Editor({
    Key key,
    this.initialDocument,
    this.showDebugPaint = false,
  }) : super(key: key);

  final List<DocDisplayNode> initialDocument;
  final showDebugPaint;

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: EditableDocument(
        initialDocument: widget.initialDocument,
        showDebugPaint: widget.showDebugPaint,
      ),
    );
  }
}
