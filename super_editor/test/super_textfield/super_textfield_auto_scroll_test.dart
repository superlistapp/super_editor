import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/metrics.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

const screenSizeWithoutKeyboard = Size(400, 800);
const screenSizeWithKeyboard = Size(400, 300);

void main() {
  group('SuperTextField on mobile', () {
    group('with an ancestor Scrollable', () {
      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in single-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Tap to focus the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the global offset where the selection is
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selection is visible in the viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in single-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Tap to focus the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the global offset where the selection is
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selection is visible in the viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('auto scrolls when focused in multi-line', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'This is\na multiline\nSuperTextField',
          lineCount: 3,
        );

        // Tap to focus to the text field
        await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Find the offset of the selected line
        final selectionOffset = _findGlobalCaretOffset(tester);

        // Ensure selected line is visible on viewport
        expect(selectionOffset.dy.floor(), lessThanOrEqualTo(screenSizeWithKeyboard.height));

        // Ensure we scroll only the necessary to reveal the selection, plus a small gap
        expect(
            screenSizeWithKeyboard.height - selectionOffset.dy.floor(), lessThanOrEqualTo(gapBetweenCaretAndKeyboard));

        // Ensure selection doesn't scroll beyond the top
        expect(selectionOffset.dy.floor(), greaterThanOrEqualTo(0));
      });

      _testWidgetsOnMobileWithKeyboard('doest not auto scroll when not focused', (tester, keyboardToggle) async {
        await _pumpTestApp(
          tester,
          text: 'Single line SuperTextField',
          lineCount: 1,
        );

        // Position of the text field before resizing
        final initialTopLeft = tester.getTopLeft(find.byType(SuperTextField));

        // Simulate a keyboard opening, which reduces available screen height.
        await keyboardToggle.open();

        // Position of the text field after resizing
        final finalTopLeft = tester.getTopLeft(find.byType(SuperTextField, skipOffstage: false));

        // Ensure the text field does not cause autoscroll
        expect(finalTopLeft, initialTopLeft);
      });
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required String text,
  required int lineCount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ...List.generate(8, (index) => const ListTile(title: Text("BEFORE"))),
            SuperTextField(
              minLines: lineCount,
              maxLines: lineCount,
              lineHeight: 24,
              textController: AttributedTextEditingController(
                text: AttributedText(text: text),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _testWidgetsOnMobileWithKeyboard(
  String description,
  Future<void> Function(WidgetTester tester, _KeyboardToggle keyboardToggle) test,
) {
  testWidgetsOnMobile(description, (tester) async {
    tester.binding.window
      ..physicalSizeTestValue = screenSizeWithoutKeyboard
      ..platformDispatcher.textScaleFactorTestValue = 1.0
      ..devicePixelRatioTestValue = 1.0;
    addTearDown(() => tester.binding.window.clearAllTestValues());

    final keyboardToggle = _KeyboardToggle(
      tester: tester,
      sizeWithoutKeyboard: screenSizeWithoutKeyboard,
      sizeWithKeyboard: screenSizeWithKeyboard,
    );

    await test(tester, keyboardToggle);
  });
}

class _KeyboardToggle {
  _KeyboardToggle({
    required this.tester,
    required this.sizeWithoutKeyboard,
    required this.sizeWithKeyboard,
    // ignore: unused_element
    this.frameCount = 60,
  });

  final WidgetTester tester;
  final Size sizeWithoutKeyboard;
  final Size sizeWithKeyboard;
  final int frameCount;

  Future<void> open() async {
    double resizedWidth = 0.0;
    double resizedHeight = 0.0;
    double totalWidthResize = sizeWithoutKeyboard.width - sizeWithKeyboard.width;
    double totalHeightResize = sizeWithoutKeyboard.height - sizeWithKeyboard.height;
    double widthShrinkPerFrame = totalWidthResize / frameCount;
    double heightShrinkPerFrame = totalHeightResize / frameCount;
    for (var i = 0; i < frameCount; i++) {
      resizedWidth += widthShrinkPerFrame;
      resizedHeight += heightShrinkPerFrame;
      final currentScreenSize = (sizeWithoutKeyboard - Offset(resizedWidth, resizedHeight)) as Size;
      tester.binding.window.physicalSizeTestValue = currentScreenSize;
      await tester.pumpAndSettle();
    }
  }
}

Offset _findGlobalCaretOffset(WidgetTester tester) {
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return tester.getTopLeft(customPaint) + caretPainter.offset!;
}
