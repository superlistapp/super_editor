import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Document selection", () {
    group("selects upstream position", () {
      test("when the positions are the same", () {
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        expect(
          _testDoc.selectUpstreamPosition(position, position),
          position,
        );
      });

      test("when the positions are in the same node", () {
        const position1 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        const position2 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1));
        expect(
          _testDoc.selectUpstreamPosition(position1, position2),
          position1,
        );
        expect(
          _testDoc.selectUpstreamPosition(position2, position1),
          position1,
        );
      });

      test("when the positions are in different nodes", () {
        const position1 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        const position2 = DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0));
        expect(
          _testDoc.selectUpstreamPosition(position1, position2),
          position1,
        );
        expect(
          _testDoc.selectUpstreamPosition(position2, position1),
          position1,
        );
      });
    });

    group("selects downstream position", () {
      test("when the positions are the same", () {
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        expect(
          _testDoc.selectDownstreamPosition(position, position),
          position,
        );
      });

      test("when the positions are in the same node", () {
        const position1 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        const position2 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1));
        expect(
          _testDoc.selectDownstreamPosition(position1, position2),
          position2,
        );
        expect(
          _testDoc.selectDownstreamPosition(position2, position1),
          position2,
        );
      });

      test("when the positions are in different nodes", () {
        const position1 = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        const position2 = DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0));
        expect(
          _testDoc.selectDownstreamPosition(position1, position2),
          position2,
        );
        expect(
          _testDoc.selectDownstreamPosition(position2, position1),
          position2,
        );
      });
    });

    group("knows if it contains a position", () {
      test("when the selection is collapsed", () {
        const selection = DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)));
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));
        expect(_testDoc.doesSelectionContainPosition(selection, position), false);
      });

      test("when the selection is within one node and contains the position", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 2)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 2)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
        );
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), true);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), true);
      });

      test("when the selection is within one node and the position sits before selection", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 2)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 2)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
        );
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), false);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), false);
      });

      test("when the selection is within one node and the position sits after selection", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
        );
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 2));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), false);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), false);
      });

      test("when the selection is across two nodes and contains the position", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
        );
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), true);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), true);
      });

      test("when the selection is across two nodes and the position comes before the selection", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
          extent: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 1)),
        );
        const position = DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), false);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), false);
      });

      test("when the selection is across two nodes and the position comes after the selection", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
        );
        const position = DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 1));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), false);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), false);
      });

      test("when the selection is across three nodes and the position is in the middle", () {
        const downstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        );
        const upstreamSelection = DocumentSelection(
          base: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
        );
        const position = DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0));

        expect(_testDoc.doesSelectionContainPosition(downstreamSelection, position), true);
        expect(_testDoc.doesSelectionContainPosition(upstreamSelection, position), true);
      });
    });
  });
}

final _testDoc = MutableDocument(
  nodes: [
    ParagraphNode(id: "1", text: AttributedText(text: "Paragraph 1")),
    ParagraphNode(id: "2", text: AttributedText(text: "Paragraph 2")),
    ParagraphNode(id: "3", text: AttributedText(text: "Paragraph 3")),
  ],
);
