import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of an [SuperEditor] widget that can lose focus to a nearby
/// [TextField] to ensure that the [SuperEditor] correctly removes
/// its caret.
// TODO: Add widget tests for focus interaction verifications
class LoseFocusDemo extends StatefulWidget {
  @override
  _LoseFocusDemoState createState() => _LoseFocusDemoState();
}

class _LoseFocusDemoState extends State<LoseFocusDemo> {
  late Document _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createDocument1();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildDocSelector(),
          Expanded(
            child: SuperEditor(
              editor: _docEditor,
              stylesheet: defaultStylesheet.copyWith(
                documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSelector() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 48.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'tap to give focus to this TextField',
        ),
      ),
    );
  }
}

Document _createDocument1() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Document #1',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}
