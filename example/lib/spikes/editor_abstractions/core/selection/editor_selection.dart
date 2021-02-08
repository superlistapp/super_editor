import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../document/rich_text_document.dart';
import '../layout/document_layout.dart';

/// A selection within a `RichTextDocument`.
///
/// A `DocumentSelection` spans from a `base` position to an
/// `extent` position, and includes all content in between.
///
/// `base` and `extent` are instances of `DocumentPosition`,
/// which represents a single position within a `RichTextDocument`.
///
/// A `DocumentSelection` does not hold a reference to a
/// `RichTextDocument`, it only represents a directional selection
/// of a `RichTextDocument`. The `base` and `extent` positions must
/// be interpreted within the context of a specific `RichTextDocument`
/// to locate nodes between `base` and `extent`, and to identify
/// partial content that is selected within the `base` and `extent`
/// nodes within the document.
class DocumentSelection {
  const DocumentSelection.collapsed({
    @required DocumentPosition position,
  })  : assert(position != null),
        base = position,
        extent = position;

  DocumentSelection({
    @required this.base,
    @required this.extent,
  })  : assert(base != null),
        assert(extent != null);

  final DocumentPosition<dynamic> base;
  final DocumentPosition<dynamic> extent;

  bool get isCollapsed => base == extent;

  @override
  String toString() {
    return '[DocumentSelection] - \n  base: ($base),\n  extent: ($extent)';
  }

  DocumentSelection collapse() {
    if (isCollapsed) {
      return this;
    } else {
      return DocumentSelection(
        base: extent,
        extent: extent,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelection && runtimeType == other.runtimeType && base == other.base && extent == other.extent;

  @override
  int get hashCode => base.hashCode ^ extent.hashCode;

  DocumentSelection copyWith({
    DocumentPosition base,
    DocumentPosition extent,
  }) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.base,
    );
  }

  DocumentSelection expandTo(DocumentPosition newExtent) {
    return copyWith(
      extent: newExtent,
    );
  }

  List<DocumentNodeSelection> computeNodeSelections({
    @required RichTextDocument document,
    @required DocumentLayoutState documentLayout,
  }) {
    print('Computing document node selections.');
    print(' - base position: $base');
    print(' - extent position: $extent');
    if (isCollapsed) {
      print(' - the document selection is collapsed');
      final docNode = document.getNode(base);
      final component = documentLayout.getComponentByNodeId(docNode.id);
      if (component == null) {
        throw Exception(
            'Cannot compute node selections. Cannot find visual component for selected node: ${docNode.id}');
      }
      final selection = component.getCollapsedSelectionAt(extent.nodePosition);

      return [
        DocumentNodeSelection(
          nodeId: docNode.id,
          nodeSelection: selection,
          isBase: true,
          isExtent: true,
        ),
      ];
    } else if (base.nodeId == extent.nodeId) {
      print(' - the document selection is within 1 node');
      final docNode = document.getNode(base);
      final component = documentLayout.getComponentByNodeId(docNode.id);
      if (component == null) {
        throw Exception(
            'Cannot compute node selections. Cannot find visual component for selected node: ${docNode.id}');
      }
      final selection = component.getSelectionBetween(
        basePosition: base.nodePosition,
        extentPosition: extent.nodePosition,
      );

      return [
        DocumentNodeSelection(
          nodeId: docNode.id,
          nodeSelection: selection,
          isBase: true,
          isExtent: true,
        ),
      ];
    } else {
      print(' - the document selection spans multiple nodes');
      final selectedNodes = document.getNodesInside(base, extent);
      final nodeSelections = <DocumentNodeSelection>[];
      for (int i = 0; i < selectedNodes.length; ++i) {
        final selectedNode = selectedNodes[i];

        // Note: we know there are at least 2 selected nodes, so
        //       we don't need to handle the special case where
        //       the first node is the same as the last.
        if (i == 0) {
          // This is the first node. Select from the current position
          // to the end of the node.
          final isBase = selectedNode.id == base.nodeId;

          final component = documentLayout.getComponentByNodeId(selectedNode.id);
          if (component == null) {
            throw Exception(
                'Cannot compute node selections. Cannot find visual component for selected node: ${selectedNode.id}');
          }

          final selectedPosition = isBase ? base.nodePosition : extent.nodePosition;
          final endPosition = component.getEndPosition();
          final selection = component.getSelectionBetween(
            basePosition: isBase ? selectedPosition : endPosition,
            extentPosition: isBase ? endPosition : selectedPosition,
          );

          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: selection,
              isBase: isBase,
              isExtent: !isBase,
              highlightWhenEmpty: true,
            ),
          );
        } else if (i == selectedNodes.length - 1) {
          // This is the last node. Select from the beginning of
          // the node to the extent position.
          final isExtent = selectedNode.id == extent.nodeId;

          final component = documentLayout.getComponentByNodeId(selectedNode.id);
          if (component == null) {
            throw Exception(
                'Cannot compute node selections. Cannot find visual component for selected node: ${selectedNode.id}');
          }

          final selectedPosition = isExtent ? extent.nodePosition : base.nodePosition;
          final beginningPosition = component.getBeginningPosition();
          final selection = component.getSelectionBetween(
            basePosition: isExtent ? beginningPosition : selectedPosition,
            extentPosition: isExtent ? selectedPosition : beginningPosition,
          );

          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: selection,
              isBase: !isExtent,
              isExtent: isExtent,
            ),
          );
        } else {
          // This node is in between the first and last in the
          // selection. Select everything.
          final component = documentLayout.getComponentByNodeId(selectedNode.id);
          if (component == null) {
            throw Exception(
                'Cannot compute node selections. Cannot find visual component for selected node: ${selectedNode.id}');
          }

          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: component.getSelectionOfEverything(),
              highlightWhenEmpty: true,
            ),
          );
        }
      }

      return nodeSelections;
    }
  }
}

class DocumentNodeSelection<SelectionType> {
  DocumentNodeSelection({
    @required this.nodeId,
    @required this.nodeSelection,
    this.isBase = false,
    this.isExtent = false,
    this.highlightWhenEmpty = false,
  });

  final String nodeId;
  final SelectionType nodeSelection;
  final bool isBase;
  final bool isExtent;
  final bool highlightWhenEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNodeSelection &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          nodeSelection == other.nodeSelection;

  @override
  int get hashCode => nodeId.hashCode ^ nodeSelection.hashCode;

  @override
  String toString() {
    return '[DocumentNodeSelection] - node: "$nodeId", selection: ($nodeSelection)';
  }
}
