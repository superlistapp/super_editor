import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';

void main() {
  group('SuperTextField gestures', () {
    group('tapping in empty space places the caret at the end of the text', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping in an area containing text places the caret at tap position', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });
    });
  });
}

Future<void> _pumpTestApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          lineHeight: 16,
          textController: AttributedTextEditingController(
            text: AttributedText(text: "abc"),
          ),
        ),
      ),
    ),
  );
}
