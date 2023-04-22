import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/document_ime/document_delta_editing.dart';

void main() {
  group('text diff', () {
    group('detects deletions', () {
      test('at the start', () {
        final textDiff = computeDiff('Before the line break \nnew line', 'new line');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 0, end: 23),
            )
          ],
        );
      });

      test('at the middle', () {
        final textDiff = computeDiff('Before we get the line break', 'Before we get line break');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 14, end: 18),
            )
          ],
        );
      });

      test('at the middle with intersecting content', () {
        final textDiff = computeDiff('Before a new line is found in a new document', 'Before a new document');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 6, end: 29),
            )
          ],
        );
      });

      test('at the end', () {
        final textDiff = computeDiff('Before the line break', 'Before the');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 10, end: 21),
            )
          ],
        );
      });
    });

    group('detects insertions', () {
      test('at the start', () {
        final textDiff = computeDiff('new line', 'Before the line break \nnew line');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 0, end: 23),
            )
          ],
        );
      });

      test('at the middle', () {
        final textDiff = computeDiff('Before we get line break', 'Before we get the line break');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 14, end: 18),
            )
          ],
        );
      });

      test('at the end', () {
        final textDiff = computeDiff('Before the', 'Before the line break');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 10, end: 21),
            )
          ],
        );
      });

      test('and keeps longest sequence', () {
        final textDiff = computeDiff('Paragraph two', 'Paragraph oneParagraph two');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 0, end: 13),
            )
          ],
        );
      });
    });

    group('detects replacements', () {
      test('at the start', () {
        final textDiff = computeDiff('A line', 'Other line');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 0, end: 1),
            ),
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 0, end: 5),
            )
          ],
        );
      });

      test('at the middle', () {
        final textDiff = computeDiff('A prefix', 'A sufix');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 2, end: 5),
            ),
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 2, end: 4),
            )
          ],
        );
      });

      test('at the end', () {
        final textDiff = computeDiff('A text', 'A string');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 2, end: 6),
            ),
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 2, end: 8),
            )
          ],
        );
      });

      test('of the whole content', () {
        final textDiff = computeDiff('A text', 'Other string');

        expect(
          textDiff,
          [
            TextDiffOperation(
              operation: TextDiffOperationKind.deletion,
              range: const TextRange(start: 0, end: 6),
            ),
            TextDiffOperation(
              operation: TextDiffOperationKind.insertion,
              range: const TextRange(start: 0, end: 12),
            )
          ],
        );
      });
    });
    group('returns no difference', () {
      test('to equal strings', () {
        final textDiff = computeDiff('The text is the same', 'The text is the same');

        expect(textDiff, []);
      });
    });
  });
}
