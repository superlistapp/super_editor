import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools_user_input.dart';
import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('autofocus', () {
      testWidgets('does not claim focus when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        expect(SuperEditorInspector.hasFocus(), false);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus when autofocus is true', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(true)
            .pump();

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: inputAndGestureVariants);

      testWidgets('claims focus by gesture when autofocus is false', (tester) async {
        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withInputSource(inputAndGestureVariants.currentValue!.inputSource)
            .withGestureMode(inputAndGestureVariants.currentValue!.gestureMode)
            .autoFocus(false)
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        expect(SuperEditorInspector.hasFocus(), true);
      }, variant: inputAndGestureVariants);
    });
  });
}
