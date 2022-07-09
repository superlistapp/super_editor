import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';

void main() {
  // TODO: try this approach:
  // SuperTextField(
  //   customDesktopGesturesBuilder: (context, proseTextBlock, child) {
  //     return ContextMenuTextFieldGestures(
  //       child: child,
  //     );
  //   },
  // );

  group("SuperTextField on desktop", () {
    group("overrides gestures", () {
      testWidgetsOnDesktop("with widget properties", (tester) async {
        int tapDownCount = 0;

        await _pumpScaffold(
          tester,
          child: SuperTextField(
            desktopGestureOverrides: CallbackSuperTextFieldGestureOverrides(onTapDown: (details) {
              tapDownCount += 1;
              return GestureOverrideResult.handled;
            }),
          ),
        );

        // Attempt to place the caret with a tap.
        await tester.tap(find.byType(SuperTextField));
        await tester.pump(kTapMinTime + const Duration(milliseconds: 1));

        // Ensure that our override was called.
        expect(tapDownCount, 1);

        // Ensure that our override prevented text field selection.
        expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: -1));
      });

      testWidgetsOnDesktop("with an ancestor SuperTextFieldDesktopGestureExtensions", (tester) async {
        final textFieldKey = GlobalKey();
        int tapDownCount = 0;

        await _pumpScaffold(
          tester,
          child: SuperTextFieldDesktopGestureExtensions(
            superTextFieldKey: textFieldKey,
            onTapDown: (details) {
              tapDownCount += 1;
              return GestureOverrideResult.handled;
            },
            child: SuperTextField(
              key: textFieldKey,
            ),
          ),
        );

        // Attempt to place the caret with a tap.
        await tester.tap(find.byType(SuperTextField));
        await tester.pump(kTapMinTime + const Duration(milliseconds: 1));

        // Ensure that our override was called.
        expect(tapDownCount, 1);

        // Ensure that our override prevented text field selection.
        expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: -1));
      });
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required Widget child,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300),
            child: child,
          ),
        ),
      ),
    ),
  );
}
