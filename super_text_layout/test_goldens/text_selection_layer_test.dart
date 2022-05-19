import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'test_tools.dart';

void main() {
  group("Text selection layer", () {
    const selectionStyle = SelectionHighlightStyle(
      color: defaultSelectionColor,
    );

    testGoldens("paints a full text selection", (tester) async {
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

    testGoldens("paints a partial text selection", (tester) async {
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

    testGoldens("paints an empty highlight when text is empty", (tester) async {
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

    testGoldens("paints no selection when text is empty", (tester) async {
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
}
