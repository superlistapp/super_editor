import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group("AttributedTextEditingController", () {
    group("word jumping", () {
      test("does nothing at beginning of text when collapsed", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection.collapsed(offset: 0);

        // Move upstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: false,
          moveLeft: true,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection didn't change.
        expect(controller.selection, const TextSelection.collapsed(offset: 0));
      });

      test("does nothing at beginning of text when expanded", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection(extentOffset: 0, baseOffset: 3);

        // Move upstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: true,
          moveLeft: true,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection didn't change.
        expect(controller.selection, const TextSelection(extentOffset: 0, baseOffset: 3));
      });

      test("does nothing at end of text when collapsed", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection.collapsed(offset: 13); // at the end of the text.

        // Move downstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: false,
          moveLeft: false,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection didn't change.
        expect(controller.selection, const TextSelection.collapsed(offset: 13));
      });

      test("does nothing at end of text when expanded", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection(extentOffset: 13, baseOffset: 8);

        // Move upstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: true,
          moveLeft: false,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection didn't change.
        expect(controller.selection, const TextSelection(extentOffset: 13, baseOffset: 8));
      });

      test("jumps word upstream", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection.collapsed(offset: 7);

        // Move upstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: false,
          moveLeft: true,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection moved upstream by one word.
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("jumps word downstream", () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'one two three',
          ),
        )..selection = const TextSelection.collapsed(offset: 4);

        // Move downstream by word.
        controller.moveCaretHorizontally(
          textLayout: _NoOpTextLayout(),
          expandSelection: false,
          moveLeft: false,
          movementModifier: MovementModifier.word,
        );

        // Ensure that the selection moved downstream by one word.
        expect(controller.selection, const TextSelection.collapsed(offset: 7));
      });
    });

    group("user", () {
      test("types hello **world** into empty field", () {
        final controller = AttributedTextEditingController(
          selection: const TextSelection.collapsed(offset: 0),
        )
          ..insertAtCaret(text: 'H')
          ..insertAtCaret(text: 'e')
          ..insertAtCaret(text: 'l')
          ..insertAtCaret(text: 'l')
          ..insertAtCaret(text: 'o')
          ..insertAtCaret(text: ' ')
          ..addComposingAttributions({boldAttribution})
          ..insertAtCaret(text: 'W')
          ..insertAtCaret(text: 'o')
          ..insertAtCaret(text: 'r')
          ..insertAtCaret(text: 'l')
          ..insertAtCaret(text: 'd');

        expect(controller.text.text, equals('Hello World'));
        ExpectedSpans([
          '______bbbbb',
        ]).expectSpans(controller.text.spans);
      });

      test('types new text in the middle of styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..insertAtCaret(text: 'b');

        expect(controller.text.text, equals('before [b] after'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 9)));
        ExpectedSpans([
          '_______bbb______',
        ]).expectSpans(controller.text.spans);
      });

      test('types batch of new text in the middle of styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..insertAtCaret(text: 'hello');

        expect(controller.text.text, equals('before [hello] after'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 13)));
        ExpectedSpans([
          '_______bbbbbbb______',
        ]).expectSpans(controller.text.spans);
      });

      test('types unstyled text in the middle of styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..clearComposingAttributions()
          ..insertAtCaret(text: 'b');

        expect(controller.text.text, equals('before [b] after'));
        ExpectedSpans([
          '_______b_b______',
        ]).expectSpans(controller.text.spans);
      });

      test('clears composing attributions by deleting all styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'before [] after',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        )..selection = const TextSelection.collapsed(offset: 9);
        expect(controller.composingAttributions, equals({boldAttribution}));

        controller.deletePreviousCharacter();
        expect(controller.composingAttributions, equals({boldAttribution}));

        controller.deletePreviousCharacter();
        expect(controller.composingAttributions.isEmpty, isTrue);
      });

      test('tries to delete previous character at beginning of text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 0)
          ..deletePreviousCharacter();

        expect(controller.text.text, equals('some text'));
      });

      test('deletes first character in text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 1)
          ..deletePreviousCharacter();

        expect(controller.text.text, equals('ome text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('tries to delete next character at end of text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 9)
          ..deleteNextCharacter();

        expect(controller.text.text, equals('some text'));
      });

      test('deletes last character in text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            'some text',
          ),
        )
          ..selection = const TextSelection.collapsed(offset: 8)
          ..deleteNextCharacter();

        expect(controller.text.text, equals('some tex'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
      });
    });

    group('insert', () {
      test('into empty text', () {
        final controller = AttributedTextEditingController(
          selection: const TextSelection.collapsed(offset: 0),
        )..insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('newtext'));
      });

      test('into empty text with caret', () {
        final controller = AttributedTextEditingController(
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('newtext'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 7)));
      });

      test('into start of existing text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('newtext:existing text'));
      });

      test('into start of existing text and pushes caret back', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('newtext:existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 7)));
      });

      test('into start of existing text and pushes selection back', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection(
            baseOffset: 1,
            extentOffset: 9,
          ),
        );
        controller.insert(newText: AttributedText('newtext'), insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 8,
              extentOffset: 16,
            ),
          ),
        );
      });

      test('into start of existing text and expands existing selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 9,
          ),
        );
        controller.insert(newText: AttributedText('newtext'), insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 16,
            ),
          ),
        );
      });

      test('into end of existing text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:'),
          selection: const TextSelection.collapsed(offset: 14),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('existing text:newtext'));
      });

      test('into end of existing text with caret before inserted text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:'),
          selection: const TextSelection.collapsed(offset: 14),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('existing text:newtext'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 21)));
      });

      test('into end of existing text with selection before inserted text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:'),
          selection: const TextSelection(baseOffset: 0, extentOffset: 8),
        );
        controller.insert(newText: AttributedText('newtext'), insertIndex: 14);

        expect(controller.text.text, equals('existing text:newtext'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 8,
            ),
          ),
        );
      });

      test('into middle of text with caret at insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:existing text',
          ),
          selection: const TextSelection.collapsed(offset: 1),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
      });

      test('into middle of text with selection around insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:existing text',
          ),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );
        controller.insert(newText: AttributedText('newtext'), insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 9,
            ),
          ),
        );
      });

      test('into middle of text with selection after insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:existing text',
          ),
          selection: const TextSelection(
            baseOffset: 3,
            extentOffset: 11,
          ),
        );
        controller.insert(newText: AttributedText('newtext'), insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 10,
              extentOffset: 18,
            ),
          ),
        );
      });

      test('before styled text - the style is not extended', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:unstyled text',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 2, markerType: SpanMarkerType.end),
              ],
            ),
          ),
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('newtext[]:unstyled text'));
        ExpectedSpans([
          '_______bb______________',
        ]).expectSpans(controller.text.spans);
      });

      test('into middle of styled text - the style is extended', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:unstyled text',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 2, markerType: SpanMarkerType.end),
              ],
            ),
          ),
          selection: const TextSelection.collapsed(offset: 1),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('[newtext]:unstyled text'));
        ExpectedSpans([
          'bbbbbbbbb______________',
        ]).expectSpans(controller.text.spans);
      });

      test('after styled text - the style is extended', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[]:unstyled text',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
              ],
            ),
          ),
          selection: const TextSelection.collapsed(offset: 1),
        );
        controller.insertAtCaret(text: 'newtext');

        expect(controller.text.text, equals('[newtext]:unstyled text'));
        ExpectedSpans([
          'bbbbbbbb_______________',
        ]).expectSpans(controller.text.spans);
      });
    });

    group('replace', () {
      test('empty text with new text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.replace(newText: AttributedText('newtext'), from: 0, to: 0);

        expect(controller.text.text, equals('newtext:existing text'));
      });

      test('empty text with new text at beginning with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(':existing text'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 1,
          ),
        );
        controller.replace(newText: AttributedText('newtext'), from: 0, to: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 0,
            extentOffset: 8,
          ),
        );
      });

      test('text with empty text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('deleteme:existing text'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.replace(newText: AttributedText(''), from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('replaceme:existing text'),
          selection: const TextSelection(baseOffset: 0, extentOffset: 9),
        );
        controller.replace(newText: AttributedText('newtext'), from: 0, to: 9);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 7)));
      });

      test('text at end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:replaceme'),
          selection: const TextSelection(baseOffset: 14, extentOffset: 23),
        );
        controller.replace(newText: AttributedText('newtext'), from: 14, to: 23);

        expect(controller.text.text, equals('existing text:newtext'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 21)));
      });

      test('text in the middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('[replaceme]'),
          selection: const TextSelection(baseOffset: 1, extentOffset: 10),
        );
        controller.replace(newText: AttributedText('newtext'), from: 1, to: 10);

        expect(controller.text.text, equals('[newtext]'));
      });

      test('in middle of styled text with new styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            '[replaceme]',
            AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 10, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        );
        final newText = AttributedText(
          'newtext',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: italicsAttribution, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.end),
            ],
          ),
        );
        controller.replace(newText: newText, from: 1, to: 10);

        expect(controller.text.text, equals('[newtext]'));

        ExpectedSpans([
          'biiiiiiib',
        ]).expectSpans(controller.text.spans);
      });
    });

    group('delete', () {
      test('from beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('deleteme:existing text'),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
      });

      test('from beginning with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('deleteme:existing text'),
          selection: const TextSelection.collapsed(offset: 8),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('from beginning with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('deleteme:existing text'),
          selection: const TextSelection(
            baseOffset: 4,
            extentOffset: 17,
          ),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 9,
            ),
          ),
        );
      });

      test('from end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:deleteme'),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
      });

      test('from end with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:deleteme'),
          // Caret part of the way into the text that will be deleted.
          selection: const TextSelection.collapsed(offset: 18),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
        expect(
          controller.selection,
          equals(
            const TextSelection.collapsed(offset: 14),
          ),
        );
      });

      test('from end with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('existing text:deleteme'),
          // Selection that starts near the end of remaining text and
          // extends part way into text that's deleted.
          selection: const TextSelection(baseOffset: 11, extentOffset: 18),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 11,
              extentOffset: 14,
            ),
          ),
        );
      });

      test('from middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('[deleteme]'),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
      });

      test('from middle with crosscutting selection at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('[deleteme]'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 5,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 1,
            ),
          ),
        );
      });

      test('from middle with partial selection in middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('[deleteme]'),
          selection: const TextSelection(
            baseOffset: 3,
            extentOffset: 6,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(const TextSelection.collapsed(offset: 1)),
        );
      });

      test('from middle with crosscutting selection at end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText('[deleteme]'),
          selection: const TextSelection(
            baseOffset: 5,
            extentOffset: 10,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 1,
              extentOffset: 2,
            ),
          ),
        );
      });
    });

    group("clearing text and selection", () {
      test("can remove the text, selection, and composing region at the same time", () {
        int listenerNotifyCount = 0;
        final controller = AttributedTextEditingController(
          text: AttributedText('my text'),
          selection: const TextSelection.collapsed(offset: 7),
          composingRegion: const TextRange(start: 3, end: 7),
        )
          ..composingAttributions = {
            boldAttribution,
          }
          ..addListener(() {
            listenerNotifyCount += 1;
          });

        controller.clearTextAndSelection();

        expect(controller.text.text, isEmpty);
        expect(
          controller.selection,
          const TextSelection.collapsed(offset: -1),
        );
        expect(controller.composingAttributions, isEmpty);
        expect(controller.composingRegion, TextRange.empty);
        expect(listenerNotifyCount, 1);

        // Below here we want to validate that the old deprecated method
        // .clear() does exactly the same thing as its replacement method
        // .clearTextAndSelection().
        //
        // As soon as the deprecated method is removed, the below code will
        // throw a compile error, at which time it will be safe to remove it.
        controller
          ..text = AttributedText('my text')
          ..selection = const TextSelection.collapsed(offset: 7)
          ..composingRegion = const TextRange(start: 3, end: 7)
          ..composingAttributions = {boldAttribution};
        listenerNotifyCount = 0;

        // ignore: deprecated_member_use_from_same_package
        controller.clear();

        expect(controller.text.text, isEmpty);
        expect(
          controller.selection,
          const TextSelection.collapsed(offset: -1),
        );
        expect(controller.composingAttributions, isEmpty);
        expect(controller.composingRegion, TextRange.empty);
        expect(listenerNotifyCount, 1);
      });

      test("can remove the text and composing region, and place the caret at the start, at the same time", () {
        int listenerNotifyCount = 0;
        final controller = AttributedTextEditingController(
          text: AttributedText('my text'),
          selection: const TextSelection.collapsed(offset: 7),
          composingRegion: const TextRange(start: 3, end: 7),
        )
          ..composingAttributions = {
            boldAttribution,
          }
          ..addListener(() {
            listenerNotifyCount += 1;
          });

        controller.clearText();

        expect(controller.text.text, isEmpty);
        expect(
          controller.selection,
          const TextSelection.collapsed(offset: 0),
        );
        expect(controller.composingAttributions, isEmpty);
        expect(controller.composingRegion, TextRange.empty);
        expect(listenerNotifyCount, 1);
      });
    });

    test('set text', () {
      final text1 = AttributedText('text1');
      final text2 = AttributedText('text2');

      final controller = AttributedTextEditingController(text: text1);
      expect(controller.text, equals(text1));
      expect(text1.hasListeners, true);
      expect(text2.hasListeners, false);

      controller.text = text2;
      expect(controller.text, equals(text2));
      expect(text1.hasListeners, false);
      expect(text2.hasListeners, true);
    });

    group('composing attributions', () {
      group('removal', () {
        test('should remove the given attributions', () {
          final controller = AttributedTextEditingController(
            text: AttributedText('my text'),
          );
          controller.addComposingAttributions(
            {boldAttribution, italicsAttribution, underlineAttribution},
          );
          expect(controller.composingAttributions.length, 3);

          controller.removeComposingAttributions({boldAttribution, underlineAttribution});

          expect(controller.composingAttributions.length, 1);
          expect(controller.composingAttributions.contains(italicsAttribution), true);
        });

        test("does nothing when it doesn't have the given composing attributions", () {
          final controller = AttributedTextEditingController(
            text: AttributedText('my text'),
          );
          controller.addComposingAttributions(
            {boldAttribution, italicsAttribution},
          );
          expect(controller.composingAttributions.length, 2);

          controller.removeComposingAttributions({underlineAttribution});

          expect(controller.composingAttributions.length, 2);
          expect(controller.composingAttributions.contains(italicsAttribution), true);
          expect(controller.composingAttributions.contains(boldAttribution), true);
        });
      });
    });
  });
}

/// A [ProseTextLayout] that throws an error if anything is called.
///
/// A [_NoOpTextLayout] can be used when a [ProseTextLayout] is needed by
/// the interface, the specific operation doesn't expect to call anything
/// on the [ProseTextLayout].
class _NoOpTextLayout implements ProseTextLayout {
  @override
  double get estimatedLineHeight => throw UnimplementedError();

  @override
  TextSelection expandSelection(TextPosition startingPosition, TextExpansion expansion, TextAffinity affinity) {
    throw UnimplementedError();
  }

  @override
  List<TextBox> getBoxesForSelection(
    TextSelection selection, {
    BoxHeightStyle boxHeightStyle = BoxHeightStyle.tight,
    BoxWidthStyle boxWidthStyle = BoxWidthStyle.tight,
  }) {
    throw UnimplementedError();
  }

  @override
  TextBox? getCharacterBox(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  double? getHeightForCaret(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  int getLineCount() {
    throw UnimplementedError();
  }

  @override
  double getLineHeightAtPosition(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  Offset getOffsetAtPosition(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionAtEndOfLine(TextPosition textPosition) {
    throw UnimplementedError();
  }

  @override
  TextPosition? getPositionAtOffset(Offset localOffset) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionAtStartOfLine(TextPosition textPosition) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionInFirstLineAtX(double x) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionInLastLineAtX(double x) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionNearestToOffset(Offset localOffset) {
    throw UnimplementedError();
  }

  @override
  TextPosition? getPositionOneLineDown(TextPosition textPosition) {
    throw UnimplementedError();
  }

  @override
  TextPosition? getPositionOneLineUp(TextPosition textPosition) {
    throw UnimplementedError();
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    throw UnimplementedError();
  }

  @override
  bool isTextAtOffset(Offset localOffset) {
    throw UnimplementedError();
  }

  @override
  TextSelection getWordSelectionAt(TextPosition position) {
    throw UnimplementedError();
  }
}
