import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text/super_text.dart';

import 'super_text_test_tools.dart';

void main() {
  group("SuperText", () {
    testWidgets("renders text and layers in a single frame", (tester) async {
      bool didBuildLayerBeneath = false;
      bool didBuildLayerAbove = false;

      await tester.pumpWidget(
        buildTestScaffold(
          child: SuperText(
            key: superTextKey,
            richText: threeLineTextSpan,
            layerBeneathBuilder: (context, TextLayout textLayout) {
              didBuildLayerBeneath = true;

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
            layerAboveBuilder: (context, TextLayout textLayout) {
              didBuildLayerAbove = true;

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
      );

      expect(didBuildLayerBeneath, isTrue);
      expect(didBuildLayerAbove, isTrue);
    });

    testWidgets("doesn't rebuild text layout when text stays the same", (tester) async {
      int layerAboveBuildCount = 0;
      int highlightBuildCount = 0;
      int layerBeneathBuildCount = 0;
      int caretBuildCount = 0;

      final userSelection = ValueNotifier<UserSelection?>(
        const UserSelection(
          highlightStyle: _primaryHighlightStyle,
          caretStyle: _primaryCaretStyle,
          blinkCaret: false,
          selection: TextSelection.collapsed(offset: 0),
        ),
      );

      await tester.pumpWidget(
        buildTestScaffold(
          child: SuperTextAnalytics(
            trackBuilds: true,
            child: SuperText(
              key: superTextKey,
              richText: threeLineTextSpan,
              layerBeneathBuilder: (context, TextLayout textLayout) {
                layerBeneathBuildCount += 1;

                return ValueListenableBuilder<UserSelection?>(
                  valueListenable: userSelection,
                  builder: (context, value, child) {
                    caretBuildCount += 1;

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
                );
              },
              layerAboveBuilder: (context, TextLayout textLayout) {
                layerAboveBuildCount += 1;

                return ValueListenableBuilder<UserSelection?>(
                  valueListenable: userSelection,
                  builder: (context, value, child) {
                    highlightBuildCount += 1;

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
                );
              },
            ),
          ),
        ),
      );

      // Ensure that the SuperText has built exactly 1 time to start off.
      final superTextState1 = (find.byKey(superTextKey).evaluate().first as StatefulElement).state as SuperTextState;
      expect(superTextState1.textBuildCount, 1);
      expect(layerBeneathBuildCount, 1);
      expect(highlightBuildCount, 1);
      expect(layerAboveBuildCount, 1);
      expect(caretBuildCount, 1);

      // Change the user selection, which will rebuild the SuperTextWithSelection
      // using the new selection value.
      userSelection.value = userSelection.value!.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      // Let the widget tree rebuild however it needs to become stable again.
      await tester.pumpAndSettle();

      // Ensure that the text within SuperText didn't rebuild since the last check.
      final superTextState2 = (find.byKey(superTextKey).evaluate().first as StatefulElement).state as SuperTextState;
      // We need to make sure the State objects remained the same because if the
      // original State object was replaced with a new one then the build count
      // will still read `1`, despite two builds taking place.
      expect(superTextState2, superTextState1);
      expect(superTextState2.textBuildCount, 1);

      // Ensure that the highlight and caret sub-trees were rebuilt when the
      // the selection changed, but the layer builders DIDN'T run again (because
      // the layer builders should only run when SuperText tells them to).
      expect(layerBeneathBuildCount, 1);
      expect(highlightBuildCount, 2);
      expect(layerAboveBuildCount, 1);
      expect(caretBuildCount, 2);
    });

    testWidgets("provides access to a TextLayout", (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: SuperText(
            key: superTextKey,
            richText: threeLineTextSpan,
          ),
        ),
      );

      final state = superTextKey.currentState;
      expect(state, isA<ProseTextBlock>());

      final textBlock = state as ProseTextBlock;
      expect(textBlock.textLayout, isA<TextLayout>());
    });
  });
}

const _primaryCaretStyle = CaretStyle(
  width: 2.0,
  color: Colors.black,
);
const _primaryHighlightStyle = SelectionHighlightStyle(
  color: defaultSelectionColor,
);
