import 'package:example/spikes/editor_abstractions/document/document_nodes.dart';
import 'package:example/spikes/editor_abstractions/document/rich_text_document.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  List<DocumentNodeSelection> computeNodeSelections({
    @required RichTextDocument document,
  }) {
    print('Computing document node selections.');
    print(' - base position: $base');
    print(' - extent position: $extent');
    if (isCollapsed) {
      final docNode = document.getNode(base);
      if (docNode is TextNode) {
        // One paragraph node is selected. The selection within
        // the node is collapsed.
        return [
          DocumentNodeSelection(
            nodeId: docNode.id,
            nodeSelection: TextSelection.collapsed(
              offset: (base.nodePosition as TextPosition).offset,
            ),
            isBase: true,
            isExtent: true,
          ),
        ];
      } else {
        print(' - Unknown document node: $docNode');
        return [];
      }
    } else if (base.nodeId == extent.nodeId) {
      final docNode = document.getNode(base);
      if (docNode is TextNode) {
        // One paragraph node is selected. The selection within
        // the paragraph has a start and end.
        final baseTextPosition = base.nodePosition as TextPosition;
        final extentTextPosition = extent.nodePosition as TextPosition;

        return [
          DocumentNodeSelection(
            nodeId: docNode.id,
            nodeSelection: TextSelection(
              baseOffset: baseTextPosition.offset,
              extentOffset: extentTextPosition.offset,
            ),
            isBase: true,
            isExtent: true,
          ),
        ];
      } else {
        print(' - Unknown document node: $docNode');
        return [];
      }
    } else {
      final selectedNodes = document.getNodesInside(base, extent);
      final nodeSelections = <DocumentNodeSelection>[];
      for (int i = 0; i < selectedNodes.length; ++i) {
        final selectedNode = selectedNodes[i];

        // TODO: support other nodes.
        if (selectedNode is! TextNode) {
          continue;
        }

        // Note: we know there are at least 2 selected nodes, so
        //       we don't need to handle the special case where
        //       the first node is the same as the last.
        if (i == 0) {
          // This is the first node. Select from the current position
          // to the end of the paragraph.
          final isBase = selectedNode.id == base.nodeId;

          final midParagraph =
              isBase ? (base.nodePosition as TextPosition).offset : (extent.nodePosition as TextPosition).offset;
          final endParagraph = (selectedNode as TextNode).text.length;

          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: TextSelection(
                baseOffset: isBase ? midParagraph : endParagraph,
                extentOffset: isBase ? endParagraph : midParagraph,
              ),
              isBase: isBase,
              isExtent: !isBase,
              highlightWhenEmpty: true,
            ),
          );
        } else if (i == selectedNodes.length - 1) {
          // This is the last node. Select from the beginning of
          // the node to the extent position.
          final isExtent = selectedNode.id == extent.nodeId;

          final midParagraph =
              isExtent ? (extent.nodePosition as TextPosition).offset : (base.nodePosition as TextPosition).offset;

          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: TextSelection(
                baseOffset: isExtent ? 0 : midParagraph,
                extentOffset: isExtent ? midParagraph : 0,
              ),
              isBase: !isExtent,
              isExtent: isExtent,
            ),
          );
        } else {
          // This node is in between the first and last in the
          // selection. Select everything.
          nodeSelections.add(
            DocumentNodeSelection(
              nodeId: selectedNode.id,
              nodeSelection: TextSelection(
                baseOffset: 0,
                extentOffset: (selectedNode as TextNode).text.length,
              ),
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
