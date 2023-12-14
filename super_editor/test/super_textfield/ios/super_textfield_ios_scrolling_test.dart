import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_text_field.dart';

import '../super_textfield_inspector.dart';
import '../super_textfield_robot.dart';

void main() {
  group("SuperTextField > scrolling >", () {
    testWidgetsOnIos('auto-scrolls to caret position upon widget initialization', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );
      controller.selection = TextSelection.collapsed(offset: controller.text.length);

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      print(
          "Controller extent: ${controller.selection.extentOffset}, scroll offset: ${SuperTextFieldInspector.findScrollOffset()}");

      // Ensure that the text field auto-scrolled to the end, where the caret should be placed.
      expect(SuperTextFieldInspector.isScrolledToEnd(), isTrue);
    });

    testWidgetsOnIos('single-line auto-scrolls to the right', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      await tester.placeCaretInSuperTextField(0);
      expect(controller.selection.extentOffset, 0);

      // Drag caret from left side of text field to right side of text field, into the
      // right auto-scroll regin.
      final gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(190, 0));

      // Pump a few more frames and ensure that every frame moves the caret further.
      int previousCaretPosition = controller.selection.extentOffset;
      for (int i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        final newCaretPosition = controller.selection.extentOffset;
        expect(newCaretPosition, greaterThan(previousCaretPosition));
        previousCaretPosition = newCaretPosition;
      }
      print("Caret offset after auto-scroll: ${SuperTextFieldInspector.findSelection()}");

      // Log the scroll offset to make sure that the scroll offset doesn't jump back
      // to the left when we move out of the auto-scroll region. This is a glitch that
      // we saw in #1673.
      final scrollOffsetAfterAutoScroll = SuperTextFieldInspector.findScrollOffset();
      print("Scroll offset after auto-scroll: $scrollOffsetAfterAutoScroll");

      // Drag back to the left to leave the auto-scroll region.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();

      // Pump a few frames to ensure that we're the selection isn't jumping around
      // in a glitchy manner.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Ensure that when we moved slightly back to the left, to move out of the auto-scroll
      // region, the scroll offset didn't jump somewhere else.
      expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);

      // Release the gesture.
      await gesture.up();

      print("Final caret offset: ${SuperTextFieldInspector.findSelection()}");
    });

    testWidgetsOnIos('single-line auto-scrolls to the left', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("This is long text that extends beyond the right side of the text field."),
      );
      final startCaretPosition = controller.text.length - 3;
      controller.selection = TextSelection.collapsed(offset: startCaretPosition);

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        // This width is important because it determines how far we need to drag the caret
        // to the right to enter the auto-scroll region.
        maxWidth: 200,
      );

      print(
          "Controller extent: ${controller.selection.extentOffset}, scroll offset: ${SuperTextFieldInspector.findScrollOffset()}");

      // Begin with the caret at the end of the text, scrolled all the way to the right.
      expect(controller.selection.extentOffset, startCaretPosition);
      // expect(SuperTextFieldInspector.isScrolledToEnd(), isTrue);

      // Tap on the text field to give it focus, so that the caret appears.
      await tester.placeCaretInSuperTextField(startCaretPosition);

      // Drag caret from right side of text field to left side of text field, into the
      // left auto-scroll regin.
      final gesture = await tester.dragCaretByDistanceInSuperTextField(const Offset(-190, 0));

      // Pump a few more frames and ensure that every frame moves the caret further.
      int previousCaretPosition = controller.selection.extentOffset;
      for (int i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        final newCaretPosition = controller.selection.extentOffset;
        expect(newCaretPosition, lessThan(previousCaretPosition));
        previousCaretPosition = newCaretPosition;
      }
      print("Caret offset after auto-scroll: ${SuperTextFieldInspector.findSelection()}");

      // // Log the scroll offset to make sure that the scroll offset doesn't jump back
      // // to the left when we move out of the auto-scroll region. This is a glitch that
      // // we saw in #1673.
      // final scrollOffsetAfterAutoScroll = SuperTextFieldInspector.findScrollOffset();
      // print("Scroll offset after auto-scroll: $scrollOffsetAfterAutoScroll");
      //
      // // Drag back to the left to leave the auto-scroll region.
      // await gesture.moveBy(const Offset(-50, 0));
      // await tester.pump();
      //
      // // Pump a few frames to ensure that we're the selection isn't jumping around
      // // in a glitchy manner.
      // await tester.pump();
      // await tester.pump();
      // await tester.pump();
      //
      // // Ensure that when we moved slightly back to the left, to move out of the auto-scroll
      // // region, the scroll offset didn't jump somewhere else.
      // expect(SuperTextFieldInspector.findScrollOffset(), scrollOffsetAfterAutoScroll);
      //
      // // Release the gesture.
      // await gesture.up();
      //
      // print("Final caret offset: ${SuperTextFieldInspector.findSelection()}");
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
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
              padding: padding,
            ),
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}
