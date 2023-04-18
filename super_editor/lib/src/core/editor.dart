import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:uuid/uuid.dart';

import 'document.dart';
import 'document_composer.dart';
import 'document_selection.dart';

/// Editor for a document editing experience.
///
/// A [Editor] is the entry point for all mutations within a document editing experience.
/// Such changes might impact a [Document], [DocumentComposer], and any other relevant objects
/// or data structures associated with a document editing experience.
///
/// The following artifacts are involved with making changes to pieces of a document editing
/// experience:
///
///  - [EditRequest] - a desired change.
///  - [EditCommand] - mutates editables to achieve a change.
///  - [EditEvent] - describes a change that was made.
///  - [EditReaction] - (optionally) requests more changes after some original change.
///  - [EditListener] - is notified of all changes made by a [Editor].
class Editor implements RequestDispatcher {
  static const Uuid _uuid = Uuid();

  /// Service locator key to obtain a [Document] from [find], if a [Document]
  /// is available in the [EditorContext].
  static const documentKey = "document";

  /// Service locator key to obtain a [DocumentComposer] from [find], if a
  /// [DocumentComposer] is available in the [EditorContext].
  static const composerKey = "composer";

  /// Generates a new ID for a [DocumentNode].
  ///
  /// Each generated node ID is universally unique.
  static String createNodeId() => _uuid.v4();

  /// Constructs a [Editor] with:
  ///  - [editables], which contains all artifacts that will be mutated by [EditCommand]s, such
  ///    as a [Document] and [DocumentComposer].
  ///  - [requestHandlers], which map each [EditRequest] to an [EditCommand].
  ///  - [reactionPipeline], which contains all possible [EditReaction]s in the order that they will
  ///    react.
  ///  - [listeners], which contains an initial set of [EditListener]s.
  Editor({
    required Map<String, Editable> editables,
    required List<EditRequestHandler> requestHandlers,
    List<EditReaction>? reactionPipeline,
    List<EditListener>? listeners,
  })  : _requestHandlers = requestHandlers,
        _reactionPipeline = reactionPipeline ?? [],
        _changeListeners = listeners ?? [] {
    _context = EditorContext(editables);
    assert(_context.findMaybe<Document>(Editor.documentKey) != null,
        "Expected a Document in the 'editables' map but it wasn't there");

    _commandExecutor = _DocumentEditorCommandExecutor(_context);
  }

  void dispose() {
    _reactionPipeline.clear();
    _changeListeners.clear();
  }

  /// Chain of Responsibility that maps a given [EditRequest] to an [EditCommand].
  final List<EditRequestHandler> _requestHandlers;

  /// Service Locator that provides all resources that are relevant for document editing.
  late final EditorContext _context;

  /// Executes [EditCommand]s and collects a list of changes.
  late final _DocumentEditorCommandExecutor _commandExecutor;

  /// A pipeline of objects that receive change lists from command execution
  /// and get the first opportunity to spawn additional commands before the
  /// change list is dispatched to regular listeners.
  final List<EditReaction> _reactionPipeline;

  /// Listeners that are notified of changes in the form of a change list
  /// after all pending [EditCommand]s are executed, and all members of
  /// the reaction pipeline are done reacting.
  final List<EditListener> _changeListeners;

  /// Adds a [listener], which is notified of each series of [EditEvent]s
  /// after a batch of [EditCommand]s complete.
  ///
  /// Listeners are held and called as a list because some listeners might need
  /// to be notified ahead of others. Generally, you should avoid that complexity,
  /// if possible, but sometimes its relevant. For example, by default, the
  /// [Document] is the highest priority listener that's registered with this
  /// [Editor]. That's because document structure is central to everything
  /// else, and therefore, we don't want other parts of the system being notified
  /// about changes, before the [Document], itself.
  void addListener(EditListener listener, {int? index}) {
    if (index != null) {
      _changeListeners.insert(index, listener);
    } else {
      _changeListeners.add(listener);
    }
  }

  /// Removes a [listener] from the set of change listeners.
  void removeListener(EditListener listener) {
    _changeListeners.remove(listener);
  }

  /// An accumulation of changes during the current execution stack.
  ///
  /// This list is tracked in local state to facilitate reactions. When Reaction 1 runs,
  /// it might submit another request, which adds more changes. When Reaction 2 runs, that
  /// reaction needs to know about the original change list, plus all changes caused by
  /// Reaction 1. This list lives across multiple request executions to make that possible.
  List<EditEvent>? _activeChangeList;

  /// Tracks the number of request executions that are in the process of running.
  int _activeCommandCount = 0;

  /// Executes the given [request].
  ///
  /// Any changes that result from the given [request] are reported to listeners as a series
  /// of [EditEvent]s.
  @override
  void execute(List<EditRequest> requests) {
    if (_activeCommandCount == 0) {
      // This is the start of a new transaction.
      for (final editable in _context._resources.values) {
        editable.onTransactionStart();
      }
    }

    _activeChangeList ??= <EditEvent>[];
    _activeCommandCount += 1;

    for (final request in requests) {
      // Execute the given request.
      final command = _findCommandForRequest(request);
      final commandChanges = _executeCommand(command);
      _activeChangeList!.addAll(commandChanges);
    }

    // Run reactions and notify listeners, but only do it once per batch of executions.
    // If we reacted and notified listeners on every execution, then every sub-request
    // would also run the reactions and notify listeners. At best this would result in
    // many superfluous calls, but in practice it would probably break lots of features
    // by notifying listeners too early, and running the same reactions over and over.
    if (_activeCommandCount == 1) {
      // Run all reactions. These reactions will likely call `execute()` again, with
      // their own requests, to make additional changes.
      _reactToChanges(_activeChangeList!);

      // Notify all listeners that care about changes, but won't spawn additional requests.
      _notifyListeners(_activeChangeList!);

      // This is the end of a transaction.
      for (final editable in _context._resources.values) {
        editable.onTransactionEnd(_activeChangeList!);
      }

      _activeChangeList = null;
    }

    _activeCommandCount -= 1;
  }

  EditCommand _findCommandForRequest(EditRequest request) {
    EditCommand? command;
    for (final handler in _requestHandlers) {
      command = handler(request);
      if (command != null) {
        return command;
      }
    }

    throw Exception(
        "Could not handle EditorRequest. DocumentEditor doesn't have a handler that recognizes the request: $request");
  }

  List<EditEvent> _executeCommand(EditCommand command) {
    // Execute the given command, and any other commands that it spawns.
    _commandExecutor.executeCommand(command);

    // Collect all the changes from the executed commands.
    //
    // We make a copy of the change-list so that asynchronous listeners
    // don't lose the contents when we clear it.
    final changeList = _commandExecutor.copyChangeList();

    // TODO: we could run the reactions here. Do we give them all a single chance
    //       to respond? Or do we keep running them until there aren't any further
    //       changes?

    // Reset the command executor so that it's ready for the next command
    // that comes in.
    _commandExecutor.reset();

    return changeList;
  }

  void _reactToChanges(List<EditEvent> changeList) {
    for (final reaction in _reactionPipeline) {
      reaction.react(_context, this, changeList);
    }
  }

  void _notifyListeners(List<EditEvent> changeList) {
    for (final listener in _changeListeners) {
      listener.onEdit(changeList);
    }
  }
}

/// An implementation of [CommandExecutor], designed for [Editor].
class _DocumentEditorCommandExecutor implements CommandExecutor {
  _DocumentEditorCommandExecutor(this._context);

  final EditorContext _context;

  final _commandsBeingProcessed = EditorCommandQueue();

  final _changeList = <EditEvent>[];
  List<EditEvent> copyChangeList() => List.from(_changeList);

  @override
  void executeCommand(EditCommand command) {
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
  void logChanges(List<EditEvent> changes) {
    _changeList.addAll(changes);
  }

  void reset() {
    _changeList.clear();
  }
}

/// An artifact that might be mutated during a request to a [Editor].
abstract class Editable {
  /// A [Editor] transaction just started, this [Editable] should avoid notifying
  /// any listeners of changes until the transaction ends.
  void onTransactionStart();

  /// A transaction that was previously started with [onTransactionStart] has now ended, this
  /// [Editable] should notify interested parties of changes.
  void onTransactionEnd(List<EditEvent> edits);
}

/// An object that processes [EditRequest]s.
abstract class RequestDispatcher {
  /// Pushes the given [request] through a [Editor] pipeline.
  void execute(List<EditRequest> request);
}

/// A command that alters something in a [Editor].
abstract class EditCommand {
  /// Executes this command and logs all changes with the [executor].
  void execute(EditorContext context, CommandExecutor executor);
}

/// All resources that are available when executing [EditCommand]s, such as a document,
/// composer, etc.
class EditorContext {
  EditorContext(this._resources);

  final Map<String, Editable> _resources;

  /// Finds an object of type [T] within this [EditorContext], which is identified by the given [id].
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

    return _resources[id] as T;
  }

  /// Finds an object of type [T] within this [EditorContext], which is identified by the given [id], or
  /// returns `null` if no such object is in this [EditorContext].
  T? findMaybe<T>(String id) {
    return _resources[id] as T?;
  }
}

/// Executes [EditCommand]s in the order in which they're queued.
///
/// Each [EditCommand] is given access to this [CommandExecutor] during
/// the command's execution. Each [EditCommand] is expected to [logChanges]
/// with the given [CommandExecutor].
abstract class CommandExecutor {
  /// Immediately executes the given [command].
  ///
  /// Client's can use this method to run an initial command, or to run
  /// a sub-command in the middle of an active command.
  void executeCommand(EditCommand command);

  /// Adds the given [command] to the beginning of the command queue, but
  /// after any set of commands that are currently executing.
  void prependCommand(EditCommand command);

  /// Adds the given [command] to the end of the command queue.
  void appendCommand(EditCommand command);

  /// Log a series of document changes that were just made by the active command.
  void logChanges(List<EditEvent> changes);
}

class EditorCommandQueue {
  /// A command that's in the process of being executed.
  EditCommand? _activeCommand;

  /// The command that's currently being executed, along with any commands
  /// that the active command adds during execution.
  final _activeCommandExpansionQueue = <EditCommand>[];

  /// All commands waiting to be executed after [_activeCommandExpansionQueue].
  final _commandBacklog = <EditCommand>[];

  bool get hasCommands => _commandBacklog.isNotEmpty;

  void prepareForExecution() {
    assert(_activeCommandExpansionQueue.isEmpty,
        "Tried to prepare for command execution but there are already commands in the active queue. Did you forget to call onCommandExecutionComplete?");

    // Set the active command to the next command in the backlog.
    _activeCommand = _commandBacklog.removeAt(0);
  }

  EditCommand? get activeCommand => _activeCommand;

  void expandActiveCommand(List<EditCommand> replacementCommands) {
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
  void prepend(EditCommand command) {
    _commandBacklog.insert(0, command);
  }

  /// Appends the given [command] to the end of the execution queue.
  void append(EditCommand command) {
    _commandBacklog.add(command);
  }
}

/// Factory method that creates and returns an [EditCommand] that can handle
/// the given [EditRequest], or `null` if this handler doesn't apply to the given
/// [EditRequest].
typedef EditRequestHandler = EditCommand? Function(EditRequest);

/// An action that a [Editor] should execute.
abstract class EditRequest {
  // Marker interface for all editor request types.
}

/// A change that took place within a [Editor].
abstract class EditEvent {
  // Marker interface for all editor change events.
}

/// An [EditEvent] that altered a [Document].
///
/// The specific [Document] change is available in [change].
class DocumentEdit implements EditEvent {
  DocumentEdit(this.change);

  final DocumentChange change;
}

/// An object that's notified with a change list from one or more
/// commands that were just executed.
///
/// An [EditReaction] can use the given [executor] to spawn additional
/// [EditCommand]s that should run in response the [changeList].
abstract class EditReaction {
  void react(EditorContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList);
}

/// An [EditReaction] that delegates its reaction to a given callback function.
class FunctionalEditReaction implements EditReaction {
  FunctionalEditReaction(this._react);

  final void Function(EditorContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList)
      _react;

  @override
  void react(EditorContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) =>
      _react(editorContext, requestDispatcher, changeList);
}

/// An object that's notified with a change list from one or more
/// commands that were just executed within a [Editor].
///
/// An [EditListener] can propagate secondary effects that are based on
/// editor changes. However, an [EditListener] shouldn't spawn additional
/// editor behaviors. This can result in infinite loops, back-and-forth changes,
/// and other undesirable effects. To spawn new [EditCommand]s based on a
/// [changeList], register an [EditReaction].
abstract class EditListener {
  void onEdit(List<EditEvent> changeList);
}

/// An [EditListener] that delegates to a callback function.
class FunctionalEditListener implements EditListener {
  FunctionalEditListener(this._onEdit);

  final void Function(List<EditEvent> changeList) _onEdit;

  @override
  void onEdit(List<EditEvent> changeList) => _onEdit(changeList);
}

/// An in-memory, mutable [Document].
class MutableDocument implements Document, Editable {
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

  @override
  void onTransactionStart() {
    // no-op
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {
    final documentChanges = edits.whereType<DocumentEdit>().map((edit) => edit.change).toList();
    if (edits.isEmpty) {
      return;
    }

    final changeLog = DocumentChangeLog(documentChanges);
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

// TODO: move the following document stuff into document.dart when we start breaking things.

abstract class Document {
  /// Returns all of the content within the document as a list
  /// of [DocumentNode]s.
  List<DocumentNode> get nodes;

  /// Returns the [DocumentNode] with the given [nodeId], or [null]
  /// if no such node exists.
  DocumentNode? getNodeById(String nodeId);

  /// Returns the [DocumentNode] at the given [index], or [null]
  /// if no such node exists.
  DocumentNode? getNodeAt(int index);

  /// Returns the index of the given [node], or [-1] if the [node]
  /// does not exist within this [Document].
  @Deprecated("Use getNodeIndexById() instead")
  int getNodeIndex(DocumentNode node);

  /// Returns the index of the `DocumentNode` in this `Document` that
  /// has the given [nodeId], or `-1` if the node does not exist.
  int getNodeIndexById(String nodeId);

  /// Returns the [DocumentNode] that appears immediately before the
  /// given [node] in this [Document], or null if the given [node]
  /// is the first node, or the given [node] does not exist in this
  /// [Document].
  DocumentNode? getNodeBefore(DocumentNode node);

  /// Returns the [DocumentNode] that appears immediately after the
  /// given [node] in this [Document], or null if the given [node]
  /// is the last node, or the given [node] does not exist in this
  /// [Document].
  DocumentNode? getNodeAfter(DocumentNode node);

  /// Returns the [DocumentNode] at the given [position], or [null] if
  /// no such node exists in this [Document].
  DocumentNode? getNode(DocumentPosition position);

  /// Returns a [DocumentRange] that ranges from [position1] to
  /// [position2], including [position1] and [position2].
  // TODO: this method is misleading (#48) because if `position1` and
  //       `position2` are in the same node, they may be returned
  //       in the wrong order because the document doesn't know
  //       how to interpret positions within a node.
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2);

  /// Returns all [DocumentNode]s from [position1] to [position2], including
  /// the nodes at [position1] and [position2].
  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2);

  /// Returns [true] if the content in the [other] document is equivalent to
  /// the content in this document, ignoring any details that are unrelated
  /// to content, such as individual node IDs.
  ///
  /// To compare [Document] equality, use the standard [==] operator.
  bool hasEquivalentContent(Document other);

  void addListener(DocumentChangeListener listener);

  void removeListener(DocumentChangeListener listener);
}

/// Listener that's notified when a document changes.
///
/// The [changeLog] includes an ordered list of all changes that were applied
/// to the [Document] since the last time this listener was notified.
typedef DocumentChangeListener = void Function(DocumentChangeLog changeLog);

/// One or more document changes that occurred within a single edit transaction.
///
/// A [DocumentChangeLog] can be used to rebuild only the parts of a document that changed.
class DocumentChangeLog {
  DocumentChangeLog(this.changes);

  final List<DocumentChange> changes;

  /// Returns `true` if the [DocumentNode] with the given [nodeId] was altered in any way
  /// by the events in this change log.
  bool wasNodeChanged(String nodeId) {
    for (final event in changes) {
      if (event is NodeDocumentChange && event.nodeId == nodeId) {
        return true;
      }
    }
    return false;
  }
}

abstract class DocumentChange {
  // Marker interface for all document changes.
}

/// A [DocumentChange] that impacts a single, specified [DocumentNode] with [nodeId].
abstract class NodeDocumentChange implements DocumentChange {
  String get nodeId;
}

/// A new [DocumentNode] was inserted in the [Document].
class NodeInsertedEvent implements NodeDocumentChange {
  const NodeInsertedEvent(this.nodeId);

  @override
  final String nodeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeInsertedEvent && runtimeType == other.runtimeType && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// A [DocumentNode] was moved to a new index.
class NodeMovedEvent implements NodeDocumentChange {
  const NodeMovedEvent({
    required this.nodeId,
    required this.from,
    required this.to,
  });

  @override
  final String nodeId;
  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeMovedEvent &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => nodeId.hashCode ^ from.hashCode ^ to.hashCode;
}

/// A [DocumentNode] was removed from the [Document].
class NodeRemovedEvent implements NodeDocumentChange {
  const NodeRemovedEvent(this.nodeId);

  @override
  final String nodeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeRemovedEvent && runtimeType == other.runtimeType && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// The content of a [DocumentNode] changed.
///
/// A node change might signify a content change, such as text changing in a paragraph, or
/// it might signify a node changing its type of content, such as converting a paragraph
/// to an image.
class NodeChangeEvent implements NodeDocumentChange {
  const NodeChangeEvent(this.nodeId);

  @override
  final String nodeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeChangeEvent && runtimeType == other.runtimeType && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => "[NodeChangeEvent] - Node: $nodeId";
}

// TODO: move the following into document_composer.dart when we start breaking things

extension InspectDocumentAffinity on Document {
  TextAffinity getAffinityForSelection(DocumentSelection selection) {
    return getAffinityBetween(base: selection.base, extent: selection.extent);
  }

  /// Returns the affinity direction implied by the given [base] and [extent].
  // TODO: Replace TextAffinity with a DocumentAffinity to avoid confusion.
  TextAffinity getAffinityBetween({
    required DocumentPosition base,
    required DocumentPosition extent,
  }) {
    final baseNode = getNode(base);
    if (baseNode == null) {
      throw Exception('No such position in document: $base');
    }
    final baseIndex = getNodeIndexById(baseNode.id);

    final extentNode = getNode(extent);
    if (extentNode == null) {
      throw Exception('No such position in document: $extent');
    }
    final extentIndex = getNodeIndexById(extentNode.id);

    late TextAffinity affinity;
    if (extentIndex > baseIndex) {
      affinity = TextAffinity.downstream;
    } else if (extentIndex < baseIndex) {
      affinity = TextAffinity.upstream;
    } else {
      // The selection is within the same node. Ask the node which position
      // comes first.
      affinity = extentNode.getAffinityBetween(base: base.nodePosition, extent: extent.nodePosition);
    }

    return affinity;
  }
}

extension InspectDocumentSelection on Document {
  /// Returns a list of all the `DocumentNodes` within the given [selection], ordered
  /// from upstream to downstream.
  List<DocumentNode> getNodesInContentOrder(DocumentSelection selection) {
    final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
    final upstreamIndex = getNodeIndexById(upstreamPosition.nodeId);
    final downstreamPosition = selectDownstreamPosition(selection.base, selection.extent);
    final downstreamIndex = getNodeIndexById(downstreamPosition.nodeId);

    return nodes.sublist(upstreamIndex, downstreamIndex + 1);
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears first in the document.
  DocumentPosition selectUpstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final docPosition1Node = getNodeById(docPosition1.nodeId)!;
    final docPosition1NodeIndex = getNodeIndexById(docPosition1Node.id);
    final docPosition2Node = getNodeById(docPosition2.nodeId)!;
    final docPosition2NodeIndex = getNodeIndexById(docPosition2Node.id);

    if (docPosition1NodeIndex < docPosition2NodeIndex) {
      return docPosition1;
    } else if (docPosition2NodeIndex < docPosition1NodeIndex) {
      return docPosition2;
    }

    // Both document positions are in the same node. Figure out which
    // node position comes first.
    final theNode = docPosition1Node;
    return theNode.selectUpstreamPosition(docPosition1.nodePosition, docPosition2.nodePosition) ==
            docPosition1.nodePosition
        ? docPosition1
        : docPosition2;
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears last in the document.
  DocumentPosition selectDownstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final upstreamPosition = selectUpstreamPosition(docPosition1, docPosition2);
    return upstreamPosition == docPosition1 ? docPosition2 : docPosition1;
  }

  /// Returns `true` if, and only if, the given [position] sits within the
  /// given [selection] in this `Document`.
  bool doesSelectionContainPosition(DocumentSelection selection, DocumentPosition position) {
    if (selection.isCollapsed) {
      return false;
    }

    final baseNode = getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = getNodeIndexById(baseNode.id);
    final extentNode = getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = getNodeIndexById(extentNode.id);

    final upstreamNode = baseNodeIndex < extentNodeIndex ? baseNode : extentNode;
    final upstreamNodeIndex = baseNodeIndex < extentNodeIndex ? baseNodeIndex : extentNodeIndex;
    final downstreamNode = baseNodeIndex < extentNodeIndex ? extentNode : baseNode;
    final downstreamNodeIndex = baseNodeIndex < extentNodeIndex ? extentNodeIndex : baseNodeIndex;

    final positionNodeIndex = getNodeIndexById(position.nodeId);

    if (upstreamNodeIndex < positionNodeIndex && positionNodeIndex < downstreamNodeIndex) {
      // The given position is sandwiched between two other nodes that form
      // the bounds of the selection. Therefore, the position is definitely within
      // the selection.
      return true;
    }

    if (positionNodeIndex == upstreamNodeIndex) {
      final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
      final downstreamPosition = upstreamPosition == selection.base ? selection.extent : selection.base;

      // This is the furthest a position could sit in the upstream node
      // and still contain the given position. Keep in mind that the
      // upstream position, downstream position, and given position may
      // all reside in the same node (in fact, they probably do).
      final downstreamCap =
          upstreamNodeIndex == downstreamNodeIndex ? downstreamPosition.nodePosition : upstreamNode.endPosition;

      // If and only if the given position comes after the upstream position,
      // and before the downstream cap, then the position is within the selection.
      return upstreamNode.selectDownstreamPosition(upstreamPosition.nodePosition, position.nodePosition) ==
          upstreamNode.selectUpstreamPosition(position.nodePosition, downstreamCap);
    }

    if (positionNodeIndex == downstreamNodeIndex) {
      final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
      final downstreamPosition = upstreamPosition == selection.base ? selection.extent : selection.base;

      // This is the furthest upstream that a position could sit in the
      // downstream node and still contain the given position. Keep in
      // mind that the upstream position, downstream position, and given
      // position may all reside in the same node (in fact, they probably do).
      final upstreamCap =
          downstreamNodeIndex == upstreamNodeIndex ? upstreamPosition.nodePosition : downstreamNode.beginningPosition;

      // If and only if the given position comes before the downstream position,
      // and after the upstream cap, then the position is within the selection.
      return downstreamNode.selectDownstreamPosition(upstreamCap, position.nodePosition) ==
          downstreamNode.selectUpstreamPosition(position.nodePosition, downstreamPosition.nodePosition);
    }

    // If we got here, then the position is either before the upstream
    // selection boundary, or after the downstream selection boundary.
    // Either way, the position is not in the selection.
    return false;
  }
}
