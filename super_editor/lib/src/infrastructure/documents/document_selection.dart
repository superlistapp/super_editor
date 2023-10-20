import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';

/// Given a [DocumentSelection], which might span text and non-text content, extracts
/// all text from that selection as an un-styled `String`.
String extractTextFromSelection({
  required Document document,
  required DocumentSelection documentSelection,
}) {
  final selectedNodes = document.getNodesInside(
    documentSelection.base,
    documentSelection.extent,
  );

  final buffer = StringBuffer();
  for (int i = 0; i < selectedNodes.length; ++i) {
    final selectedNode = selectedNodes[i];
    dynamic nodeSelection;

    if (i == 0) {
      // This is the first node and it may be partially selected.
      final baseSelectionPosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

      final extentSelectionPosition =
          selectedNodes.length > 1 ? selectedNode.endPosition : documentSelection.extent.nodePosition;

      nodeSelection = selectedNode.computeSelection(
        base: baseSelectionPosition,
        extent: extentSelectionPosition,
      );
    } else if (i == selectedNodes.length - 1) {
      // This is the last node and it may be partially selected.
      final nodePosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: nodePosition,
      );
    } else {
      // This node is fully selected. Copy the whole thing.
      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: selectedNode.endPosition,
      );
    }

    final nodeContent = selectedNode.copyContent(nodeSelection);
    if (nodeContent != null) {
      buffer.write(nodeContent);
      if (i < selectedNodes.length - 1) {
        buffer.writeln();
      }
    }
  }
  return buffer.toString();
}
