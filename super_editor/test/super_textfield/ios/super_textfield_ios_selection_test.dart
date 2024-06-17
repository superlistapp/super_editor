import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/toolbar.dart';
import 'package:super_editor/super_text_field.dart';

import '../super_textfield_inspector.dart';

void main() {
  group("SuperTextField mobile selection > iOS", () {
    group("on tap >", () {
      testWidgetsOnIos("when beyond first character > places caret at end of word", (tester) async {
        // TODO: Add this test - for an example, see the Super Editor version: super_editor_ios_selection_test.dart
        //       This test isn't implemented because when I got to it we didn't have any WidgetTester
        //       extensions to tap to place the caret. Create those extensions and then implement this.
        //       Issue: https://github.com/superlistapp/super_editor/issues/2098
      }, skip: true);

      testWidgetsOnIos("when near first character > places caret at start of word", (tester) async {
        // TODO: Add this test - for an example, see the Super Editor version: super_editor_ios_selection_test.dart
        //       This test isn't implemented because when I got to it we didn't have any WidgetTester
        //       extensions to tap to place the caret. Create those extensions and then implement this.
        //       Issue: https://github.com/superlistapp/super_editor/issues/2098
      }, skip: true);
    });

    testWidgetsOnIos("tapping on caret toggles the toolbar", (tester) async {
      await _pumpScaffold(tester);

      // Ensure there's no selection to begin with, and no toolbar is displayed.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: -1));
      expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);

      // Place the caret at the end of the text by tapping in empty space at the center
      // of the text field.
      await tester.tap(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 3));

      // Tap again in the empty space by tapping in the center of the text field.
      await tester.tap(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);

      // Ensure that the text field toolbar is visible.
      expect(find.byType(IOSTextEditingFloatingToolbar), findsOneWidget);

      // Tap a third time in the empty space by tapping in the center of the text field.
      await tester.tap(find.byType(SuperTextField));
      await tester.pumpAndSettle(kDoubleTapTimeout);

      // Ensure that the text field toolbar disappeared.
      expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  EdgeInsets? padding,
  TextAlign? textAlign,
}) async {
  final textFieldFocusNode = FocusNode();
  const tapRegionGroupId = "test_super_text_field";

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TapRegion(
          groupId: tapRegionGroupId,
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
                    tapRegionGroupId: tapRegionGroupId,
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
