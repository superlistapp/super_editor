import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class EditorShowcase extends StatefulWidget {
  const EditorShowcase();

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<EditorShowcase> {
  Document _doc;
  DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc);
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  static Document _createInitialDocument() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'A supercharged rich text editor for Flutter',
          ),
          metadata: {
            'blockType': 'header1',
            'textAlign': 'center',
          },
        ),
      ],
    );
  }

  static TextStyle _textStyleBuilder(Set<dynamic> attributions) {
    var result = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 18,
      height: 27 / 18,
      color: const Color(0xFF003F51).withOpacity(0.9),
    );

    for (final attribution in attributions) {
      if (attribution is! String) {
        continue;
      }

      switch (attribution) {
        case 'header1':
          result = result.copyWith(
            fontSize: 68,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
          break;
        case 'header2':
          result = result.copyWith(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            height: 1.2,
          );
          break;
        case 'blockquote':
          result = result.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
            color: Colors.grey,
          );
          break;
        case 'bold':
          result = result.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'italics':
          result = result.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'strikethrough':
          result = result.copyWith(decoration: TextDecoration.lineThrough);
          break;
      }
    }
    return result;
  }

  static Widget _centeredHeaderBuilder(ComponentContext context) {
    var result = paragraphBuilder(context);
    final node = context.documentNode;

    if (node is ParagraphNode) {
      if (node.metadata['blockType'] == 'header1') {
        return Center(child: result);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1113).tighten(height: 622),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Editor.custom(
          editor: _docEditor,
          maxWidth: 800,
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 61),
          textStyleBuilder: _textStyleBuilder,
          componentBuilders: [
            _centeredHeaderBuilder,
            ...defaultComponentBuilders,
          ],
        ),
      ),
    );
  }
}
