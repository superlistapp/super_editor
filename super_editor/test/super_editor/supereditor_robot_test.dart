import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';

import 'document_test_tools.dart';
import 'supereditor_inspector.dart';
import 'supereditor_robot.dart';

void main() {
  group("SuperEditor robot", () {
    testWidgets("taps to place caret in empty paragraph", (tester) async {
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

    testWidgets("taps to place caret before first character", (tester) async {
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

    testWidgets("taps to place caret in middle of paragraph", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 10);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 10),
          ),
        ),
      );
    });

    testWidgets("taps to place caret after last character", (tester) async {
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
            nodePosition: TextNodePosition(offset: paragraphLength),
          ),
        ),
      );
    });

    testWidgets("enters text with hardware keyboard", (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .forDesktop()
          .autoFocus(true)
          .pump();

      // Tap to place the caret in the first paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText("Hello, world!");

      // Verify that SuperEditor displays the text we typed.
      expect(SuperEditorInspector.findTextInParagraph("1").text, "Hello, world!");
    });
  });
}
