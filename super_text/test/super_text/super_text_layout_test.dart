import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text/super_text.dart';

// TODO: getOffsetAtPosition()
// TODO: getLineHeightAtPosition()
// TODO: getOffsetForCaret()
// TODO: getHeightForCaret()
// TODO: getBoxesForSelection()
// TODO: getCharacterBox()
// TODO: getPositionInFirstLineAtX()
// TODO: getPositionInLastLineAtX()
// TODO: getWordSelectionAt()
// TODO: expandSelection()
// TODO: isTextAtOffset
// TODO: getSelectionInRect()

void main() {
  group("SuperText", () {
    group("text layout", () {
      group("calculates line count", () {
        testWidgets("for empty text", (tester) async {
          await _pumpEmptyText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          expect(textLayout.getLineCount(), 0);
        });

        testWidgets("for one line of text", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: SuperText(
                key: _textKey,
                richText: _oneLineSpan,
              ),
            ),
          );

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          expect(textLayout.getLineCount(), 1);
        });

        testWidgets("for three lines of text", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          expect(textLayout.getLineCount(), 3);
        });
      });

      group("finds precise", () {
        testWidgets("character when text is empty", (tester) async {
          await _pumpEmptyText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          expect(textLayout.getPositionAtOffset(Offset.zero), null);
        });

        testWidgets("character when offset is outside of text", (tester) async {
          await _pumpEmptyText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          expect(textLayout.getPositionAtOffset(const Offset(-50, 0)), null);
        });

        testWidgets("characters in first line", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          final firstLineEstimatedMiddle = textBox.size.height / 6;
          expect(
            textLayout.getPositionAtOffset(Offset(1, firstLineEstimatedMiddle)),
            const TextPosition(offset: 0),
          );

          expect(
            textLayout.getPositionAtOffset(Offset(textBox.size.width / 2, firstLineEstimatedMiddle)),
            const TextPosition(offset: 25, affinity: TextAffinity.upstream),
          );

          expect(
            // Note: an offset == textBox width is considered "outside" the text
            textLayout.getPositionAtOffset(Offset(textBox.size.width - 1, firstLineEstimatedMiddle)),
            const TextPosition(offset: 47, affinity: TextAffinity.upstream),
          );
        });

        testWidgets("characters in second line", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          final secondLineEstimatedMiddle = (textBox.size.height / 6) * 3;
          expect(
            textLayout.getPositionAtOffset(Offset(1, secondLineEstimatedMiddle)),
            const TextPosition(offset: 48),
          );

          expect(
            textLayout.getPositionAtOffset(Offset(textBox.size.width / 2, secondLineEstimatedMiddle)),
            const TextPosition(offset: 71, affinity: TextAffinity.downstream),
          );

          expect(
            // Note: an offset == textBox width is considered "outside" the text
            textLayout.getPositionAtOffset(Offset(textBox.size.width - 1, secondLineEstimatedMiddle)),
            const TextPosition(offset: 93, affinity: TextAffinity.upstream),
          );
        });

        testWidgets("characters in third line", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          final thirdLineEstimatedMiddle = (textBox.size.height / 6) * 5;
          expect(
            textLayout.getPositionAtOffset(Offset(1, thirdLineEstimatedMiddle)),
            const TextPosition(offset: 94),
          );

          expect(
            textLayout.getPositionAtOffset(Offset(textBox.size.width / 2, thirdLineEstimatedMiddle)),
            const TextPosition(offset: 116, affinity: TextAffinity.upstream),
          );

          expect(
            // Note: an offset == textBox width is considered "outside" the text
            textLayout.getPositionAtOffset(Offset(textBox.size.width - 1, thirdLineEstimatedMiddle)),
            const TextPosition(offset: 130, affinity: TextAffinity.upstream),
          );
        });
      });

      group("finds nearest", () {
        testWidgets("TextPosition on the left side", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          final firstLineEstimatedMiddle = textBox.size.height / 6;
          expect(
            textLayout.getPositionNearestToOffset(Offset(0, firstLineEstimatedMiddle)),
            const TextPosition(offset: 0),
          );

          final secondLineEstimatedMiddle = (textBox.size.height / 6) * 3;
          expect(
            textLayout.getPositionNearestToOffset(Offset(0, secondLineEstimatedMiddle)),
            const TextPosition(offset: 48),
          );

          final thirdLineEstimatedMiddle = (textBox.size.height / 6) * 5;
          expect(
            textLayout.getPositionNearestToOffset(Offset(0, thirdLineEstimatedMiddle)),
            const TextPosition(offset: 94),
          );
        });

        testWidgets("TextPosition on the right side", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          final firstLineEstimatedMiddle = textBox.size.height / 6;
          expect(
            textLayout.getPositionNearestToOffset(Offset(800, firstLineEstimatedMiddle)),
            const TextPosition(offset: 47, affinity: TextAffinity.upstream),
          );

          final secondLineEstimatedMiddle = (textBox.size.height / 6) * 3;
          expect(
            textLayout.getPositionNearestToOffset(Offset(800, secondLineEstimatedMiddle)),
            const TextPosition(offset: 93, affinity: TextAffinity.upstream),
          );

          final thirdLineEstimatedMiddle = (textBox.size.height / 6) * 5;
          expect(
            textLayout.getPositionNearestToOffset(Offset(800, thirdLineEstimatedMiddle)),
            const TextPosition(offset: 130, affinity: TextAffinity.upstream),
          );
        });

        testWidgets("TextPosition on the top side", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          expect(
            textLayout.getPositionNearestToOffset(const Offset(0, -50)),
            const TextPosition(offset: 0),
          );

          expect(
            textLayout.getPositionNearestToOffset(Offset(textBox.size.width / 2, -50)),
            const TextPosition(offset: 25, affinity: TextAffinity.upstream),
          );

          expect(
            textLayout.getPositionNearestToOffset(Offset(textBox.size.width, -50)),
            const TextPosition(offset: 47, affinity: TextAffinity.upstream),
          );
        });

        testWidgets("TextPosition on the bottom side", (tester) async {
          await _pumpThreeLinePlainText(tester);

          final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
          final textBox = _textKey.currentContext!.findRenderObject() as RenderBox;

          expect(
            textLayout.getPositionNearestToOffset(Offset(0, textBox.size.height + 50)),
            const TextPosition(offset: 94),
          );

          expect(
            textLayout.getPositionNearestToOffset(Offset(textBox.size.width / 2, textBox.size.height + 50)),
            const TextPosition(offset: 116, affinity: TextAffinity.upstream),
          );

          expect(
            textLayout.getPositionNearestToOffset(Offset(textBox.size.width, textBox.size.height + 50)),
            const TextPosition(offset: 130, affinity: TextAffinity.upstream),
          );
        });
      });

      testWidgets("finds the beginning of lines", (tester) async {
        await _pumpThreeLinePlainText(tester);
        final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;

        // Line 1
        expect(
          textLayout.getPositionAtStartOfLine(const TextPosition(offset: 5)),
          const TextPosition(offset: 0),
        );

        // Line 2
        expect(
          textLayout.getPositionAtStartOfLine(const TextPosition(offset: 55)),
          const TextPosition(offset: 48),
        );

        // Line 3
        expect(
          textLayout.getPositionAtStartOfLine(const TextPosition(offset: 100)),
          const TextPosition(offset: 94),
        );
      });

      testWidgets("finds the end of lines", (tester) async {
        await _pumpThreeLinePlainText(tester);
        final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;

        // Line 1
        expect(
          textLayout.getPositionAtEndOfLine(const TextPosition(offset: 5)),
          const TextPosition(offset: 47, affinity: TextAffinity.upstream),
        );

        // Line 2
        expect(
          textLayout.getPositionAtEndOfLine(const TextPosition(offset: 55)),
          const TextPosition(offset: 93, affinity: TextAffinity.upstream),
        );

        // Line 3
        expect(
          textLayout.getPositionAtEndOfLine(const TextPosition(offset: 100)),
          const TextPosition(offset: 130, affinity: TextAffinity.upstream),
        );
      });

      group("moves a line", () {
        group("up", () {
          testWidgets("from the first line", (tester) async {
            await _pumpThreeLinePlainText(tester);

            final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
            expect(textLayout.getPositionOneLineUp(const TextPosition(offset: 5)), null);
          });

          testWidgets("from the last line", (tester) async {
            await _pumpThreeLinePlainText(tester);

            final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
            expect(
              textLayout.getPositionOneLineUp(const TextPosition(offset: 100)),
              const TextPosition(offset: 55, affinity: TextAffinity.upstream),
            );
          });
        });

        group("down", () {
          testWidgets("from the last line", (tester) async {
            await _pumpThreeLinePlainText(tester);

            final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
            expect(textLayout.getPositionOneLineDown(const TextPosition(offset: 100)), null);
          });

          testWidgets("from the first line", (tester) async {
            await _pumpThreeLinePlainText(tester);

            final textLayout = RenderSuperText.textLayoutFrom(_textKey)!;
            expect(
              textLayout.getPositionOneLineDown(const TextPosition(offset: 5)),
              const TextPosition(offset: 53, affinity: TextAffinity.upstream),
            );
          });
        });
      });
    });
  });
}

Future<void> _pumpThreeLinePlainText(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildScaffold(
      child: SuperText(
        key: _textKey,
        richText: _threeLineSpan,
      ),
    ),
  );
}

Future<void> _pumpEmptyText(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildScaffold(
      child: SuperText(
        key: _textKey,
        richText: const TextSpan(text: "", style: _testTextStyle),
      ),
    ),
  );
}

final _textKey = GlobalKey(debugLabel: "super_text");

const _threeLineSpan = TextSpan(
  text: "This is some text. It is explicitly laid out in\n" // Line indices: 0 -> 47/48 (upstream/downstream)
      "multiple lines so that we don't need to guess\n" // Line indices: 48 ->  93/94 (upstream/downstream)
      "where the layout forces a line break", // Line indices: 94 -> 130
  style: _testTextStyle,
);

const _oneLineSpan = TextSpan(
  text: "This is some text. It is explicitly laid out in", // Line indices: 0 -> 46/47 (upstream/downstream)
  style: _testTextStyle,
);

const _testTextStyle = TextStyle(
  color: Color(0xFF000000),
  fontFamily: 'Roboto',
  fontSize: 20,
);

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: child,
      ),
    ),
  );
}
