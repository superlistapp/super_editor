import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import 'custom_parsers/callout_block.dart';
import 'custom_parsers/upsell_block.dart';

void main() {
  group("Markdown deserialization", () {
    test("handles custom placeholder block syntax", () {
      final document = deserializeMarkdownToDocument(
        '''# Header 1
This is a normal paragraph.

@@@ upsell
  
This is another normal paragraph.''',
        customBlockSyntax: [UpsellBlockSyntax()],
        customElementToNodeConverters: [UpsellElementToNodeConverter()],
      );

      expect(document.nodes.length, 4);
      expect(
        document.nodes[0],
        isA<ParagraphNode>(),
      );
      expect(
        document.nodes[1],
        isA<ParagraphNode>(),
      );
      expect(
        document.nodes[2],
        isA<UpsellNode>(),
      );
      expect(
        document.nodes[3],
        isA<ParagraphNode>(),
      );
    });

    test("handles custom text block syntax", () {
      final document = deserializeMarkdownToDocument(
        '''# Header 1
This is a normal paragraph.

@@@ callout
This is a **callout**!
@@@
  
This is another normal paragraph.''',
        customBlockSyntax: [CalloutBlockSyntax()],
        customElementToNodeConverters: [CalloutElementToNodeConverter()],
      );

      expect(document.nodes.length, 4);
      expect(
        document.nodes[0],
        isA<ParagraphNode>(),
      );
      expect(
        document.nodes[1],
        isA<ParagraphNode>(),
      );
      expect(
        document.nodes[2],
        isA<ParagraphNode>(),
      );
      expect(
        (document.nodes[2] as ParagraphNode).metadata["blockType"],
        const NamedAttribution("callout"),
      );
      expect(
        document.nodes[3],
        isA<ParagraphNode>(),
      );
    });
  });
}
