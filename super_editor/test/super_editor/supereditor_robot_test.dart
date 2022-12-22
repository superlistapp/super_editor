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

    testWidgetsOnAllPlatforms("taps to place caret at a non-linebreak offset with different affinities",
        (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Ensure that the document doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), null);

      // Tap to place the caret in the first paragraph with a downstream affinity. This assumes that the paragraph
      // does not wrap at the second character of the paragraph, which should be true for any reasonable display size.
      await tester.placeCaretInParagraph("1", 1, affinity: TextAffinity.downstream);
      // Ensure the document has the correct selection, including affinity;
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(
              offset: 1,
              affinity: TextAffinity.downstream,
            ),
          ),
        ),
      );

      // Place the caret at the same offset as before but with an upstream affinity.
      await tester.pump(kTapTimeout * 2); // Pause to avoid double tap.
      await tester.placeCaretInParagraph("1", 1, affinity: TextAffinity.upstream);
      // Ensure the document has the correct selection, including affinity;
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(
              offset: 1,
              affinity: TextAffinity.upstream,
            ),
          ),
        ),
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
          .withInputSource(TextInputSource.keyboard)
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
          .withInputSource(TextInputSource.ime)
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
