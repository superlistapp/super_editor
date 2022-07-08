import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../../../test/super_editor/document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    testGoldens('displays paragraphs with different alignments', (tester) async {
      await tester 
        .createDocument()
        .withCustomContent(_createParagraphTestDoc())        
        .pump();

      await screenMatchesGolden(tester, 'paragraph_alignments');
    });
  });
}

MutableDocument _createParagraphTestDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Various paragraph formations',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is a short\nparagraph of text\nthat is left aligned',
        ),
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is a short\nparagraph of text\nthat is center aligned',
        ),
        metadata: {
          'textAlign': 'center',
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is a short\nparagraph of text\nthat is right aligned',
        ),
        metadata: {
          'textAlign': 'right',
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'orem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}
