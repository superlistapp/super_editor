import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group('SuperEditor link editing >', () {
    testWidgetsOnAllPlatforms('recognizes a URL when typing and converts it to a link', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph("1", 0);

      // Type a URL. It shouldn't linkify until we add a space.
      await tester.typeImeText("https://www.google.com");

      // Ensure it's not linkified yet.
      var text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "https://www.google.com");
      expect(
        text.getAttributionSpansInRange(
          attributionFilter: (attribution) => true,
          range: SpanRange(0, text.text.length - 1),
        ),
        isEmpty,
      );

      // Type a space, to cause a linkify reaction.
      await tester.typeImeText(" ");

      // Ensure it's linkified.
      text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "https://www.google.com ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://www.google.com")),
          },
          range: SpanRange(0, text.text.length - 2),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('recognizes a second URL when typing and converts it to a link', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph("1", 0);

      // Type text with two URLs
      await tester.typeImeText("https://www.google.com and https://flutter.dev ");

      // Ensure both URLs are linkified with the correct URLs.
      final text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "https://www.google.com and https://flutter.dev ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://www.google.com")),
          },
          range: const SpanRange(0, 21),
        ),
        isTrue,
      );

      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://flutter.dev")),
          },
          range: const SpanRange(27, 45),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('recognizes a URL without www and converts it to a link', (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .pump();

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph("1", 0);

      // Type a URL without the www. It shouldn't linkify until we add a space.
      await tester.typeImeText("google.com");

      // Ensure it's not linkified yet.
      var text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "google.com");
      expect(
        text.getAttributionSpansInRange(
          attributionFilter: (attribution) => true,
          range: SpanRange(0, text.text.length - 1),
        ),
        isEmpty,
      );

      // Type a space, to cause a linkify reaction.
      await tester.typeImeText(" ");

      // Ensure it's linkified.
      text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "google.com ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://google.com")),
          },
          range: SpanRange(0, text.text.length - 2),
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

      // Place the caret at the beginning of the empty document.
      await tester.placeCaretInParagraph("1", 0);

      // Type a URL. It shouldn't linkify until we add a space.
      await tester.typeImeText("www.google.com");

      // Type a space, to cause a linkify reaction.
      await tester.typeImeText(" ");

      // Ensure it's linkified with a URL schema.
      var text = SuperEditorInspector.findTextInParagraph("1");
      text = SuperEditorInspector.findTextInParagraph("1");

      expect(text.text, "www.google.com ");
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("https://www.google.com")),
          },
          range: SpanRange(0, text.text.length - 2),
        ),
        isTrue,
      );
    });

    testWidgetsOnAllPlatforms('does not expand the link when inserting before the link', (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret in the first paragraph at the start of the link.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText('Go to ');

      // Ensure that the link is unchanged
      expect(
        SuperEditorInspector.findDocument(),
        equalsMarkdown("Go to [www.google.com](www.google.com)"),
      );
    });

    testWidgets('does not expand the link when inserting after the link', (tester) async {
      // Configure and render a document.
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret in the first paragraph at the start of the link.
      await tester.placeCaretInParagraph(doc.nodes.first.id, 14);

      // Type some text by simulating hardware keyboard key presses.
      await tester.typeKeyboardText(' to learn anything');

      // Ensure that the link is unchanged
      expect(
        SuperEditorInspector.findDocument(),
        equalsMarkdown("[www.google.com](www.google.com) to learn anything"),
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
          range: SpanRange(0, text.text.length - 1),
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
          range: SpanRange(0, text.text.length - 1),
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
          range: SpanRange(0, text.text.length - 1),
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
          range: SpanRange(0, text.text.length - 1),
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
          range: const SpanRange(0, 12),
        ),
        isTrue,
      );
      expect(
        text.hasAttributionsThroughout(
          attributions: {
            LinkAttribution(url: Uri.parse("www.google.com")),
          },
          range: SpanRange(13, text.text.length - 1),
        ),
        isFalse,
      );
    });

    testWidgetsOnAllPlatforms('does not extend link to new paragraph', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("[www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Place the caret at "www.google.com|".
      await tester.placeCaretInParagraph(doc.nodes.first.id, 14);

      // Create a new paragraph.
      await tester.pressEnter();

      // We had an issue where link attributions were extended to the beginning of
      // an empty paragraph, but were removed after the user started typing. So, first,
      // ensure that no link markers were added to the empty paragraph.
      expect(doc.nodes.length, 2);
      final newParagraphId = doc.nodes[1].id;
      AttributedText newParagraphText = SuperEditorInspector.findTextInParagraph(newParagraphId);
      expect(newParagraphText.spans.markers, isEmpty);

      // Type some text.
      await tester.typeImeText("New paragraph");

      // Ensure the text we typed didn't re-introduce a link attribution.
      newParagraphText = SuperEditorInspector.findTextInParagraph(newParagraphId);
      expect(newParagraphText.text, "New paragraph");
      expect(
        newParagraphText.getAttributionSpansInRange(
          attributionFilter: (a) => a is LinkAttribution,
          range: SpanRange(0, newParagraphText.text.length - 1),
        ),
        isEmpty,
      );
    });

    testWidgetsOnAllPlatforms('does not extend link to new list item', (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown(" * [www.google.com](www.google.com)")
          .withInputSource(TextInputSource.ime)
          .pump();

      final doc = SuperEditorInspector.findDocument()!;

      // Ensure the Markdown correctly created a list item.
      expect(doc.nodes.first, isA<ListItemNode>());

      // Place the caret at "www.google.com|".
      await tester.placeCaretInParagraph(doc.nodes.first.id, 14);

      // Create a new list item.
      await tester.pressEnter();

      // We had an issue where link attributions were extended to the beginning of
      // an empty list item, but were removed after the user started typing. So, first,
      // ensure that no link markers were added to the empty list item.
      expect(doc.nodes.length, 2);
      expect(doc.nodes[1], isA<ListItemNode>());
      final newListItemId = doc.nodes[1].id;
      AttributedText newListItemText = SuperEditorInspector.findTextInParagraph(newListItemId);
      expect(newListItemText.spans.markers, isEmpty);

      // Type some text.
      await tester.typeImeText("New list item");

      // Ensure the text we typed didn't re-introduce a link attribution.
      newListItemText = SuperEditorInspector.findTextInParagraph(newListItemId);
      expect(newListItemText.text, "New list item");
      expect(
        newListItemText.getAttributionSpansInRange(
          attributionFilter: (a) => a is LinkAttribution,
          range: SpanRange(0, newListItemText.text.length - 1),
        ),
        isEmpty,
      );
    });

    // TODO: once it's easier to configure task components (#1295), add a test that checks link attributions when inserting a new task
  });
}
