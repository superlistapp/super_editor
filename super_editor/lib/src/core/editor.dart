import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:uuid/uuid.dart';

import 'document.dart';
import 'document_composer.dart';

/// Editor for a document editing experience.
///
/// An [Editor] is the entry point for all mutations within a document editing experience.
/// Such changes might impact a [Document], [DocumentComposer], and any other relevant objects
/// or data structures associated with a document editing experience.
///
/// The following artifacts are involved with making changes to pieces of a document editing
/// experience:
///
///  - [EditRequest] - a desired change.
///  - [EditCommand] - mutates [Editable]s to achieve a change.
///  - [EditEvent] - describes a change that was made.
///  - [EditReaction] - (optionally) requests more changes after some original change.
///  - [EditListener] - is notified of all changes made by an [Editor].
class Editor implements RequestDispatcher {
  static const Uuid _uuid = Uuid();

  /// Service locator key to obtain a [Document] from [find], if a [Document]
  /// is available in the [EditContext].
  static const documentKey = "document";

  /// Service locator key to obtain a [DocumentComposer] from [find], if a
  /// [DocumentComposer] is available in the [EditContext].
  static const composerKey = "composer";

  /// Service locator key to obtain a [DocumentLayoutEditable] from [find], if
  /// a [DocumentLayoutEditable] is available in the [EditContext].
  static const layoutKey = "layout";

  /// Generates a new ID for a [DocumentNode].
  ///
  /// Each generated node ID is universally unique.
  static String createNodeId() => _uuid.v4();

  /// Constructs an [Editor] with:
  ///  - [editables], which contains all artifacts that will be mutated by [EditCommand]s, such
  ///    as a [Document] and [DocumentComposer].
  ///  - [requestHandlers], which map each [EditRequest] to an [EditCommand].
  ///  - [reactionPipeline], which contains all possible [EditReaction]s in the order that they will
  ///    react.
  ///  - [listeners], which contains an initial set of [EditListener]s.
  Editor({
    required Map<String, Editable> editables,
    List<EditRequestHandler>? requestHandlers,
    List<EditReaction>? reactionPipeline,
    List<EditListener>? listeners,
  })  : requestHandlers = requestHandlers ?? [],
        reactionPipeline = reactionPipeline ?? [],
        _changeListeners = listeners ?? [] {
    context = EditContext(editables);
    _commandExecutor = _DocumentEditorCommandExecutor(context);
  }

  void dispose() {
    reactionPipeline.clear();
    _changeListeners.clear();
  }

  /// Chain of Responsibility that maps a given [EditRequest] to an [EditCommand].
  final List<EditRequestHandler> requestHandlers;

  /// Service Locator that provides all resources that are relevant for document editing.
  late final EditContext context;

  /// Executes [EditCommand]s and collects a list of changes.
  late final _DocumentEditorCommandExecutor _commandExecutor;

  /// A pipeline of objects that receive change-lists from command execution
  /// and get the first opportunity to spawn additional commands before the
  /// change list is dispatched to regular listeners.
  final List<EditReaction> reactionPipeline;

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

  /// Executes the given [requests].
  ///
  /// Any changes that result from the given [requests] are reported to listeners as a series
  /// of [EditEvent]s.
  @override
  void execute(List<EditRequest> requests) {
    // print("Request execution:");
    // for (final request in requests) {
    //   print(" - ${request.runtimeType}");
    // }
    // print(StackTrace.current);

    if (_activeCommandCount == 0) {
      // This is the start of a new transaction.
      for (final editable in context._resources.values) {
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
      if (_activeChangeList!.isNotEmpty) {
        // Run all reactions. These reactions will likely call `execute()` again, with
        // their own requests, to make additional changes.
        _reactToChanges();

        // Notify all listeners that care about changes, but won't spawn additional requests.
        _notifyListeners();

        // This is the end of a transaction.
        for (final editable in context._resources.values) {
          editable.onTransactionEnd(_activeChangeList!);
        }
      } else {
        editorOpsLog.warning("We have an empty change list after processing one or more requests: $requests");
      }

      _activeChangeList = null;
    }

    _activeCommandCount -= 1;
  }

  EditCommand _findCommandForRequest(EditRequest request) {
    EditCommand? command;
    for (final handler in requestHandlers) {
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

  void _reactToChanges() {
    for (final reaction in reactionPipeline) {
      // Note: we pass the active change list because reactions will cause more
      // changes to be added to that list.
      reaction.react(context, this, _activeChangeList!);
    }
  }

  void _notifyListeners() {
    final changeList = List<EditEvent>.from(_activeChangeList!, growable: false);
    for (final listener in _changeListeners) {
      // Note: we pass a given copy of the change list, because listeners should
      // never cause additional editor changes.
      listener.onEdit(changeList);
    }
  }
}

/// An implementation of [CommandExecutor], designed for [Editor].
class _DocumentEditorCommandExecutor implements CommandExecutor {
  _DocumentEditorCommandExecutor(this._context);

  final EditContext _context;

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
  void prependCommand(EditCommand command) {
    _commandsBeingProcessed.prepend(command);
  }

  @override
  void appendCommand(EditCommand command) {
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
abstract mixin class Editable {
  /// A [Editor] transaction just started, this [Editable] should avoid notifying
  /// any listeners of changes until the transaction ends.
  void onTransactionStart() {}

  /// A transaction that was previously started with [onTransactionStart] has now ended, this
  /// [Editable] should notify interested parties of changes.
  void onTransactionEnd(List<EditEvent> edits) {}
}

/// An object that processes [EditRequest]s.
abstract class RequestDispatcher {
  /// Pushes the given [requests] through a [Editor] pipeline.
  void execute(List<EditRequest> requests);
}

/// A command that alters something in a [Editor].
abstract class EditCommand {
  /// Executes this command and logs all changes with the [executor].
  void execute(EditContext context, CommandExecutor executor);
}

/// All resources that are available when executing [EditCommand]s, such as a document,
/// composer, etc.
class EditContext {
  EditContext(this._resources);

  final Map<String, Editable> _resources;

  /// Finds an object of type [T] within this [EditContext], which is identified by the given [id].
  T find<T extends Editable>(String id) {
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

  /// Finds an object of type [T] within this [EditContext], which is identified by the given [id], or
  /// returns `null` if no such object is in this [EditContext].
  T? findMaybe<T extends Editable>(String id) {
    if (_resources[id] == null) {
      return null;
    }

    if (_resources[id] is! T) {
      editorLog.shout(
          "Tried to find an editor resource of type '$T' for ID '$id', but the resource with that ID is of type '${_resources[id].runtimeType}");
      throw Exception(
          "Tried to find an editor resource of type '$T' for ID '$id', but the resource with that ID is of type '${_resources[id].runtimeType}");
    }

    return _resources[id] as T;
  }

  /// Makes the given [editable] available as a resource under the given [id].
  void put(String id, Editable editable) => _resources[id] = editable;

  /// Removes any resource in this context with the given [id].
  void remove(String id) => _resources.remove(id);
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

  void expandActiveCommand(List<EditCommand> additionalCommands) {
    _activeCommandExpansionQueue.addAll(additionalCommands);
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

  @override
  String toString() => "DocumentEdit -> $change";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DocumentEdit && runtimeType == other.runtimeType && change == other.change;

  @override
  int get hashCode => change.hashCode;
}

/// An object that's notified with a change list from one or more
/// commands that were just executed.
///
/// An [EditReaction] can use the given [executor] to spawn additional
/// [EditCommand]s that should run in response to the [changeList].
abstract class EditReaction {
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList);
}

/// An [EditReaction] that delegates its reaction to a given callback function.
class FunctionalEditReaction implements EditReaction {
  FunctionalEditReaction(this._react);

  final void Function(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList)
      _react;

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) =>
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

  /// Creates an [Document] with a single [ParagraphNode].
  ///
  /// Optionally, takes in a [nodeId] for the [ParagraphNode].
  factory MutableDocument.empty([String? nodeId]) {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: nodeId ?? Editor.createNodeId(),
          text: AttributedText(),
        ),
      ],
    );
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
    if (documentChanges.isEmpty) {
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
