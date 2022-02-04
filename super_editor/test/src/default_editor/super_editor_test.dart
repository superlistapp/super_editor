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
                inputSource: _inputAndGestureVariants.currentValue!.inputSource,
                gestureMode: _inputAndGestureVariants.currentValue!.gestureMode,
                autofocus: false,
              ),
            ),
          ),
        );

        expect(focusNode.hasFocus, false);
      }, variant: _inputAndGestureVariants);

      testWidgets('claims focus when autofocus = true - ', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleBlockDoc()),
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

      testWidgets('claims focus by gesture when autofocus = false -', (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: DocumentEditor(document: singleBlockDoc()),
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
  });
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
