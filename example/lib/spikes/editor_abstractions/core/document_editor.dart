import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'document.dart';

class DocumentEditor {
  static Uuid _uuid = Uuid();
  static String createNodeId() => _uuid.v4();

  DocumentEditor({
    @required MutableDocument document,
  }) : _document = document;

  final MutableDocument _document;

  void executeCommand(EditorCommand command) {
    command.execute(_document, this);
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void insertNodeAt(int index, DocumentNode node) {
    if (index <= _document.nodes.length) {
      _document._mutateDocument((onNodeChange) {
        _document.nodes.insert(index, node);
        node.addListener(onNodeChange);
      });
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void insertNodeAfter({
    @required DocumentNode previousNode,
    @required DocumentNode newNode,
  }) {
    final nodeIndex = _document.nodes.indexOf(previousNode);
    if (nodeIndex >= 0 && nodeIndex < _document.nodes.length) {
      _document._mutateDocument((onNodeChange) {
        _document.nodes.insert(nodeIndex + 1, newNode);
        newNode.addListener(onNodeChange);
      });
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void deleteNodeAt(int index) {
    if (index >= 0 && index < _document.nodes.length) {
      _document._mutateDocument((onNodeChange) {
        final removedNode = _document.nodes.removeAt(index);
        removedNode.removeListener(onNodeChange);
      });
    } else {
      print('Could not delete node. Index out of range: $index');
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  bool deleteNode(DocumentNode node) {
    bool isRemoved;

    _document._mutateDocument((onNodeChange) {
      node.removeListener(onNodeChange);
      isRemoved = _document.nodes.remove(node);
    });

    return isRemoved;
  }
}

abstract class EditorCommand {
  void execute(Document document, DocumentEditor editor);
}

class MutableDocument with ChangeNotifier implements Document {
  MutableDocument({
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

  void _mutateDocument(void Function(VoidCallback onNodeChange) operation) {
    operation.call(_forwardNodeChange);
    notifyListeners();
  }

  void _forwardNodeChange() {
    notifyListeners();
  }
}
