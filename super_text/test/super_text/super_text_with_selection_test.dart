import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text/super_text.dart';

import 'super_text_test_tools.dart';

const _highlightStyle = SelectionHighlightStyle(color: defaultSelectionColor);
const _caretStyle = CaretStyle(color: Color(0xFF000000));

void main() {
  group("SuperTextWithSelection", () {
    testWidgets("doesn't rebuild text layout when text stays the same", (tester) async {
      final userSelection = ValueNotifier<UserSelection?>(
        const UserSelection(
          highlightStyle: _highlightStyle,
          caretStyle: _caretStyle,
          blinkCaret: false,
          selection: TextSelection.collapsed(offset: 0),
        ),
      );

      await tester.pumpWidget(
        buildTestScaffold(
          child: SuperTextAnalytics(
            trackBuilds: true,
            child: ValueListenableBuilder<UserSelection?>(
              valueListenable: userSelection,
              builder: (context, value, child) {
                return SuperTextWithSelection.single(
                  richText: threeLineTextSpan,
                  userSelection: value,
                );
              },
            ),
          ),
        ),
      );

      // Ensure that the SuperText has built exactly 1 time to start off.
      final superTextState1 = (find.byType(SuperText).evaluate().first as StatefulElement).state as SuperTextState;
      expect(superTextState1.textBuildCount, 1);

      // Change the user selection, which will rebuild the SuperTextWithSelection
      // using the new selection value.
      userSelection.value = userSelection.value!.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      // Let the widget tree rebuild however it needs to become stable again.
      await tester.pumpAndSettle();

      // Ensure that the text within SuperText didn't rebuild since the last check.
      final superTextState2 = (find.byType(SuperText).evaluate().first as StatefulElement).state as SuperTextState;
      // We need to make sure the State objects remained the same because if the
      // original State object was replaced with a new one then the build count
      // will still read `1`, despite two builds taking place.
      expect(superTextState2, superTextState1);
      expect(superTextState2.textBuildCount, 1);
    });
  });
}
