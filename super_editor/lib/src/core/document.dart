import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A read-only document with styled text and multimedia elements.
///
/// A `Document` is comprised of a list of `DocumentNode`s,
/// which describe the type and substance of a piece of content
/// within the document. For example, a `ParagraphNode` holds a
/// single paragraph of text within the document.
///
/// New types of content can be added by subclassing `DocumentNode`.
///
/// To represent a specific location within a `Document`,
/// see `DocumentPosition`.
///
/// A `Document` has no opinion on the visual presentation of its
/// content.
///
/// To edit the content of a document, see `DocumentEditor`.
abstract class Document with ChangeNotifier {
  /// Returns all of the content within the document as a list
  /// of `DocumentNode`s.
  List<DocumentNode> get nodes;

  /// Returns the `DocumentNode` with the given `nodeId`, or `null`
  /// if no such node exists.
  DocumentNode? getNodeById(String nodeId);

  /// Returns the `DocumentNode` at the given `index`, or `null`
  /// if no such node exists.
  DocumentNode? getNodeAt(int index);

  /// Returns the index of the given `node`, or `-1` if the `node`
  /// does not exist within this `Document`.
  int getNodeIndex(DocumentNode node);

  /// Returns the `DocumentNode` that appears immediately before the
  /// given `node` in this `Document`, or null if the given `node`
  /// is the first node, or the given `node` does not exist in this
  /// `Document`.
  DocumentNode? getNodeBefore(DocumentNode node);

  /// Returns the `DocumentNode` that appears immediately after the
  /// given `node` in this `Document`, or null if the given `node`
  /// is the last node, or the given `node` does not exist in this
  /// `Document`.
  DocumentNode? getNodeAfter(DocumentNode node);

  /// Returns the `DocumentNode` at the given `position`, or `null` if
  /// no such node exists in this `Document`.
  DocumentNode? getNode(DocumentPosition position);

  /// Returns a `DocumentRange` that ranges from `position1` to
  /// `position2`, including `position1` and `position2`.
  // TODO: this method is misleading (#48) because if `position1` and
  //       `position2` are in the same node, they may be returned
  //       in the wrong order because the document doesn't know
  //       how to interpret positions within a node.
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2);

  /// Returns all `DocumentNode`s from `position1` to `position2`, including
  /// the nodes at `position1` and `position2`.
  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2);
}

/// A span within a `Document` that begins at `start` and
/// ends at `end`.
///
/// The `start` position must come before the `end` position in
/// the document.
class DocumentRange {
  DocumentRange({
    required this.start,
    required this.end,
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

/// A specific position within a `Document`.
///
/// A `DocumentPosition` points to a specific node by way of a `nodeId`,
/// and points to a specific position within the node by way of a
/// `nodePosition`.
///
/// The type of the `nodePosition` depends upon the type of `DocumentNode`
/// that this position points to. For example, a `ParagraphNode`
/// uses a `TextPosition` to represent a `nodePosition`.
class DocumentPosition<PositionType> {
  const DocumentPosition({
    required this.nodeId,
    required this.nodePosition,
  });

  /// ID of a `DocumentNode` within a `Document`.
  final String nodeId;

  /// Node-specific representation of a position.
  ///
  /// For example: a paragraph node might use a `TextPosition`.
  final PositionType nodePosition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPosition && nodeId == other.nodeId && nodePosition == other.nodePosition;

  @override
  int get hashCode => nodeId.hashCode ^ nodePosition.hashCode;

  @override
  String toString() {
    return '[DocumentPosition] - node: "$nodeId", position: ($nodePosition)';
  }
}

/// A single content node within a `Document`.
abstract class DocumentNode implements ChangeNotifier {
  /// ID that is unique within a `Document`.
  String get id;

  /// Returns the node position that corresponds to the beginning
  /// of content in this node.
  ///
  /// For example, a `ParagraphNode` would return `TextPosition(offset: 0)`.
  dynamic get beginningPosition;

  /// Returns the node position that corresponds to the end of the
  /// content in this node.
  ///
  /// For example, a `ParagraphNode` would return
  /// `TextPosition(offset: text.length)`.
  dynamic get endPosition;

  /// Returns a node-specific representation of a selection from
  /// `base` to `extent`.
  ///
  /// For example, a `ParagraphNode` would return a `TextSelection`.
  dynamic computeSelection({
    @required dynamic base,
    @required dynamic extent,
  });

  /// Returns a plain-text version of the content in this node
  /// within `selection`, or null if the given selection does
  /// not make sense as plain-text.
  String? copyContent(dynamic selection);
}
