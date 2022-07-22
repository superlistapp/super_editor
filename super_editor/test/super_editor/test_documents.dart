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
            // String length is 445
            text:
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          ),
        ),
      ],
    );

MutableDocument singleBlockDoc() => MutableDocument(
      nodes: [
        HorizontalRuleNode(id: "1"),
      ],
    );

MutableDocument longTextDoc() => MutableDocument(
      nodes: [
        ParagraphNode(
          id: "1",
          text: AttributedText(
            text:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
          ),
        ),
        ParagraphNode(
          id: "2",
          text: AttributedText(
              text:
                  'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
        ),
        ParagraphNode(
          id: "3",
          text: AttributedText(
            text:
                'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
        ParagraphNode(
          id: "4",
          text: AttributedText(
            text:
                'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
          ),
        ),
      ],
    );
