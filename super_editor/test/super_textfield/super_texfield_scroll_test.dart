import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../test_tools.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnAllPlatforms('single-line jumps scroll position horizontally as the user types', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "ABCDEFG"),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        maxWidth: 50,
      );

      // Move selection to the end of the text
      // TODO: change to simulate user input when IME simulation is available
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();

      // Position at the end of the viewport
      final viewportRight = tester.getBottomRight(find.byType(SuperTextField)).dx;

      // Position at the end of the text
      final textRight = tester.getBottomRight(find.byType(SuperText)).dx;

      // Ensure the text field scrolled its content horizontally
      expect(textRight, lessThanOrEqualTo(viewportRight));
    });

    testWidgetsOnAllPlatforms('multi-line jumps scroll position vertically as the user types', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "A\nB\nC\nD"),
      );

      // Pump the widget tree with a SuperTextField with a maxHeight smaller
      // than the text heght
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 20,
      );

      // Move selection to the end of the text
      // TODO: change to simulate user input when IME simulation is available
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();

      // Position at the end of the viewport
      final viewportBottom = tester.getBottomRight(find.byType(SuperTextField)).dy;

      // Position at the end of the text
      final textBottom = tester.getBottomRight(find.byType(SuperText)).dy;

      // Ensure the text field scrolled its content vertically
      expect(textBottom, lessThanOrEqualTo(viewportBottom));
    });

    testWidgetsOnDesktop("doesn't scroll vertically when maxLines is null", (tester) async {
      // With the Ahem font the estimated line height is equal to the true line height
      // so we need to use a custom font.
      await loadAppFonts();

      // We use some padding because it affects the viewport height calculation.
      const verticalPadding = 6.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300),
              child: SuperDesktopTextField(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
                minLines: 1,
                maxLines: null,
                textController: AttributedTextEditingController(
                  text: AttributedText(text: "SuperTextField"),
                ),
                textStyleBuilder: (_) => const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // In the running app, the estimated line height and actual line height differ. 
      // This test ensures that we account for that. Ideally, this test would check that the scrollview doesn't scroll. 
      // However, in test suites, the estimated and actual line heights are always identical.
      // Therefore, this test ensures that we add up the appropriate dimensions, 
      // rather than verify the scrollview's max scroll extent.

      final viewportHeight = tester.getRect(find.byType(SuperTextFieldScrollview)).height;

      final layoutState = (find.byType(SuperDesktopTextField).evaluate().single as StatefulElement).state as SuperDesktopTextFieldState;
      final contentHeight = layoutState.textLayout.getLineHeightAtPosition(const TextPosition(offset: 0));

      // Vertical padding is added to both top and bottom
      final totalHeight = contentHeight + (verticalPadding * 2);

      // Ensure the viewport is big enough so the text doesn't scroll vertically
      expect(viewportHeight, greaterThanOrEqualTo(totalHeight));
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: SuperTextField(
            textController: textController,
            lineHeight: 20,
            textStyleBuilder: (_) => const TextStyle(fontSize: 20),
            minLines: minLines,
            maxLines: maxLines,
          ),
        ),
      ),
    ),
  );
}
