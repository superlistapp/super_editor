import 'dart:math';
import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../../super_textfield_text_test_tools.dart';

void main() {
  group("EventSourcedAttributedTextEditingController", () {
    group("updates the entire value", () {
      test("by selecting all text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection.collapsed(offset: 27), // end of text
          ),
        );

        // Ensure that we can select all text.
        controller.selectAll();
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 27),
        );

        // Ensure that we can undo the selection.
        controller.undo();
        expect(controller.selection, const TextSelection.collapsed(offset: 27));
      });

      test("by replacing the text and selection", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection.collapsed(offset: 27), // end of text
          ),
        );

        // Replace all the contents
        controller.updateTextAndSelection(
          text: AttributedText(text: "This is new text"),
          selection: const TextSelection(baseOffset: 8, extentOffset: 11),
          composingRegion: const TextRange(start: 8, end: 12),
        );

        // Ensure that all the properties were updated.
        expect(controller.text.text, "This is new text");
        expect(controller.selection, const TextSelection(baseOffset: 8, extentOffset: 11));
        expect(controller.composingRegion, const TextRange(start: 8, end: 12));

        // Ensure that we can undo the entire replacement.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(controller.selection, const TextSelection.collapsed(offset: 27));
        expect(controller.composingRegion, TextRange.empty);
      });

      test("by clearing everything", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection.collapsed(offset: 27), // end of text
          ),
        );

        controller.clear();
        expect(controller.text.text, "");
        expect(controller.selection, const TextSelection.collapsed(offset: -1));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(controller.selection, const TextSelection.collapsed(offset: 27));
      });
    });

    group("changes attributions", () {
      test("by toggling on selected text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is styled text.",
            ),
            selection: const TextSelection(baseOffset: 8, extentOffset: 13),
          ),
        );

        // Toggle the selected attributions on.
        controller.toggleSelectionAttributions([boldAttribution]);

        // Ensure the attribution was added to the selection.
        expect(controller.text, equalsMarkdown("This is **styled** text."));

        // Ensure that we can undo the toggle.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is styled text."));
      });

      test("by toggling off selected text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is styled text.",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 13, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection(baseOffset: 9, extentOffset: 12),
          ),
        );

        // Toggle the selected attributions off
        controller.toggleSelectionAttributions([boldAttribution]);

        // Ensure the attribution was removed from the selection.
        expect(controller.text, equalsMarkdown("This is **s**tyle**d** text."));

        // Ensure that we can undo the toggle.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is **styled** text."));

        // We're skipping this test because AttributedText.toggleAttributions()
        // has a bug where it doesn't merge markers at the end of the range.
        // What we're getting after undo'ing is: "This is **style****d** text.".
      }, skip: true);

      test("by clearing from selected text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is styled text.",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 13, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection(baseOffset: 9, extentOffset: 12),
          ),
        );

        // Ensure that we can remove selected attributions.
        controller.clearSelectionAttributions();
        expect(controller.text, equalsMarkdown("This is **s**tyle**d** text."));

        // Ensure that we can undo it.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is **styled** text."));
      });
    });

    group("moves the caret", () {
      group("horizontally", () {
        test("upstream and downstream", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection.collapsed(offset: 5),
            ),
          );

          // Move one character downstream
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: false,
            movementModifier: null,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 6));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 5));

          // Move one character upstream
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: true,
            movementModifier: null,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 4));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 5));
        });

        test("by expanding the selection", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection.collapsed(offset: 5),
            ),
          );

          // Move one character downstream and expand.
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: false,
            movementModifier: null,
            expandSelection: true,
          );
          expect(controller.selection, const TextSelection(baseOffset: 5, extentOffset: 6));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 5));

          // Move one character upstream and expand.
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: true,
            movementModifier: null,
            expandSelection: true,
          );
          expect(controller.selection, const TextSelection(baseOffset: 5, extentOffset: 4));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 5));
        });

        test("by collapsing the selection", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection(baseOffset: 5, extentOffset: 7),
            ),
          );

          // Collapse selection downstream
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: false,
            movementModifier: null,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 7));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection(baseOffset: 5, extentOffset: 7));

          // Move one character upstream
          controller.moveCaretHorizontally(
            textLayout: _FakeTextLayout(_multilineText),
            moveLeft: true,
            movementModifier: null,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 5));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection(baseOffset: 5, extentOffset: 7));
        });
      });

      group("vertically", () {
        test("upstream and downstream", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection.collapsed(offset: 25), // middle of line 2
            ),
          );

          // Move selection down a line.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: false,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 42));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 25));

          // Move selection up a line.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: true,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 8));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 25));
        });

        test("by expanding the selection", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection.collapsed(offset: 25), // middle of line 2
            ),
          );

          // Move selection down a line and expand.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: false,
            expandSelection: true,
          );
          expect(controller.selection, const TextSelection(baseOffset: 25, extentOffset: 42));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 25));

          // Move selection up a line and expand.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: true,
            expandSelection: true,
          );
          expect(controller.selection, const TextSelection(baseOffset: 25, extentOffset: 8));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection.collapsed(offset: 25));
        });

        test("by collapsing the selection", () {
          final controller = EventSourcedAttributedTextEditingController(
            AttributedTextEditingValue(
              text: AttributedText(
                text: _multilineText.join('\n'),
              ),
              selection: const TextSelection(baseOffset: 25, extentOffset: 42), // line 2 -> 3
            ),
          );

          // Collapse selection down and try to move down a line.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: false,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 55));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection(baseOffset: 25, extentOffset: 42));

          // Collapse the selection upward, and try to move up a line.
          controller.moveCaretVertically(
            textLayout: _FakeTextLayout(_multilineText),
            moveUp: true,
            expandSelection: false,
          );
          expect(controller.selection, const TextSelection.collapsed(offset: 8));

          // Undo it.
          controller.undo();
          expect(controller.selection, const TextSelection(baseOffset: 25, extentOffset: 42));
        });
      });
    });

    group("inserts text", () {
      test("character by character", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "a",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );

        controller
          ..insertCharacter("b")
          ..insertCharacter("c")
          ..insertCharacter("d");

        expect(controller.text, equalsMarkdown("**abcd**"));
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("with newlines", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "a",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );

        controller
          ..insertCharacter("b")
          ..insertNewline()
          ..insertCharacter("c");

        expect(controller.text, equalsMarkdown("**ab\nc**"));
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("at the caret without styles", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "a",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );

        controller
          ..insertAtCaretUnstyled(text: "bc")
          ..insertAtCaretUnstyled(text: "d");

        expect(controller.text, equalsMarkdown("**a**bcd"));
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("at the caret with composing attributions", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "a"),
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );

        controller
          ..addComposingAttributions({boldAttribution})
          ..insertAtCaret(text: "bc")
          ..insertAtCaret(text: "d");

        expect(controller.text, equalsMarkdown("a**bcd**"));
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("at the caret with upstream attributions", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "a",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );

        controller
          ..insertAtCaretWithUpstreamAttributions(text: "bc")
          ..insertAtCaretWithUpstreamAttributions(text: "d");

        expect(controller.text, equalsMarkdown("**abcd**"));
        expect(controller.selection, const TextSelection.collapsed(offset: 4));
      });

      test("at arbitrary offsets and automatically pushes the caret", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection.collapsed(offset: 27), // end of text
          ),
        );

        controller.insert(
          newText: AttributedText(text: " (modified)"),
          insertIndex: 21,
        );

        expect(controller.text.text, "This is some existing (modified) text.");
        expect(controller.selection, const TextSelection.collapsed(offset: 38));
      });

      test("at arbitrary offsets and automatically expands the selection", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            // Select the space between "existing" and "text", which
            // should expand when the new text is added.
            selection: const TextSelection(
              baseOffset: 21,
              extentOffset: 22,
            ),
          ),
        );

        controller.insert(
          newText: AttributedText(text: " (modified)"),
          insertIndex: 21,
        );

        expect(controller.text.text, "This is some existing (modified) text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 21,
            extentOffset: 33,
          ),
        );
      });
    });

    group("replaces text", () {
      test("by replacing selection and extending upstream attributions", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: boldAttribution, offset: 11, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            selection: const TextSelection(
              baseOffset: 12,
              extentOffset: 21,
            ),
          ),
        );

        controller.replaceSelectionWithTextAndUpstreamAttributions(replacementText: " new");
        expect(controller.text, equalsMarkdown("This is **some new** text."));
        expect(controller.selection, const TextSelection.collapsed(offset: 16));

        // Undo it.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is **some** existing text."));
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 12,
            extentOffset: 21,
          ),
        );
      });

      test("by replacing selection with new attributed text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 13,
              extentOffset: 21,
            ),
          ),
        );

        controller.replaceSelectionWithAttributedText(
          attributedReplacementText: AttributedText(
            text: "new",
            spans: AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 2, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        );
        expect(controller.text, equalsMarkdown("This is some **new** text."));
        expect(controller.selection, const TextSelection.collapsed(offset: 16));

        // Undo it.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is some existing text."));
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 13,
            extentOffset: 21,
          ),
        );
      });

      test("by replacing selection with unstyled text", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 13,
              extentOffset: 21,
            ),
          ),
        );

        controller.replaceSelectionWithUnstyledText(replacementText: "new");
        expect(controller.text, equalsMarkdown("This is some new text."));
        expect(controller.selection, const TextSelection.collapsed(offset: 16));

        // Undo it.
        controller.undo();
        expect(controller.text, equalsMarkdown("This is some existing text."));
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 13,
            extentOffset: 21,
          ),
        );
      });

      test("by replacing arbitrary text away from the caret", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 21,
              extentOffset: 22,
            ),
          ),
        );

        controller.replace(
          newText: AttributedText(text: "That's"),
          from: 0,
          to: 7,
        );
        expect(controller.text.text, "That's some existing text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 20,
            extentOffset: 21,
          ),
        );

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 21,
            extentOffset: 22,
          ),
        );
      });

      test("by replacing arbitrary text that overlaps the caret", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection.collapsed(offset: 17),
          ),
        );

        controller.replace(
          newText: AttributedText(text: "other"),
          from: 8,
          to: 21,
        );
        expect(controller.text.text, "This is other text.");
        expect(controller.selection, const TextSelection.collapsed(offset: 13));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(controller.selection, const TextSelection.collapsed(offset: 17));
      });

      test("by replacing arbitrary text away from an expanded selection", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 0,
              extentOffset: 11,
            ),
          ),
        );

        controller.replace(
          newText: AttributedText(text: "new"),
          from: 13,
          to: 21,
        );
        expect(controller.text.text, "This is some new text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 0,
            extentOffset: 11,
          ),
        );

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 0,
            extentOffset: 11,
          ),
        );
      });

      test("by replacing arbitrary text contained within an expanded selection", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 8,
              extentOffset: 21,
            ),
          ),
        );

        controller.replace(
          newText: AttributedText(text: "new"),
          from: 13,
          to: 21,
        );
        expect(controller.text.text, "This is some new text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 8,
            extentOffset: 16,
          ),
        );

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 8,
            extentOffset: 21,
          ),
        );
      });

      test("by replacing arbitrary text that overlaps an expanded selection", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(
              text: "This is some existing text.",
            ),
            selection: const TextSelection(
              baseOffset: 13,
              extentOffset: 26,
            ),
          ),
        );

        controller.replace(
          newText: AttributedText(text: "thing else"),
          from: 12,
          to: 26,
        );
        expect(controller.text.text, "This is something else.");
        expect(controller.selection, const TextSelection.collapsed(offset: 22));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "This is some existing text.");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 13,
            extentOffset: 26,
          ),
        );
      });
    });

    group("deletes text", () {
      test("between the caret and the beginning of the line", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "before the caret:after"),
            selection: const TextSelection.collapsed(offset: 16),
          ),
        );

        controller.deleteTextOnLineBeforeCaret(textLayout: _FakeTextLayout(["before the caret:after"]));
        expect(controller.text.text, ":after");
        expect(controller.selection, const TextSelection.collapsed(offset: 0));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "before the caret:after");
        expect(
          controller.selection,
          const TextSelection.collapsed(offset: 16),
        );
      });

      test("when it's selected", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "before:selected:after"),
            selection: const TextSelection(
              baseOffset: 7,
              extentOffset: 14,
            ),
          ),
        );

        controller.deleteSelectedText();
        expect(controller.text.text, "before::after");
        expect(controller.selection, const TextSelection.collapsed(offset: 7));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "before:selected:after");
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 7,
            extentOffset: 14,
          ),
        );
      });

      test("by character", () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "abcd"),
            selection: const TextSelection.collapsed(offset: 2),
          ),
        );

        controller.deletePreviousCharacter();
        expect(controller.text.text, "acd");
        expect(controller.selection, const TextSelection.collapsed(offset: 1));

        controller.deleteNextCharacter();
        expect(controller.text.text, "ad");
        expect(controller.selection, const TextSelection.collapsed(offset: 1));

        // Undo it.
        controller.undo();
        controller.undo();
        expect(controller.text.text, "abcd");
        expect(controller.selection, const TextSelection.collapsed(offset: 2));
      });

      test('from beginning', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "deleteme:existing text"),
          ),
        );

        controller.delete(from: 0, to: 8);
        expect(controller.text.text, equals(':existing text'));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "deleteme:existing text");
      });

      test('from beginning with caret', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "deleteme:existing text"),
            selection: const TextSelection.collapsed(offset: 8),
          ),
        );

        controller.delete(from: 0, to: 8);
        expect(controller.text.text, equals(':existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "deleteme:existing text");
        expect(controller.selection, const TextSelection.collapsed(offset: 8));
      });

      test('from beginning with selection', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "deleteme:existing text"),
            selection: const TextSelection(
              baseOffset: 4,
              extentOffset: 17,
            ),
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

        // Undo it.
        controller.undo();
        expect(controller.text.text, "deleteme:existing text");
        expect(
            controller.selection,
            const TextSelection(
              baseOffset: 4,
              extentOffset: 17,
            ));
      });

      test('from end', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "existing text:deleteme"),
          ),
        );

        controller.delete(from: 14, to: 22);
        expect(controller.text.text, equals('existing text:'));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "existing text:deleteme");
        expect(controller.selection, const TextSelection.collapsed(offset: -1));
      });

      test('from end with caret', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "existing text:deleteme"),
            // Caret part of the way into the text that will be deleted.
            selection: const TextSelection.collapsed(offset: 18),
          ),
        );

        controller.delete(from: 14, to: 22);
        expect(controller.text.text, equals('existing text:'));
        expect(
          controller.selection,
          equals(
            const TextSelection.collapsed(offset: 14),
          ),
        );

        // Undo it.
        controller.undo();
        expect(controller.text.text, "existing text:deleteme");
        expect(controller.selection, const TextSelection.collapsed(offset: 18));
      });

      test('from end with selection', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "existing text:deleteme"),
            // Selection that starts near the end of remaining text and
            // extends part way into text that's deleted.
            selection: const TextSelection(baseOffset: 11, extentOffset: 18),
          ),
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

        // Undo it.
        controller.undo();
        expect(controller.text.text, "existing text:deleteme");
        expect(controller.selection, const TextSelection(baseOffset: 11, extentOffset: 18));
      });

      test('from middle', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "[deleteme]"),
          ),
        );

        controller.delete(from: 1, to: 9);
        expect(controller.text.text, equals('[]'));

        // Undo it.
        controller.undo();
        expect(controller.text.text, "[deleteme]");
        expect(controller.selection, const TextSelection.collapsed(offset: -1));
      });

      test('from middle with crosscutting selection at beginning', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "[deleteme]"),
            selection: const TextSelection(
              baseOffset: 0,
              extentOffset: 5,
            ),
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

        // Undo it.
        controller.undo();
        expect(controller.text.text, "[deleteme]");
        expect(
            controller.selection,
            const TextSelection(
              baseOffset: 0,
              extentOffset: 5,
            ));
      });

      test('from middle with partial selection in middle', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "[deleteme]"),
            selection: const TextSelection(
              baseOffset: 3,
              extentOffset: 6,
            ),
          ),
        );

        controller.delete(from: 1, to: 9);
        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(const TextSelection.collapsed(offset: 1)),
        );

        // Undo it.
        controller.undo();
        expect(controller.text.text, "[deleteme]");
        expect(
            controller.selection,
            const TextSelection(
              baseOffset: 3,
              extentOffset: 6,
            ));
      });

      test('from middle with crosscutting selection at end', () {
        final controller = EventSourcedAttributedTextEditingController(
          AttributedTextEditingValue(
            text: AttributedText(text: "[deleteme]"),
            selection: const TextSelection(
              baseOffset: 5,
              extentOffset: 10,
            ),
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

        // Undo it.
        controller.undo();
        expect(controller.text.text, "[deleteme]");
        expect(
            controller.selection,
            const TextSelection(
              baseOffset: 5,
              extentOffset: 10,
            ));
      });
    });
  });
}

// Line positions:
// 0 -> 18 (upstream)
// 18 (downstream) -> 35 (upstream)
// 36 (upstream) -> 55
const _multilineText = [
  "This is line one.", // assume a "\n" at the end of the line
  "This is line two.", // assume a "\n" at the end of the line
  "This is line three.",
];

class _FakeTextLayout implements ProseTextLayout {
  _FakeTextLayout(this._lines);

  final List<String> _lines;

  @override
  double get estimatedLineHeight => 18;

  @override
  double getLineHeightAtPosition(TextPosition position) {
    return 18;
  }

  @override
  int getLineCount() {
    return _lines.length;
  }

  @override
  bool isTextAtOffset(Offset localOffset) {
    throw UnimplementedError();
  }

  @override
  TextSelection expandSelection(TextPosition startingPosition, TextExpansion expansion, TextAffinity affinity) {
    throw UnimplementedError();
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    throw UnimplementedError();
  }

  @override
  TextBox? getCharacterBox(TextPosition position) {
    throw UnimplementedError();
  }

  @override
  double? getHeightForCaret(TextPosition position) {
    return 20;
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
  TextPosition? getPositionAtOffset(Offset localOffset) {
    throw UnimplementedError();
  }

  @override
  TextPosition getPositionAtEndOfLine(TextPosition textPosition) {
    int characterCount = 0;
    for (int i = 0; i < _lines.length; i += 1) {
      if (characterCount <= textPosition.offset && textPosition.offset < characterCount + _lines[i].length) {
        return TextPosition(offset: characterCount + _lines[i].length);
      }
      characterCount += _lines[i].length;
    }

    throw Exception("Invalid text position: $textPosition");
  }

  @override
  TextPosition getPositionAtStartOfLine(TextPosition textPosition) {
    int characterCount = 0;
    for (int i = 0; i < _lines.length; i += 1) {
      if (characterCount <= textPosition.offset && textPosition.offset < characterCount + _lines[i].length) {
        return TextPosition(offset: characterCount);
      }
      characterCount += _lines[i].length;
    }

    throw Exception("Invalid text position: $textPosition");
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
    late int lineWithPosition;
    late int positionInLine;
    int characterCount = 0;
    bool isFound = false;
    for (int i = 0; i < _lines.length; i += 1) {
      if (characterCount <= textPosition.offset && textPosition.offset < characterCount + _lines[i].length) {
        isFound = true;
        lineWithPosition = i;
        positionInLine = textPosition.offset - characterCount;
      }
      characterCount += _lines[i].length;

      if (isFound) {
        break;
      }
    }

    if (lineWithPosition == _lines.length - 1) {
      return null;
    }

    final nextLine = lineWithPosition + 1;
    return TextPosition(
      offset: min(positionInLine, _lines[nextLine].length - 1) + characterCount,
    );
  }

  @override
  TextPosition? getPositionOneLineUp(TextPosition textPosition) {
    late int lineWithPosition;
    late int positionInLine;
    int characterCount = 0;
    bool isFound = false;
    for (int i = 0; i < _lines.length; i += 1) {
      if (characterCount <= textPosition.offset && textPosition.offset < characterCount + _lines[i].length) {
        isFound = true;
        lineWithPosition = i;
        positionInLine = textPosition.offset - characterCount;
      }

      if (isFound) {
        break;
      } else {
        characterCount += _lines[i].length;
      }
    }

    if (lineWithPosition == 0) {
      return null;
    }

    final previousLine = lineWithPosition - 1;
    return TextPosition(
      offset: min(positionInLine, _lines[previousLine].length - 1) + characterCount - _lines[previousLine].length,
    );
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    throw UnimplementedError();
  }

  @override
  TextSelection getWordSelectionAt(TextPosition position) {
    throw UnimplementedError();
  }
}
