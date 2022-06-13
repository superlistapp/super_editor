import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/supereditor_inspector.dart';
import '../../super_editor/supereditor_robot.dart';

void main() {
  group('SuperEditor', () {
    group('autofocus', () {
      testWidgets('does not claim focus when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(_inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(_inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        expect(SuperEditorInspector.hasFocus(), false);
      }, variant: _inputAndGestureVariants);

      testWidgets('claims focus when autofocus is true', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(_inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(_inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(true)
            .pump();

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: _inputAndGestureVariants);

      testWidgets('claims focus by gesture when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(_inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(_inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: _inputAndGestureVariants);
    });

    group("stylesheet", () {
      testWidgets("change causes presentation to run again", (tester) async {
        // Configure and render a document.
        final testDocument = await tester //
            .createDocument()
            .withSingleParagraph()
            .useStylesheet(_stylesheet1)
            .pump();

        // Ensure that the initial text is black
        expect(SuperEditorInspector.findParagraphStyle("1")!.color, Colors.black);

        // Configure and render a document with a different stylesheet.
        await tester //
            .updateDocument(testDocument)
            .useStylesheet(_stylesheet2)
            .pump();

        // Expect the paragraph to now be white.
        expect(SuperEditorInspector.findParagraphStyle("1")!.color, Colors.white);
      });
    });
  });
}

final _stylesheet1 = Stylesheet(
  inlineTextStyler: inlineTextStyler,
  rules: [
    StyleRule(BlockSelector.all, (document, node) {
      return {
        "textStyle": const TextStyle(
          color: Colors.black,
        ),
      };
    }),
  ],
);

final _stylesheet2 = Stylesheet(
  inlineTextStyler: inlineTextStyler,
  rules: [
    StyleRule(BlockSelector.all, (document, node) {
      return {
        "textStyle": const TextStyle(
          color: Colors.white,
        ),
      };
    }),
  ],
);

TextStyle inlineTextStyler(Set<Attribution> attributions, TextStyle base) {
  return base;
}

class _InputAndGestureTuple {
  final DocumentInputSource inputSource;
  final DocumentGestureMode gestureMode;

  const _InputAndGestureTuple(this.inputSource, this.gestureMode);

  @override
  String toString() {
    return '${inputSource.name} Input Source & ${gestureMode.name} Gesture Mode';
  }
}

final _inputAndGestureVariants = ValueVariant<_InputAndGestureTuple>(
  {
    const _InputAndGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.mouse),
    const _InputAndGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.iOS),
    const _InputAndGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.android),
    const _InputAndGestureTuple(DocumentInputSource.ime, DocumentGestureMode.mouse),
    const _InputAndGestureTuple(DocumentInputSource.ime, DocumentGestureMode.iOS),
    const _InputAndGestureTuple(DocumentInputSource.ime, DocumentGestureMode.android),
  },
);
