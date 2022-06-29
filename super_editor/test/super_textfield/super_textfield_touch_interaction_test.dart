import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';

void main() {
  group('SuperTextField touch interaction', () {
    group('tapping in an empty space selects the end of the text', () {
      testWidgetsOnMobile("when having no selection", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a position without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });

      testWidgetsOnMobile("when having a valid selection", (tester) async {
        await _pumpTestApp(
          tester,
          selection: const TextSelection.collapsed(offset: 0),
        );

        // Tap in a position without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping in an area containing text moves selection to tap position', () {
      testWidgetsOnMobile("when having no selection", (tester) async {
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

      testWidgetsOnMobile("when having a valid selection", (tester) async {
        await _pumpTestApp(
          tester,
          selection: const TextSelection.collapsed(offset: 2),
        );

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

Future<void> _pumpTestApp(
  WidgetTester tester, {
  TextSelection? selection,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          lineHeight: 16,
          textController: AttributedTextEditingController(
            text: AttributedText(text: "abc"),
            selection: selection,
          ),
        ),
      ),
    ),
  );
}
