import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'document.dart';

/// Editor for a `Document`.
///
/// A `DocumentEditor` executes commands that alter the structure
/// of a `Document`. Commands are used so that document changes
/// can be event-sourced, allowing for undo/redo behavior.
// TODO: design and implement comprehensive event-sourced editing API (#49)
class DocumentEditor {
  static Uuid _uuid = Uuid();

  /// Generates a new ID for a `DocumentNode`.
  ///
  /// Each generated node ID is universally unique.
  static String createNodeId() => _uuid.v4();

  /// Constructs a `DocumentEditor` that makes changes to the given
  /// `MutableDocument`.
  DocumentEditor({
    required MutableDocument document,
  }) : _document = document;

  final MutableDocument _document;

  /// Returns a read-only version of the `Document` that this editor
  /// is editing.
  Document get document => _document;

  /// Executes the given `command` to alter the `Document` that is tied
  /// to this `DocumentEditor`.
  void executeCommand(EditorCommand command) {
    command.execute(_document, DocumentEditorTransaction._(_document));
  }
}

abstract class EditorCommand {
  /// Executes this command against the given `document`, with changes
  /// applied to the given `transaction`.
  ///
  /// The `document` is provided in case this command needs to query
  /// the current content of the `document` to make appropriate changes.
  void execute(Document document, DocumentEditorTransaction transaction);
}

/// Functional version of an `EditorCommand` for commands that
/// don't require variables or private functions.
class EditorCommandFunction implements EditorCommand {
  EditorCommandFunction(this._execute);

  final void Function(Document, DocumentEditorTransaction) _execute;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _execute(document, transaction);
  }
}

/// Accumulates changes to a document to facilitate editing actions.
class DocumentEditorTransaction {
  DocumentEditorTransaction._(
    MutableDocument document,
  ) : _document = document;

  final MutableDocument _document;

  /// Inserts the given `node` into the `Document` at the given `index`.
  void insertNodeAt(int index, DocumentNode node) {
    _document.insertNodeAt(index, node);
  }

  /// Inserts `newNode` immediately after the given `previousNode`.
  void insertNodeAfter({
    required DocumentNode previousNode,
    required DocumentNode newNode,
  }) {
    _document.insertNodeAfter(previousNode: previousNode, newNode: newNode);
  }

  /// Deletes the node at the given `index`.
  void deleteNodeAt(int index) {
    _document.deleteNodeAt(index);
  }

  /// Deletes the given `node` from the `Document`.
  bool deleteNode(DocumentNode node) {
    return _document.deleteNode(node);
  }
}

/// An in-memory, mutable `Document`.
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

  @override
  List<DocumentNode> get nodes => _nodes;

  @override
  DocumentNode? getNodeById(String nodeId) {
    return _nodes.firstWhereOrNull(
      (element) => element.id == nodeId,
    );
  }

  @override
  DocumentNode? getNodeAt(int index) {
    if (index < 0 || index >= _nodes.length) {
      return null;
    }

    return _nodes[index];
  }

  @override
  int getNodeIndex(DocumentNode node) {
    return _nodes.indexOf(node);
  }

  @override
  DocumentNode? getNodeBefore(DocumentNode node) {
    final nodeIndex = getNodeIndex(node);
    return nodeIndex > 0 ? getNodeAt(nodeIndex - 1) : null;
  }

  @override
  DocumentNode? getNodeAfter(DocumentNode node) {
    final nodeIndex = getNodeIndex(node);
    return nodeIndex >= 0 && nodeIndex < nodes.length - 1 ? getNodeAt(nodeIndex + 1) : null;
  }

  @override
  DocumentNode? getNode(DocumentPosition position) =>
      _nodes.firstWhereOrNull((element) => element.id == position.nodeId);

  @override
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

  @override
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

  /// Inserts the given `node` into the `Document` at the given `index`.
  void insertNodeAt(int index, DocumentNode node) {
    if (index <= nodes.length) {
      nodes.insert(index, node);
      node.addListener(_forwardNodeChange);
      notifyListeners();
    }
  }

  /// Inserts `newNode` immediately after the given `previousNode`.
  void insertNodeAfter({
    required DocumentNode previousNode,
    required DocumentNode newNode,
  }) {
    final nodeIndex = nodes.indexOf(previousNode);
    if (nodeIndex >= 0 && nodeIndex < nodes.length) {
      nodes.insert(nodeIndex + 1, newNode);
      newNode.addListener(_forwardNodeChange);
      notifyListeners();
    }
  }

  /// Deletes the node at the given `index`.
  void deleteNodeAt(int index) {
    if (index >= 0 && index < nodes.length) {
      final removedNode = nodes.removeAt(index);
      removedNode.removeListener(_forwardNodeChange);
      notifyListeners();
    } else {
      print('Could not delete node. Index out of range: $index');
    }
  }

  /// Deletes the given `node` from the `Document`.
  bool deleteNode(DocumentNode node) {
    bool isRemoved = false;

    node.removeListener(_forwardNodeChange);
    isRemoved = nodes.remove(node);

    notifyListeners();

    return isRemoved;
  }

  void _forwardNodeChange() {
    notifyListeners();
  }
}
