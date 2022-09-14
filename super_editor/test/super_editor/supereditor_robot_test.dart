import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor robot", () {
    testWidgetsOnAllPlatforms("taps to place caret in empty paragraph", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the beginning of the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret before first character", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the beginning of the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret in middle of paragraph", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();
      await tester.pumpAndSettle();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      final offsetBeforeLineBreak = await SuperEditorInspector.findOffsetOfLineBreak(tester) - 1;

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", offsetBeforeLineBreak, affinity: TextAffinity.downstream);

      // Ensure that the document has the expected text caret selection.
      final expectedSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: offsetBeforeLineBreak),
        ),
      );
      expect(
        SuperEditorInspector.findDocumentSelection(),
        expectedSelection,
      );

      // Pause so we don't double-tap and select a word instead of placing the caret
      await tester.pump(const Duration(seconds: 2));

      // Tap to place the caret in the first paragraph with a different affinity.
      await tester.placeCaretInParagraph("1", offsetBeforeLineBreak, affinity: TextAffinity.upstream);
      // Since we're not tapping at a line break the resulting selection should be the same.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        expectedSelection,
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret after last character", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret at the end of the first paragraph.
      const paragraphLength = 445;
      await tester.placeCaretInParagraph("1", paragraphLength);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: paragraphLength, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("enters text with hardware keyboard", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .withInputSource(DocumentInputSource.keyboard)
          .autoFocus(true)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText("Hello, world!");

      // Verify that SuperEditor displays the text we typed.
      expect(SuperEditorInspector.findTextInParagraph("1").text, "Hello, world!");
    });

    testWidgetsOnDesktop("enters text with IME keyboard", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .withInputSource(DocumentInputSource.ime)
          .autoFocus(true)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeImeText("Hello, world!");

      // Verify that SuperEditor displays the text we typed.
      expect(SuperEditorInspector.findTextInParagraph("1").text, "Hello, world!");
    });
  });
}
