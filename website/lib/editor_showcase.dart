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

  static TextStyle Function(Set<Attribution> attributions) _textStyleBuilder(
    bool isNarrowScreen,
  ) {
    return (Set<Attribution> attributions) {
      var result = TextStyle(
        fontFamily: 'Aeonik',
        fontWeight: FontWeight.w400,
        fontSize: 18,
        height: 27 / 18,
        color: const Color(0xFF003F51),
      );

      for (final attribution in attributions) {
        if (attribution == header1Attribution) {
          result = result.copyWith(
            fontSize: isNarrowScreen ? 40 : 68,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
        } else if (attribution == blockquoteAttribution) {
          result = result.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          );
        } else if (attribution == boldAttribution) {
          result = result.copyWith(fontWeight: FontWeight.bold);
        } else if (attribution == italicsAttribution) {
          result = result.copyWith(fontStyle: FontStyle.italic);
        } else if (attribution == strikethroughAttribution) {
          result = result.copyWith(decoration: TextDecoration.lineThrough);
        }
      }
      return result;
    };
  }

  static Widget _centeredHeaderBuilder(ComponentContext context) {
    final node = context.documentNode;

    if (node is ParagraphNode && node.metadata['blockType'] == 'header1') {
      return Center(child: paragraphBuilder(context));
    }

    return null;
  }

  static Widget _blockquoteBuilder(ComponentContext context) {
    final node = context.documentNode;

    if (node is ParagraphNode &&
        node.metadata['blockType'] == blockquoteAttribution) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.black26,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 8),
        child: paragraphBuilder(context),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrowScreen = constraints.biggest.width <= 768;

          return Container(
            constraints: BoxConstraints(maxWidth: 1112)
                .tighten(height: isNarrowScreen ? 400 : 632),
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
              padding: isNarrowScreen
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.symmetric(horizontal: 96, vertical: 60),
              textStyleBuilder: _textStyleBuilder(isNarrowScreen),
              componentBuilders: [
                _centeredHeaderBuilder,
                _blockquoteBuilder,
                ...defaultComponentBuilders,
              ],
            ),
          );
        },
      ),
    );
  }
}
