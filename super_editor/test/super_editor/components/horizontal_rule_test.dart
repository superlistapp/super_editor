import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group('SuperEditor horizontal rule component', () {
    testWidgetsOnAllPlatforms('inserts a paragraph when typing at the end', (tester) async {
      final testContext = await tester
          .createDocument() //
          .fromMarkdown('''
Paragraph 1

---

Paragraph 2
''')
          .withInputSource(TextInputSource.ime)
          .pump();

      final document = testContext.editContext.document;

      // Place caret at the beginning of the last node.
      await tester.placeCaretInParagraph(document.nodes.last.id, 0);

      // Press left arrow to move the selection to the end of the horizontal rule.
      await tester.pressLeftArrow();

      // Type at the end of the horizontal rule
      await tester.typeImeText('new paragraph');

      // Ensure a new node was created.
      expect(document.nodes.length, 4);

      // The node should be inserted after the horizontal rule.
      final insertedNode = document.nodes[2];

      // Ensure the inserted node is a paragraph.
      expect(insertedNode, isA<ParagraphNode>());

      // Ensure the text was inserted at the new paragraph.
      expect((insertedNode as ParagraphNode).text.text, 'new paragraph');

      // Ensure the caret sits at the end of the text.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: insertedNode.id,
            nodePosition: const TextNodePosition(offset: 13),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('inserts a paragraph when typing at the beginning', (tester) async {
      final testContext = await tester
          .createDocument() //
          .fromMarkdown('''
Paragraph 1

---

Paragraph 2
''')
          .withInputSource(TextInputSource.ime)
          .pump();

      final document = testContext.editContext.document;

      // Place caret at the end of the first node.
      await tester.placeCaretInParagraph(document.nodes.first.id, 11);

      // Press right arrow to move the selection to the beginning of the horizontal rule.
      await tester.pressRightArrow();

      // Type at the beginning of the horizontal rule
      await tester.typeImeText('new paragraph');

      // Ensure a new node was created.
      expect(document.nodes.length, 4);

      // The node should be inserted before the horizontal rule.
      final insertedNode = document.nodes[1];

      // Ensure the inserted node is a paragraph.
      expect(insertedNode, isA<ParagraphNode>());

      // Ensure the text was inserted at the new paragraph.
      expect((insertedNode as ParagraphNode).text.text, 'new paragraph');

      // Ensure the caret sits at the end of the text.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: insertedNode.id,
            nodePosition: const TextNodePosition(offset: 13),
          ),
        ),
      );
    });
  });
}
