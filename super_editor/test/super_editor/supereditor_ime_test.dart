import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/test/ime.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('text input', () {
      testWidgetsOnArbitraryDesktop('applies multiple deltas at the same time', (tester) async {
        // This test simulates an auto-correction scenario,
        // where the IME sends multiple insertion deltas at once.

        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the start of the document.
        await tester.placeCaretInParagraph('1', 0);

        // Send initial delta, insertion of 'Goin'.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaNonTextUpdate(
              oldText: '',
              selection: TextSelection.collapsed(offset: 0),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: '',
              textInserted: 'Goin',
              insertionOffset: 0,
              selection: TextSelection.collapsed(offset: 4),
              composing: TextRange(start: 0, end: 4),
            )
          ],
          getter: imeClientGetter,
        );

        // Send the insertion of 'h'.
        // The current text is 'Goinh'. This is a typo, which will be auto-corrected later.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaNonTextUpdate(
              oldText: 'Goin',
              selection: TextSelection.collapsed(offset: 4),
              composing: TextRange(start: 0, end: 4),
            ),
            TextEditingDeltaInsertion(
              oldText: 'Goin',
              textInserted: 'h',
              insertionOffset: 4,
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange(start: 0, end: 5),
            )
          ],
          getter: imeClientGetter,
        );

        // Simulate the IME changing the composing region.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaNonTextUpdate(
              oldText: 'Goinh',
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange(start: -1, end: -1),
            )
          ],
          getter: imeClientGetter,
        );

        // Send the insertion of '.'.
        // The current text is 'Goinh.'.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaInsertion(
              oldText: 'Goinh',
              textInserted: '.',
              insertionOffset: 5,
              selection: TextSelection.collapsed(offset: 6),
              composing: TextRange(start: -1, end: -1),
            )
          ],
          getter: imeClientGetter,
        );

        // Simulate the auto-correction kicking in.
        // First, delete everything.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaDeletion(
              oldText: 'Goinh.',
              deletedRange: TextRange(start: 0, end: 6),
              selection: TextSelection.collapsed(offset: 0),
              composing: TextRange(start: -1, end: -1),
            )
          ],
          getter: imeClientGetter,
        );

        // Send the insertion of the auto-corrected word,
        // followed by the insertion of the '.' that were typed.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaInsertion(
              oldText: '',
              textInserted: 'Going',
              insertionOffset: 0,
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaInsertion(
              oldText: 'Going',
              textInserted: '.',
              insertionOffset: 5,
              selection: TextSelection.collapsed(offset: 6),
              composing: TextRange(start: -1, end: -1),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the text was inserted.
        expect(
          SuperEditorInspector.findTextInParagraph('1').text,
          'Going.',
        );
      });
    });
  });
}
