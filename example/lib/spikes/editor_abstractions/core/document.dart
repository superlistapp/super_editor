import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

/// A rich text document.
///
/// A `RichTextDocument` is comprised of a list of `DocumentNode`s,
/// which describe the type and substance of a piece of content
/// within the document. For example, a `ParagraphNode` holds a
/// single paragraph of text within the document.
///
/// The purpose of the `RichTextDocument` is to facilitate the
/// traversal of content within a rich text document, and edit
/// the contents.
///
/// To represent a specific location within a `RichTextDocument`,
/// see `DocumentPosition`.
class RichTextDocument with ChangeNotifier {
  static Uuid _uuid = Uuid();
  static String createNodeId() => _uuid.v4();

  RichTextDocument({
    List<DocumentNode> nodes = const [],
  }) : _nodes = nodes {
    // Register listeners for all initial nodes.
    for (final node in _nodes) {
      node.addListener(_forwardNodeChange);
    }
  }

  final List<DocumentNode> _nodes;
  List<DocumentNode> get nodes => _nodes;

  DocumentNode getNodeById(String nodeId) {
    return _nodes.firstWhere(
      (element) => element.id == nodeId,
      orElse: () => null,
    );
  }

  DocumentNode getNodeAt(int index) {
    return _nodes[index];
  }

  int getNodeIndex(DocumentNode node) {
    return _nodes.indexOf(node);
  }

  DocumentNode getNodeBefore(DocumentNode node) {
    final nodeIndex = getNodeIndex(node);
    print('Index of "${node.id}": $nodeIndex');
    return nodeIndex > 0 ? getNodeAt(nodeIndex - 1) : null;
  }

  DocumentNode getNodeAfter(DocumentNode node) {
    final nodeIndex = getNodeIndex(node);
    return nodeIndex >= 0 && nodeIndex < nodes.length - 1 ? getNodeAt(nodeIndex + 1) : null;
  }

  void insertNodeAt(int index, DocumentNode node) {
    if (index <= _nodes.length) {
      _nodes.insert(index, node);
      node.addListener(_forwardNodeChange);
      notifyListeners();
    }
  }

  void insertNodeAfter({
    @required DocumentNode previousNode,
    @required DocumentNode newNode,
  }) {
    final nodeIndex = _nodes.indexOf(previousNode);
    if (nodeIndex >= 0 && nodeIndex < _nodes.length) {
      _nodes.insert(nodeIndex + 1, newNode);
      newNode.addListener(_forwardNodeChange);
      notifyListeners();
    }
  }

  void deleteNodeAt(int index) {
    if (index >= 0 && index < _nodes.length) {
      final removedNode = _nodes.removeAt(index);
      removedNode.removeListener(_forwardNodeChange);
      notifyListeners();
    } else {
      print('Could not delete node. Index out of range: $index');
    }
  }

  bool deleteNode(DocumentNode node) {
    node.removeListener(_forwardNodeChange);
    return _nodes.remove(node);
  }

  // TODO: this method is misleading because if `position1` and
  //       `position2` are in the same node, they may be returned
  //       in the wrong order because the document doesn't know
  //       how to interpret positions within a node.
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2) {
    final node1 = getNode(position1);
    if (node1 == null) {
      throw Exception('No such position in document: $position1');
    }
    final index1 = _nodes.indexOf(node1);

    final node2 = getNode(position2);
    if (node2 == null) {
      throw Exception('No such position in document: $position2');
    }
    final index2 = _nodes.indexOf(node2);

    return DocumentRange(
      start: index1 < index2 ? position1 : position2,
      end: index1 < index2 ? position2 : position1,
    );
  }

  DocumentNode getNode(DocumentPosition position) =>
      _nodes.firstWhere((element) => element.id == position.nodeId, orElse: () => null);

  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2) {
    final node1 = getNode(position1);
    if (node1 == null) {
      throw Exception('No such position in document: $position1');
    }
    final index1 = _nodes.indexOf(node1);

    final node2 = getNode(position2);
    if (node2 == null) {
      throw Exception('No such position in document: $position2');
    }
    final index2 = _nodes.indexOf(node2);

    final from = min(index1, index2);
    final to = max(index1, index2);

    return _nodes.sublist(from, to + 1);
  }

  void _forwardNodeChange() {
    notifyListeners();
  }
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
