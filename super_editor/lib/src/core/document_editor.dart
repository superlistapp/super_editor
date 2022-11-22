import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:uuid/uuid.dart';

import 'document.dart';
import 'document_composer.dart';

/// Editor for a [Document].
///
/// A [DocumentEditor] executes commands that alter the structure
/// of a [Document]. Commands are used so that document changes
/// can be event-sourced, allowing for undo/redo behavior.
// TODO: design and implement comprehensive event-sourced editing API (#49)
class DocumentEditor {
  static const Uuid _uuid = Uuid();

  /// Generates a new ID for a [DocumentNode].
  ///
  /// Each generated node ID is universally unique.
  static String createNodeId() => _uuid.v4();

  DocumentEditor({
    required this.document,
    required List<EditorRequestHandler> requestHandlers,
  })  : _requestHandlers = requestHandlers,
        context = EditorContext() {
    context.put("document", document);
  }

  final MutableDocument document;

  /// Chain of Responsibility that maps a given [EditorRequest] to an [EditorCommand].
  final List<EditorRequestHandler> _requestHandlers;

  /// Service Locator that provides all resources that are relevant for document editing.
  final EditorContext context;

  final _commandsBeingProcessed = <EditorCommand>[];
  final _changeList = <DocumentChangeEvent>[];

  /// Executes the given [request].
  ///
  /// Any changes that result from the given [request] are reported to listeners as a series
  /// of [DocumentChangeEvent]s.
  void execute(EditorRequest request) {
    EditorCommand? command;
    for (final handler in _requestHandlers) {
      command = handler(request);
      if (command != null) {
        break;
      }
    }

    if (command == null) {
      throw Exception(
          "Could not handle EditorRequest. DocumentEditor doesn't have a handler that recognizes the request: $request");
    }

    // Add the command that we're processing to the stack. One command might run other commands. We
    // track them in a stack so that we can emit change notifications at one time.
    _commandsBeingProcessed.add(command);

    // Run the command.
    final changes = command.execute(context);
    _changeList.addAll(changes);

    // Now that our command is done, remove it from the stack.
    _commandsBeingProcessed.removeLast();

    // If we ran the root command, it's now complete. Notify listeners.
    if (_commandsBeingProcessed.isEmpty && changes.isNotEmpty) {
      // We make a copy of the change-list so that asynchronous listeners
      // don't lose the contents when we clear it.
      document.notifyListeners(
        DocumentChangeLog(
          List<DocumentChangeEvent>.from(_changeList, growable: false),
        ),
      );

      // TODO: move this notification outside DocumentEditor
      if (_changeList.whereType<SelectionChangeEvent>().isNotEmpty) {
        final composer = context.find<DocumentComposer>("composer");
        composer.notifySelectionListeners();
      }

      _changeList.clear();
    }
  }
}

/// All resources that are available when executing [EditorCommand]s, such as a document,
/// composer, etc.
class EditorContext {
  final _resources = <String, dynamic>{};

  T find<T>(String id) {
    if (!_resources.containsKey(id)) {
      editorLog.shout("Tried to find an editor resource for the ID '$id', but there's no resource with that ID.");
      throw Exception("Tried to find an editor resource for the ID '$id', but there's no resource with that ID.");
    }
    if (_resources[id] is! T) {
      editorLog.shout(
          "Tried to find an editor resource of type '$T' for ID '$id', but the resource with that ID is of type '${_resources[id].runtimeType}");
      throw Exception(
          "Tried to find an editor resource of type '$T' for ID '$id', but the resource with that ID is of type '${_resources[id].runtimeType}");
    }

    return _resources[id];
  }

  void put(String id, dynamic resource) => _resources[id] = resource;
}

/// Factory method that creates and returns an [EditorCommand] that can handle
/// the given [EditorRequest], or `null` if this handler doesn't apply to the given
/// [EditorRequest].
typedef EditorRequestHandler = EditorCommand? Function(EditorRequest);

/// An action that a [DocumentEditor] should execute.
abstract class EditorRequest {
  // Marker interface for all editor request types.
}

/// A command that alters something in a [DocumentEditor].
abstract class EditorCommand {
  /// Executes this command and returns metadata about any changes that
  /// were made.
  List<DocumentChangeEvent> execute(EditorContext context);
}

/// Functional version of an [EditorCommand] for commands that
/// don't require variables or private functions.
class EditorCommandFunction implements EditorCommand {
  /// Creates a functional editor command given the [EditorCommand.execute]
  /// function to be stored for execution.
  EditorCommandFunction(this._execute);

  final List<DocumentChangeEvent> Function(EditorContext) _execute;

  @override
  List<DocumentChangeEvent> execute(EditorContext context) => _execute(context);
}

/// An in-memory, mutable [Document].
class MutableDocument implements Document {
  /// Creates an in-memory, mutable version of a [Document].
  ///
  /// Initializes the content of this [MutableDocument] with the given [nodes],
  /// if provided, or empty content otherwise.
  MutableDocument({
    List<DocumentNode>? nodes,
  }) : _nodes = nodes ?? [];

  void dispose() {
    _listeners.clear();
  }

  final List<DocumentNode> _nodes;

  @override
  List<DocumentNode> get nodes => UnmodifiableListView(_nodes);

  /// Maps a node id to its index in the node list.
  final Map<String, int> _nodeIndicesById = {};

  /// Maps a node id to its node.
  final Map<String, DocumentNode> _nodesById = {};

  final _listeners = <DocumentChangeListener>[];

  @override
  DocumentNode? getNodeById(String nodeId) {
    return _nodesById[nodeId];
  }

  @override
  DocumentNode? getNodeAt(int index) {
    if (index < 0 || index >= _nodes.length) {
      return null;
    }

    return _nodes[index];
  }

  @override
  @Deprecated("Use getNodeIndexById() instead")
  int getNodeIndex(DocumentNode node) {
    final index = _nodeIndicesById[node.id] ?? -1;
    if (index < 0) {
      return -1;
    }

    if (_nodes[index] != node) {
      // We found a node by id, but it wasn't the node we expected. Therefore, we couldn't find the requested node.
      return -1;
    }

    return index;
  }

  @override
  int getNodeIndexById(String nodeId) {
    return _nodeIndicesById[nodeId] ?? -1;
  }

  @override
  DocumentNode? getNodeBefore(DocumentNode node) {
    final nodeIndex = getNodeIndexById(node.id);
    return nodeIndex > 0 ? getNodeAt(nodeIndex - 1) : null;
  }

  @override
  DocumentNode? getNodeAfter(DocumentNode node) {
    final nodeIndex = getNodeIndexById(node.id);
    return nodeIndex >= 0 && nodeIndex < _nodes.length - 1 ? getNodeAt(nodeIndex + 1) : null;
  }

  @override
  DocumentNode? getNode(DocumentPosition position) => getNodeById(position.nodeId);

  @override
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2) {
    late TextAffinity affinity = getAffinityBetween(base: position1, extent: position2);
    return DocumentRange(
      start: affinity == TextAffinity.downstream ? position1 : position2,
      end: affinity == TextAffinity.downstream ? position2 : position1,
    );
  }

  @override
  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2) {
    final node1 = getNode(position1);
    if (node1 == null) {
      throw Exception('No such position in document: $position1');
    }
    final index1 = getNodeIndexById(node1.id);

    final node2 = getNode(position2);
    if (node2 == null) {
      throw Exception('No such position in document: $position2');
    }
    final index2 = getNodeIndexById(node2.id);

    final from = min(index1, index2);
    final to = max(index1, index2);

    return _nodes.sublist(from, to + 1);
  }

  /// Inserts the given [node] into the [Document] at the given [index].
  void insertNodeAt(int index, DocumentNode node) {
    if (index <= nodes.length) {
      nodes.insert(index, node);
    }
  }

  /// Inserts [newNode] immediately before the given [existingNode].
  void insertNodeBefore({
    required DocumentNode existingNode,
    required DocumentNode newNode,
  }) {
    final nodeIndex = nodes.indexOf(existingNode);
    nodes.insert(nodeIndex, newNode);
  }

  /// Inserts [newNode] immediately after the given [existingNode].
  void insertNodeAfter({
    required DocumentNode existingNode,
    required DocumentNode newNode,
  }) {
    final nodeIndex = nodes.indexOf(existingNode);
    if (nodeIndex >= 0 && nodeIndex < nodes.length) {
      nodes.insert(nodeIndex + 1, newNode);
    }
  }

  /// Adds [node] to the end of the document.
  void add(DocumentNode node) {
    _nodes.insert(_nodes.length, node);
    node.addListener(_forwardNodeChange);

    // The node list changed, we need to update the map to consider the new indices.
    _refreshNodeIdCaches();

    notifyListeners();
  }

  /// Deletes the node at the given [index].
  void deleteNodeAt(int index) {
    if (index >= 0 && index < nodes.length) {
      nodes.removeAt(index);
    } else {
      editorDocLog.warning('Could not delete node. Index out of range: $index');
    }
  }

  /// Deletes the given [node] from the [Document].
  bool deleteNode(DocumentNode node) {
    bool isRemoved = false;

    isRemoved = nodes.remove(node);

    return isRemoved;
  }

  /// Moves a [DocumentNode] matching the given [nodeId] from its current index
  /// in the [Document] to the given [targetIndex].
  ///
  /// If none of the nodes in this document match [nodeId], throws an error.
  void moveNode({required String nodeId, required int targetIndex}) {
    final node = getNodeById(nodeId);
    if (node == null) {
      throw Exception('Could not find node with nodeId: $nodeId');
    }

    if (nodes.remove(node)) {
      nodes.insert(targetIndex, node);
    }
  }

  /// Replaces the given [oldNode] with the given [newNode]
  void replaceNode({
    required DocumentNode oldNode,
    required DocumentNode newNode,
  }) {
    final index = _nodes.indexOf(oldNode);

    if (index != -1) {
      _nodes.removeAt(index);
      _nodes.insert(index, newNode);
    } else {
      throw Exception('Could not find oldNode: ${oldNode.id}');
    }
  }

  /// Returns [true] if the content of the [other] [Document] is equivalent
  /// to the content of this [Document].
  ///
  /// Content equivalency compares types of content nodes, and the content
  /// within them, like the text of a paragraph, but ignores node IDs and
  /// ignores the runtime type of the [Document], itself.
  @override
  bool hasEquivalentContent(Document other) {
    final otherNodes = other.nodes;
    if (_nodes.length != otherNodes.length) {
      return false;
    }

    for (int i = 0; i < _nodes.length; ++i) {
      if (!_nodes[i].hasEquivalentContent(otherNodes[i])) {
        return false;
      }
    }

    return true;
  }

  @override
  void addListener(DocumentChangeListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(DocumentChangeListener listener) {
    _listeners.remove(listener);
  }

  @protected
  void notifyListeners(DocumentChangeLog changeLog) {
    for (final listener in _listeners) {
      listener(changeLog);
    }
  }

  /// Updates all the maps which use the node id as the key.
  ///
  /// All the maps are cleared and re-populated.
  void _refreshNodeIdCaches() {
    _nodeIndicesById.clear();
    _nodesById.clear();
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      _nodeIndicesById[node.id] = i;
      _nodesById[node.id] = node;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutableDocument &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(_nodes, other.nodes);

  @override
  int get hashCode => _nodes.hashCode;
}
