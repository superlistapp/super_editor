import 'package:super_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/serialization/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Markdown', () {
    group('serialization', () {
      test('headers', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'My Header'),
          ),
        ]);

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header1';
        expect(serializeDocumentToMarkdown(doc).trim(), '# My Header');

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header2';
        expect(serializeDocumentToMarkdown(doc).trim(), '## My Header');

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header3';
        expect(serializeDocumentToMarkdown(doc).trim(), '### My Header');

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header4';
        expect(serializeDocumentToMarkdown(doc).trim(), '#### My Header');

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header5';
        expect(serializeDocumentToMarkdown(doc).trim(), '##### My Header');

        (doc.nodes[0] as ParagraphNode).metadata['blockType'] = 'header6';
        expect(serializeDocumentToMarkdown(doc).trim(), '###### My Header');
      });

      test('header with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'My Header',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 3, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            metadata: {'blockType': 'header1'},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '# My **Header**');
      });

      test('blockquote', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is a blockquote'),
            metadata: {'blockType': 'blockquote'},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '> This is a blockquote');
      });

      test('blockquote with styles', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a blockquote',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 10, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 19, markerType: SpanMarkerType.end),
                ],
              ),
            ),
            metadata: {'blockType': 'blockquote'},
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '> This is a **blockquote**');
      });

      test('code', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is some code'),
            metadata: {'blockType': 'code'},
          ),
        ]);

        expect(
            serializeDocumentToMarkdown(doc).trim(),
            '''
```
This is some code
```'''
                .trim());
      });

      test('paragraph', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(text: 'This is a paragraph.'),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), 'This is a paragraph.');
      });

      test('paragraph with one inline style', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 5, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), 'This **is a** paragraph.');
      });

      test('paragraph with overlapping bold and italics', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 5, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.end),
                  SpanMarker(attribution: 'italics', offset: 5, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'italics', offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), 'This ***is a*** paragraph.');
      });

      test('paragraph with overlapping code and bold', () {
        final doc = MutableDocument(nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText(
              text: 'This is a paragraph.',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 5, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.end),
                  SpanMarker(attribution: 'code', offset: 5, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'code', offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), 'This `**is a**` paragraph.');
      });

      test('image', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: '1',
            imageUrl: 'https://someimage.com/the/image.png',
            altText: 'some alt text',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '![some alt text](https://someimage.com/the/image.png)');
      });

      test('horizontal rule', () {
        final doc = MutableDocument(nodes: [
          HorizontalRuleNode(
            id: '1',
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '---');
      });

      test('unordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText(text: 'Unordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.unordered,
            indent: 1,
            text: AttributedText(text: 'Unordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 3'),
          ),
        ]);

        expect(
            serializeDocumentToMarkdown(doc).trim(),
            '''
  * Unordered 1
  * Unordered 2
    * Unordered 2.1
    * Unordered 2.2
  * Unordered 3'''
                .trim());
      });

      test('unordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.unordered,
            text: AttributedText(
              text: 'Unordered 1',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '* **Unordered** 1');
      });

      test('ordered list items', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 1'),
          ),
          ListItemNode(
            id: '2',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 2'),
          ),
          ListItemNode(
            id: '3',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText(text: 'Ordered 2.1'),
          ),
          ListItemNode(
            id: '4',
            itemType: ListItemType.ordered,
            indent: 1,
            text: AttributedText(text: 'Ordered 2.2'),
          ),
          ListItemNode(
            id: '5',
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 3'),
          ),
        ]);

        expect(
            serializeDocumentToMarkdown(doc).trim(),
            '''
  1. Ordered 1
  1. Ordered 2
    1. Ordered 2.1
    1. Ordered 2.2
  1. Ordered 3'''
                .trim());
      });

      test('ordered list item with styles', () {
        final doc = MutableDocument(nodes: [
          ListItemNode(
            id: '1',
            itemType: ListItemType.ordered,
            text: AttributedText(
              text: 'Ordered 1',
              spans: AttributedSpans(
                attributions: [
                  SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: 'bold', offset: 6, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        ]);

        expect(serializeDocumentToMarkdown(doc).trim(), '1. **Ordered** 1');
      });

      test('example doc', () {
        final doc = MutableDocument(nodes: [
          ImageNode(
            id: DocumentEditor.createNodeId(),
            imageUrl: 'https://someimage.com/the/image.png',
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'Example Doc'),
            metadata: {'blockType': 'header1'},
          ),
          HorizontalRuleNode(id: DocumentEditor.createNodeId()),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'Unordered list:'),
          ),
          ListItemNode(
            id: DocumentEditor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 1'),
          ),
          ListItemNode(
            id: DocumentEditor.createNodeId(),
            itemType: ListItemType.unordered,
            text: AttributedText(text: 'Unordered 2'),
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'Ordered list:'),
          ),
          ListItemNode(
            id: DocumentEditor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 1'),
          ),
          ListItemNode(
            id: DocumentEditor.createNodeId(),
            itemType: ListItemType.ordered,
            text: AttributedText(text: 'Ordered 2'),
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'A blockquote:'),
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'This is a blockquote.'),
            metadata: {'blockType': 'blockquote'},
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: 'Some code:'),
          ),
          ParagraphNode(
            id: DocumentEditor.createNodeId(),
            text: AttributedText(text: '{\n  // This is some code.\n}'),
            metadata: {'blockType': 'code'},
          ),
        ]);

        // Ensure that the document serializes. We don't bother with
        // validating the output because other tests should validate
        // the per-node serializations.
        final markdown = serializeDocumentToMarkdown(doc);
      });
    });

    group('deserialization', () {
      test('headers', () {
        final header1Doc = deserializeMarkdownToDocument('# Header 1');
        expect((header1Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header1');

        final header2Doc = deserializeMarkdownToDocument('## Header 2');
        expect((header2Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header2');

        final header3Doc = deserializeMarkdownToDocument('### Header 3');
        expect((header3Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header3');

        final header4Doc = deserializeMarkdownToDocument('#### Header 4');
        expect((header4Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header4');

        final header5Doc = deserializeMarkdownToDocument('##### Header 5');
        expect((header5Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header5');

        final header6Doc = deserializeMarkdownToDocument('###### Header 6');
        expect((header6Doc.nodes.first as ParagraphNode).metadata['blockType'], 'header6');
      });

      test('blockquote', () {
        final blockquoteDoc = deserializeMarkdownToDocument('> This is a blockquote');

        final blockquote = blockquoteDoc.nodes.first as ParagraphNode;
        expect(blockquote.metadata['blockType'], 'blockquote');
        expect(blockquote.text.text, 'This is a blockquote');
      });

      test('code block', () {
        final codeBlockDoc = deserializeMarkdownToDocument('''
```
This is some code
```''');

        final code = codeBlockDoc.nodes.first as ParagraphNode;
        expect(code.metadata['blockType'], 'code');
        expect(code.text.text, 'This is some code\n');
      });

      test('image', () {
        final codeBlockDoc = deserializeMarkdownToDocument('![Image alt text](https://images.com/some/image.png)');

        final image = codeBlockDoc.nodes.first as ImageNode;
        expect(image.imageUrl, 'https://images.com/some/image.png');
        expect(image.altText, 'Image alt text');
      });

      test('single unstyled paragraph', () {
        final markdown = 'This is some unstyled text to parse as markdown';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        expect(paragraph.text.text, 'This is some unstyled text to parse as markdown');
      });

      test('single styled paragraph', () {
        final markdown = 'This is **some *styled*** text to parse as markdown';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 1);
        expect(document.nodes.first, isA<ParagraphNode>());

        final paragraph = document.nodes.first as ParagraphNode;
        final styledText = paragraph.text;
        expect(styledText.text, 'This is some styled text to parse as markdown');

        expect(styledText.getAllAttributionsAt(0).isEmpty, true);
        expect(styledText.getAllAttributionsAt(8).contains('bold'), true);
        expect(styledText.getAllAttributionsAt(13).containsAll(['bold', 'italics']), true);
        expect(styledText.getAllAttributionsAt(19).isEmpty, true);
      });

      test('unordered list', () {
        final markdown = '''
 * list item 1
 * list item 2
   * list item 2.1
   * list item 2.2
 * list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 5);
        for (final node in document.nodes) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.unordered);
        }

        expect((document.nodes[0] as ListItemNode).indent, 0);
        expect((document.nodes[1] as ListItemNode).indent, 0);
        expect((document.nodes[2] as ListItemNode).indent, 1);
        expect((document.nodes[3] as ListItemNode).indent, 1);
        expect((document.nodes[4] as ListItemNode).indent, 0);
      });

      test('ordered list', () {
        final markdown = '''
 1. list item 1
 1. list item 2
    1. list item 2.1
    1. list item 2.2
 1. list item 3''';

        final document = deserializeMarkdownToDocument(markdown);

        expect(document.nodes.length, 5);
        for (final node in document.nodes) {
          expect(node, isA<ListItemNode>());
          expect((node as ListItemNode).type, ListItemType.ordered);
        }

        expect((document.nodes[0] as ListItemNode).indent, 0);
        expect((document.nodes[1] as ListItemNode).indent, 0);
        expect((document.nodes[2] as ListItemNode).indent, 1);
        expect((document.nodes[3] as ListItemNode).indent, 1);
        expect((document.nodes[4] as ListItemNode).indent, 0);
      });

      test('example doc 1', () {
        final document = deserializeMarkdownToDocument(exampleMarkdownDoc1);

        expect(document.nodes.length, 18);

        expect(document.nodes[0], isA<ParagraphNode>());
        expect((document.nodes[0] as ParagraphNode).metadata['blockType'], 'header1');

        expect(document.nodes[1], isA<HorizontalRuleNode>());

        expect(document.nodes[2], isA<ParagraphNode>());

        expect(document.nodes[3], isA<ParagraphNode>());

        for (int i = 4; i < 9; ++i) {
          expect(document.nodes[i], isA<ListItemNode>());
        }

        expect(document.nodes[9], isA<HorizontalRuleNode>());

        for (int i = 10; i < 15; ++i) {
          expect(document.nodes[i], isA<ListItemNode>());
        }

        expect(document.nodes[15], isA<HorizontalRuleNode>());

        expect(document.nodes[16], isA<ImageNode>());

        expect(document.nodes[17], isA<ParagraphNode>());
      });
    });
  });
}

final exampleMarkdownDoc1 = '''
# Example 1
---
This is an example doc that has various types of nodes.

It includes multiple paragraphs, ordered list items, unordered list items, images, and HRs.

 * unordered item 1
 * unordered item 2
   * unordered item 2.1
   * unordered item 2.2
 * unordered item 3

---

 1. ordered item 1
 2. ordered item 2
   1. ordered item 2.1
   2. ordered item 2.2
 3. ordered item 3

---

![Image alt text](https://images.com/some/image.png)

The end!
''';
