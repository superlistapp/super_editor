import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';

void main() {
  group('SuperEditor text tools', () {
    group('word expansion', () {
      test('does not expand when there is a space after the caret', () {
        // Notice there is a space at the start
        const text = ' SuperEditor is awesome';
        // Pretend that the caret is at the start of the text and expand by word
        final expandedSelection = expandPositionToWord(text: text, textPosition: const TextPosition(offset: 0));

        // Ensure that the selection didn't change, because it wasn't in a word
        expect(expandedSelection, const TextSelection.collapsed(offset: 0));
      });

      test('does not expand when there are spaces surrounding the caret', () {
        // Notice there is are 2 spaces in the middle
        const text = 'SuperEditor  is awesome';
        // Pretend that the caret is in the middle of 2 spaces of the text and expand by word
        // `SuperEditor | is awesome`
        final expandedSelection = expandPositionToWord(text: text, textPosition: const TextPosition(offset: 12));

        // Ensure that the selection didn't change, because it wasn't in a word
        expect(expandedSelection, const TextSelection.collapsed(offset: 12));
      });

      test('does not expand when there is a space before the caret', () {
        // Notice there is a space at the end
        const text = 'SuperEditor is awesome ';
        // Pretend that the caret is at the end of the text and expand by word
        final expandedSelection =
            expandPositionToWord(text: text, textPosition: const TextPosition(offset: text.length));

        // Ensure that the selection didn't change, because it wasn't in a word
        expect(expandedSelection, const TextSelection.collapsed(offset: text.length));
      });

      test('expand when the caret is just before a word', () {
        // Notice there is a space at first
        const text = ' SuperEditor is awesome';

        // Pretend that the caret is at the start of the text and expand by word
        final expandedSelection = expandPositionToWord(text: text, textPosition: const TextPosition(offset: 1));
        expect(
          expandedSelection,
          const TextSelection(baseOffset: 1, extentOffset: 12),
        );
      });

      test('expand when the caret is in the middle of a word', () {
        const text = 'SuperEditor is awesome';

        // Pretend that the caret is at the start of the text and expand by word
        final expandedSelection = expandPositionToWord(text: text, textPosition: const TextPosition(offset: 6));
        expect(
          expandedSelection,
          const TextSelection(baseOffset: 0, extentOffset: 11),
        );
      });

      test('expand when the caret is at the end of a word', () {
        // Notice there is a space at first
        const text = 'SuperEditor is awesome';

        // Pretend that the caret is at the start of the text and expand by word
        final expandedSelection =
            expandPositionToWord(text: text, textPosition: const TextPosition(offset: text.length));
        expect(
          expandedSelection,
          const TextSelection(baseOffset: text.length - 7, extentOffset: text.length),
        );
      });
    });
  });
}
