import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor copy and paste > ', () {
    testWidgetsOnMac('pastes within a paragraph', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document and
      // add some text to give us a non-empty paragraph.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 0);
      await tester.typeImeText("Pasted text: ");

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.nodes.first.id;
      expect(SuperEditorInspector.findTextInParagraph(nodeId).text, "Pasted text: This was pasted here");
    });

    testWidgetsOnMac('pastes within a list item', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown(" * Pasted text:")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the end of the list item.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 12);
      await tester.typeImeText(" "); // <- manually add a space because Markdown strips it

      // Paste text into the paragraph.
      tester
        ..simulateClipboard()
        ..setSimulatedClipboardContent("This was pasted here");
      await tester.pressCmdV();

      // Ensure that the text was pasted into the paragraph.
      final nodeId = doc.nodes.first.id;
      expect(SuperEditorInspector.findTextInParagraph(nodeId).text, "Pasted text: This was pasted here");
    });
  });
}
