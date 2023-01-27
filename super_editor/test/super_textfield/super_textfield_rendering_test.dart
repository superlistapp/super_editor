import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnAllPlatforms('renders text on the first frame when given a line height', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'Editing text'),
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
  });
}

/// Pumps a widget tree that switches between a [Text] and a [SuperTextField] depending on [showTextField].
Future<void> _pumpSwitchableTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
  required ValueNotifier<bool> showTextField,
  double? lineHeight,
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
                    maxLines: 3,
                  )
                : const Text('');
          },
        ),
      ),
    ),
  );
}
