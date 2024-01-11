import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';

import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

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

      testWidgetsOnArbitraryDesktop("auto scrolls when caret moves beyond viewport edge", (tester) async {
        const textFieldWidth = 400.0;

        await _pumpSingleLineTextField(
          tester,
          controller: AttributedTextEditingController(
            text: AttributedText(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget."),
          ),
          width: textFieldWidth,
        );

        // Place the caret at the beginning of the text.
        await tester.placeCaretInSuperTextField(0);

        // Ensure the text field has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, isTrue);

        // Move the caret to the right a large number of times, such that it's
        // guaranteed to push beyond the right edge of the viewport. Ensure that
        // the caret remains visible at all times.
        for (int i = 0; i < 100; i += 1) {
          await tester.pressRightArrow();
          await tester.pump();

          // Ensure that the caret is still visible.
          // TODO: Change lessThanOrEqualTo() to strictly lessThan() after #1770
          expect(SuperTextFieldInspector.findCaretRectInViewport()!.left, lessThanOrEqualTo(textFieldWidth));
        }
      });
    });
  });
}

Future<void> _pumpSingleLineTextField(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  double? width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 400,
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
