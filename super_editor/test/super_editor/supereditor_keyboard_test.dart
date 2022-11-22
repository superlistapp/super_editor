import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor keyboard', () {
    group('on any desktop', () {
      group('moves caret', () {
        testAllInputsOnDesktop("left by one character when LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2, inputSource: inputSource);

          await tester.pressLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 1));
        });

        testAllInputsOnDesktop("left by one character and expands when SHIFT + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2, inputSource: inputSource);

          await tester.pressShiftLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 1));
        });

        testAllInputsOnDesktop("right by one character when RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2, inputSource: inputSource);

          await tester.pressRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 3));
        });

        testAllInputsOnDesktop("right by one character and expands when SHIFT + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 2, inputSource: inputSource);

          await tester.pressShiftRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 3));
        });

        testAllInputsOnMac("to beginning of word when ALT + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressAltLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 8));
        });

        testAllInputsOnMac("to beginning of word and expands when SHIFT + ALT + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftAltLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testAllInputsOnMac("to end of word when ALT + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressAltRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testAllInputsOnMac("to end of word and expands when SHIFT + ALT + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftAltRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testAllInputsOnMac("to beginning of line when CMD + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressCmdLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 0));
        });

        testAllInputsOnMac("to beginning of line and expands when SHIFT + CMD + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCmdLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 0));
        });

        testAllInputsOnMac("to end of line when CMD + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressCmdRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 26, TextAffinity.upstream));
        });

        testAllInputsOnMac("to end of line and expands when SHIFT + CMD + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCmdRightArrow();

          expect(
            SuperEditorInspector.findDocumentSelection(),
            _selectionInParagraph(nodeId, from: 10, to: 26, toAffinity: TextAffinity.upstream),
          );
        });

        testAllInputsOnWindowsAndLinux("to beginning of word when CTL + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressCtlLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 8));
        });

        testAllInputsOnWindowsAndLinux("to beginning of word and expands when SHIFT + CTL + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCtlLeftArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testAllInputsOnWindowsAndLinux("to end of word when CTL + Right_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressCtlRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testAllInputsOnWindowsAndLinux("to end of word and expands when SHIFT + CTL + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineWithCaret(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCtlRightArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testAllInputsOnDesktop("up one line when UP_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41, inputSource: inputSource);

          await tester.pressUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 12));
        });

        testAllInputsOnDesktop("up one line and expands when SHIFT + UP_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41, inputSource: inputSource);

          await tester.pressShiftUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 12));
        });

        testAllInputsOnDesktop("down one line when DOWN_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12, inputSource: inputSource);

          await tester.pressDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 41));
        });

        testAllInputsOnDesktop("down one line and expands when SHIFT + DOWN_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12, inputSource: inputSource);

          await tester.pressShiftDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 41));
        });

        testAllInputsOnDesktop("to beginning of line when UP_ARROW is pressed at top of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12, inputSource: inputSource);

          await tester.pressUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 0));
        });

        testAllInputsOnDesktop("to beginning of line and expands when SHIFT + UP_ARROW is pressed at top of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 12, inputSource: inputSource);

          await tester.pressShiftUpArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 0));
        });

        testAllInputsOnDesktop("to end of line when DOWN_ARROW is pressed at end of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41, inputSource: inputSource);

          await tester.pressDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _caretInParagraph(nodeId, 58));
        });

        testAllInputsOnDesktop("end of line and expands when SHIFT + DOWN_ARROW is pressed at end of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLineWithCaret(tester, offset: 41, inputSource: inputSource);

          await tester.pressShiftDownArrow();

          expect(SuperEditorInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 58));
        });
      });
    });
  });

  group('SuperEditor software keyboard', () {
    testWidgetsOnIos('pressing tab indent list', (tester) async {
      await _pumpUnorderedList(tester);

      final node = SuperEditorInspector.getNodeAt<ListItemNode>(0);

      // Ensure we started with indentation level 0.
      expect(node.indent, 0);

      await tester.placeCaretInParagraph(node.id, 0);

      // Simulate the user pressing TAB on the software keyboard.
      await tester.typeImeText("\t");

      // Ensure we indented the list item.
      expect(node.indent, 1);

      // Ensure the selection didn't change.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      // Ensure the content of the list item didn't change.
      expect(node.text.text, 'list item 1');
    });
  });

  group('SuperEditor inputSource', () {
    testWidgetsOnMobile('configures for IME input by default on mobile', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .pump();

      final document = SuperEditorInspector.findDocument()!;

      // Ensure the document was created with one node.
      expect(document.nodes.length, 1);

      // Tap to give focus to the editor.
      await tester.placeCaretInParagraph(document.nodes.first.id, 0);

      // Ensure that IME input is enabled. To check IME input, we arbitrarily simulate a newline action from
      // the IME. If the editor responds to the newline, it means IME input is enabled.
      // We expect the newline to insert a new paragraph node.
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();

      // Ensure a new node was added.
      expect(document.nodes.length, 2);
    });

    testWidgetsOnDesktop('configures for keyboard input by default on desktop', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .pump();

      final document = SuperEditorInspector.findDocument()!;

      // Ensure the document was created with one node.
      expect(document.nodes.length, 1);

      // Tap to give focus to the editor.
      await tester.placeCaretInParagraph(document.nodes.first.id, 0);

      // Ensure that IME input is disabled. To check IME input, we arbitrarily simulate a newline action from
      // the IME. If the editor doesn't respond to the newline, it means IME input is disabled.
      // We expect that the document content remains unchanged.
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();

      // Ensure no node was added.
      expect(document.nodes.length, 1);

      // Simulate typing on a keyboard.
      await tester.typeKeyboardText('abc');

      // Ensure text was added.
      expect(SuperEditorInspector.findTextInParagraph(document.nodes.first.id).text, 'abc');
    });
  });
}

Future<String> _pumpSingleLineWithCaret(
  WidgetTester tester, {
  required int offset,
  required DocumentInputSource inputSource,
}) async {
  final testContext = await tester //
      .createDocument()
      .fromMarkdown("This is some testing text.") // Length is 26
      .withInputSource(inputSource)
      .pump();

  final nodeId = testContext.editContext.editor.document.nodes.first.id;

  await tester.placeCaretInParagraph(nodeId, offset);

  return nodeId;
}

Future<String> _pumpDoubleLineWithCaret(WidgetTester tester,
    {required int offset, required DocumentInputSource inputSource}) async {
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

/// Pumps a [SuperEditor] configure with IME input, containing 2 unordered list items.
///
/// Both items have one level of indentation.
Future<TestDocumentContext> _pumpUnorderedList(WidgetTester tester) async {
  const markdown = '''
 * list item 1
 * list item 2

''';

  final testContext = await tester //
      .createDocument()
      .fromMarkdown(markdown)
      .withInputSource(DocumentInputSource.ime)
      .pump();

  return testContext;
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
