import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../test_tools.dart';

void main() {
  group('SuperTextField on some bad Android software keyboards', () {
    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a collapsed selection (on Android)', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpScaffold(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Place caret at This|. We don't put caret at the end of the text
      // to ensure we are not deleting always the last character
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.pressBackspace();      

      // Ensure text is deleted
      expect(controller.text.text, 'Thi is a text');
    });

    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a expanded selection (on Android)', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpScaffold(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Selects ' text'
      controller.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 14,
      );
      await tester.pump();

      await tester.pressBackspace();

      // Ensure text is deleted
      expect(controller.text.text, 'This is a');
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300),
          child: SuperTextField(
            textController: controller,
          ),
        ),
      ),
    ),
  );
}
