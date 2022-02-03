import 'package:super_editor/super_editor.dart';

MutableDocument paragraphThenHrThenParagraphDoc() => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(text: "This is the first node in a document.")),
        HorizontalRuleNode(id: "2"),
        ParagraphNode(id: "3", text: AttributedText(text: "This is the third node in a document.")),
      ],
    );

MutableDocument paragraphThenHrDoc() => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(text: "Paragraph 1")),
        HorizontalRuleNode(id: "2"),
      ],
    );

MutableDocument hrThenParagraphDoc() => MutableDocument(
      nodes: [
        HorizontalRuleNode(id: "1"),
        ParagraphNode(id: "2", text: AttributedText(text: "Paragraph 1")),
      ],
    );

MutableDocument singleBlockDoc() => MutableDocument(
      nodes: [
        HorizontalRuleNode(id: "1"),
      ],
    );
