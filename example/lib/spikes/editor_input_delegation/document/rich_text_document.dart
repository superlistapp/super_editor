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
class RichTextDocument {
  static Uuid _uuid = Uuid();
  static String createNodeId() => _uuid.v4();

  RichTextDocument({
    List<DocumentNode> nodes = const [],
  }) : _nodes = nodes;

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
    return nodeIndex > 0 ? getNodeAt(nodeIndex - 1) : null;
  }

  DocumentNode getNodeAfter(DocumentNode node) {
    final nodeIndex = getNodeIndex(node);
    return nodeIndex >= 0 && nodeIndex < nodes.length - 1 ? getNodeAt(nodeIndex + 1) : null;
  }

  void insertNodeAt(int index, DocumentNode node) {
    if (index <= _nodes.length) {
      _nodes.insert(index, node);
    }
  }

  void insertNodeAfter({
    @required DocumentNode previousNode,
    @required DocumentNode newNode,
  }) {
    final nodeIndex = _nodes.indexOf(previousNode);
    if (nodeIndex >= 0 && nodeIndex < _nodes.length) {
      _nodes.insert(nodeIndex + 1, newNode);
    }
  }

  void deleteNodeAt(int index) {
    if (index >= 0 && index < _nodes.length) {
      _nodes.removeAt(index);
    } else {
      print('Could not delete node. Index out of range: $index');
    }
  }

  bool deleteNode(DocumentNode node) {
    return _nodes.remove(node);
  }

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
abstract class DocumentNode {
  String get id;

  bool tryToCombineWithOtherNode(DocumentNode other);
}

class ParagraphNode implements DocumentNode {
  ParagraphNode({
    @required this.id,
    this.paragraph = '',
  });

  final String id;

  String paragraph;

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // TODO: need to be able to list items into paragraphs somehow.
    if (other is! ParagraphNode) {
      return false;
    }

    final otherParagraph = other as ParagraphNode;
    this.paragraph += otherParagraph.paragraph;
    return true;
  }
}
