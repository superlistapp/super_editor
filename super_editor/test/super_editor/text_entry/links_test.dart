import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group('SuperEditor link editing >', () {
    testWidgetsOnAllPlatforms('recognizes a URL when typing and converts it to a link', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

      // Type a URL. It shouldn't linkify until we add a space.
      await tester.typeImeText("https://www.google.com");

      // Ensure it's not linkified yet.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "https://www.google.com");
      expect(
        text.getAttributionSpansInRange(
          attributionFilter: (attribution) => true,
          range: SpanRange(start: 0, end: text.text.length - 1),
        ),
        isEmpty,
      );

      // Type a space, to cause a linkify reaction.
      await tester.typeImeText(" ");

      // Ensure it's linkified.
      text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "https://www.google.com ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 2),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('inserts https scheme if it is missing', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

      // Type a URL. It shouldn't linkify until we add a space.
      await tester.typeImeText("www.google.com");

      // Type a space, to cause a linkify reaction.
      await tester.typeImeText(" ");

      // Ensure it's linkified with a URL schema.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);
      text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "www.google.com ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 2),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('can insert characters in the middle of a link', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "www.goog|le.com"
      await tester.placeCaretInParagraph(doc.nodes.first.id, 8);

      // Add characters.
      await tester.typeImeText("oooo");

      // Ensure the characters were inserted, the whole link is still attributed.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "www.googoooole.com");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 1),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('user can delete characters at the beginning of a link', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "|www.google.com"
      await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

      // Delete downstream characters.
      await tester.pressDelete();
      await tester.pressDelete();
      await tester.pressDelete();
      await tester.pressDelete();

      // Ensure the characters were inserted, the whole link is still attributed.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "google.com");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 1),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('user can delete characters in the middle of a link', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "www.google.com|"
      await tester.placeCaretInParagraph(doc.nodes.first.id, 10);

      // Delete upstream characters.
      await tester.pressBackspace();
      await tester.pressBackspace();
      await tester.pressBackspace();
      await tester.pressBackspace();
      await tester.pressBackspace();

      // Ensure the characters were inserted, the whole link is still attributed.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "www.g.com");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 1),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('user can delete characters at the end of a link', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "www.google.com|"
      await tester.placeCaretInParagraph(doc.nodes.first.id, 14);

      // Delete upstream characters.
      await tester.pressBackspace();
      await tester.pressBackspace();
      await tester.pressBackspace();
      await tester.pressBackspace();

      // Ensure the characters were inserted, the whole link is still attributed.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "www.google");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(start: 0, end: text.text.length - 1),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('user can delete characters at the end of a link and then keep typing', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "www.google.com|"
      await tester.placeCaretInParagraph(doc.nodes.first.id, 14);

      // Delete a character at the end of the link.
      await tester.pressBackspace();

      // Start typing new content, which shouldn't become part of the link.
      await tester.typeImeText(" hello");

      // Ensure the text were inserted, and only the URL is linkified.
      final nodeId = doc.nodes.first.id;
      var text = SuperEditorInspector.findTextInParagraph(nodeId);

      expect(text.text, "www.google.co hello");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: const SpanRange(start: 0, end: 12),
        ),
        isTrue,
      );
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(start: 13, end: text.text.length - 1),
        ),
        isFalse,
      );
    });
  });
}
