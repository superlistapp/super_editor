import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A document with styled text and multimedia elements.
///
/// A `Document` is comprised of a list of `DocumentNode`s,
/// which describe the type and substance of a piece of content
/// within the document. For example, a `ParagraphNode` holds a
/// single paragraph of text within the document.
///
/// To represent a specific location within a `Document`,
/// see `DocumentPosition`.
abstract class Document with ChangeNotifier {
  List<DocumentNode> get nodes;

  DocumentNode getNodeById(String nodeId);

  DocumentNode getNodeAt(int index);

  int getNodeIndex(DocumentNode node);

  DocumentNode getNodeBefore(DocumentNode node);

  DocumentNode getNodeAfter(DocumentNode node);

  // TODO: this method is misleading because if `position1` and
  //       `position2` are in the same node, they may be returned
  //       in the wrong order because the document doesn't know
  //       how to interpret positions within a node.
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2);

  DocumentNode getNode(DocumentPosition position);

  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2);
}

/// A span within a `RichTextDocument` that begins at `start` and
/// ends at `end`.
///
/// The `start` position must come before the `end` position in
/// the document.
class DocumentRange {
  DocumentRange({
    @required this.start,
    @required this.end,
  });

  final DocumentPosition<dynamic> start;
  final DocumentPosition<dynamic> end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentRange && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() {
    return '[DocumentRange] - from: ($start), to: ($end)';
  }
}

/// A singular position within a `RichTextDocument`.
///
/// The type of the `nodePosition` depends upon the type of
/// `DocumentNode` that this position points to.
class DocumentPosition<PositionType> {
  const DocumentPosition({
    this.nodeId,
    this.nodePosition,
  });

  final String nodeId;

  /// Node-specific representation of a position.
  ///
  /// For example: a paragraph node might use a `TextPosition`.
  final PositionType nodePosition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPosition &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          nodePosition == other.nodePosition;

  @override
  int get hashCode => nodeId.hashCode ^ nodePosition.hashCode;

  @override
  String toString() {
    return '[DocumentPosition] - node: "$nodeId", position: ($nodePosition)';
  }
}

/// A single content node within a `RichTextDocument`.
abstract class DocumentNode implements ChangeNotifier {
  String get id;

  dynamic get beginningPosition;

  dynamic get endPosition;

  /// Returns a node-specific representation of a selection from
  /// `base` to `extent`.
  dynamic computeSelection({
    @required dynamic base,
    @required dynamic extent,
  });

  /// Returns a plain-text version of the content in this node
  /// within `selection`, or null if the given selection does
  /// not make sense as plain-text.
  String copyContent(dynamic selection);
}
