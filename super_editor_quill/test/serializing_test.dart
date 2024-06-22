import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor_quill/src/parsing/parser.dart';
import 'package:super_editor_quill/src/serializing/serializing.dart';

import 'quill_delta_comparison.dart';
import 'test_documents.dart';

void main() {
  group("Delta document serializing >", () {
    group("text >", () {
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
