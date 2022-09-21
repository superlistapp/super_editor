import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_document_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperDocument keyboard', () {
    group('on any desktop', () {
      group('moves selection', () {
        testAllInputsOnDesktop("left by one character and expands when SHIFT + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 2, inputSource: inputSource);

          await tester.pressShiftLeftArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 1));
        });

        testAllInputsOnDesktop("right by one character and expands when SHIFT + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 2, inputSource: inputSource);

          await tester.pressShiftRightArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 2, to: 3));
        });

        testAllInputsOnMac("to beginning of word and expands when SHIFT + ALT + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftAltLeftArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testAllInputsOnMac("to end of word and expands when SHIFT + ALT + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftAltRightArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testAllInputsOnMac("to beginning of line and expands when SHIFT + CMD + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCmdLeftArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 0));
        });

        testAllInputsOnMac("to end of line and expands when SHIFT + CMD + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCmdRightArrow();

          expect(
            SuperDocumentInspector.findDocumentSelection(),
            _selectionInParagraph(nodeId, from: 10, to: 26, toAffinity: TextAffinity.upstream),
          );
        });

        testAllInputsOnWindowsAndLinux("to beginning of word and expands when SHIFT + CTL + LEFT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCtlLeftArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 8));
        });

        testAllInputsOnWindowsAndLinux("to end of word and expands when SHIFT + CTL + RIGHT_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpSingleLineAndSelectAWord(tester, offset: 10, inputSource: inputSource);

          await tester.pressShiftCtlRightArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 10, to: 12));
        });

        testAllInputsOnDesktop("up one line and expands when SHIFT + UP_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLine(tester, offset: 41, inputSource: inputSource);

          await tester.pressShiftUpArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 12));
        });

        testAllInputsOnDesktop("down one line and expands when SHIFT + DOWN_ARROW is pressed", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLine(tester, offset: 12, inputSource: inputSource);

          await tester.pressShiftDownArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 41));
        });

        testAllInputsOnDesktop("to beginning of line and expands when SHIFT + UP_ARROW is pressed at top of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLine(tester, offset: 12, inputSource: inputSource);

          await tester.pressShiftUpArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 12, to: 0));
        });

        testAllInputsOnDesktop("end of line and expands when SHIFT + DOWN_ARROW is pressed at end of document", (
          tester, {
          required DocumentInputSource inputSource,
        }) async {
          final nodeId = await _pumpDoubleLine(tester, offset: 41, inputSource: inputSource);

          await tester.pressShiftDownArrow();

          expect(SuperDocumentInspector.findDocumentSelection(), _selectionInParagraph(nodeId, from: 41, to: 58));
        });
      });
    });
  });
}

Future<String> _pumpSingleLineAndSelectAWord(
  WidgetTester tester, {
  required int offset,
  required DocumentInputSource inputSource,
}) async {
  final testContext = await tester //
      .createDocument()
      .fromMarkdown("This is some testing text.") // Length is 26
      .withInputSource(inputSource)
      .pump();

  final nodeId = testContext.documentContext.document.nodes.first.id;

  // TODO: we need to start with double tap word selection
  await tester.placeCaretInParagraph(nodeId, offset);

  return nodeId;
}

Future<String> _pumpDoubleLine(
  WidgetTester tester, {
  required int offset,
  required DocumentInputSource inputSource,
}) async {
  final testContext = await tester //
      .createDocument()
      // Text indices:
      // - first line: [0, 28]
      // - newline: 29
      // - second line: [30, 58]
      .fromMarkdown("This is the first paragraph.\nThis is the second paragraph.")
      .pump();

  final nodeId = testContext.documentContext.document.nodes.first.id;

  return nodeId;
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
