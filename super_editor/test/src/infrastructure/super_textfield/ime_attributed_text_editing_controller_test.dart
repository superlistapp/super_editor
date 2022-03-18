import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('ImeAttributedTextEditingController', () {
    group('platform', () {
      test('types hello **world** into empty field', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            selection: const TextSelection.collapsed(offset: 0),
          ),
        )
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: '',
              textInserted: 'H',
              insertionOffset: 0,
              selection: TextSelection.collapsed(offset: 1),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'H',
              textInserted: 'e',
              insertionOffset: 1,
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'He',
              textInserted: 'l',
              insertionOffset: 2,
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hel',
              textInserted: 'l',
              insertionOffset: 3,
              selection: TextSelection.collapsed(offset: 4),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hell',
              textInserted: 'o',
              insertionOffset: 4,
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello',
              textInserted: ' ',
              insertionOffset: 5,
              selection: TextSelection.collapsed(offset: 6),
              composing: TextRange.empty,
            )
          ])
          ..addComposingAttributions({boldAttribution})
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello ',
              textInserted: 'W',
              insertionOffset: 6,
              selection: TextSelection.collapsed(offset: 7),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello W',
              textInserted: 'o',
              insertionOffset: 7,
              selection: TextSelection.collapsed(offset: 8),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello Wo',
              textInserted: 'r',
              insertionOffset: 8,
              selection: TextSelection.collapsed(offset: 9),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello Wor',
              textInserted: 'l',
              insertionOffset: 9,
              selection: TextSelection.collapsed(offset: 10),
              composing: TextRange.empty,
            )
          ])
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'Hello Worl',
              textInserted: 'd',
              insertionOffset: 10,
              selection: TextSelection.collapsed(offset: 11),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('Hello World'));
        ExpectedSpans([
          '______bbbbb',
        ]).expectSpans(controller.text.spans);
      });

      test('types new text in the middle of styled text', () {
        final controller = ImeAttributedTextEditingController(
            controller: AttributedTextEditingController(
          text: AttributedText(
            text: 'before [] after',
            spans: AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        ))
          ..selection = const TextSelection.collapsed(offset: 8)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'before [] after',
              textInserted: 'b',
              insertionOffset: 8,
              selection: TextSelection.collapsed(offset: 9),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('before [b] after'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 9)));
        ExpectedSpans([
          '_______bbb______',
        ]).expectSpans(controller.text.spans);
      });

      test('types batch of new text in the middle of styled text', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: 'before [] after',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'before [] after',
              textInserted: 'hello',
              insertionOffset: 8,
              selection: TextSelection.collapsed(offset: 13),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('before [hello] after'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 13)));
        ExpectedSpans([
          '_______bbbbbbb______',
        ]).expectSpans(controller.text.spans);
      });

      test('types unstyled text in the middle of styled text', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: 'before [] after',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..clearComposingAttributions()
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaInsertion(
              oldText: 'before [] after',
              textInserted: 'b',
              insertionOffset: 8,
              selection: TextSelection.collapsed(offset: 9),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('before [b] after'));
        ExpectedSpans([
          '_______b_b______',
        ]).expectSpans(controller.text.spans);
      });

      test('clears composing attributions by deleting individual styled characters', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: 'before [] after',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        )..selection = const TextSelection.collapsed(offset: 9);
        expect(controller.composingAttributions, equals({boldAttribution}));

        controller.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'before [] after',
            deletedRange: TextRange(start: 8, end: 9),
            selection: TextSelection.collapsed(offset: 8),
            composing: TextRange.empty,
          )
        ]);
        expect(controller.composingAttributions, equals({boldAttribution}));

        controller.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'before [ after',
            deletedRange: TextRange(start: 7, end: 8),
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange.empty,
          )
        ]);
        expect(controller.composingAttributions.isEmpty, isTrue);
      });

      test('replaces selected text with new character', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: '[replaceme]',
            ),
          ),
        )
          ..selection = const TextSelection(baseOffset: 1, extentOffset: 10)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaReplacement(
              oldText: '[replaceme]',
              replacementText: 'b',
              replacedRange: TextRange(start: 1, end: 10),
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
          ]);

        expect(controller.text.text, equals('[b]'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 2)));
      });

      test('replaces selected text with batch of new text', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: '[replaceme]',
            ),
          ),
        )
          ..selection = const TextSelection(baseOffset: 1, extentOffset: 10)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaReplacement(
              oldText: '[replaceme]',
              replacementText: 'new',
              replacedRange: TextRange(start: 1, end: 10),
              selection: TextSelection.collapsed(offset: 4),
              composing: TextRange.empty,
            ),
          ]);

        expect(controller.text.text, equals('[new]'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 4)));
      });

      test('deletes first character in text with backspace key', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: 'some text',
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 1)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaDeletion(
              oldText: 'some text',
              deletedRange: TextRange(start: 0, end: 1),
              selection: TextSelection.collapsed(offset: 0),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('ome text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('deletes last character in text with delete key', () {
        final controller = ImeAttributedTextEditingController(
          controller: AttributedTextEditingController(
            text: AttributedText(
              text: 'some text',
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..updateEditingValueWithDeltas([
            const TextEditingDeltaDeletion(
              oldText: 'some text',
              deletedRange: TextRange(start: 8, end: 9),
              selection: TextSelection.collapsed(offset: 8),
              composing: TextRange.empty,
            )
          ]);

        expect(controller.text.text, equals('some tex'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
      });
    });
  });
}
