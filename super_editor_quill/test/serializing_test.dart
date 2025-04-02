import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/parsing/parser.dart';
import 'package:super_editor_quill/src/serializing/serializers.dart';
import 'package:super_editor_quill/src/serializing/serializing.dart';
import 'package:super_editor_quill/super_editor_quill_test.dart';

import 'test_documents.dart';

void main() {
  group("Delta document serializing >", () {
    test("empty document", () {
      final deltas = MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(""),
          ),
        ],
      ).toQuillDeltas();

      final expectedDeltas = Delta.fromJson([
        {"insert": "\n"},
      ]);

      expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
    });

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
              metadata: const {
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
              metadata: const {
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
              metadata: const {
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

    group("custom serializers >", () {
      test("can serialize inline embeds", () {
        const userMentionAttribution = _UserTagAttribution("123456");

        final deltas = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "1",
              text: AttributedText(
                "Inline embed @John Smith and bold and italics",
                AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: userMentionAttribution, offset: 13, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: userMentionAttribution, offset: 23, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: boldAttribution, offset: 29, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: boldAttribution, offset: 32, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: italicsAttribution, offset: 38, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: italicsAttribution, offset: 44, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
            ),
          ],
        ).toQuillDeltas(
          serializers: _serializersWithInlineEmbeds,
        );

        final expectedDeltas = Delta.fromJson([
          {"insert": "Inline embed "},
          {
            "insert": {
              "tag": {
                "type": "user",
                "userId": "123456",
                "text": "@John Smith",
              },
            },
          },
          {"insert": " and "},
          {
            "insert": "bold",
            "attributes": {"bold": true},
          },
          {"insert": " and "},
          {
            "insert": "italics",
            "attributes": {"italic": true},
          },
          {"insert": "\n"},
        ]);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });

      test("doesn't merge custom block with previous delta", () {
        final deltas = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "1",
              text: AttributedText(
                "This is a regular paragraph.",
              ),
            ),
            ParagraphNode(
              id: "2",
              text: AttributedText(
                "This is a banner (a custom block style).",
              ),
              metadata: const {
                'blockType': _BannerAttribution('red'),
              },
            ),
          ],
        ).toQuillDeltas(
          serializers: [
            const _BannerDeltaSerializer(),
            ...defaultDeltaSerializers,
          ],
        );

        final expectedDeltas = Delta.fromJson([
          {"insert": "This is a regular paragraph.\nThis is a banner (a custom block style)."},
          {
            "insert": "\n",
            "attributes": {
              "banner-color": "red",
            },
          },
        ]);

        expect(deltas, quillDocumentEquivalentTo(expectedDeltas));
      });
    });
  });
}

const _serializersWithInlineEmbeds = [
  ParagraphDeltaSerializer(inlineEmbedDeltaSerializers: _inlineEmbedSerializers),
  ListItemDeltaSerializer(inlineEmbedDeltaSerializers: _inlineEmbedSerializers),
  TaskDeltaSerializer(inlineEmbedDeltaSerializers: _inlineEmbedSerializers),
  imageDeltaSerializer,
  videoDeltaSerializer,
  audioDeltaSerializer,
  fileDeltaSerializer,
];

const _inlineEmbedSerializers = [_UserTagInlineEmbedSerializer()];

class _UserTagInlineEmbedSerializer implements InlineEmbedDeltaSerializer {
  const _UserTagInlineEmbedSerializer();

  @override
  bool serialize(String text, Set<Attribution> attributions, Delta deltas) {
    final userTag = attributions.whereType<_UserTagAttribution>().firstOrNull;
    if (userTag == null) {
      return false;
    }

    deltas.operations.add(
      Operation.insert({
        "tag": {
          "type": "user",
          "userId": userTag.userId,
          "text": text,
        },
      }),
    );

    return true;
  }
}

class _UserTagAttribution implements Attribution {
  const _UserTagAttribution(this.userId);

  @override
  String get id => userId;

  final String userId;

  @override
  bool canMergeWith(Attribution other) {
    return other is _UserTagAttribution && userId == other.userId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserTagAttribution && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}

class _BannerDeltaSerializer extends TextBlockDeltaSerializer {
  const _BannerDeltaSerializer();

  @override
  Map<String, dynamic> getBlockFormats(TextNode textBlock) {
    final bannerAttribution = textBlock.metadata['blockType'];
    if (bannerAttribution is! _BannerAttribution) {
      return super.getBlockFormats(textBlock);
    }

    final formats = super.getBlockFormats(textBlock);
    formats['banner-color'] = bannerAttribution.color;

    return formats;
  }
}

class _BannerAttribution implements Attribution {
  const _BannerAttribution(this.color);

  @override
  String get id => "banner-$color";

  final String color;

  @override
  bool canMergeWith(Attribution other) {
    if (other is! _BannerAttribution) {
      return false;
    }

    return color == other.color;
  }
}
