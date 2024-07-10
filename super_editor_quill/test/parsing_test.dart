import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

import 'test_documents.dart';

// Useful links:
//  - create a Delta document in the browser: https://quilljs.com/docs/delta
//  - list of supported formats (bold, italics, header, etc): https://quilljs.com/docs/formats

void main() {
  group("Delta document parsing >", () {
    group("text >", () {
      test("newlines", () {
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "\nLine one\nLine two\nLine three\nLine four\n\n"}
            ],
          },
        );

        expect((document.getNodeAt(0)! as TextNode).text.text, "");
        expect((document.getNodeAt(1)! as TextNode).text.text, "Line one");
        expect((document.getNodeAt(2)! as TextNode).text.text, "Line two");
        expect((document.getNodeAt(3)! as TextNode).text.text, "Line three");
        expect((document.getNodeAt(4)! as TextNode).text.text, "Line four");
        expect((document.getNodeAt(5)! as TextNode).text.text, "");
        expect((document.getNodeAt(6)! as TextNode).text.text, "");

        // A note on the length of the document. If this document is placed in a
        // Quill editor, there will only be 6 lines the user can edit. This seems
        // like it's probably a part of Quill specified behavior. I think that
        // because every Quill document must always end with a newline, the final
        // newline of a document is ignored by a Quill editor. But in our case
        // we parse every newline, including the trailing newline, so the length
        // of this document is 7. If that's a problem, we can make the parser
        // more intelligent about this later.
        expect(document.nodeCount, 7);
      });

      test("multiline code block", () {
        // Notice that Delta encodes each line of a code block as a separate attributed
        // delta. But when a Quill editor renders the code block, it's rendered as one
        // block. This test ensures that Super Editor accumulates back-to-back code
        // lines into a single code node.
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "This is a code block"},
              {
                "attributes": {"code-block": "plain"},
                "insert": "\n"
              },
              {"insert": "This is line two"},
              {
                "attributes": {"code-block": "plain"},
                "insert": "\n"
              },
              {"insert": "This is line three"},
              {
                "attributes": {"code-block": "plain"},
                "insert": "\n"
              },
            ],
          },
        );

        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.text,
          "This is a code block\nThis is line two\nThis is line three",
        );
        expect((document.getNodeAt(0)! as ParagraphNode).getMetadataValue("blockType"), codeAttribution);
        expect((document.getNodeAt(1)! as ParagraphNode).text.text, "");
        expect(document.nodeCount, 2);
      });

      test("all text blocks and styles", () {
        final document = parseQuillDeltaOps(allTextStylesDeltaDocument);

        final nodes = document.iterator..moveNext();
        DocumentNode? node = nodes.current;

        // Check the header.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "All Text Styles");

        nodes.moveNext();
        node = nodes.current;

        // Check the paragraph with various formatting.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text,
            "Samples of styles: bold, italics, underline, strikethrough, text color, background color, font change, link");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: boldAttribution, start: 19, end: 22),
            const AttributionSpan(attribution: italicsAttribution, start: 25, end: 31),
            const AttributionSpan(attribution: underlineAttribution, start: 34, end: 42),
            const AttributionSpan(attribution: strikethroughAttribution, start: 45, end: 57),
            const AttributionSpan(attribution: ColorAttribution(Color(0xFFe60000)), start: 60, end: 69),
            const AttributionSpan(attribution: BackgroundColorAttribution(Color(0xFFe60000)), start: 72, end: 87),
            const AttributionSpan(attribution: FontFamilyAttribution("serif"), start: 90, end: 100),
            const AttributionSpan(attribution: LinkAttribution("google.com"), start: 103, end: 106),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - left aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Left aligned");
        expect(node.metadata["textAlign"], isNull);

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - center aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Center aligned");
        expect(node.metadata["textAlign"], "center");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - right aligned.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Right aligned");
        expect(node.metadata["textAlign"], "right");

        nodes.moveNext();
        node = nodes.current;

        // Paragraph - justified.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Justified");
        expect(node.metadata["textAlign"], "justify");

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Ordered list items.
        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.text, "Ordered item 1");
        expect(node.type, ListItemType.ordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.text, "Ordered item 2");
        expect(node.type, ListItemType.ordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Unordered list items.
        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.text, "Unordered item 1");
        expect(node.type, ListItemType.unordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ListItemNode>());
        expect((node as ListItemNode).text.text, "Unordered item 2");
        expect(node.type, ListItemType.unordered);
        expect(node.indent, 0);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Tasks.
        expect(node, isA<TaskNode>());
        expect((node as TaskNode).text.text, "I'm a task that's incomplete");
        expect(node.isComplete, isFalse);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<TaskNode>());
        expect((node as TaskNode).text.text, "I'm a task that's complete");
        expect(node.isComplete, isTrue);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Indented paragraphs.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "I'm an indented paragraph at level 1");
        expect((node as ParagraphNode).indent, 1);

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "I'm a paragraph indented at level 2");
        expect((node as ParagraphNode).indent, 2);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Superscript and subscript.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Some contentThis is a subscript");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: subscriptAttribution, start: 12, end: 30),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Some contentThis is a superscript");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: superscriptAttribution, start: 12, end: 32),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Text sizes.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "HUGE");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("huge"), start: 0, end: 3),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "Large");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("large"), start: 0, end: 4),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "small");
        expect(
          node.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: NamedFontSizeAttribution("small"), start: 0, end: 4),
          },
        );

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Blockquote.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "This is a blockquote");
        expect(node.metadata["blockType"], blockquoteAttribution);

        nodes.moveNext();
        node = nodes.current;

        // Blank line.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        nodes.moveNext();
        node = nodes.current;

        // Code block - with multiple lines.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "This is a code block\nThat spans two lines.");
        expect(node.metadata["blockType"], codeAttribution);

        nodes.moveNext();
        node = nodes.current;

        // Final newline node.
        expect(node, isA<ParagraphNode>());
        expect((node as TextNode).text.text, "");

        // No more nodes.
        expect(nodes.moveNext(), isFalse);
      });

      test("overlapping styles", () {
        final document = parseQuillDeltaDocument(
          {
            "ops": [
              {"insert": "This "},
              {
                "attributes": {"bold": true},
                "insert": "paragraph ",
              },
              {
                "attributes": {"italic": true, "bold": true},
                "insert": "has ",
              },
              {
                "attributes": {"underline": true, "italic": true, "bold": true},
                "insert": "some",
              },
              {
                "attributes": {"underline": true, "italic": true},
                "insert": " overlapping",
              },
              {
                "attributes": {"underline": true},
                "insert": " styles",
              },
              {"insert": ".\n"},
            ],
          },
        );

        final paragraph = document.first as ParagraphNode;
        expect(paragraph.text.text, "This paragraph has some overlapping styles.");
        expect(
          paragraph.text.getAttributionSpansByFilter((a) => true),
          {
            const AttributionSpan(attribution: boldAttribution, start: 5, end: 22),
            const AttributionSpan(attribution: italicsAttribution, start: 15, end: 34),
            const AttributionSpan(attribution: underlineAttribution, start: 19, end: 41),
          },
        );
      });

      test("gracefully handles unknown inline text format", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph "},
          {
            // A non-existent inline format.
            "attributes": {"unknown": true},
            "insert": "one"
          },
          {"insert": "\nParagraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.text, "Paragraph one");
        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.getAttributionSpansByFilter((a) => true),
          const <AttributionSpan>{},
        );

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.text, "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.text, "");
      });

      test("gracefully handles unknown text block format", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one"},
          {
            "attributes": {"unknown-name": "unknown-value"},
            "insert": "\n"
          },
          {"insert": "Paragraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.text, "Paragraph one");
        expect((document.getNodeAt(0)! as ParagraphNode).metadata["blockType"], paragraphAttribution);
        expect(
          (document.getNodeAt(0)! as ParagraphNode).text.getAttributionSpansByFilter((a) => true),
          const <AttributionSpan>{},
        );

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.text, "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.text, "");
      });
    });

    group("media >", () {
      test("an image", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "image": "https://quilljs.com/assets/images/icon.png",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final image = document.getNodeAt(1)!;
        expect(image, isA<ImageNode>());
        image as ImageNode;
        expect(image.imageUrl, "https://quilljs.com/assets/images/icon.png");
      });

      // TODO: make it possible to linkify an image (needs added support in SuperEditor).
      test("an image with a link", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "image": "https://quilljs.com/assets/images/icon.png",
            },
            "attributes": {
              "link": "https://quilljs.com",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final image = document.getNodeAt(1)!;
        expect(image, isA<ImageNode>());
        image as ImageNode;
        expect(image.imageUrl, "https://quilljs.com/assets/images/icon.png");
      }, skip: true);

      test("a video", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "video": "https://quilljs.com/assets/media/video.mp4",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final video = document.getNodeAt(1)!;
        expect(video, isA<VideoNode>());
        video as VideoNode;
        expect(video.url, "https://quilljs.com/assets/media/video.mp4");
      });

      test("audio", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "audio": "https://quilljs.com/assets/media/audio.mp3",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final audio = document.getNodeAt(1)!;
        expect(audio, isA<AudioNode>());
        audio as AudioNode;
        expect(audio.url, "https://quilljs.com/assets/media/audio.mp3");
      });

      test("a file", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "file": "https://quilljs.com/assets/media/file.pdf",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        final file = document.getNodeAt(1)!;
        expect(file, isA<FileNode>());
        file as FileNode;
        expect(file.url, "https://quilljs.com/assets/media/file.pdf");
      });

      test("gracefully handles unknown media block", () {
        final document = parseQuillDeltaOps([
          {"insert": "Paragraph one\n"},
          {
            "insert": {
              "unknown": "this block type doesn't exist",
            },
          },
          {"insert": "Paragraph two\n"},
        ]);

        expect(document.nodeCount, 3);

        expect(document.getNodeAt(0)!, isA<ParagraphNode>());
        expect((document.getNodeAt(0)! as ParagraphNode).text.text, "Paragraph one");

        expect(document.getNodeAt(1)!, isA<ParagraphNode>());
        expect((document.getNodeAt(1)! as ParagraphNode).text.text, "Paragraph two");

        expect(document.getNodeAt(2)!, isA<ParagraphNode>());
        expect((document.getNodeAt(2)! as ParagraphNode).text.text, "");
      });
    });
  });
}
