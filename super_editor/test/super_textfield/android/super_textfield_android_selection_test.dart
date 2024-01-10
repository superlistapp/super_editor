import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/toolbar.dart';
import 'package:super_editor/super_text_field.dart';

import '../super_textfield_inspector.dart';
import '../super_textfield_robot.dart';

void main() {
  group("SuperTextField Android selection >", () {
    testWidgetsOnAndroid("long-pressing in empty space shows the toolbar", (tester) async {
      await _pumpTestApp(tester);

      // Ensure there's no selection to begin with, and no toolbar is displayed.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: -1));
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Place the caret at the end of the text by tapping in empty space at the center
      // of the text field.
      await tester.tap(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 3));
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Long-press in empty space at the center of the text field.
      await tester.longPress(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);

      // Ensure that the text field toolbar is visible.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsOneWidget);

      // Tap again to hide the toolbar.
      await tester.tap(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);

      // Ensure that the text field toolbar disappeared.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
    });

    testWidgetsOnAndroid("long-pressing in empty space when there is NO selection does NOT show the toolbar",
        (tester) async {
      await _pumpTestApp(tester);

      // Ensure there's no selection to begin with, and no toolbar is displayed.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: -1));
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Long-press in empty space at the center of the text field.
      await tester.longPress(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);

      // Ensure that no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
    });

    testWidgetsOnAndroid("tapping at collapsed handle shows/hides the toolbar", (tester) async {
      await _pumpTestApp(tester);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Place caret at the end of the textfield.
      await tester.placeCaretInSuperTextField(3);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Tap on the drag handle to show the toolbar.
      await tester.tapOnAndroidCollapsedHandle();
      await tester.pump();

      // Ensure that the text field toolbar is visible.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsOneWidget);

      // Tap on the drag handle to hide the toolbar.
      await tester.tapOnAndroidCollapsedHandle();
      await tester.pump();

      // Ensure the toolbar disappeared.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
    });

    testWidgetsOnAndroid("tapping at existing collapsed selection shows/hides the toolbar", (tester) async {
      await _pumpTestApp(tester);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Place caret at "ab|c".
      await tester.placeCaretInSuperTextField(2);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Tap again on the same position to show the toolbar.
      await tester.placeCaretInSuperTextField(2);

      // Ensure that the toolbar is visible and the selection didn't change.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsOneWidget);
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 2),
      );

      // Tap again on the same position to hide the toolbar.
      await tester.placeCaretInSuperTextField(2);

      // Ensure the toolbar disappeared and the selection didn't change.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 2),
      );
    });

    testWidgetsOnAndroid("tapping at existing expanded selection places the caret", (tester) async {
      await _pumpTestApp(tester);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Double tap to select "abc".
      await tester.doubleTapAtSuperTextField(2);

      // Ensure the toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsOneWidget);

      // Tap at "ab|c" to place the caret. Pump to avoid a pan gesture.
      await tester.pump(kTapTimeout);
      await tester.placeCaretInSuperTextField(2);

      // Ensure that the toolbar disappeared and the selection changed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 2),
      );
    });

    testWidgetsOnAndroid("hides toolbar when the user taps to move the caret", (tester) async {
      await _pumpTestApp(tester);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Place caret at the beginning of the textfield.
      await tester.placeCaretInSuperTextField(0);

      // Ensure no toolbar is displayed.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);

      // Tap on the drag handle to show the toolbar.
      await tester.tapOnAndroidCollapsedHandle();
      await tester.pump();

      // Ensure that the text field toolbar is visible.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsOneWidget);

      // Place caret at the end of the textfield.
      await tester.placeCaretInSuperTextField(3);

      // Ensure the toolbar disappeared.
      expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  EdgeInsets? padding,
  TextAlign? textAlign,
}) async {
  final textFieldFocusNode = FocusNode();
  const tapRegionGroupdId = "test_super_text_field";

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TapRegion(
          groupId: tapRegionGroupdId,
          onTapOutside: (_) {
            // Unfocus on tap outside so that we're sure that all gesture tests
            // pass when using TapRegion's for focus, because apps should be able
            // to do that.
            textFieldFocusNode.unfocus();
          },
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  child: SuperTextField(
                    focusNode: textFieldFocusNode,
                    tapRegionGroupId: tapRegionGroupdId,
                    padding: padding,
                    textAlign: textAlign ?? TextAlign.left,
                    textController: controller ??
                        AttributedTextEditingController(
                          text: AttributedText('abc'),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
