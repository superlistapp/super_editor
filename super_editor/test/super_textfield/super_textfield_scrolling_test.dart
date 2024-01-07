import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';

import 'super_textfield_inspector.dart';

void main() {
  group("SuperTextField > scrolling >", () {
    group("single line >", () {
      testWidgetsOnAllPlatforms("scroll bar doesn't appear when empty", (tester) async {
        await _pumpSingleLineTextField(tester);

        // The bug that originally caused an issue with empty scrolling (#1749) didn't have
        // a scrollable distance until the 2nd frame. Therefore, we pump one extra frame.
        await tester.pump();
        await tester.pump();

        // Ensure that the text field isn't scrollable (the content shouldn't exceed the viewport).
        expect(SuperTextFieldInspector.hasScrollableExtent(), isFalse);
      });
    });
  });
}

Future<void> _pumpSingleLineTextField(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SuperTextField(
                  textController: controller,
                  hintBuilder: _createHintBuilder("Hint text..."),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  minLines: 1,
                  maxLines: 1,
                  inputSource: TextInputSource.ime,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

WidgetBuilder _createHintBuilder(String hintText) {
  return (BuildContext context) {
    return Text(
      hintText,
      style: const TextStyle(color: Colors.grey),
    );
  };
}
