import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("MutableDocument", () {
    test("calculates a range from an upstream selection within a single node", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText("This is a paragraph of text."),
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
            text: AttributedText("This is a paragraph of text."),
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

    group("getNodeIndexById returns the correct index", () {
      test("when creating a document", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        // Ensure the indices are correct when creating the document.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when inserting a node at the beginning by index", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node at the beginning.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeAt(0, thirdNode);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(thirdNode.id), 0);
        expect(document.getNodeIndexById(firstNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when inserting a node at the middle by index", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node between firstNode and secondNode.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeAt(1, thirdNode);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when inserting a node at the end by index", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node at the end.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeAt(2, thirdNode);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when inserting a node before the first node", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node at the beginning.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeBefore(
          existingNodeId: firstNode.id,
          newNode: thirdNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(thirdNode.id), 0);
        expect(document.getNodeIndexById(firstNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when inserting a node before the last node", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node between the two nodes.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeBefore(
          existingNodeId: secondNode.id,
          newNode: thirdNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when inserting a node after the first node", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node between the two nodes.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeAfter(
          existingNodeId: firstNode.id,
          newNode: thirdNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when inserting a node after the last node", () {
        final document = _createTwoParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;

        // Insert a new node at the end.
        final thirdNode = ParagraphNode(
          id: "3",
          text: AttributedText("This is the third paragraph."),
        );
        document.insertNodeAfter(
          existingNodeId: secondNode.id,
          newNode: thirdNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when moving a node from the beginning to the middle", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.moveNode(
          nodeId: firstNode.id,
          targetIndex: 1,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(secondNode.id), 0);
        expect(document.getNodeIndexById(firstNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when moving a node from the middle to the end", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.moveNode(
          nodeId: secondNode.id,
          targetIndex: 2,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when moving a node from the end to the middle", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.moveNode(
          nodeId: thirdNode.id,
          targetIndex: 1,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
        expect(document.getNodeIndexById(secondNode.id), 2);
      });

      test("when moving a node from the middle to the beginning", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.moveNode(
          nodeId: secondNode.id,
          targetIndex: 0,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(secondNode.id), 0);
        expect(document.getNodeIndexById(firstNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when deleting a node at the beginning", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.deleteNode(firstNode.id);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), -1);
        expect(document.getNodeIndexById(secondNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
      });

      test("when deleting a node at the middle", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.deleteNode(secondNode.id);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(secondNode.id), -1);
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(thirdNode.id), 1);
      });

      test("when deleting a node at the end", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        document.deleteNode(thirdNode.id);

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(thirdNode.id), -1);
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
      });

      test("when replacing a node at the beginning", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        final fourthNode = ParagraphNode(
          id: "4",
          text: AttributedText("This is the third paragraph."),
        );

        document.replaceNodeById(
          firstNode.id,
          fourthNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(firstNode.id), -1);
        expect(document.getNodeIndexById(fourthNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when replacing a node at the middle", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        final fourthNode = ParagraphNode(
          id: "4",
          text: AttributedText("This is the third paragraph."),
        );

        document.replaceNodeById(
          secondNode.id,
          fourthNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(secondNode.id), -1);
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(fourthNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("when replacing a node at the end", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        final fourthNode = ParagraphNode(
          id: "4",
          text: AttributedText("This is the third paragraph."),
        );

        document.replaceNodeById(
          thirdNode.id,
          fourthNode,
        );

        // Ensure the indices are correct.
        expect(document.getNodeIndexById(thirdNode.id), -1);
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(fourthNode.id), 2);
      });

      test("when replacing a node with a node that has the same ID", () {
        final document = _createThreeParagraphDoc();
        final firstNode = document.getNodeAt(0)!;
        final secondNode = document.getNodeAt(1)!;
        final thirdNode = document.getNodeAt(2)!;

        final updatedSecondNode = ParagraphNode(
          id: secondNode.id,
          text: AttributedText("This is the updated second paragraph."),
        );

        document.replaceNodeById(
          secondNode.id,
          updatedSecondNode,
        );

        expect(document.toList(), [firstNode, updatedSecondNode, thirdNode]);
        expect(document.getNodeById(secondNode.id), same(updatedSecondNode));
        expect(document.getNodeIndexById(firstNode.id), 0);
        expect(document.getNodeIndexById(secondNode.id), 1);
        expect(document.getNodeIndexById(thirdNode.id), 2);
      });

      test("without re-indexing the other nodes when the ID stays the same", () {
        final nodes = [
          for (var i = 0; i < 100; i++) _IdReadCountingParagraphNode("$i"),
        ];
        final document = MutableDocument(nodes: [...nodes]);
        for (final node in nodes) {
          node.idReads = 0;
        }

        document.replaceNodeById("50", ParagraphNode(id: "50", text: AttributedText("Updated")));

        final idReadsOfOtherNodes = [
          for (var i = 0; i < nodes.length; i++)
            if (i != 50) nodes[i].idReads,
        ];
        expect(idReadsOfOtherNodes, everyElement(0));
        expect(document.getNodeIndexById("51"), 51);
      });
    });
  });
}

class _IdReadCountingParagraphNode extends ParagraphNode {
  _IdReadCountingParagraphNode(String id) : super(id: id, text: AttributedText("Paragraph $id"));

  int idReads = 0;

  @override
  String get id {
    idReads += 1;
    return super.id;
  }
}

MutableDocument _createTwoParagraphDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText("This is the first paragraph."),
      ),
      ParagraphNode(
        id: "2",
        text: AttributedText("This is the second paragraph."),
      ),
    ],
  );
}

MutableDocument _createThreeParagraphDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText("This is the first paragraph."),
      ),
      ParagraphNode(
        id: "2",
        text: AttributedText("This is the second paragraph."),
      ),
      ParagraphNode(
        id: "3",
        text: AttributedText("This is the third paragraph."),
      ),
    ],
  );
}
