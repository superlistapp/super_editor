import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text/super_text.dart';

import 'super_text_test_tools.dart';

const primaryCaretStyle = CaretStyle(color: Colors.black);

void main() {
  group("Caret layer", () {
    group("with a single caret", () {
      testWidgets("can switch out the BlinkController", (tester) async {
        // Start with built-in BlinkController
        final blinkControllerHolder = ValueNotifier<BlinkController?>(null);
        await tester.pumpWidget(
          buildTestScaffold(
            child: SuperText(
              richText: threeLineTextSpan,
              layerAboveBuilder: (context, textLayout) {
                return Stack(
                  children: [
                    // We switch the BlinkController using a builder so that we don't
                    // risk replacing the entire widget tree across pumps. We need to
                    // retain the same State object for the TextLayoutCaret, so that
                    // we can test the didUpdateWidget() behavior.
                    ValueListenableBuilder(
                      valueListenable: blinkControllerHolder,
                      builder: (context, value, child) {
                        return TextLayoutCaret(
                          textLayout: textLayout,
                          blinkController: blinkControllerHolder.value,
                          style: primaryCaretStyle,
                          position: const TextPosition(offset: 35),
                          blinkCaret: false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );

        // Give SuperText time to layout its layers.
        await tester.pumpAndSettle();

        // Switch to an external BlinkController
        blinkControllerHolder.value = BlinkController(tickerProvider: tester);

        // Give the Flutter pipeline time to rebuild after the ValueNotifier change.
        await tester.pumpAndSettle();

        // Switch back an internal BlinkController
        blinkControllerHolder.value = null;

        // Give the Flutter pipeline time to rebuild after the ValueNotifier change.
        await tester.pumpAndSettle();

        // As long as this test completes without an error, it should be the
        // case that the BlinkController was successfully switched from an internal
        // controller to an external controller, and then back.
      });

      testGoldens("paints a normal caret", (tester) async {
        await pumpThreeLinePlainSuperText(
          tester,
          aboveBuilder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle,
                  position: const TextPosition(offset: 35),
                  blinkCaret: false,
                ),
              ],
            );
          },
        );

        await screenMatchesGolden(tester, "CaretLayer_single-caret_normal");
      });

      testGoldens("paints caret styles", (tester) async {
        await pumpThreeLinePlainSuperText(
          tester,
          aboveBuilder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: const CaretStyle(
                    width: 4,
                    color: Colors.red,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  position: const TextPosition(offset: 35),
                  blinkCaret: false,
                ),
              ],
            );
          },
        );

        await screenMatchesGolden(tester, "CaretLayer_single-caret_decorated");
      });
    });

    group("with multiple carets", () {
      testGoldens("paints multiple carets", (tester) async {
        await pumpThreeLinePlainSuperText(
          tester,
          aboveBuilder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle,
                  position: const TextPosition(offset: 35),
                  blinkCaret: false,
                ),
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle.copyWith(color: Colors.purpleAccent),
                  position: const TextPosition(offset: 83),
                  blinkCaret: false,
                ),
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle.copyWith(color: Colors.green),
                  position: const TextPosition(offset: 16),
                  blinkCaret: false,
                ),
              ],
            );
          },
        );

        await screenMatchesGolden(tester, "CaretLayer_multi-caret");
      });

      testGoldens("paints two carets at the same position", (tester) async {
        await pumpThreeLinePlainSuperText(
          tester,
          aboveBuilder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle,
                  position: const TextPosition(offset: 35),
                  blinkCaret: false,
                ),
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: primaryCaretStyle.copyWith(color: Colors.purpleAccent),
                  position: const TextPosition(offset: 35),
                  blinkCaret: false,
                ),
              ],
            );
          },
        );

        await screenMatchesGolden(tester, "CaretLayer_two-carets-same-position");
      });
    });
  });
}
