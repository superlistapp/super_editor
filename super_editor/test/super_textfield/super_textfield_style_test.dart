import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_bricks/golden_bricks.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperTextField > DefaultTextStyle >', () {
    testWidgetsOnAllPlatforms('inherits the enclosing DefaultTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(fontFamily: goldenBricks),
              child: SuperTextField(
                textController: AttributedTextEditingController(
                  text: AttributedText('Hello, world!'),
                ),
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

      // Ensure the font family from the default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        goldenBricks,
      );
    });

    testWidgetsOnAllPlatforms('changes visual text when the enclosing default text style changes', (tester) async {
      final styleNotifier = ValueNotifier<TextStyle>(
        const TextStyle(fontFamily: goldenBricks),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
                valueListenable: styleNotifier,
                builder: (context, style, child) {
                  return DefaultTextStyle(
                    style: style,
                    child: SuperTextField(
                      textController: AttributedTextEditingController(
                        text: AttributedText('Hello, world!'),
                      ),
                    ),
                  );
                }),
          ),
        ),
      );

      final textField = find.byType(SuperTextField);
      expect(textField, findsOneWidget);

      // Ensure the font family from the default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        goldenBricks,
      );

      // Change the default text style.
      styleNotifier.value = const TextStyle(
        fontFamily: 'Roboto',
      );
      await tester.pump();

      // Ensure the font family from the new default text style was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontFamily,
        'Roboto',
      );
    });
  });
}

InlineSpan _findSpanAtOffset(
  WidgetTester tester, {
  required int offset,
}) {
  final superText = tester.widget<SuperText>(find.byType(SuperText));
  return superText.richText.getSpanForPosition(TextPosition(offset: offset))!;
}
