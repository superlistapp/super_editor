import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'supereditor_inspector.dart';
import 'supereditor_robot.dart';

void main() {
  group('SuperEditor keyboard', () {
    group('on any desktop', () {
      group('moves caret', () {
        testWidgetsOnDesktop("left by one character when LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2);

          await tester.pressLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 1));
        });

        testWidgetsOnDesktop("left by one character and expands when SHIFT + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2);

          await tester.pressShiftLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 1));
        });

        testWidgetsOnDesktop("right by one character when RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2);

          await tester.pressRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 3));
        });

        testWidgetsOnDesktop("right by one character and expands when SHIFT + RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2);

          await tester.pressShiftRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 3));
        });

        testWidgetsOnMac("to beginning of word when ALT + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressAltLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 8));
        });

        testWidgetsOnMac("to beginning of word and expands when SHIFT + ALT + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftAltLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testWidgetsOnMac("to end of word when ALT + RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressAltRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testWidgetsOnMac("to end of word and expands when SHIFT + ALT + RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftAltRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testWidgetsOnMac("to beginning of line when CMD + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressCmdLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 0));
        });

        testWidgetsOnMac("to beginning of line and expands when SHIFT + CMD + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftCmdLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 0));
        });

        testWidgetsOnMac("to end of line when CMD + RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressCmdRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 26, TextAffinity.upstream));
        });

        testWidgetsOnMac("to end of line and expands when SHIFT + CMD + RIGHT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftCmdRightArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _selectionInParagraph(nodeId, from: 10, to: 26, toAffinity: TextAffinity.upstream),
          );
        });

        testWidgetsOnWindowsAndLinux("to beginning of word when CTL + LEFT_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressCtlLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 8));
        });

        testWidgetsOnWindowsAndLinux("to beginning of word and expands when SHIFT + CTL + LEFT_ARROW is pressed",
            (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftCtlLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testWidgetsOnWindowsAndLinux("to end of word when CTL + Right_ARROW is pressed", (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressCtlRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testWidgetsOnWindowsAndLinux("to end of word and expands when SHIFT + CTL + RIGHT_ARROW is pressed",
            (tester) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10);

          await tester.pressShiftCtlRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testWidgetsOnDesktop("up one line when UP_ARROW is pressed", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41);

          await tester.pressUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testWidgetsOnDesktop("up one line and expands when SHIFT + UP_ARROW is pressed", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41);

          await tester.pressShiftUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 12));
        });

        testWidgetsOnDesktop("down one line when DOWN_ARROW is pressed", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12);

          await tester.pressDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 41));
        });

        testWidgetsOnDesktop("down one line and expands when SHIFT + DOWN_ARROW is pressed", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12);

          await tester.pressShiftDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 41));
        });

        testWidgetsOnDesktop("to beginning of line when UP_ARROW is pressed at top of document", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12);

          await tester.pressUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 0));
        });

        testWidgetsOnDesktop("to beginning of line and expands when SHIFT + UP_ARROW is pressed at top of document",
            (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41);

          await tester.pressShiftUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 12));
        });

        testWidgetsOnDesktop("to end of line when DOWN_ARROW is pressed at end of document", (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41);

          await tester.pressDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 58));
        });

        testWidgetsOnDesktop("end of line and expands when SHIFT + DOWN_ARROW is pressed at end of document",
            (tester) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41);

          await tester.pressShiftDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 58));
        });
      });
    });
  });
}

Future<String> _pumpSingleLineWithCaret(WidgetTester tester, {required int offset}) async {
  final testContext = await tester //
      .createDocument()
      .fromMarkdown("This is some testing text.") // Length is 26
      .pump();

  final nodeId = testContext.editContext.editor.document.nodes.first.id;

  await tester.placeCaretInParagraph(nodeId, offset);

  return nodeId;
}

Future<String> _pumpDoubleLineWithCaret(WidgetTester tester, {required int offset}) async {
  final testContext = await tester //
      .createDocument()
      // Text indices:
      // - first line: [0, 28]
      // - newline: 29
      // - second line: [30, 58]
      .fromMarkdown("This is the first paragraph.\nThis is the second paragraph.")
      .pump();

  final nodeId = testContext.editContext.editor.document.nodes.first.id;

  await tester.placeCaretInParagraph(nodeId, offset);

  return nodeId;
}

DocumentSelection _caretInParagraph(String nodeId, int offset, [TextAffinity textAffinity = TextAffinity.downstream]) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: offset, affinity: textAffinity)),
  );
}

DocumentSelection _selectionInParagraph(
  String nodeId, {
  required int from,
  TextAffinity fromAffinity = TextAffinity.downstream,
  required int to,
  TextAffinity toAffinity = TextAffinity.downstream,
}) {
  return DocumentSelection(
    base: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: from, affinity: fromAffinity)),
    extent: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: to, affinity: toAffinity)),
  );
}
