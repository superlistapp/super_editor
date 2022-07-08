import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("MutableDocument", () {
    test("calculates a range from an upstream selection within a single node", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(text: "This is a paragraph of text."),
          ),
        ],
      );

      // Try to get an upstream range.
      final range = document.getRangeBetween(
        const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 20)),
        const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 10)),
      );

      // Ensure the range is upstream.
      expect(
        range.start,
        const DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 10),
        ),
      );
      expect(
        range.end,
        const DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
    });

    test("calculates a range from an downstream selection within a single node", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(text: "This is a paragraph of text."),
          ),
        ],
      );

      // Try to get an upstream range.
      final range = document.getRangeBetween(
        const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 10)),
        const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 20)),
      );

      // Ensure the range is upstream.
      expect(
        range.start,
        const DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 10),
        ),
      );
      expect(
        range.end,
        const DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
    });
  });
}
