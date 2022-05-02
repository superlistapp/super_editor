import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class DocumentStylesDemo extends StatefulWidget {
  const DocumentStylesDemo({Key? key}) : super(key: key);

  @override
  _DocumentStylesDemoState createState() => _DocumentStylesDemoState();
}

class _DocumentStylesDemoState extends State<DocumentStylesDemo> {
  late Document _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createSampleDocument();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
  }

  Stylesheet _createStyles() {
    // This stylesheet is defined here as an example. If you want to use
    // the default stylesheet in Super Editor, or make adjustments to it,
    // then use the defaultStylesheet
    return Stylesheet(
      rules: [
        StyleRule(
          BlockSelector.all,
          (doc, docNode) {
            return {
              "maxWidth": 640.0,
              "padding": const CascadingPadding.symmetric(horizontal: 24),
              "textStyle": const TextStyle(
                color: Colors.black,
                fontSize: 18,
                height: 1.4,
              ),
            };
          },
        ),
        StyleRule(
          const BlockSelector("header1"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 40),
              "textStyle": const TextStyle(
                color: Color(0xFF333333),
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            };
          },
        ),
        StyleRule(
          const BlockSelector("header2"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 32),
              "textStyle": const TextStyle(
                color: Color(0xFF333333),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            };
          },
        ),
        StyleRule(
          const BlockSelector("header3"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 28),
              "textStyle": const TextStyle(
                color: Color(0xFF333333),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            };
          },
        ),
        StyleRule(
          const BlockSelector("paragraph"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 24),
            };
          },
        ),
        StyleRule(
          const BlockSelector("paragraph").after("header1"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 0),
            };
          },
        ),
        StyleRule(
          const BlockSelector("paragraph").after("header2"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 0),
            };
          },
        ),
        StyleRule(
          const BlockSelector("paragraph").after("header3"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 0),
            };
          },
        ),
        StyleRule(
          const BlockSelector("listItem"),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(top: 24),
            };
          },
        ),
        StyleRule(
          BlockSelector.all.last(),
          (doc, docNode) {
            return {
              "padding": const CascadingPadding.only(bottom: 96),
            };
          },
        ),
      ],
      inlineTextStyler: defaultInlineTextStyler,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor(
      editor: _docEditor,
      stylesheet: _createStyles(),
    );
  }
}

MutableDocument _createSampleDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 1'),
        metadata: {'blockType': header1Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 2'),
        metadata: {'blockType': header2Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 3'),
        metadata: {'blockType': header3Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 4'),
        metadata: {'blockType': header4Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 5'),
        metadata: {'blockType': header5Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Header 6'),
        metadata: {'blockType': header6Attribution},
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'This is a paragraph of regular text'),
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'This is a blockquote'),
        metadata: {'blockType': blockquoteAttribution},
      ),
    ],
  );
}
