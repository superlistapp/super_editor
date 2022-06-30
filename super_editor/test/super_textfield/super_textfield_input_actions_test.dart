import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

void main() {
  group("SuperTextField input actions", () {
    testWidgetsOnMobile("unfocus on DONE", (tester) async {
      FocusNode focusNode = FocusNode();      

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SuperTextField(
                focusNode: focusNode,
                lineHeight: 16,                
              ),
            ),
          ),
        ),
      );

      // Focus SuperTextField. This should show the software keyboard
      focusNode.requestFocus();
      await tester.pump();

      // Ensure we have focus
      expect(focusNode.hasFocus, true);

      // Simulate a tap at the action button
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      
      // Ensure focus was removed
      expect(focusNode.hasFocus, false);
    });
  });
}
