import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of an [SuperEditor] widget where the [DocumentEditor] changes.
///
/// This demo ensures that [SuperEditor] state resets where appropriate
/// when its content is replaced.
class SwitchDocumentDemo extends StatefulWidget {
  @override
  State<SwitchDocumentDemo> createState() => _SwitchDocumentDemoState();
}

class _SwitchDocumentDemoState extends State<SwitchDocumentDemo> {
  late MutableDocument _doc1;
  late MutableDocumentComposer _composer1;
  late Editor _docEditor1;

  late MutableDocument _doc2;
  late MutableDocumentComposer _composer2;
  late Editor _docEditor2;

  late Document _activeDocument;
  late DocumentComposer _activeComposer;
  late Editor _activeDocumentEditor;

  @override
  void initState() {
    super.initState();
    _doc1 = _createDocument1();
    _composer1 = MutableDocumentComposer();
    _docEditor1 = createDefaultDocumentEditor(document: _doc1, composer: _composer1);

    _doc2 = _createDocument2();
    _composer2 = MutableDocumentComposer();
    _docEditor2 = createDefaultDocumentEditor(document: _doc2, composer: _composer2);

    _activeDocument = _doc1;
    _activeComposer = _composer1;
    _activeDocumentEditor = _docEditor1;
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
              editor: _activeDocumentEditor,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              _activeDocument = _doc1;
              _activeComposer = _composer1;
              _activeDocumentEditor = _docEditor1;
            });
          },
          child: const Text('Document 1'),
        ),
        const SizedBox(width: 24),
        TextButton(
          onPressed: () {
            setState(() {
              _activeDocument = _doc2;
              _activeComposer = _composer2;
              _activeDocumentEditor = _docEditor2;
            });
          },
          child: const Text('Document 2'),
        ),
      ],
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

MutableDocument _createDocument2() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Document #2'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
    ],
  );
}
