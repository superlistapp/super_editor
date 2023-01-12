import 'dart:math';

import 'package:collection/collection.dart';
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
    required MutableDocument document,
    required List<EditorRequestHandler> requestHandlers,
  })  : _document = document,
        _requestHandlers = requestHandlers,
        context = EditorContext() {
    context.put("document", document);

    _commandExecutor = _DocumentEditorCommandExecutor(context);
  }

  /// The [Document] that this [DocumentEditor] edits.
  Document get document => _document;
  final MutableDocument _document;

  /// Chain of Responsibility that maps a given [EditorRequest] to an [EditorCommand].
  final List<EditorRequestHandler> _requestHandlers;

  /// Service Locator that provides all resources that are relevant for document editing.
  final EditorContext context;

  /// Executes [EditorCommand]s and collects a list of changes.
  late final _DocumentEditorCommandExecutor _commandExecutor;

  /// Executes the given [request].
  ///
  /// Any changes that result from the given [request] are reported to listeners as a series
  /// of [DocumentChangeEvent]s.
  void execute(EditorRequest request) {
    EditorCommand? command;
    for (final handler in _requestHandlers) {
      command = handler(request);
      if (command != null) {
        // We found a command that implements the given request.
        break;
      }
    }

    if (command == null) {
      throw Exception(
          "Could not handle EditorRequest. DocumentEditor doesn't have a handler that recognizes the request: $request");
    }

    // Execute the given command, and any other commands that it spawns.
    _commandExecutor.executeCommand(command);

    // Collect all the changes from the executed commands.
    //
    // We make a copy of the change-list so that asynchronous listeners
    // don't lose the contents when we clear it.
    final changeList = _commandExecutor.copyChangeList();

    // Reset the command executor so that it's ready for the next command
    // that comes in.
    _commandExecutor.reset();

    if (changeList.isNotEmpty) {
      // We finished running all commands in the queue. Notify listeners
      // of all the changes that were made.
      _document.notifyListeners(DocumentChangeLog(changeList));

      // TODO: have the composer listen for document changes and find selection updates
      if (changeList.whereType<SelectionChangeEvent>().isNotEmpty) {
        final composer = context.find<DocumentComposer>(EditorContext.composer);
        composer.selectionComponent.notifySelectionListeners();
      }
    }
  }
}

/// All resources that are available when executing [EditorCommand]s, such as a document,
/// composer, etc.
class EditorContext {
  /// Service locator key to obtain a [Document] from [find], if a [Document]
  /// is available in the [EditorContext].
  static const document = "document";

  /// Service locator key to obtain a [DocumentComposer] from [find], if a
  /// [DocumentComposer] is available in the [EditorContext].
  static const composer = "composer";

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

/// Executes [EditorCommands] in the order in which they're queued.
///
/// Each [EditorCommand] is given access to this [CommandExecutor] during
/// the command's execution. Each [EditorCommand] is expected to [logChanges]
/// with the given [CommandExecutor].
abstract class CommandExecutor {
  /// Immediately executes the given [command].
  ///
  /// Client's can use this method to run an initial command, or to run
  /// a sub-command in the middle of an active command.
  void executeCommand(EditorCommand command);

  /// Adds the given [command] to the beginning of the command queue, but
  /// after any set of commands that are currently executing.
  void prependCommand(EditorCommand command);

  /// Adds the given [command] to the end of the command queue.
  void appendCommand(EditorCommand command);

  /// Log a series of document changes that were just made by the active command.
  void logChanges(List<DocumentChangeEvent> changes);
}

class _DocumentEditorCommandExecutor implements CommandExecutor {
  _DocumentEditorCommandExecutor(this._context);

  final EditorContext _context;

  final _commandsBeingProcessed = EditorCommandQueue();

  final _changeList = <DocumentChangeEvent>[];
  List<DocumentChangeEvent> copyChangeList() => List.from(_changeList);

  @override
  void executeCommand(EditorCommand command) {
    _commandsBeingProcessed.append(command);

    // Run the given command, and any other commands that it spawns.
    while (_commandsBeingProcessed.hasCommands) {
      _commandsBeingProcessed.prepareForExecution();

      final command = _commandsBeingProcessed.activeCommand!;
      command.execute(_context, this);

      _commandsBeingProcessed.onCommandExecutionComplete();
    }
  }

  @override
  void prependCommand(command) {
    _commandsBeingProcessed.prepend(command);
  }

  @override
  void appendCommand(command) {
    _commandsBeingProcessed.append(command);
  }

  @override
  void logChanges(List<DocumentChangeEvent> changes) {
    _changeList.addAll(changes);
  }

  void reset() {
    _changeList.clear();
  }
}

class EditorCommandQueue {
  /// A command that's in the process of being executed.
  EditorCommand? _activeCommand;

  /// The command that's currently being executed, along with any commands
  /// that the active command adds during execution.
  final _activeCommandExpansionQueue = <EditorCommand>[];

  /// All commands waiting to be executed after [_activeCommandExpansionQueue].
  final _commandBacklog = <EditorCommand>[];

  bool get hasCommands => _commandBacklog.isNotEmpty;

  void prepareForExecution() {
    assert(_activeCommandExpansionQueue.isEmpty,
        "Tried to prepare for command execution but there are already commands in the active queue. Did you forget to call onCommandExecutionComplete?");

    // Set the active command to the next command in the backlog.
    _activeCommand = _commandBacklog.removeAt(0);
  }

  EditorCommand? get activeCommand => _activeCommand;

  void expandActiveCommand(List<EditorCommand> replacementCommands) {
    _activeCommandExpansionQueue.addAll(replacementCommands);
  }

  void onCommandExecutionComplete() {
    // Now that the active command is done, move any expansion commands
    // to the primary backlog.
    _commandBacklog.insertAll(0, _activeCommandExpansionQueue);
    _activeCommandExpansionQueue.clear();

    // Clear the active command, now that its complete.
    _activeCommand = null;
  }

  /// Prepends the given [command] at the front of the execution queue.
  void prepend(EditorCommand command) {
    _commandBacklog.insert(0, command);
  }

  /// Appends the given [command] to the end of the execution queue.
  void append(EditorCommand command) {
    _commandBacklog.add(command);
  }
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
  /// Executes this command and logs all changes with the [executor].
  void execute(EditorContext context, CommandExecutor executor);
}

/// An in-memory, mutable [Document].
class MutableDocument implements Document {
  /// Creates an in-memory, mutable version of a [Document].
  ///
  /// Initializes the content of this [MutableDocument] with the given [nodes],
  /// if provided, or empty content otherwise.
  MutableDocument({
    List<DocumentNode>? nodes,
  }) : _nodes = nodes ?? [] {
    _refreshNodeIdCaches();
  }

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
    if (index <= _nodes.length) {
      _nodes.insert(index, node);
      _refreshNodeIdCaches();
    }
  }

  /// Inserts [newNode] immediately before the given [existingNode].
  void insertNodeBefore({
    required DocumentNode existingNode,
    required DocumentNode newNode,
  }) {
    final nodeIndex = _nodes.indexOf(existingNode);
    _nodes.insert(nodeIndex, newNode);
    _refreshNodeIdCaches();
  }

  /// Inserts [newNode] immediately after the given [existingNode].
  void insertNodeAfter({
    required DocumentNode existingNode,
    required DocumentNode newNode,
  }) {
    final nodeIndex = _nodes.indexOf(existingNode);
    if (nodeIndex >= 0 && nodeIndex < _nodes.length) {
      _nodes.insert(nodeIndex + 1, newNode);
      _refreshNodeIdCaches();
    }
  }

  /// Adds [node] to the end of the document.
  void add(DocumentNode node) {
    _nodes.insert(_nodes.length, node);

    // The node list changed, we need to update the map to consider the new indices.
    _refreshNodeIdCaches();
  }

  /// Deletes the node at the given [index].
  void deleteNodeAt(int index) {
    if (index >= 0 && index < _nodes.length) {
      _nodes.removeAt(index);
      _refreshNodeIdCaches();
    } else {
      editorDocLog.warning('Could not delete node. Index out of range: $index');
    }
  }

  /// Deletes the given [node] from the [Document].
  bool deleteNode(DocumentNode node) {
    bool isRemoved = false;

    isRemoved = _nodes.remove(node);
    if (isRemoved) {
      _refreshNodeIdCaches();
    }

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

    if (_nodes.remove(node)) {
      _nodes.insert(targetIndex, node);
      _refreshNodeIdCaches();
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
      _refreshNodeIdCaches();
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
