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

MutableDocument singleParagraphEmptyDoc() => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(text: "")),
      ],
    );

MutableDocument twoParagraphEmptyDoc() => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(text: "")),
        ParagraphNode(id: "2", text: AttributedText(text: "")),
      ],
    );

MutableDocument singleParagraphDoc() => MutableDocument(
      nodes: [
        ParagraphNode(
            id: "1",
            text: AttributedText(
                text:
                    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")),
      ],
    );

MutableDocument singleBlockDoc() => MutableDocument(
      nodes: [
        HorizontalRuleNode(id: "1"),
      ],
    );
