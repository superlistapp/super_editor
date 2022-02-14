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

  SingleColumnLayoutStylesheet _createStyles() {
    // This stylesheet is defined here as an example. If you want to use
    // the default stylesheet in Super Editor, or make adjustments to it,
    // then use the defaultDocumentStylesheet
    return const SingleColumnLayoutStylesheet(
      standardContentWidth: 640.0,
      margin: EdgeInsets.only(bottom: 96, top: 96),
      inlineTextStyler: defaultInlineTextStyler,
      blockStyles: DocumentBlockStyles(
        text: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 20, left: 20, right: 20),
          textStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            height: 1.8,
          ),
        ),
        h1: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 40, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
        h2: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 32, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        h3: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 28, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        h4: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 22, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        h5: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 20, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        h6: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 16, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        listItem: TextBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 20, left: 20, right: 20),
          textStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            height: 1.8,
          ),
        ),
        blockquote: BlockquoteBlockStyle(
          paddingAdjustment: EdgeInsets.only(top: 20, left: 20, right: 20),
          textStyle: TextStyle(
            color: Color(0xFF555555),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
          backgroundColor: Color(0xFFF0F0F0),
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        image: BlockStyle(paddingAdjustment: EdgeInsets.only(top: 20)),
        hr: BlockStyle(paddingAdjustment: EdgeInsets.zero),
      ),
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
