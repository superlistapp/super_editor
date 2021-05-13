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
            'blockType': header1Attribution,
            'textAlign': 'center',
          },
        ),
      ],
    );
  }

  static TextStyle _textStyleBuilder(Set<dynamic> attributions) {
    var result = TextStyle(
      fontFamily: 'Aeonik',
      fontWeight: FontWeight.w300,
      fontSize: 18,
      height: 27 / 18,
      color: const Color(0xFF003F51),
    );

    for (final attribution in attributions) {
      if (attribution is NamedAttribution) {
        switch (attribution.name) {
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
        constraints: BoxConstraints(maxWidth: 1112).tighten(height: 632),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.79),
              blurRadius: 75,
            ),
          ],
        ),
        child: Editor.custom(
          editor: _docEditor,
          maxWidth: 1112,
          padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 60),
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
