import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('floating cursor', () {
      testWidgetsOnIos('hides caret when over text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at "|This is a paragraph".
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 0);

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(50, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(100, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Move the floating cursor to the right.
        // The floating cursor will be over the text.
        await tester.updateFloatingCursorGesture(const Offset(175, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);
      });

      testWidgetsOnIos('hides caret when near text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at the end of the text.
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 19);

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Moves the floating cursor to the maximum distance before the grey caret is displayed.
        await tester.updateFloatingCursorGesture(const Offset(30, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);
      });

      testWidgetsOnIos('shows grey caret when far from text', (tester) async {
        // Pump a SuperEditor which displays the content in a single line.
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(500, 500))
            .pump();

        // Place caret at the end of the text.
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 19);

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Moves the floating cursor to the first pixel where the grey caret should be displayed.
        await tester.updateFloatingCursorGesture(const Offset(31, 0));
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Ensure the caret is grey.
        BlinkingCaret caret = tester.widget<BlinkingCaret>(_caretFinder());
        expect(caret.color, Colors.grey);

        // Release the floating cursor.
        await tester.stopFloatingCursorGesture();
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Ensure the caret is blue.
        caret = tester.widget<BlinkingCaret>(_caretFinder());
        expect(caret.color, Colors.blue);
      });

      testWidgetsOnIos('collapses an expanded selection', (tester) async {
        final testContext = await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .pump();

        final nodeId = testContext.document.nodes.first.id;

        // Double tap to select the word "This"
        await tester.doubleTapInParagraph(nodeId, 0);

        // Ensure the word is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection(
            base: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 4),
            ),
          ),
        );

        // Show the floating cursor.
        await tester.startFloatingCursorGesture();
        await tester.pump();

        // Ensure the selection collapsed.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 4, affinity: TextAffinity.upstream),
            ),
          ),
        );
      });
    });
  });
}

Finder _caretFinder() {
  return find.byType(BlinkingCaret);
}
