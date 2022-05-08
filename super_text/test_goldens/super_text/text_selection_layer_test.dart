import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text/src/text_selection_layer.dart';

import 'super_text_test_tools.dart';

void main() {
  group("Text selection layer", () {
    const selectionStyle = SelectionHighlightStyle(
      color: defaultSelectionColor,
    );

    testGoldens("paints a full text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          return TextLayoutSelectionHighlight(
            textLayout: textLayout,
            style: selectionStyle,
            selection: TextSelection(
              baseOffset: 0,
              extentOffset: threeLineTextSpan.toPlainText().length,
            ),
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_full-selection");
    });

    testGoldens("paints a partial text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          return TextLayoutSelectionHighlight(
            textLayout: textLayout,
            style: selectionStyle,
            selection: const TextSelection(
              baseOffset: 35,
              extentOffset: 80,
            ),
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_partial-selection");
    });

    testGoldens("paints an empty highlight when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          return TextLayoutEmptyHighlight(
            textLayout: textLayout,
            style: selectionStyle,
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_small-highlight-when-empty");
    });

    testGoldens("paints no selection when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, getTextLayout) {
          final textLayout = getTextLayout();
          if (textLayout == null) {
            return const SizedBox();
          }

          return TextLayoutSelectionHighlight(
            textLayout: textLayout,
            style: selectionStyle,
            selection: null,
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_no-selection-when-empty");
    });
  });
}
