import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';

void main() {
  group("SuperTextField on desktop", () {
    group("overrides gestures", () {
      testWidgetsOnDesktop("with widget properties", (tester) async {
        int tapDownCount = 0;

        await _pumpScaffold(
          tester,
          child: SuperTextField(
            gestureOverrideBuilder: (context, textLayoutResolver, [child]) {
              return GestureDetector(
                onTapDown: (details) {
                  tapDownCount += 1;
                },
                behavior: HitTestBehavior.translucent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(1.0),
                  ),
                  child: child,
                ),
              );
            },
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
