import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';

import '../test_tools.dart';

void main() {
  group("SuperTextField caret", () {
    // Duration to switch between visible and invisible
    const flashPeriod = Duration(milliseconds: 500);

    testWidgetsOnDesktop("blinks at rest", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),
        ),
      );

      // Press tab to focus SuperTextField
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Ensure caret is visible at start
      expect(_isCaretVisible(tester), true);

      // Trigger a frame with an ellapsed time equal to the flashPeriod,
      // so the caret should change from visible to invisible
      await tester.pump(flashPeriod);

      // Ensure caret is invisible after the flash period
      expect(_isCaretVisible(tester), false);

      // Trigger another frame to make caret visible again
      await tester.pump(flashPeriod);

      // Ensure caret is visible
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnDesktop("does NOT blink while typing", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      // Interval between each key is pressed.
      final typingInterval = (flashPeriod ~/ 2);

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),
        ),
      );

      // Press tab to focus SuperTextField
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("a");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("b");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("c");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("d");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnAllPlatforms("is NOT displayed without a text selection", (tester) async {
      await tester.pumpWidget(
        _buildScaffold(
          child: const SuperTextField(),
        ),
      );
      await tester.pump();

      expect(_isCaretPresent(tester), isFalse);
    });

    testWidgetsOnAllPlatforms("is displayed with focus and a text selection", (tester) async {
      final controller = AttributedTextEditingController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            focusNode: FocusNode()..requestFocus(),
            textController: controller,
          ),
        ),
      );
      await tester.pump();

      expect(_isCaretPresent(tester), isTrue);
    });

    testWidgetsOnAllPlatforms("uses the given caretStyle", (tester) async {
      final controller = AttributedTextEditingController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      const caretStyle = CaretStyle(
        color: Colors.red,
        width: 5,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      );

      await tester.pumpWidget(
        _buildScaffold(
          child: SuperTextField(
            focusNode: FocusNode()..requestFocus(),
            textController: controller,
            caretStyle: caretStyle,
          ),
        ),
      );
      await tester.pump();

      final caret = tester.widget<TextLayoutCaret>(find.byType(TextLayoutCaret));

      expect(caret.style.color, caretStyle.color);
      expect(caret.style.width, caretStyle.width);
      expect(caret.style.borderRadius, caretStyle.borderRadius);
    });
  });
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}

bool _isCaretPresent(WidgetTester tester) {
  final caretMatches = find.byType(TextLayoutCaret).evaluate();
  if (caretMatches.isEmpty) {
    return false;
  }
  final caretState = (caretMatches.single as StatefulElement).state as TextLayoutCaretState;
  return caretState.isCaretPresent;
}

bool _isCaretVisible(WidgetTester tester) {
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return caretPainter.blinkController!.opacity == 1.0;
}
