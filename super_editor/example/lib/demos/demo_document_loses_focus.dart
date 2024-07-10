import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of an [SuperEditor] widget that can lose focus to a nearby
/// [TextField] to ensure that the [SuperEditor] correctly removes
/// its caret.
class LoseFocusDemo extends StatefulWidget {
  @override
  State<LoseFocusDemo> createState() => _LoseFocusDemoState();
}

class _LoseFocusDemoState extends State<LoseFocusDemo> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createDocument1();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
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
          _buildTextField(),
          Expanded(
            child: SuperEditorDebugVisuals(
              config: const SuperEditorDebugVisualsConfig(
                showFocus: true,
                showImeConnection: true,
              ),
              child: SuperEditor(
                editor: _docEditor,
                inputSource: TextInputSource.ime,
                stylesheet: defaultStylesheet.copyWith(
                  documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
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

MutableDocument _createDocument1() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Document #1'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}
