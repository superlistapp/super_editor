import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnAllPlatforms('renders text on the first frame when given a line height', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText('Editing text'),
      );

      // Indicates whether we should display the Text or the SuperTextField.
      final showTextField = ValueNotifier<bool>(false);

      // Pump the widget tree showing the Text widget.
      await _pumpSwitchableTestApp(
        tester,
        controller: controller,
        showTextField: showTextField,
        lineHeight: 16,
      );

      // Switch to display the SuperTextField.
      showTextField.value = true;

      // Pump exactly one frame to inspect if the text was rendered.
      await tester.pump();

      // Ensure the SuperTextField rendered the text.
      expect(find.text('Editing text', findRichText: true), findsOneWidget);
    });

    testWidgetsOnMobile('expands to respect minLines', (tester) async {
      // Indicates whether we should display the Text or the SuperTextField.
      final showTextField = ValueNotifier<bool>(false);

      // Pump the widget tree showing the Text widget.
      await _pumpSwitchableTestApp(
        tester,
        controller: AttributedTextEditingController(
          text: AttributedText('1'),
        ),
        showTextField: showTextField,
        minLines: 5,
      );

      // Switch to display the SuperTextField, so we can inspect it on its first frame.
      showTextField.value = true;
      await tester.pump();

      // Ensure the text is rendered in the first frame.
      expect(find.text('1', findRichText: true), findsOneWidget);

      // Ensure the text field expanded to the height of minLines.
      final textHeight = tester.getSize(find.byType(SuperText)).height;
      final textFieldHeight = tester.getSize(find.byType(SuperTextField)).height;
      final minLinesHeight = textHeight * 5;
      expect(textFieldHeight, moreOrLessEquals(minLinesHeight));
    });

    testWidgetsOnMobile('shrinks to fit maxLines', (tester) async {
      // Indicates whether we should display the Text or the SuperTextField.
      final showTextField = ValueNotifier<bool>(false);

      // Pump the widget tree showing the Text widget.
      await _pumpSwitchableTestApp(
        tester,
        controller: AttributedTextEditingController(
          text: AttributedText('1\n2\n3\n4\n5\n6'),
        ),
        showTextField: showTextField,
        maxLines: 3,
      );

      // Switch to display the SuperTextField, so we can inspect it on its first frame.
      showTextField.value = true;
      await tester.pump();

      // Ensure the text is rendered in the first frame.
      expect(find.text('1\n2\n3\n4\n5\n6', findRichText: true), findsOneWidget);

      // Ensure the text field shrank to half of the text size.
      final textHeight = tester.getSize(find.byType(SuperText)).height;
      final textFieldHeight = tester.getSize(find.byType(SuperTextField)).height;
      final maxLinesHeight = textHeight / 2;
      expect(textFieldHeight, moreOrLessEquals(maxLinesHeight));
    });

    testWidgetsOnAllPlatforms('renders a hint with baseline cross-axis alignment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperTextField(
              textController: AttributedTextEditingController(),
              minLines: 1,
              maxLines: 3,
              hintBuilder: (context) => const Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Hint one'),
                  Text('Hint two'),
                ],
              ),
            ),
          ),
        ),
      );

      // Reaching this point means that SuperTextField was able to render without errors.
    });
  });
}

/// Pumps a widget tree that switches between a [Text] and a [SuperTextField] depending on [showTextField].
Future<void> _pumpSwitchableTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
  required ValueNotifier<bool> showTextField,
  double? lineHeight,
  int? minLines,
  int? maxLines,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: showTextField,
          builder: (context, _) {
            return showTextField.value
                ? SuperTextField(
                    textController: controller,
                    lineHeight: lineHeight,
                    minLines: minLines,
                    maxLines: maxLines,
                  )
                : const Text('');
          },
        ),
      ),
    ),
  );
}
