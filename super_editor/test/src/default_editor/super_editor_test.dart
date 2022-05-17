import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:super_editor/super_editor.dart';

import 'test_documents.dart';

void main() {
  group('SuperEditor', () {
    group('autofocus', () {
      testWidgets('does not claim focus when autofocus is false', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleParagraphDoc()),
                focusNode: focusNode,
                inputSource: _inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: _inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: false,
              ),
            ),
          ),
        );

        expect(focusNode.hasFocus, false);
      }, variant: _inputAndGestureVariants);

      testWidgets('claims focus when autofocus is true', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleParagraphDoc()),
                focusNode: focusNode,
                inputSource: _inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: _inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: true,
              ),
            ),
          ),
        );

        expect(focusNode.hasFocus, true);
      }, variant: _inputAndGestureVariants);

      testWidgets('claims focus by gesture when autofocus is false', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleParagraphDoc()),
                focusNode: focusNode,
                inputSource: _inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: _inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: false,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(SuperEditor));
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, true);
      }, variant: _inputAndGestureVariants);
    });

    group("stylesheet", () {
      testWidgets("change causes presentation to run again", (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleParagraphDoc()),
                stylesheet: _stylesheet1,
              ),
            ),
          ),
        );

        // Ensure that the initial text is black
        expect(find.byType(LayoutAwareRichText), findsOneWidget);
        final richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.black);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleParagraphDoc()),
                stylesheet: _stylesheet2,
              ),
            ),
          ),
        );

        // Ensure that the new stylesheet was applied, and the text is
        // now painted white.
        expect(find.byType(LayoutAwareRichText), findsOneWidget);
        final richText2 = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText2.text.style!.color, Colors.white);
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
