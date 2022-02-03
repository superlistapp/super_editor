import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:super_editor/super_editor.dart';

import 'test_documents.dart';


void main() {
  group('SuperEditor', () {
    group('autofocus tests -', () {
      testWidgets('does not claim focus when autofocus = false', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleBlockDoc()),
                focusNode: focusNode,
                inputSource: inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: false,
              ),
            ),
          ),
        );

        expect(focusNode.hasFocus, false);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus when autofocus = true - ', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleBlockDoc()),
                focusNode: focusNode,
                inputSource: inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: true,
              ),
            ),
          ),
        );

        expect(focusNode.hasFocus, true);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus by gesture when autofocus = false -', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleBlockDoc()),
                focusNode: focusNode,
                inputSource: inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: false,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(SuperEditor));
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, true);
      }, variant: inputAndGestureVariants);
    });
  });
}


class InputGestureTuple {
  final DocumentInputSource inputSource;
  final DocumentGestureMode gestureMode;

  const InputGestureTuple(this.inputSource, this.gestureMode);

  @override
  String toString() {
    return '${inputSource.name} Input Source & ${gestureMode.name} Gesture Mode';
  }
}

final inputAndGestureVariants = ValueVariant<InputGestureTuple>(
  {
    const InputGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.mouse),
    const InputGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.iOS),
    const InputGestureTuple(DocumentInputSource.keyboard, DocumentGestureMode.android),
    const InputGestureTuple(DocumentInputSource.ime, DocumentGestureMode.mouse),
    const InputGestureTuple(DocumentInputSource.ime, DocumentGestureMode.iOS),
    const InputGestureTuple(DocumentInputSource.ime, DocumentGestureMode.android),
  },
);
