import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/parsing/parser.dart';
import 'package:super_editor_quill/src/serializing/serializing.dart';

import 'quill_delta_comparison.dart';
import 'test_documents.dart';

void main() {
  group("Delta document serializing >", () {
    group("text >", () {
      test("multiline header", () {
        // Note: The official Quill editor doesn't seem to support multiline
        //       headers, visually. The Delta format definitely doesn't
        //       support them. Each header line gets its own attributed
        //       insertion.
        final deltas = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "1",
              text: AttributedText("This paragraph is followed by a multiline header:"),
            ),
            ParagraphNode(
              id: "2",
              text: AttributedText("This is a header\nThis is line two\nThis is line three"),
              metadata: {
                "blockType": header1Attribution,
              },
            ),
          ],
        ).toQuillDeltas();

        final expectedDeltas = Delta.fromJson([
          {"insert": "This paragraph is followed by a multiline header:\nThis is a header"},
          {
            "attributes": {"header": 1},
            "insert": "\n",
          },
          {"insert": "This is line two"},
          {
            "attributes": {"header": 1},
            "insert": "\n",
          },
          {"insert": "This is line three"},
          {
            "attributes": {"header": 1},
            "insert": "\n",
          },
        ]);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });

      test("multiline blockquote", () {
        // Note: The official Quill editor doesn't seem to support multiline
        //       blockquotes, visually. The Delta format definitely doesn't
        //       support them. Each blockquote line gets its own attributed
        //       insertion.
        final deltas = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "1",
              text: AttributedText("This paragraph is followed by a multiline blockquote:"),
            ),
            ParagraphNode(
              id: "2",
              text: AttributedText("This is a blockquote\nThis is line two\nThis is line three"),
              metadata: {
                "blockType": blockquoteAttribution,
              },
            ),
          ],
        ).toQuillDeltas();

        final expectedDeltas = Delta.fromJson([
          {"insert": "This paragraph is followed by a multiline blockquote:\nThis is a blockquote"},
          {
            "attributes": {"blockquote": true},
            "insert": "\n",
          },
          {"insert": "This is line two"},
          {
            "attributes": {"blockquote": true},
            "insert": "\n",
          },
          {"insert": "This is line three"},
          {
            "attributes": {"blockquote": true},
            "insert": "\n",
          },
        ]);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });

      test("multiline code block", () {
        // Note: Quill can display multiple lines in a single code block, but
        //       Delta serializes each of those lines as separate, attributed
        //       insertions.
        final deltas = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "1",
              text: AttributedText("This paragraph is followed by a multiline code block:"),
            ),
            ParagraphNode(
              id: "2",
              text: AttributedText("This is a code block\nThis is line two\nThis is line three"),
              metadata: {
                "blockType": codeAttribution,
              },
            ),
          ],
        ).toQuillDeltas();

        final expectedDeltas = Delta.fromJson([
          {"insert": "This paragraph is followed by a multiline code block:\nThis is a code block"},
          {
            "attributes": {"code-block": "plain"},
            "insert": "\n",
          },
          {"insert": "This is line two"},
          {
            "attributes": {"code-block": "plain"},
            "insert": "\n",
          },
          {"insert": "This is line three"},
          {
            "attributes": {"code-block": "plain"},
            "insert": "\n",
          },
        ]);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });

      test("all text blocks and styles", () {
        final deltas = createAllTextStylesSuperEditorDocument().toQuillDeltas();
        final expectedDeltas = Delta.fromJson(allTextStylesDeltaDocument);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });
    });

    group("media >", () {
      test("image", () {
        final deltas = parseQuillDeltaDocument({
          "ops": [
            {"insert": "This is paragraph 1\n"},
            {
              "insert": {"image": "https://quilljs.com/assets/images/icon.png"},
            },
            {"insert": "This is paragraph 2\n"},
          ]
        }).toQuillDeltas();

        expect(deltas.operations, [
          Operation.insert("This is paragraph 1\n"),
          Operation.insert({
            "image": "https://quilljs.com/assets/images/icon.png",
          }),
          Operation.insert("This is paragraph 2\n"),
        ]);
      });

      test("video", () {
        final deltas = parseQuillDeltaDocument({
          "ops": [
            {"insert": "This is paragraph 1\n"},
            {
              "insert": {"video": "https://quilljs.com/assets/videos/video.mp4"},
            },
            {"insert": "This is paragraph 2\n"},
          ]
        }).toQuillDeltas();

        expect(deltas.operations, [
          Operation.insert("This is paragraph 1\n"),
          Operation.insert({
            "video": "https://quilljs.com/assets/videos/video.mp4",
          }),
          Operation.insert("This is paragraph 2\n"),
        ]);
      });

      test("audio", () {
        final deltas = parseQuillDeltaDocument({
          "ops": [
            {"insert": "This is paragraph 1\n"},
            {
              "insert": {"audio": "https://quilljs.com/assets/audio/audio.mp3"},
            },
            {"insert": "This is paragraph 2\n"},
          ]
        }).toQuillDeltas();

        expect(deltas.operations, [
          Operation.insert("This is paragraph 1\n"),
          Operation.insert({
            "audio": "https://quilljs.com/assets/audio/audio.mp3",
          }),
          Operation.insert("This is paragraph 2\n"),
        ]);
      });

      test("file", () {
        final deltas = parseQuillDeltaDocument({
          "ops": [
            {"insert": "This is paragraph 1\n"},
            {
              "insert": {"file": "https://quilljs.com/assets/files/file.pdf"},
            },
            {"insert": "This is paragraph 2\n"},
          ]
        }).toQuillDeltas();

        expect(deltas.operations, [
          Operation.insert("This is paragraph 1\n"),
          Operation.insert({
            "file": "https://quilljs.com/assets/files/file.pdf",
          }),
          Operation.insert("This is paragraph 2\n"),
        ]);
      });
    });
  });
}
