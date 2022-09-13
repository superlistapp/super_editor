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

    testWidgetsOnAllPlatforms("taps to place caret just before a line break", (tester) async {
      // Configure and render a document.
      await tester
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .autoFocus(true)
          .withEditorSize(const Size(300, 700))
          .withSelection(
            const DocumentSelection.collapsed(
                position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0))),
          )
          .pump();
      await tester.pumpAndSettle();
      final offset = await _findOffsetOfLineBreak(tester);

      // Tap to place the at the end of the first line
      await tester.placeCaretInParagraph("1", offset, affinity: TextAffinity.upstream);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: offset, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("taps to place caret just before after a line break", (tester) async {
      // Configure and render a document.
      await tester
          .createDocument()
          .withSingleParagraph()
          .forDesktop()
          .autoFocus(true)
          .withEditorSize(const Size(300, 700))
          .withSelection(
            const DocumentSelection.collapsed(
                position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0))),
          )
          .pump();
      await tester.pumpAndSettle();
      final offsetOfLineBreak = await _findOffsetOfLineBreak(tester);

      // Tap to place the at the end of the first line
      await tester.placeCaretInParagraph("1", offsetOfLineBreak, affinity: TextAffinity.downstream);

      // Ensure that the document has the expected text caret selection.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: offsetOfLineBreak, affinity: TextAffinity.downstream),
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

/// Locates the first line break in a paragraph, or fails the test if it cannot find one.
Future<int> _findOffsetOfLineBreak(WidgetTester tester) async {
  final composer = tester.widget<SuperEditor>(find.byType(SuperEditor)).composer;
  expect(composer, isNotNull);
  final previousSelection = composer!.selection;
  final firstLineCaretY = SuperEditorInspector.findCaretOffsetInDocument().dy;
  var offset = 1;
  for (; offset < 2000; offset++) {
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: '1',
        nodePosition: TextNodePosition(
          offset: offset,
          affinity: TextAffinity.downstream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final caretY = SuperEditorInspector.findCaretOffsetInDocument().dy;
    if (caretY > firstLineCaretY) break;
  }
  expect(offset, lessThan(2000), reason: 'Failed to find line break in paragraph');

  composer.selection = previousSelection;
  await tester.pumpAndSettle();

  return offset;
}
