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
      );

      // Let the underlying SuperText layout however many times it needs so that it
      // builds and paints its decoration layers.
      await tester.pumpAndSettle();

      // Get the build count before changing the user's selection.
      final superTextState1 = (find.byType(SuperText).evaluate().first as StatefulElement).state as SuperTextState;
      final buildCountBeforeSelectionChange = superTextState1.buildCount;

      // Change the user selection, which will rebuild the SuperTextWithSelection
      // using the new selection value.
      userSelection.value = userSelection.value!.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      // Let the widget tree rebuild however it needs to become stable again.
      await tester.pumpAndSettle();

      // Get the build count after handling the user's selection change.
      final superTextState2 = (find.byType(SuperText).evaluate().first as StatefulElement).state as SuperTextState;
      final buildCountAfterSelectionChange = superTextState2.buildCount;

      // Ensure that the underlying SuperText widget didn't run another build()
      // call after we moved the user's selection.
      expect(buildCountBeforeSelectionChange, buildCountAfterSelectionChange);
    });
  });
}
