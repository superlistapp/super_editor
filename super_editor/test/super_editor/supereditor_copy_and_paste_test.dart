import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_runners.dart';
import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor copy and paste > ', () {
    testWidgetsOnApple('pastes within a paragraph', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document and
      // add some text to give us a non-empty paragraph.
      await tester.placeCaretInParagraph(doc.first.id, 0);
      await tester.typeImeText("Pasted text: ");

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.first.id;
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Pasted text: This was pasted here");
    });

    testWidgetsOnApple('pastes within a list item', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown(" * Pasted text:")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the end of the list item.
      await tester.placeCaretInParagraph(doc.first.id, 12);
      await tester.typeImeText(" "); // <- manually add a space because Markdown strips it

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.first.id;
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Pasted text: This was pasted here");
    });

    testAllInputsOnDesktop('pastes multiple paragraphs', (
      tester, {
      required TextInputSource inputSource,
    }) async {
      final testContext = await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(inputSource)
          .pump();

      // Place the caret at the empty paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Simulate pasting multiple lines.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent('''This is a paragraph
This is a second paragraph
This is the third paragraph''');
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await tester.pressCmdV();
      } else {
        await tester.pressCtlV();
      }

      // Ensure three paragraphs were created.
      final doc = testContext.document;
      expect(doc.nodeCount, 3);
      expect((doc.getNodeAt(0)! as ParagraphNode).text.text, 'This is a paragraph');
      expect((doc.getNodeAt(1)! as ParagraphNode).text.text, 'This is a second paragraph');
      expect((doc.getNodeAt(2)! as ParagraphNode).text.text, 'This is the third paragraph');
    });
  });
}
