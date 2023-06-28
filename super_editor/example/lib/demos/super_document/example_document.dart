import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';

Document createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: "1",
        imageUrl: 'https://i.ibb.co/5nvRdx1/flutter-horizon.png',
        metadata: const SingleColumnLayoutComponentStyles(
          width: double.infinity,
          padding: EdgeInsets.zero,
        ).toMetadata(),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Welcome to Super Editor 💙 🚀',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              "Super Editor is a toolkit to help you build document editors, document layouts, text fields, and more.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Ready-made solutions 📦',
        ),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'SuperEditor is a ready-made, configurable document editing experience.',
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'SuperTextField is a ready-made, configurable text field.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Quickstart 🚀',
        ),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(text: 'To get started with your own editing experience, take the following steps:'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              "Now, you're off to the races! SuperEditor renders your document, and lets you select, insert, and delete content.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Explore the toolkit 🔎',
        ),
        metadata: {
          'blockType': header2Attribution,
        },
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "Use MutableDocument as an in-memory representation of a document.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "Implement your own document data store by implementing the Document api.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "Implement your down DocumentLayout to position and size document components however you'd like.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "Use SuperSelectableText to paint text with selection boxes and a caret.",
        ),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: 'Use AttributedText to quickly and easily apply metadata spans to a string.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text:
              "We hope you enjoy using Super Editor. Let us know what you're building, and please file issues for any bugs that you find.",
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "Built by the Flutter Bounty Hunters",
          spans: AttributedSpans(attributions: [
            SpanMarker(
                attribution: LinkAttribution(url: Uri.parse("https://flutterbountyhunters.com")),
                offset: 13,
                markerType: SpanMarkerType.start),
            SpanMarker(
                attribution: LinkAttribution(url: Uri.parse("https://flutterbountyhunters.com")),
                offset: 34,
                markerType: SpanMarkerType.end),
          ]),
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          text: "",
        ),
      ),
    ],
  );
}
