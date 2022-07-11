import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

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
        // TODO:
      });
    });

    group("moves the caret", () {
      // TODO:
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
      // TODO:
    });

    group("deletes text", () {
      // TODO:
    });
  });
}
