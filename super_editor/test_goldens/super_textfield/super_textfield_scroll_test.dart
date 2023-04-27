import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperTextField', () {
    testGoldens("multi-line accounts for padding when jumping scroll position vertically (on Android)", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Pump the widget tree with a SuperTextField which is two lines tall.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 50,
        maxWidth: 200,
        padding: const EdgeInsets.all(10.0),
        configuration: SuperTextFieldPlatformConfiguration.android,
      );

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_down_android');

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_up_android');
    });

    testGoldens("multi-line accounts for padding when jumping scroll position vertically (on iOS)", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Pump the widget tree with a SuperTextField which is two lines tall.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 50,
        maxWidth: 200,
        padding: const EdgeInsets.all(10.0),
        configuration: SuperTextFieldPlatformConfiguration.iOS,
      );

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_down_ios');

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_up_ios');
    });

    testGoldens("multi-line accounts for padding when jumping scroll position vertically (on iOS)", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Pump the widget tree with a SuperTextField which is two lines tall.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 50,
        maxWidth: 200,
        padding: const EdgeInsets.all(10.0),
        configuration: SuperTextFieldPlatformConfiguration.desktop,
      );

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_down_desktop');

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_up_desktop');
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
  EdgeInsets? padding,
  SuperTextFieldPlatformConfiguration? configuration,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? double.infinity,
              maxHeight: maxHeight ?? double.infinity,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.yellow,
                border: Border.all(),
              ),
              child: SuperTextField(
                textController: textController,
                lineHeight: 20,
                textStyleBuilder: (_) => const TextStyle(fontSize: 20, color: Colors.black, fontFamily: 'Roboto'),
                minLines: minLines,
                maxLines: maxLines,
                padding: padding,
                configuration: configuration,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}
