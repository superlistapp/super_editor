import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_composer.dart';
import 'document_editor.dart';

/// Abstractions:
///
/// An `EditorRequest` is what you want to happen.
///
/// An `EditorCommand` makes a desired change.
///
/// An `EditorEvent` is a receipt for what changed.
///
/// A `DocumentEditor` processes `EditorRequest`s by executing associated `EditorCommand`s and logs
/// resulting `EditorEvent`s.
///
/// We separate `EditorRequest`s from `EditorCommand`s because requests declare an outcome, while
/// commands have full implementation knowledge. Consider a keyboard handler for ALT+RIGHT-ARROW.
/// That handler always wants to move the caret downstream by one word. But, if we combined requests
/// with commands, then an app that uses `MutableDocument` and an app that uses `DatabaseDocument`
/// would have to re-implement the keyboard handler, so that the handler executes the version of the
/// command that knows how to work with the specific document type. We'd rather keep the same keyboard
/// handler, which dispatches the same request, and then let each app register different command
/// implementations to handle that same request.

void main() {
  // Example: how an editor and context would be configured.
  final editor = DocumentEditor(
    requestHandlers: [
      (EditorRequest request) => request is InsertTextAtCaretRequest ? InsertAtCaretCommand(request) : null,
      (EditorRequest request) => request is DeleteSelectionRequest ? DeleteSelectionCommand() : null,
    ],
  );
  editor.context.put("document", MutableDocument());
  editor.context.put("composer", DocumentComposer());
}

class InsertTextAtCaretRequest implements EditorRequest {
  InsertTextAtCaretRequest(this.textToInsert);

  final AttributedText textToInsert;
}

class InsertAtCaretCommand implements EditorCommand {
  InsertAtCaretCommand(this.request);

  final InsertTextAtCaretRequest request;

  @override
  List<EditorChangeEvent> execute(EditorContext context) {
    // Retrieve arbitrary resources from the context so that app developers
    // aren't limited to what ships with super_editor
    final document = context.find<MutableDocument>("document");
    final composer = context.find<DocumentComposer>("composer");

    // Do the work
    if (composer.selection == null) {
      editorDocLog.shout('ERROR: can\'t insert text at caret because there is no document selection');
      return [];
    }

    final documentPosition = composer.selection!.extent;
    final textNode = document.getNodeById(documentPosition.nodeId);
    if (textNode is! TextNode) {
      editorDocLog.shout('ERROR: can\'t insert text in a node that isn\'t a TextNode: $textNode');
      return [];
    }

    final textOffset = (documentPosition.nodePosition as TextPosition).offset;
    textNode.text = textNode.text.insert(
      textToInsert: request.textToInsert,
      startOffset: textOffset,
    );

    // Dispatch different change events at the same time, to prevent
    // race conditions.
    return [
      const DocumentChangeEvent(),
      const SelectionChangeEvent(),
    ];
  }
}

class DeleteSelectionRequest implements EditorRequest {
  //
}

class DeleteSelectionCommand implements EditorCommand {
  DeleteSelectionCommand();

  @override
  List<EditorChangeEvent> execute(EditorContext context) {
    // Retrieve arbitrary resources from the context so that app developers
    // aren't limited to what ships with super_editor
    final document = context.find<MutableDocument>("document");
    final composer = context.find<DocumentComposer>("composer");
    final documentSelection = composer.selection;
    if (documentSelection == null) {
      editorDocLog.shout('ERROR: can\'t delete selection because there is no document selection');
      return [];
    }

    // Do the work
    _deleteSelection(document, documentSelection);

    // Dispatch different change events at the same time, to prevent
    // race conditions.
    return [
      const DocumentChangeEvent(),
      const SelectionChangeEvent(),
    ];
  }

  void _deleteSelectionWithinSingleNode({
    required MutableDocument document,
    required DocumentSelection documentSelection,
    required DocumentNode node,
  }) {
    editorDocLog.fine(' - deleting selection within single node');
    final basePosition = documentSelection.base.nodePosition;
    final extentPosition = documentSelection.extent.nodePosition;

    if (basePosition is UpstreamDownstreamNodePosition) {
      if (basePosition == extentPosition) {
        // The selection is collapsed. Nothing to delete.
        return;
      }

      // The selection is expanded within a block-level node. The only
      // possibility is that the entire node is selected. Delete the node
      // and replace it with an empty paragraph.
      document.replaceNode(
        oldNode: node,
        newNode: ParagraphNode(id: node.id, text: AttributedText()),
      );
    } else if (node is TextNode) {
      editorDocLog.fine(' - its a TextNode');
      final baseOffset = (basePosition as TextPosition).offset;
      final extentOffset = (extentPosition as TextPosition).offset;
      final startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
      final endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;
      editorDocLog.fine(' - deleting from $startOffset to $endOffset');

      node.text = node.text.removeRegion(
        startOffset: startOffset,
        endOffset: endOffset,
      );
    }
  }

  void _deleteSelection(MutableDocument document, DocumentSelection documentSelection) {
    editorDocLog.info('DeleteSelectionCommand', 'DocumentEditor: deleting selection: $documentSelection');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);

    if (nodes.length == 1) {
      // This is a selection within a single node.
      _deleteSelectionWithinSingleNode(
        document: document,
        documentSelection: documentSelection,
        node: nodes.first,
      );

      // Done handling single-node selection deletion.
      return;
    }

    final range = document.getRangeBetween(documentSelection.base, documentSelection.extent);

    final startNode = document.getNode(range.start);
    final baseNode = document.getNode(documentSelection.base);
    if (startNode == null) {
      throw Exception('Could not locate start node for DeleteSelectionCommand: ${range.start}');
    }
    final startNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.base.nodePosition
        : documentSelection.extent.nodePosition;
    final startNodeIndex = document.getNodeIndex(startNode);

    final endNode = document.getNode(range.end);
    if (endNode == null) {
      throw Exception('Could not locate end node for DeleteSelectionCommand: ${range.end}');
    }
    final endNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.extent.nodePosition
        : documentSelection.base.nodePosition;
    final endNodeIndex = document.getNodeIndex(endNode);

    _deleteNodesBetweenFirstAndLast(
      document: document,
      startNode: startNode,
      endNode: endNode,
    );

    editorDocLog.fine(' - deleting partial selection within the starting node.');
    _deleteSelectionWithinNodeFromPositionToEnd(
      document: document,
      node: startNode,
      nodePosition: startNodePosition,
      replaceWithParagraph: false,
    );

    editorDocLog.fine(' - deleting partial selection within ending node.');
    _deleteSelectionWithinNodeFromStartToPosition(
      document: document,
      node: endNode,
      nodePosition: endNodePosition,
    );

    // If all selected nodes were deleted, e.g., the user selected from
    // the beginning of the first node to the end of the last node, then
    // we need insert an empty paragraph node so that there's a place
    // to position the caret.
    if (document.getNodeById(startNode.id) == null && document.getNodeById(endNode.id) == null) {
      final insertIndex = min(startNodeIndex, endNodeIndex);
      document.insertNodeAt(insertIndex, ParagraphNode(id: baseNode!.id, text: AttributedText()));
      return;
    }

    // The start/end nodes may have been deleted due to empty content.
    // Refresh our references so that we can decide if we need to merge
    // the nodes.
    final startNodeAfterDeletion = document.getNodeById(startNode.id);
    final endNodeAfterDeletion = document.getNodeById(endNode.id);

    // If the start node and end nodes are both `TextNode`s
    // then we need to consider merging them if one or both are
    // empty.
    if (startNodeAfterDeletion is! TextNode || endNodeAfterDeletion is! TextNode) {
      return;
    }

    editorDocLog.fine(' - combining last node text with first node text');
    startNodeAfterDeletion.text = startNodeAfterDeletion.text.copyAndAppend(endNodeAfterDeletion.text);

    editorDocLog.fine(' - deleting last node');
    document.deleteNode(endNodeAfterDeletion);

    editorDocLog.fine(' - done with selection deletion');
  }

  void _deleteNodesBetweenFirstAndLast({
    required MutableDocument document,
    required DocumentNode startNode,
    required DocumentNode endNode,
  }) {
    // Delete all nodes between the first node and the last node.
    final startIndex = document.getNodeIndex(startNode);
    final endIndex = document.getNodeIndex(endNode);

    editorDocLog.fine(' - start node index: $startIndex');
    editorDocLog.fine(' - end node index: $endIndex');
    editorDocLog.fine(' - initially ${document.nodes.length} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    for (int i = endIndex - 1; i > startIndex; --i) {
      editorDocLog.fine(' - deleting node $i: ${document.getNodeAt(i)?.id}');
      document.deleteNodeAt(i);
    }
  }

  void _deleteSelectionWithinNodeFromPositionToEnd({
    required MutableDocument document,
    required DocumentNode node,
    required dynamic nodePosition,
    required bool replaceWithParagraph,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The position is already at the end of the node. Nothing to do.
        return;
      }

      // The position is on the upstream side of block-level content.
      // Delete the whole block.
      _deleteBlockLevelNode(
        document: document,
        node: node,
        replaceWithParagraph: replaceWithParagraph,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.beginningPosition) {
        // All text is selected. Delete the node.
        document.deleteNode(node);
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: nodePosition.offset,
          endOffset: node.text.text.length,
        );
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteSelectionWithinNodeFromStartToPosition({
    required MutableDocument document,
    required DocumentNode node,
    required dynamic nodePosition,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        // The position is already at the beginning of the node. Nothing to do.
        return;
      }

      // The position is on the downstream side of block-level content.
      // Delete the whole block.
      _deleteBlockLevelNode(
        document: document,
        node: node,
        replaceWithParagraph: false,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.endPosition) {
        // All text is selected. Delete the node.
        document.deleteNode(node);
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: 0,
          endOffset: nodePosition.offset,
        );
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteBlockLevelNode({
    required MutableDocument document,
    required DocumentNode node,
    required bool replaceWithParagraph,
  }) {
    if (replaceWithParagraph) {
      // TODO: for now deleting a block-level node simply means replacing
      //       it with an empty ParagraphNode because after doing that,
      //       the general deletion logic that called this function will
      //       collapse empty paragraphs together, which gives the
      //       result we want.
      //
      //       We avoid deleting the node because the composer is
      //       depending on the first node still existing at the end of
      //       the deletion. This is a fragile relationship between the
      //       composer and the editor and needs to be addressed.
      editorDocLog.fine(' - replacing block-level node with a ParagraphNode: ${node.id}');

      final newNode = ParagraphNode(id: node.id, text: AttributedText());
      document.replaceNode(oldNode: node, newNode: newNode);
    } else {
      editorDocLog.fine(' - deleting block level node');
      document.deleteNode(node);
    }
  }
}

//------------- TYPES ---------
class DocumentEditor {
  DocumentEditor({
    required List<EditorRequestHandler> requestHandlers,
  })  : _requestHandlers = requestHandlers,
        context = EditorContext();

  /// Chain of Responsibility that maps a given [EditorRequest] to an [EditorCommand].
  final List<EditorRequestHandler> _requestHandlers;

  /// Service Locator that provides all resources that are relevant for document editing.
  final EditorContext context;

  final _listeners = <EditorListener>{};

  /// Executes the given [request].
  ///
  /// Any changes that result from the given [request] are reported to listeners as a series
  /// of [EditorChangeEvent]s.
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

    final changes = command.execute(context);
    if (changes.isNotEmpty) {
      _notifyListeners(changes);
    }
  }

  void addListener(EditorListener listener) {
    _listeners.add(listener);
  }

  void removeListener(EditorListener listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(List<EditorChangeEvent> changes) {
    for (final listener in _listeners) {
      listener.onChange(changes);
    }
  }
}

/// An action that a [DocumentEditor] should execute.
abstract class EditorRequest {
  // Marker interface for all editor request types.
}

/// All resources that are available when executing [EditorCommand]s, such as a document,
/// composer, etc.
class EditorContext {
  final _resources = <String, dynamic>{};

  T find<T>(String id) {
    if (!_resources.containsKey(id)) {
      throw Exception("Tried to find an editor resource for the ID '$id', but there's no resource with that ID.");
    }
    if (_resources[id] is! T) {
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

abstract class EditorCommand {
  List<EditorChangeEvent> execute(EditorContext context);
}

abstract class EditorListener {
  void onChange(List<EditorChangeEvent> changes);
}

abstract class EditorChangeEvent {
  // Marker interface for all editor change events.
}

class DocumentChangeEvent implements EditorChangeEvent {
  const DocumentChangeEvent();
}

class SelectionChangeEvent implements EditorChangeEvent {
  const SelectionChangeEvent();
}
