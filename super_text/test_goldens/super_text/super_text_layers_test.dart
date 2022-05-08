import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'super_text_test_tools.dart';

void main() {
  group("SuperText", () {
    group("builds layers", () {
      testGoldens("that can paint line boxes", (tester) async {
        await pumpThreeLinePlainSuperText(tester, beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          final lineCount = textLayout.getLineCount();
          final lineRects = <Rect>[];
          final lineColors = <Color>[];
          TextPosition? textPosition = const TextPosition(offset: 0);

          while (textPosition != null) {
            // Select the line
            final lineSelection = TextSelection(
              baseOffset: textPosition.offset,
              extentOffset: textLayout.getPositionAtEndOfLine(textPosition).offset,
            );
            // Convert the line selection to a rectangle
            lineRects.add(textLayout.getBoxesForSelection(lineSelection).first.toRect());
            // Select a color for this rectangle
            lineColors.add(HSVColor.fromAHSV(1.0, 360.0 * (lineColors.length / lineCount), 1.0, 1.0).toColor());

            textPosition = textLayout.getPositionOneLineDown(textPosition);
          }

          return Stack(
            children: [
              for (int i = 0; i < lineRects.length; i += 1)
                Positioned.fromRect(
                  rect: lineRects[i],
                  child: ColoredBox(color: lineColors[i]),
                ),
            ],
          );
        });

        await screenMatchesGolden(tester, "SuperText_layers_line-boxes");
      });

      testGoldens("that can paint character boxes", (tester) async {
        await pumpThreeLinePlainSuperText(tester, beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          final characterRects = <Rect>[];
          final characterColors = <Color>[];

          final textLength = threeLineTextSpan.toPlainText().length;
          for (int i = 0; i < textLength; i += 1) {
            // Get the bounding rectangle for the character
            characterRects.add(textLayout.getCharacterBox(TextPosition(offset: i)).toRect());
            // Select a color for this character
            characterColors
                .add(HSVColor.fromAHSV(1.0, 360.0 * (characterColors.length / textLength), 1.0, 1.0).toColor());
          }

          return Stack(
            children: [
              for (int i = 0; i < characterRects.length; i += 1)
                Positioned.fromRect(
                  rect: characterRects[i],
                  child: ColoredBox(color: characterColors[i]),
                ),
            ],
          );
        });

        await screenMatchesGolden(tester, "SuperText_layers_character-boxes");
      });

      testGoldens("that can paint carets", (tester) async {
        await pumpThreeLinePlainSuperText(tester, beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          const textPosition = TextPosition(offset: 115);
          final caretOffset = textLayout.getOffsetForCaret(textPosition);
          final caretHeight = textLayout.getHeightForCaret(textPosition)!;
          final caretRectangle = Rect.fromPoints(caretOffset, caretOffset + Offset(2, caretHeight));

          return Stack(
            children: [
              Positioned.fromRect(
                rect: caretRectangle,
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          );
        });

        await screenMatchesGolden(tester, "SuperText_layers_caret");
      });
    });
  });
}
