import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../test_tools.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnAndroid('BACKSPACE deletes previous character when selection is collapsed (on Android)', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpTestApp(tester, controller: controller);

      // Focus the text field
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Place caret at This|. We don't put caret at the end of the text
      // to ensure we are not deleting always the last character
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      // Press backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Ensure text is deleted
      expect(controller.text.text, 'Thi is a text');
    });

    testWidgetsOnAndroid('BACKSPACE deletes selection when selection is expanded (on Android)', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpTestApp(tester, controller: controller);

      // Focus the text field
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Selects ' text'
      controller.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 14,
      );
      await tester.pump();

      // Press backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Ensure text is deleted
      expect(controller.text.text, 'This is a');
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          textController: controller,
        ),
      ),
    ),
  );
}
