import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/strings.dart';

void main() {
  group("Strings", () {
    group("find upstream", () {
      test("1 character", () {
        expect("a💙c".moveOffsetUpstreamByCharacter(0), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(1), 0);
        expect("a💙c".moveOffsetUpstreamByCharacter(3), 1);
        expect("a💙c".moveOffsetUpstreamByCharacter(4), 3);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(-1), throwsException);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(5), throwsException);
      });

      test("2 characters", () {
        expect("a💙c".moveOffsetUpstreamByCharacter(0, characterCount: 2), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(1, characterCount: 2), null);
        expect("a💙c".moveOffsetUpstreamByCharacter(3, characterCount: 2), 0);
        expect("a💙c".moveOffsetUpstreamByCharacter(4, characterCount: 2), 1);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(-1, characterCount: 2), throwsException);
        expect(() => "a💙c".moveOffsetUpstreamByCharacter(5, characterCount: 2), throwsException);
      });

      group("a word", () {
        test('separated by space', () {
          expect("move a💙c words".moveOffsetUpstreamByWord(15), 10);
          expect("move a💙c words".moveOffsetUpstreamByWord(10), 5);
          expect("move a💙c words".moveOffsetUpstreamByWord(9), 5);
          expect("move a💙c words".moveOffsetUpstreamByWord(8), 5);
          expect("move a💙c words".moveOffsetUpstreamByWord(4), 0);
          expect("move a💙c words".moveOffsetUpstreamByWord(0), null);
          expect(() => "move a💙c words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move a💙c words".moveOffsetUpstreamByWord(16), throwsException);
        });

        test("separated by multiple spaces", () {
          expect("move   words".moveOffsetUpstreamByWord(12), 7);
          expect("move   words".moveOffsetUpstreamByWord(7), 0);
          expect("move   words".moveOffsetUpstreamByWord(6), 0);
          expect("move   words".moveOffsetUpstreamByWord(4), 0);
          expect("move   words".moveOffsetUpstreamByWord(0), null);
          expect(() => "move   words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move   words".moveOffsetUpstreamByWord(13), throwsException);
        });

        test("separated by punctuation", () {
          expect("move.words".moveOffsetUpstreamByWord(10), 5);
          expect("move.words".moveOffsetUpstreamByWord(5), 0);
          expect("move.words".moveOffsetUpstreamByWord(4), 0);
          expect("move.words".moveOffsetUpstreamByWord(0), null);
          expect(() => "move.words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move.words".moveOffsetUpstreamByWord(11), throwsException);
        });

        test("separated by punctuation and spaces", () {
          expect("move. words".moveOffsetUpstreamByWord(11), 6);
          expect("move. words".moveOffsetUpstreamByWord(6), 0);
          expect("move. words".moveOffsetUpstreamByWord(5), 0);
          expect("move. words".moveOffsetUpstreamByWord(4), 0);
          expect("move. words".moveOffsetUpstreamByWord(0), null);
          expect(() => "move. words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move. words".moveOffsetUpstreamByWord(12), throwsException);
        });

        test("separated by multi-byte punctuation", () {
          expect("move\u{10B3F}words".moveOffsetUpstreamByWord(11), 6);
          expect("move\u{10B3F}words".moveOffsetUpstreamByWord(6), 0);
          expect("move\u{10B3F}words".moveOffsetUpstreamByWord(4), 0);
          expect("move\u{10B3F}words".moveOffsetUpstreamByWord(0), null);
          expect(() => "move\u{10B3F}words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move\u{10B3F}words".moveOffsetUpstreamByWord(12), throwsException);
        });

        test("leading and trailing spaces", () {
          expect("  move words  ".moveOffsetUpstreamByWord(14), 7);
          expect("  move words  ".moveOffsetUpstreamByWord(7), 2);
          expect("  move words  ".moveOffsetUpstreamByWord(2), 0);
          expect("  move words  ".moveOffsetUpstreamByWord(0), null);
          expect(() => "move\u{10B3F}words".moveOffsetUpstreamByWord(-1), throwsException);
          expect(() => "move\u{10B3F}words".moveOffsetUpstreamByWord(15), throwsException);
        });
      });
    });

    group("find downstream", () {
      test("1 character", () {
        expect("a💙c".moveOffsetDownstreamByCharacter(0), 1);
        expect("a💙c".moveOffsetDownstreamByCharacter(1), 3);
        expect("a💙c".moveOffsetDownstreamByCharacter(3), 4);
        expect("a💙c".moveOffsetDownstreamByCharacter(4), null);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(-1), throwsException);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(5), throwsException);
      });

      test("2 characters", () {
        expect("a💙c".moveOffsetDownstreamByCharacter(0, characterCount: 2), 3);
        expect("a💙c".moveOffsetDownstreamByCharacter(1, characterCount: 2), 4);
        expect("a💙c".moveOffsetDownstreamByCharacter(3, characterCount: 2), null);
        expect("a💙c".moveOffsetDownstreamByCharacter(4, characterCount: 2), null);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(-1, characterCount: 2), throwsException);
        expect(() => "a💙c".moveOffsetDownstreamByCharacter(5, characterCount: 2), throwsException);
      });

      group('a word', () {
        test("separated by space", () {
          expect("move a💙c words".moveOffsetDownstreamByWord(0), 4);
          expect("move a💙c words".moveOffsetDownstreamByWord(4), 9);
          expect("move a💙c words".moveOffsetDownstreamByWord(5), 9);
          expect("move a💙c words".moveOffsetDownstreamByWord(6), 9);
          expect("move a💙c words".moveOffsetDownstreamByWord(8), 9);
          expect("move a💙c words".moveOffsetDownstreamByWord(9), 15);
          expect("move a💙c words".moveOffsetDownstreamByWord(10), 15);
          expect("move a💙c words".moveOffsetDownstreamByWord(15), null);
          expect(() => "move a💙c words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move a💙c words".moveOffsetDownstreamByWord(16), throwsException);
        });

        test("separated by multiple spaces", () {
          expect("move   words".moveOffsetDownstreamByWord(0), 4);
          expect("move   words".moveOffsetDownstreamByWord(4), 12);
          expect("move   words".moveOffsetDownstreamByWord(5), 12);
          expect("move   words".moveOffsetDownstreamByWord(12), null);
          expect(() => "move   words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move   words".moveOffsetDownstreamByWord(13), throwsException);
        });

        test("separated by punctuation", () {
          expect("move.words".moveOffsetDownstreamByWord(0), 4);
          expect("move.words".moveOffsetDownstreamByWord(4), 10);
          expect("move.words".moveOffsetDownstreamByWord(5), 10);
          expect("move.words".moveOffsetDownstreamByWord(10), null);
          expect(() => "move.words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move.words".moveOffsetDownstreamByWord(11), throwsException);
        });

        test("separated by punctuation and spaces", () {
          expect("move. words".moveOffsetDownstreamByWord(0), 4);
          expect("move. words".moveOffsetDownstreamByWord(4), 11);
          expect("move. words".moveOffsetDownstreamByWord(5), 11);
          expect("move. words".moveOffsetDownstreamByWord(6), 11);
          expect("move. words".moveOffsetDownstreamByWord(11), null);
          expect(() => "move. words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move. words".moveOffsetDownstreamByWord(12), throwsException);
        });

        test("separated by multi-byte punctuation", () {
          expect("move\u{10B3F}words".moveOffsetDownstreamByWord(0), 4);
          expect("move\u{10B3F}words".moveOffsetDownstreamByWord(4), 11);
          expect("move\u{10B3F}words".moveOffsetDownstreamByWord(6), 11);
          expect("move\u{10B3F}words".moveOffsetDownstreamByWord(11), null);
          expect(() => "move\u{10B3F}words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move\u{10B3F}words".moveOffsetDownstreamByWord(12), throwsException);
        });

        test("leading and trailing spaces", () {
          expect("  move words  ".moveOffsetDownstreamByWord(0), 6);
          expect("  move words  ".moveOffsetDownstreamByWord(1), 6);
          expect("  move words  ".moveOffsetDownstreamByWord(6), 12);
          expect("  move words  ".moveOffsetDownstreamByWord(14), null);
          expect(() => "move\u{10B3F}words".moveOffsetDownstreamByWord(-1), throwsException);
          expect(() => "move\u{10B3F}words".moveOffsetDownstreamByWord(15), throwsException);
        });
      });
    });
  });
}
