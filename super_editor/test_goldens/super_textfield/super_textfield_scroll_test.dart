import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperTextField', () {
    testGoldens("multi-line accounts for padding when jumping scroll position down", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.column(
        wrap: (child) => Row(
          children: [child],
        ),
      )
        ..addScenario(
          'SuperTextField with padding, scrolled to the end (on Android)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          'SuperTextField with padding, scrolled to the end (on iOS)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          'SuperTextField with padding, scrolled to the end (on Desktop)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.desktop,
          ),
        );
      await tester.pumpWidgetBuilder(builder.build());

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_down');
    });

    testGoldens("multi-line accounts for padding when jumping scroll position up", (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: "First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.column(
        wrap: (child) => Row(
          children: [child],
        ),
      )
        ..addScenario(
          'SuperTextField with padding, scrolled to the beginning (on Android)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.android,
          ),
        )
        ..addScenario(
          'SuperTextField with padding, scrolled to the beginning (on iOS)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        )
        ..addScenario(
          'SuperTextField with padding, scrolled to the beginning (on Desktop)',
          _buildTextField(
            textController: controller,
            minLines: 1,
            maxLines: 2,
            maxHeight: 50,
            maxWidth: 200,
            padding: const EdgeInsets.all(10.0),
            configuration: SuperTextFieldPlatformConfiguration.desktop,
          ),
        );
      await tester.pumpWidgetBuilder(builder.build());

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'super_textfield_scrolled_up');
    });
  });
}

Widget _buildTextField({
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
  EdgeInsets? padding,
  SuperTextFieldPlatformConfiguration? configuration,
}) {
  return ConstrainedBox(
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
  );
}
