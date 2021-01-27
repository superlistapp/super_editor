import 'dart:math';

import 'package:example/spikes/editor_input_delegation/selection/editor_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class RichTextDocument {
  factory RichTextDocument.fromOldImplementation(EditorSelection editorSelection) {
    final nodes = <DocumentNode>[];
    for (final displayNode in editorSelection.displayNodes) {
      nodes.add(
        ParagraphNode(
          id: displayNode.key.toString(),
          key: displayNode.key,
          paragraph: displayNode.paragraph,
        ),
      );
    }

    return RichTextDocument._(nodes: nodes);
  }

  RichTextDocument._({
    List<DocumentNode> nodes = const [],
  }) : _nodes = nodes;

  final List<DocumentNode> _nodes;
  List<DocumentNode> get nodes => _nodes;

  DocumentNode getNode(DocumentPosition position) => _nodes.firstWhere((element) => element.id == position.nodeId);

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

class DocumentPosition<PositionType> {
  DocumentPosition({
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

abstract class DocumentNode {
  String get id;
}

class ParagraphNode implements DocumentNode {
  ParagraphNode({
    @required this.id,
    @required this.key,
    String paragraph = '',
  }) : _paragraph = paragraph;

  final String id;

  // TODO: delete this key
  final GlobalKey key;

  String _paragraph;
  String get paragraph => _paragraph;
}
