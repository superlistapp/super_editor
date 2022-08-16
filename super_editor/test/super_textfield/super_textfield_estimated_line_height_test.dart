import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnArbitraryDesktop('computes line height for empty field', (tester) async {
      // We need to load the app fonts, because using Ahem the estimated line height
      // is always equal to the true line height.
      await loadAppFonts();

      // Pump an empty SuperTextField.
      final controller = AttributedTextEditingController();
      await _pumpScaffold(tester, controller: controller);
      await tester.pumpAndSettle();

      // When the text field is empty the line height is estimated.
      final heightWithEmptyText = tester.getSize(find.byType(SuperTextField)).height;

      // Change the text, this should recompute viewport height.
      controller.text = AttributedText(text: 'Leave a message');
      await tester.pumpAndSettle();

      // When the text field has content the line height should be the true line height.
      final heightWithText = tester.getSize(find.byType(SuperTextField)).height;

      // Ensure the text field has ~ the same height when it's empty and when it has content
      expect(heightWithEmptyText.truncate(), equals(heightWithText.truncate()));
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester, {required AttributedTextEditingController controller}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          textController: controller,
          hintBuilder: (context) {
            return const Text(
              'Leave a message',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            );
          },
          hintBehavior: HintBehavior.displayHintUntilTextEntered,
          minLines: 1,
          maxLines: null,
          textStyleBuilder: (_) => const TextStyle(
            fontSize: 16,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    ),
  );
}
