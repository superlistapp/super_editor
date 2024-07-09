import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools.dart';
import 'test_tools_goldens.dart';

void main() {
  group("Text selection layer", () {
    const selectionStyle = SelectionHighlightStyle(
      color: defaultSelectionColor,
    );

    testGoldensOnAndroid("paints a full text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, textLayout) {
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

    testGoldensOnAndroid("paints a partial text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, textLayout) {
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

    testGoldensOnAndroid("paints an empty highlight when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, textLayout) {
          return TextLayoutEmptyHighlight(
            textLayout: textLayout,
            style: selectionStyle,
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_small-highlight-when-empty");
    });

    testGoldensOnAndroid("paints no selection when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, textLayout) {
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

  group("Text selection layer with BorderRadius", () {
    final selectionStyle = SelectionHighlightStyle(
      color: defaultSelectionColor,
      borderRadius: BorderRadius.circular(10),
    );

    testGoldensOnAndroid("paints a full text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, textLayout) {
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

      await screenMatchesGolden(tester, "TextSelectionLayer_full-selection-border-radius");
    });

    testGoldensOnAndroid("paints a partial text selection", (tester) async {
      await pumpThreeLinePlainSuperText(
        tester,
        beneathBuilder: (context, textLayout) {
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

      await screenMatchesGolden(tester, "TextSelectionLayer_partial-selection-border-radius");
    });

    testGoldensOnAndroid("paints an empty highlight when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, textLayout) {
          return TextLayoutEmptyHighlight(
            textLayout: textLayout,
            style: selectionStyle,
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_small-highlight-when-empty-border-radius");
    });

    testGoldensOnAndroid("paints no selection when text is empty", (tester) async {
      await pumpEmptySuperText(
        tester,
        beneathBuilder: (context, textLayout) {
          return TextLayoutSelectionHighlight(
            textLayout: textLayout,
            style: selectionStyle,
            selection: null,
          );
        },
      );

      await screenMatchesGolden(tester, "TextSelectionLayer_no-selection-when-empty-border-radius");
    });
  });
}
