import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../../test/super_editor/supereditor_test_tools.dart';
import '../test_tools_goldens.dart';

void main() {
  group("SuperEditor selection >", () {
    group("color >", () {
      testGoldensOnMac("default selection color", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        // Select the whole paragraph so that the selection color is clearly visible.
        await tester.tripleTapInParagraph("1", 0);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFileWithPixelAllowance("goldens/super-editor_selection-color_default.png", 6),
        );
      });

      testGoldensOnMac("custom selection color", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .withSelectionStyles(const SelectionStyles(selectionColor: Colors.deepPurple))
            .useStylesheet(defaultStylesheet.copyWith(
              selectedTextColorStrategy: ({
                required Color originalTextColor,
                required Color selectionHighlightColor,
              }) =>
                  Colors.white,
            ))
            .pump();

        // Select the whole paragraph so that the selection color is clearly visible.
        await tester.tripleTapInParagraph("1", 0);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFileWithPixelAllowance("goldens/super-editor_selection-color_custom.png", 6),
        );
      });
    });
  });
}
