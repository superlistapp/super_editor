import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text/super_text.dart';

import 'super_text_test_tools.dart';

void main() {
  testWidgets("super duper text", (tester) async {
    BlinkController.indeterminateAnimationsEnabled = true;

    await tester.pumpWidget(
      buildTestScaffold(
        child: SuperText(
          key: superTextKey,
          richText: threeLineTextSpan,
          layerBeneathBuilder: SuperDuperTextLayoutLayer(
            builder: (context, textLayout) {
              print("Building SuperDuperTextLayoutLayer beneath");
              print(" - context: $context");
              print(" - textLayout: $textLayout");
              return Stack(
                children: [
                  TextLayoutSelectionHighlight(
                    textLayout: textLayout,
                    style: _primaryHighlightStyle,
                    selection: const TextSelection(baseOffset: 11, extentOffset: 21),
                  ),
                ],
              );
            },
          ),
          layerAboveBuilder: SuperDuperTextLayoutLayer(
            builder: (context, textLayout) {
              print("Building SuperDuperTextLayoutLayer above");
              print(" - context: $context");
              print(" - textLayout: $textLayout");
              return Stack(
                children: [
                  TextLayoutCaret(
                    textLayout: textLayout,
                    style: _primaryCaretStyle,
                    position: const TextPosition(offset: 21),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    print("");
    print("-------");
    print("-------");
    print("");

    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });
}

const _primaryCaretStyle = CaretStyle(
  width: 2.0,
  color: Colors.black,
);
const _primaryHighlightStyle = SelectionHighlightStyle(
  color: defaultSelectionColor,
);
