import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';

void main() {
  group('text_tools.dart', () {
    group('expand position to word', () {
      test('does not expand when there is no word next to the caret', () {
        // Notice there is a space at first
        const text = ' SuperEditor is awesome';
        // Place a collapsed selection at "| SuperEditor is awesome"
        expect(
          const TextSelection.collapsed(offset: 0),
          expandPositionToWord(text: text, textPosition: const TextPosition(offset: 0)),
        );
      });
      test('expand when there is a word next to the caret', () {
        // Notice there is a space at first
        const text = ' SuperEditor is awesome';
        // Place a collapsed selection at " |SuperEditor is awesome"
        expect(
          const TextSelection(baseOffset: 1, extentOffset: 12),
          expandPositionToWord(text: text, textPosition: const TextPosition(offset: 1)),
        );
      });
    });
  });
}
