import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:linkify/linkify.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'attributions.dart';
import 'horizontal_rule.dart';
import 'image.dart';
import 'list_items.dart';
import 'multi_node_editing.dart';
import 'text.dart';
import 'text_tools.dart';

/// Performs common, high-level editing and composition tasks
/// with a simplified API.
///
/// [CommonEditorOperations] is intended to provide a simple and
/// easy to use API for common tasks; it is not intended to operate
/// as a fundamental document manipulation tool. [CommonEditorOperations]
/// is built on top of [DocumentEditor], [DocumentLayout], and
/// [DocumentComposer]. Use those core artifacts to implement any
/// operations that are not supported by [CommonEditorOperations].
///
/// For example, compare the following [CommonEditorOperations] calls
/// to their respective implementation:
/// TODO: show 2-3 examples that compare the [CommonEditorOperations]
///       call with the comparable implementation to make it clear
///       that anything this class does, the developer can do directly.
///
/// If you implement operations for your editor that are not provided
/// by [CommonEditorOperations], consider implementing those operations
/// as extension methods on top of [CommonEditorOperations] so that the
/// rest of your editor can use those behaviors as if they were
/// implemented within [CommonEditorOperations].
class CommonEditorOperations {
  CommonEditorOperations({
    required this.editor,
    required this.composer,
    required this.documentLayoutResolver,
  });

  // Marked as protected for extension methods and subclasses
  @protected
  final DocumentEditor editor;
  // Marked as protected for extension methods and subclasses
  @protected
  final DocumentComposer composer;
  // Marked as protected for extension methods and subclasses
  @protected
  final DocumentLayoutResolver documentLayoutResolver;

  /// Clears the [DocumentComposer]'s current selection and sets
  /// the selection to the given collapsed [documentPosition].
  ///
  /// Returns [true] if the selection was set to the given [documentPosition],
  /// or [false] if the given [documentPosition] could not be
  /// resolved to a location within the [Document].
  bool insertCaretAtPosition(DocumentPosition documentPosition) {
    if (editor.document.getNodeById(documentPosition.nodeId) == null) {
      return false;
    }

    composer.selection = DocumentSelection.collapsed(position: documentPosition);
    return true;
  }

  /// Locates the [DocumentPosition] at the given [documentOffset] and
  /// sets the [DocumentComposer]'s selection to that collapsed position.
  ///
  /// If [findNearestPosition] is [true] (the default), then the [DocumentPosition]
  /// nearest the given [documentOffset] is used. If [findNearestPosition] is
  /// [false] then the selection is only changed if the given [documentOffset]
  /// sits directly on top of a valid [DocumentPosition], e.g., within the
  /// bounding box of a line of text, or within the bounds of an image.
  ///
  /// Returns [true] if the selection is set based on the given [documentOffset],
  /// or [false] if no relevant [DocumentPosition could be located.
  bool insertCaretAtOffset(
    Offset documentOffset, {
    findNearestPosition = true,
  }) {
    DocumentPosition? position;
    if (findNearestPosition) {
      position = documentLayoutResolver().getDocumentPositionNearestToOffset(documentOffset);
    } else {
      position = documentLayoutResolver().getDocumentPositionAtOffset(documentOffset);
    }

    if (position != null) {
      composer.selection = DocumentSelection.collapsed(position: position);
      return true;
    } else {
      return false;
    }
  }

  /// Sets the [DocumentComposer]'s selection to a [DocumentSelection]
  /// that spans from [baseDocumentPosition] to [extentDocumentPosition]
  /// with the selection direction going from the base position to the
  /// extent position.
  ///
  /// Returns [true] if the selection is successfully changed. Returns
  /// [false] if either [DocumentPosition] could not be mapped to locations
  /// within the [Document], and therefore the selection could not be set.
  bool selectRegion({
    required DocumentPosition baseDocumentPosition,
    required DocumentPosition extentDocumentPosition,
  }) {
    if (editor.document.getNodeById(baseDocumentPosition.nodeId) == null) {
      return false;
    }
    if (editor.document.getNodeById(extentDocumentPosition.nodeId) == null) {
      return false;
    }

    composer.selection = DocumentSelection(
      base: baseDocumentPosition,
      extent: extentDocumentPosition,
    );

    return true;
  }

  /// Given a collapsed selection in a [TextNode], expands the
  /// [DocumentComposer]'s selection to include the entire word in
  /// which the current selection sits.
  ///
  /// Returns [true] if a word was selected. Returns [false] if no
  /// selection could be computed, e.g., the selection was not collapsed,
  /// the selection was not in a [TextNode].
  bool selectSurroundingWord() {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final selectedNode = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return false;
    }

    final docSelection = composer.selection!;
    final currentSelection = TextSelection(
      baseOffset: (docSelection.base.nodePosition as TextNodePosition).offset,
      extentOffset: (docSelection.extent.nodePosition as TextNodePosition).offset,
    );
    final selectedText = currentSelection.textInside(selectedNode.text.text);

    if (selectedText.contains(' ')) {
      // The selection already spans multiple paragraphs. Nothing to do.
      return false;
    }

    final wordTextSelection = expandPositionToWord(
      text: selectedNode.text.text,
      textPosition: TextPosition(offset: (docSelection.extent.nodePosition as TextNodePosition).offset),
    );
    final wordNodeSelection = TextNodeSelection.fromTextSelection(wordTextSelection);

    composer.selection = DocumentSelection(
      base: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: wordNodeSelection.base,
      ),
      extent: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: wordNodeSelection.extent,
      ),
    );

    return true;
  }

  /// Sets the [DocumentComposer]'s selection to include the entire
  /// [Document].
  ///
  /// Always returns [true].
  bool selectAll() {
    final nodes = editor.document.nodes;
    if (nodes.isEmpty) {
      return false;
    }

    composer.selection = DocumentSelection(
      base: DocumentPosition(
        nodeId: nodes.first.id,
        nodePosition: nodes.first.beginningPosition,
      ),
      extent: DocumentPosition(
        nodeId: nodes.last.id,
        nodePosition: nodes.last.endPosition,
      ),
    );

    return true;
  }

  /// Collapses the [DocumentComposer]'s selection at the current
  /// extent [DocumentPosition].
  ///
  /// Returns [true] if the selection was collapsed, or [false] if
  /// there was no selection to collapse.
  bool collapseSelection() {
    if (composer.selection == null) {
      return false;
    }

    composer.selection = composer.selection!.collapse();

    return true;
  }

  /// Moves the [DocumentComposer]'s selection extent position in the
  /// upstream direction (to the left for left-to-right languages).
  ///
  /// {@template skip_unselectable_components}
  /// This selection movement skips any node whose visual component is
  /// not visually selectable, e.g., a horizontal rule that doesn't
  /// change it's visual state when it's selected.
  /// {@endtemplate}
  ///
  /// Expands/contracts the selection if [expand] is [true], otherwise
  /// collapses the selection or keeps it collapsed.
  ///
  /// By default, moves one character at a time when the extent sits in
  /// a [TextNode]. To move word-by-word, pass [MovementModifier.word]
  /// in [movementModifier]. To move to the beginning of a line, pass
  /// [MovementModifier.line] in [movementModifier].
  ///
  /// Returns [true] if the extent moved, or the selection changed, e.g., the
  /// selection collapsed but the extent stayed in the same place. Returns
  /// [false] if the extent did not move and the selection did not change.
  bool moveCaretUpstream({
    bool expand = false,
    MovementModifier? movementModifier,
  }) {
    if (composer.selection == null) {
      return false;
    }

    if (!composer.selection!.isCollapsed && !expand) {
      composer.selection = composer.selection!.collapseUpstream(editor.document);
      return true;
    }

    final currentExtent = composer.selection!.extent;
    final nodeId = currentExtent.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node == null) {
      return false;
    }
    final extentComponent = documentLayoutResolver().getComponentByNodeId(nodeId);
    if (extentComponent == null) {
      return false;
    }

    String newExtentNodeId = nodeId;
    NodePosition? newExtentNodePosition =
        extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifier);

    if (newExtentNodePosition == null) {
      // Move to next node
      final nextNode = _getUpstreamSelectableNodeBefore(node);

      if (nextNode == null) {
        // We're at the beginning of the document and can't go anywhere.
        return false;
      }

      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayoutResolver().getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        return false;
      }
      newExtentNodePosition = nextComponent.getEndPosition();
    }

    final newExtent = DocumentPosition(
      nodeId: newExtentNodeId,
      nodePosition: newExtentNodePosition,
    );

    if (expand) {
      // Selection should be expanded.
      composer.selection = composer.selection!.expandTo(
        newExtent,
      );
    } else {
      // Selection should be replaced by new collapsed position.
      composer.selection = DocumentSelection.collapsed(
        position: newExtent,
      );
    }

    return true;
  }

  /// Moves the [DocumentComposer]'s selection extent position in the
  /// downstream direction (to the right for left-to-right languages).
  ///
  /// {@macro skip_unselectable_components}
  ///
  /// Expands/contracts the selection if [expand] is [true], otherwise
  /// collapses the selection or keeps it collapsed.
  ///
  /// By default, moves one character at a time when the extent sits in
  /// a [TextNode]. To move word-by-word, pass [MovementModifier.word]
  /// in [movementModifier]. To move to the end of a line, pass
  /// [MovementModifier.line] in [movementModifier].
  ///
  /// Returns [true] if the extent moved, or the selection changed, e.g., the
  /// selection collapsed but the extent stayed in the same place. Returns
  /// [false] if the extent did not move and the selection did not change.
  bool moveCaretDownstream({
    bool expand = false,
    MovementModifier? movementModifier,
  }) {
    if (composer.selection == null) {
      return false;
    }

    if (!composer.selection!.isCollapsed && !expand) {
      composer.selection = composer.selection!.collapseDownstream(editor.document);
      return true;
    }

    final currentExtent = composer.selection!.extent;
    final nodeId = currentExtent.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node == null) {
      return false;
    }
    final extentComponent = documentLayoutResolver().getComponentByNodeId(nodeId);
    if (extentComponent == null) {
      return false;
    }

    String newExtentNodeId = nodeId;
    NodePosition? newExtentNodePosition =
        extentComponent.movePositionRight(currentExtent.nodePosition, movementModifier);

    if (newExtentNodePosition == null) {
      // Move to next node
      final nextNode = _getDownstreamSelectableNodeAfter(node);

      if (nextNode == null) {
        // We're at the beginning/end of the document and can't go
        // anywhere.
        return false;
      }

      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayoutResolver().getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        throw Exception(
            'Could not find next component to move the selection horizontally. Next node ID: ${nextNode.id}');
      }
      newExtentNodePosition = nextComponent.getBeginningPosition();
    }

    final newExtent = DocumentPosition(
      nodeId: newExtentNodeId,
      nodePosition: newExtentNodePosition,
    );

    if (expand) {
      // Selection should be expanded.
      composer.selection = composer.selection!.expandTo(
        newExtent,
      );
    } else {
      // Selection should be replaced by new collapsed position.
      composer.selection = DocumentSelection.collapsed(
        position: newExtent,
      );
    }

    return true;
  }

  /// Moves the [DocumentComposer]'s selection extent position up,
  /// vertically, either by moving the selection extent up one line of
  /// text, or by moving the selection extent up to the node above the
  /// current extent.
  ///
  /// If the current selection extent wants to move to the node above,
  /// but there is no node above the current extent, the extent is moved
  /// to the "start" position of the current node. For example: the extent
  /// moves from the middle of the first line of text in a paragraph to
  /// the beginning of the paragraph.
  ///
  /// {@macro skip_unselectable_components}
  ///
  /// Expands/contracts the selection if [expand] is [true], otherwise
  /// collapses the selection or keeps it collapsed.
  ///
  /// Returns [true] if the extent moved, or the selection changed, e.g., the
  /// selection collapsed but the extent stayed in the same place. Returns
  /// [false] if the extent did not move and the selection did not change.
  bool moveCaretUp({
    bool expand = false,
  }) {
    if (composer.selection == null) {
      return false;
    }

    final currentExtent = composer.selection!.extent;
    final nodeId = currentExtent.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node == null) {
      return false;
    }
    final extentComponent = documentLayoutResolver().getComponentByNodeId(nodeId);
    if (extentComponent == null) {
      return false;
    }

    String newExtentNodeId = nodeId;
    NodePosition? newExtentNodePosition = extentComponent.movePositionUp(currentExtent.nodePosition);

    if (newExtentNodePosition == null) {
      // Move to next node
      final nextNode = _getUpstreamSelectableNodeBefore(node);
      if (nextNode != null) {
        newExtentNodeId = nextNode.id;
        final nextComponent = documentLayoutResolver().getComponentByNodeId(nextNode.id);
        if (nextComponent == null) {
          editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
          return false;
        }
        final offsetToMatch = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
        newExtentNodePosition = nextComponent.getEndPositionNearX(offsetToMatch.dx);
      } else {
        // We're at the top of the document. Move the cursor to the
        // beginning of the current node.
        newExtentNodePosition = extentComponent.getBeginningPosition();
      }
    }

    final newExtent = DocumentPosition(
      nodeId: newExtentNodeId,
      nodePosition: newExtentNodePosition,
    );

    _updateSelectionExtent(position: newExtent, expandSelection: expand);

    return true;
  }

  /// Moves the [DocumentComposer]'s selection extent position down,
  /// vertically, either by moving the selection extent down one line of
  /// text, or by moving the selection extent down to the node below the
  /// current extent.
  ///
  /// If the current selection extent wants to move to the node below,
  /// but there is no node below the current extent, the extent is moved
  /// to the "end" position of the current node. For example: the extent
  /// moves from the middle of the last line of text in a paragraph to
  /// the end of the paragraph.
  ///
  /// {@macro skip_unselectable_components}
  ///
  /// Expands/contracts the selection if [expand] is [true], otherwise
  /// collapses the selection or keeps it collapsed.
  ///
  /// Returns [true] if the extent moved, or the selection changed, e.g., the
  /// selection collapsed but the extent stayed in the same place. Returns
  /// [false] if the extent did not move and the selection did not change.
  bool moveCaretDown({
    bool expand = false,
  }) {
    if (composer.selection == null) {
      return false;
    }

    final currentExtent = composer.selection!.extent;
    final nodeId = currentExtent.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node == null) {
      return false;
    }
    final extentComponent = documentLayoutResolver().getComponentByNodeId(nodeId);
    if (extentComponent == null) {
      return false;
    }

    String newExtentNodeId = nodeId;
    NodePosition? newExtentNodePosition = extentComponent.movePositionDown(currentExtent.nodePosition);

    if (newExtentNodePosition == null) {
      // Move to next node
      final nextNode = _getDownstreamSelectableNodeAfter(node);
      if (nextNode != null) {
        newExtentNodeId = nextNode.id;
        final nextComponent = documentLayoutResolver().getComponentByNodeId(nextNode.id);
        if (nextComponent == null) {
          editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
          return false;
        }
        final offsetToMatch = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
        newExtentNodePosition = nextComponent.getBeginningPositionNearX(offsetToMatch.dx);
      } else {
        // We're at the bottom of the document. Move the cursor to the
        // end of the current node.
        newExtentNodePosition = extentComponent.getEndPosition();
      }
    }

    final newExtent = DocumentPosition(
      nodeId: newExtentNodeId,
      nodePosition: newExtentNodePosition,
    );

    _updateSelectionExtent(position: newExtent, expandSelection: expand);

    return true;
  }

  /// Moves the [DocumentComposer]'s selection to the nearest node to [startingNode],
  /// whose [DocumentComponent] is visually selectable.
  /// 
  /// Expands the selection if [expand] is `true`, otherwise collapses the selection.
  /// 
  /// If a downstream selectable node if found, it will be used, otherwise,
  /// a upstream selectable node will be searched.
  ///
  /// If a selectable node is found, the selection will move to its beginning.
  /// If no selectable node is found, the selection will remain unchanged.
  ///
  /// Returns `true` if the selection is moved and `false` otherwise, e.g., there
  /// are no selectable nodes in the document.
  bool moveSelectionToNearestSelectableNode(
    DocumentNode startingNode, {
    bool expand = false,
  }) {
    String? newNodeId;
    NodePosition? newPosition;

    // Try to find a new selection downstream.
    final downstreamNode = _getDownstreamSelectableNodeAfter(startingNode);
    if (downstreamNode != null) {
      newNodeId = downstreamNode.id;
      final nextComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
      newPosition = nextComponent?.getBeginningPosition();
    }

    // Try to find a new selection upstream.
    if (newPosition == null) {
      final upstreamNode = _getUpstreamSelectableNodeBefore(startingNode);
      if (upstreamNode != null) {
        newNodeId = upstreamNode.id;
        final previousComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
        newPosition = previousComponent?.getBeginningPosition();
      }
    }

    if (newNodeId == null || newPosition == null) {
      return false;
    }

    final newExtent = DocumentPosition(
      nodeId: newNodeId,
      nodePosition: newPosition,
    );
    _updateSelectionExtent(position: newExtent, expandSelection: expand);

    return true;
  }

  void _updateSelectionExtent({
    required DocumentPosition position,
    required bool expandSelection,
  }) {
    if (expandSelection) {
      // Selection should be expanded.
      composer.selection = composer.selection!.expandTo(position);
    } else {
      // Selection should be replaced by new collapsed position.
      composer.selection = DocumentSelection.collapsed(position: position);
    }
  }

  /// Returns the first [DocumentNode] before [startingNode] whose
  /// [DocumentComponent] is visually selectable.
  DocumentNode? _getUpstreamSelectableNodeBefore(DocumentNode startingNode) {
    bool foundSelectableNode = false;
    DocumentNode prevNode = startingNode;
    DocumentNode? selectableNode;
    do {
      selectableNode = editor.document.getNodeBefore(prevNode);

      if (selectableNode != null) {
        final nextComponent = documentLayoutResolver().getComponentByNodeId(selectableNode.id);
        if (nextComponent != null) {
          foundSelectableNode = nextComponent.isVisualSelectionSupported();
        }
        prevNode = selectableNode;
      }
    } while (!foundSelectableNode && selectableNode != null);

    return selectableNode;
  }

  /// Returns the first [DocumentNode] after [startingNode] whose
  /// [DocumentComponent] is visually selectable.
  DocumentNode? _getDownstreamSelectableNodeAfter(DocumentNode startingNode) {
    bool foundSelectableNode = false;
    DocumentNode prevNode = startingNode;
    DocumentNode? selectableNode;
    do {
      selectableNode = editor.document.getNodeAfter(prevNode);

      if (selectableNode != null) {
        final nextComponent = documentLayoutResolver().getComponentByNodeId(selectableNode.id);
        if (nextComponent != null) {
          foundSelectableNode = nextComponent.isVisualSelectionSupported();
        }
        prevNode = selectableNode;
      }
    } while (!foundSelectableNode && selectableNode != null);

    return selectableNode;
  }

  /// Deletes a unit of content that comes after the [DocumentComposer]'s
  /// selection extent, or deletes all selected content if the selection
  /// is not collapsed.
  ///
  /// In the case of text editing, deletes the character that appears after
  /// the caret.
  ///
  /// If the caret sits at the end of a content block, such as the end of
  /// a text node, and the next node is not visually selectable, then the
  /// next node is deleted and the caret is kept where it is.
  ///
  /// Returns [true] if content was deleted, or [false] if no downstream
  /// content exists.
  bool deleteDownstream() {
    if (composer.selection == null) {
      return false;
    }

    if (!composer.selection!.isCollapsed) {
      // A span of content is selected. Delete the selection.
      _deleteExpandedSelection();
      return true;
    }

    if (composer.selection!.extent.nodePosition is UpstreamDownstreamNodePosition) {
      final nodePosition = composer.selection!.extent.nodePosition as UpstreamDownstreamNodePosition;
      if (nodePosition.affinity == TextAffinity.upstream) {
        // The caret is sitting on the upstream edge of block-level content. Delete the
        // whole block by replacing it with an empty paragraph.
        final nodeId = composer.selection!.extent.nodeId;
        _replaceBlockNodeWithEmptyParagraphAndCollapsedSelection(nodeId);

        return true;
      } else {
        // The caret is sitting on the downstream edge of block-level content and
        // the user is trying to delete downstream. It's not obvious what should
        // happen in this situation. Super Editor chooses to move the caret to
        // the next node and to not delete anything.
        return _moveSelectionToBeginningOfNextNode();
      }
    }

    if (composer.selection!.extent.nodePosition is TextNodePosition) {
      final textPosition = composer.selection!.extent.nodePosition as TextNodePosition;
      final text = (editor.document.getNodeById(composer.selection!.extent.nodeId) as TextNode).text.text;
      if (textPosition.offset == text.length) {
        final node = editor.document.getNodeById(composer.selection!.extent.nodeId)!;
        final nodeAfter = editor.document.getNodeAfter(node);

        if (nodeAfter is TextNode) {
          // The caret is at the end of one TextNode and is followed by
          // another TextNode. Merge the two TextNodes.
          return _mergeTextNodeWithDownstreamTextNode();
        } else if (nodeAfter != null) {
          final componentAfter = documentLayoutResolver().getComponentByNodeId(nodeAfter.id)!;

          if (componentAfter.isVisualSelectionSupported()) {
            // The caret is at the end of a TextNode, but the next node
            // is not a TextNode. Move the document selection to the
            // next node.
            return _moveSelectionToBeginningOfNextNode();
          } else {
            // The next node/component isn't selectable. Delete it.
            _deleteNonSelectedNode(nodeAfter);
            return true;
          }
        }
      } else {
        return _deleteDownstreamCharacter();
      }
    }

    return false;
  }

  bool _moveSelectionToBeginningOfNextNode() {
    if (composer.selection == null) {
      return false;
    }

    final node = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (node == null) {
      return false;
    }

    final nodeAfter = editor.document.getNodeAfter(node);
    if (nodeAfter == null) {
      return false;
    }

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeAfter.id,
        nodePosition: nodeAfter.beginningPosition,
      ),
    );

    return true;
  }

  bool _mergeTextNodeWithDownstreamTextNode() {
    final node = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (node == null) {
      return false;
    }
    if (node is! TextNode) {
      return false;
    }

    final nodeAfter = editor.document.getNodeAfter(node);
    if (nodeAfter == null) {
      return false;
    }
    if (nodeAfter is! TextNode) {
      return false;
    }

    final firstNodeTextLength = node.text.text.length;

    // Send edit command.
    editor.executeCommand(
      CombineParagraphsCommand(
        firstNodeId: node.id,
        secondNodeId: nodeAfter.id,
      ),
    );

    // Place the cursor at the point where the text came together.
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: node.id,
        nodePosition: TextNodePosition(offset: firstNodeTextLength),
      ),
    );

    return true;
  }

  bool _deleteDownstreamCharacter() {
    if (composer.selection == null) {
      return false;
    }
    if (!_isTextEntryNode(document: editor.document, selection: composer.selection!)) {
      return false;
    }
    if (composer.selection!.isCollapsed && (composer.selection!.extent.nodePosition as TextNodePosition).offset < 0) {
      return false;
    }

    final textNode = editor.document.getNode(composer.selection!.extent) as TextNode;
    final text = textNode.text;
    final currentTextPosition = (composer.selection!.extent.nodePosition as TextNodePosition);
    if (currentTextPosition.offset >= text.text.length) {
      return false;
    }

    final nextCharacterOffset = getCharacterEndBounds(text.text, currentTextPosition.offset);

    // Delete the selected content.
    editor.executeCommand(
      DeleteSelectionCommand(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: currentTextPosition,
          ),
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: nextCharacterOffset),
          ),
        ),
      ),
    );

    return true;
  }

  /// Deletes a unit of content that comes before the [DocumentComposer]'s
  /// selection extent, or deletes all selected content if the selection
  /// is not collapsed.
  ///
  /// In the case of text editing, deletes the character that appears before
  /// the caret.
  ///
  /// If the caret sits at the beginning of a content block, such as the
  /// beginning of a text node, and the upstream node is not visually selectable,
  /// then the upstream node is deleted and the caret is kept where it is.
  ///
  /// Returns [true] if content was deleted, or [false] if no upstream
  /// content exists.
  bool deleteUpstream() {
    if (composer.selection == null) {
      return false;
    }

    if (!composer.selection!.isCollapsed) {
      // A span of content is selected. Delete the selection.
      _deleteExpandedSelection();
      return true;
    }

    final node = editor.document.getNodeById(composer.selection!.extent.nodeId)!;

    // If the caret is at the beginning of a list item, unindent the list item.
    if (node is ListItemNode && (composer.selection!.extent.nodePosition as TextNodePosition).offset == 0) {
      return unindentListItem();
    }

    if (composer.selection!.extent.nodePosition is UpstreamDownstreamNodePosition) {
      final nodePosition = composer.selection!.extent.nodePosition as UpstreamDownstreamNodePosition;
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The caret is sitting on the downstream edge of block-level content. Delete the
        // whole block by replacing it with an empty paragraph.
        final nodeId = composer.selection!.extent.nodeId;
        _replaceBlockNodeWithEmptyParagraphAndCollapsedSelection(nodeId);

        return true;
      } else {
        // The caret is sitting on the upstream edge of block-level content and
        // the user is trying to delete upstream.
        //  * If the node above is an empty paragraph, delete it.
        //  * If the node above is non-selectable, delete it.
        //  * Otherwise, move the caret up to the node above.
        final nodeBefore = editor.document.getNodeBefore(node);
        if (nodeBefore == null) {
          return false;
        }

        final componentBefore = documentLayoutResolver().getComponentByNodeId(nodeBefore.id)!;

        if (nodeBefore is TextNode && nodeBefore.text.text.isEmpty) {
          editor.executeCommand(EditorCommandFunction((doc, transaction) {
            transaction.deleteNode(nodeBefore);
          }));
          return true;
        }

        if (!componentBefore.isVisualSelectionSupported()) {
          // The node/component above is not selectable. Delete it.
          _deleteNonSelectedNode(nodeBefore);
          return true;
        }

        return _moveSelectionToEndOfPrecedingNode();
      }
    }

    if (composer.selection!.extent.nodePosition is TextNodePosition) {
      final textPosition = composer.selection!.extent.nodePosition as TextNodePosition;
      if (textPosition.offset == 0) {
        final nodeBefore = editor.document.getNodeBefore(node);
        if (nodeBefore == null) {
          return false;
        }

        final componentBefore = documentLayoutResolver().getComponentByNodeId(nodeBefore.id)!;

        if (nodeBefore is TextNode) {
          // The caret is at the beginning of one TextNode and is preceded by
          // another TextNode. Merge the two TextNodes.
          return _mergeTextNodeWithUpstreamTextNode();
        } else if (!componentBefore.isVisualSelectionSupported()) {
          // The node/component above is not selectable. Delete it.
          _deleteNonSelectedNode(nodeBefore);
          return true;
        } else if ((node as TextNode).text.text.isEmpty) {
          // The caret is at the beginning of an empty TextNode and the preceding
          // node is not a TextNode. Delete the current TextNode and move the
          // selection up to the preceding node if exist.
          if (_moveSelectionToEndOfPrecedingNode()) {
            editor.executeCommand(EditorCommandFunction((doc, transaction) {
              transaction.deleteNode(node);
            }));
          }
          return true;
        } else {
          // The caret is at the beginning of a non-empty TextNode, and the
          // preceding node is not a TextNode. Move the document selection to the
          // preceding node.
          return _moveSelectionToEndOfPrecedingNode();
        }
      } else {
        return _deleteUpstreamCharacter();
      }
    }

    return false;
  }

  bool _moveSelectionToEndOfPrecedingNode() {
    if (composer.selection == null) {
      return false;
    }

    final node = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (node == null) {
      return false;
    }

    final nodeBefore = editor.document.getNodeBefore(node);
    if (nodeBefore == null) {
      return false;
    }

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeBefore.id,
        nodePosition: nodeBefore.endPosition,
      ),
    );

    return true;
  }

  bool _mergeTextNodeWithUpstreamTextNode() {
    final node = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (node == null) {
      return false;
    }

    final nodeAbove = editor.document.getNodeBefore(node);
    if (nodeAbove == null) {
      return false;
    }
    if (nodeAbove is! TextNode) {
      return false;
    }

    final aboveParagraphLength = nodeAbove.text.text.length;

    // Send edit command.
    editor.executeCommand(
      CombineParagraphsCommand(
        firstNodeId: nodeAbove.id,
        secondNodeId: node.id,
      ),
    );

    // Place the cursor at the point where the text came together.
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeAbove.id,
        nodePosition: TextNodePosition(offset: aboveParagraphLength),
      ),
    );

    return true;
  }

  bool _deleteUpstreamCharacter() {
    if (composer.selection == null) {
      return false;
    }
    if (!_isTextEntryNode(document: editor.document, selection: composer.selection!)) {
      return false;
    }
    if (composer.selection!.isCollapsed && (composer.selection!.extent.nodePosition as TextNodePosition).offset <= 0) {
      return false;
    }

    final textNode = editor.document.getNode(composer.selection!.extent) as TextNode;
    final currentTextPosition = composer.selection!.extent.nodePosition as TextNodePosition;

    final previousCharacterOffset = getCharacterStartBounds(textNode.text.text, currentTextPosition.offset);

    final newSelectionPosition = DocumentPosition(
      nodeId: textNode.id,
      nodePosition: TextNodePosition(offset: previousCharacterOffset),
    );

    // Delete the selected content.
    editor.executeCommand(
      DeleteSelectionCommand(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: currentTextPosition,
          ),
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: previousCharacterOffset),
          ),
        ),
      ),
    );

    composer.selection = DocumentSelection.collapsed(position: newSelectionPosition);

    return true;
  }

  /// Replaces the [DocumentNode] with the given `nodeId` with a [ParagraphNode],
  /// and places the caret in the new [ParagraphNode].
  ///
  /// This can be used, for example, to effectively delete an image by replacing
  /// it with an empty paragraph.
  void _replaceBlockNodeWithEmptyParagraphAndCollapsedSelection(String nodeId) {
    editor.executeCommand(EditorCommandFunction((doc, transaction) {
      final oldNode = doc.getNodeById(nodeId);
      if (oldNode == null) {
        return;
      }

      final newNode = ParagraphNode(
        id: oldNode.id,
        text: AttributedText(),
      );

      transaction.replaceNode(oldNode: oldNode, newNode: newNode);

      composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newNode.id,
          nodePosition: newNode.beginningPosition,
        ),
      );
    }));
  }

  /// Deletes all selected content.
  ///
  /// Returns [true] if content was deleted, or [false] if no content was
  /// selected.
  bool deleteSelection() {
    if (composer.selection == null) {
      return false;
    }

    if (composer.selection!.isCollapsed) {
      return false;
    }

    // The document selection includes a span of content. It may or may not
    // cross nodes. Either way, delete the selected content.
    _deleteExpandedSelection();
    return true;
  }

  void _deleteExpandedSelection() {
    final newSelectionPosition = getDocumentPositionAfterExpandedDeletion(
      document: editor.document,
      selection: composer.selection!,
    );

    // Delete the selected content.
    editor.executeCommand(
      DeleteSelectionCommand(documentSelection: composer.selection!),
    );

    composer.selection = DocumentSelection.collapsed(position: newSelectionPosition);
  }

  /// Returns the [DocumentPosition] where the caret should sit after deleting
  /// the given [selection] from the given [document].
  ///
  /// This method doesn't delete any content. Instead, it determines what would
  /// be deleted if a delete operation was run for the given [selection]. Based
  /// on the shared understanding of content deletion rules, the resulting caret
  /// position is returned.
  // TODO: Move this method to an appropriate place. It was made public and static
  //       because document_keyboard_actions.dart also uses this behavior.
  static DocumentPosition getDocumentPositionAfterExpandedDeletion({
    required Document document,
    required DocumentSelection selection,
  }) {
    // Figure out where the caret should appear after the
    // deletion.
    // TODO: This calculation depends upon the first
    //       selected node still existing after the deletion. This
    //       is a fragile expectation and should be revisited.
    final basePosition = selection.base;
    final baseNode = document.getNode(basePosition);
    if (baseNode == null) {
      throw Exception('Failed to _getDocumentPositionAfterDeletion because the base node no longer exists.');
    }
    final baseNodeIndex = document.getNodeIndex(baseNode);

    final extentPosition = selection.extent;
    final extentNode = document.getNode(extentPosition);
    if (extentNode == null) {
      throw Exception('Failed to _getDocumentPositionAfterDeletion because the extent node no longer exists.');
    }
    final extentNodeIndex = document.getNodeIndex(extentNode);

    final topNodeIndex = min(baseNodeIndex, extentNodeIndex);
    final topNode = document.getNodeAt(topNodeIndex)!;
    final topNodePosition = baseNodeIndex < extentNodeIndex ? basePosition.nodePosition : extentPosition.nodePosition;

    final bottomNodeIndex = max(baseNodeIndex, extentNodeIndex);
    final bottomNode = document.getNodeAt(bottomNodeIndex)!;
    final bottomNodePosition =
        baseNodeIndex < extentNodeIndex ? extentPosition.nodePosition : basePosition.nodePosition;

    DocumentPosition newSelectionPosition;

    if (baseNodeIndex != extentNodeIndex) {
      if (topNodePosition == topNode.beginningPosition && bottomNodePosition == bottomNode.endPosition) {
        // All nodes in the selection will be deleted. Assume that the base
        // node will be retained and converted into a paragraph, if it's not
        // already a paragraph.
        newSelectionPosition = DocumentPosition(
          nodeId: baseNode.id,
          nodePosition: const TextNodePosition(offset: 0),
        );
      } else if (topNodePosition == topNode.beginningPosition) {
        // The top node will be deleted, but only part of the bottom node
        // will be deleted.
        newSelectionPosition = DocumentPosition(
          nodeId: bottomNode.id,
          nodePosition: bottomNode.beginningPosition,
        );
      } else if (bottomNodePosition == bottomNode.endPosition) {
        // The bottom node will be deleted, but only part of the top node
        // will be deleted.
        newSelectionPosition = DocumentPosition(
          nodeId: topNode.id,
          nodePosition: topNodePosition,
        );
      } else {
        // Part of the top and bottom nodes will be deleted, but both of
        // those nodes will remain.

        // The caret should end up at the base position
        newSelectionPosition = baseNodeIndex <= extentNodeIndex ? selection.base : selection.extent;
      }
    } else {
      // Selection is within a single node.
      //
      // If it's an upstream/downstream selection node, then the whole node
      // is selected, and it will be replaced by a Paragraph Node.
      //
      // Otherwise, it must be a TextNode, in which case we need to figure
      // out which DocumentPosition contains the earlier TextNodePosition.
      if (basePosition.nodePosition is UpstreamDownstreamNodePosition) {
        // Assume that the node was replace with an empty paragraph.
        newSelectionPosition = DocumentPosition(
          nodeId: baseNode.id,
          nodePosition: const TextNodePosition(offset: 0),
        );
      } else if (basePosition.nodePosition is TextNodePosition) {
        final baseOffset = (basePosition.nodePosition as TextNodePosition).offset;
        final extentOffset = (extentPosition.nodePosition as TextNodePosition).offset;

        newSelectionPosition = DocumentPosition(
          nodeId: baseNode.id,
          nodePosition: TextNodePosition(offset: min(baseOffset, extentOffset)),
        );
      } else {
        throw Exception(
            'Unknown selection position type: $basePosition, for node: $baseNode, within document selection: $selection');
      }
    }

    return newSelectionPosition;
  }

  void _deleteNonSelectedNode(DocumentNode node) {
    assert(composer.selection?.base.nodeId != node.id);
    assert(composer.selection?.extent.nodeId != node.id);

    editor.executeCommand(DeleteNodeCommand(nodeId: node.id));
  }

  /// Adds the given [attributions] to all [AttributedText] within the
  /// [DocumentComposer]'s current selection.
  ///
  /// Returns [true] if any text exists within the selection, or [false]
  /// otherwise.
  bool addAttributionsToSelection(Set<Attribution> attributions) {
    if (composer.selection == null) {
      return false;
    }

    if (composer.selection!.isCollapsed) {
      return false;
    }

    editor.executeCommand(
      AddTextAttributionsCommand(
        documentSelection: composer.selection!,
        attributions: attributions,
      ),
    );

    return false;
  }

  /// Removes the given [attributions] from all [AttributedText] within the
  /// [DocumentComposer]'s current selection.
  ///
  /// Returns [true] if any text exists within the selection, or [false]
  /// otherwise.
  bool removeAttributionsFromSelection(Set<Attribution> attributions) {
    if (composer.selection == null) {
      return false;
    }

    if (composer.selection!.isCollapsed) {
      return false;
    }

    editor.executeCommand(
      RemoveTextAttributionsCommand(
        documentSelection: composer.selection!,
        attributions: attributions,
      ),
    );

    return false;
  }

  /// Toggles the given [attributions] on all [AttributedText] within the
  /// [DocumentComposer]'s current selection.
  ///
  /// Returns [true] if any text exists within the selection, or [false]
  /// otherwise.
  bool toggleAttributionsOnSelection(Set<Attribution> attributions) {
    if (composer.selection == null) {
      return false;
    }

    if (composer.selection!.isCollapsed) {
      return false;
    }

    editor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: composer.selection!,
        attributions: attributions,
      ),
    );

    return false;
  }

  /// Adds the given [attributions] to the [DocumentComposer]'s input
  /// mode so that any new plain text inserted using [insertPlainText()]
  /// will contain the given [attributions].
  ///
  /// Always returns [true].
  bool activateComposerAttributions(Set<Attribution> attributions) {
    composer.preferences.addStyles(attributions);
    return true;
  }

  /// Removes the given [attributions] from the [DocumentComposer]'s input
  /// mode so that any new plain text inserted using [insertPlainText()]
  /// **doesn't** contain the given [attributions].
  ///
  /// Always returns [true].
  bool deactivateComposerAttributions(Set<Attribution> attributions) {
    composer.preferences.removeStyles(attributions);
    return true;
  }

  /// Toggles the presence of the given [attributions] within the
  /// [DocumentComposer]'s input mode.
  ///
  /// Always returns [true].
  bool toggleComposerAttributions(Set<Attribution> attributions) {
    composer.preferences.toggleStyles(attributions);
    return true;
  }

  /// Removes all [attributions] within the [DocumentComposer]'s
  /// input mode.
  ///
  /// Always returns [true].
  bool clearComposerAttributions() {
    composer.preferences.clearStyles();
    return true;
  }

  /// Inserts the given [text] at the [DocumentComposer]'s current
  /// selection extent, applying any [Attribution]s that are
  /// currently activated in the [DocumentComposer]'s input mode.
  ///
  /// Any selected content is deleted before inserting the new text.
  ///
  /// Returns `true` if the [text] was successfully inserted, or [false]
  /// if it wasn't, e.g., there was no selection, or more than one node
  /// was selected.
  bool insertPlainText(String text) {
    editorOpsLog.fine('Attempting to insert "$text" at document selection: ${composer.selection}');
    if (composer.selection == null) {
      editorOpsLog.fine("The composer has no selection. Can't insert.");
      return false;
    }

    if (!composer.selection!.isCollapsed) {
      // The selection is expanded. Delete the selected content
      // and then insert the new text.
      editorOpsLog.fine("The selection is expanded. Deleting the selection before inserting text.");
      _deleteExpandedSelection();
    }

    final extentNodePosition = composer.selection!.extent.nodePosition;
    if (extentNodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      insertBlockLevelNewline();
    }

    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId)!;
    if (extentNode is! TextNode) {
      editorOpsLog
          .fine("Couldn't insert text because Super Editor doesn't know how to handle a node of type: $extentNode");
      return false;
    }

    final textNode = editor.document.getNode(composer.selection!.extent) as TextNode;
    final initialTextOffset = (composer.selection!.extent.nodePosition as TextNodePosition).offset;

    editorOpsLog.fine("Executing text insertion command.");
    editor.executeCommand(
      InsertTextCommand(
        documentPosition: composer.selection!.extent,
        textToInsert: text,
        attributions: composer.preferences.currentAttributions,
      ),
    );

    editorOpsLog.fine("Updating Document Composer selection after text insertion.");
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextNodePosition(
          offset: initialTextOffset + text.length,
        ),
      ),
    );

    return true;
  }

  /// Inserts the given [character] at the current extent position.
  ///
  /// By default, the current [DocumentComposer] input mode's [Attribution]s
  /// are added to the given [character]. To insert [character] exactly as it's provided,
  /// set [ignoreComposerAttributions] to [true].
  ///
  /// If the current selection is expanded, the current selection is deleted
  /// before the character is inserted.
  ///
  /// If the caret sits at the boundary of a block node, a new paragraph is
  /// inserted before or after the block node, and then the character is inserted.
  ///
  /// Returns [true] if the [character] was successfully inserted, or [false]
  /// if it wasn't, e.g., the currently selected node is not a [TextNode].
  bool insertCharacter(
    String character, {
    bool ignoreComposerAttributions = false,
  }) {
    editorOpsLog.fine("Trying to insert '$character'");
    if (composer.selection == null) {
      return false;
    }

    if (!composer.selection!.isCollapsed) {
      _deleteExpandedSelection();
    }

    final extentNodePosition = composer.selection!.extent.nodePosition;
    if (extentNodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      insertBlockLevelNewline();
    }

    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId)!;
    if (extentNode is! TextNode) {
      editorOpsLog.fine(
          "Couldn't insert character because Super Editor doesn't know how to handle a node of type: $extentNode");
      return false;
    }

    // Delegate the action to the standard insert-character behavior.
    final inserted = _insertCharacterInTextComposable(
      character,
      ignoreComposerAttributions: ignoreComposerAttributions,
    );
    editorOpsLog.fine("Did insert '$character'? $inserted");
    return inserted;
  }

  // TODO: refactor to make prefix matching extensible (#68)
  bool convertParagraphByPatternMatching(String nodeId) {
    final node = editor.document.getNodeById(nodeId);
    if (node == null) {
      return false;
    }
    if (node is! ParagraphNode) {
      return false;
    }

    editorOpsLog.fine("Running pattern matching on a ParagraphNode, to convert it to another node type.");
    final text = node.text;
    final textSelection = composer.selection!.extent.nodePosition as TextNodePosition;
    final textBeforeCaret = text.text.substring(0, textSelection.offset);

    final unorderedListItemMatch = RegExp(r'^\s*[\*-]\s+$');
    final hasUnorderedListItemMatch = unorderedListItemMatch.hasMatch(textBeforeCaret);

    // We want to match "1. ", " 1. ", "1) ", " 1) ".
    final orderedListItemMatch = RegExp(r'^\s*1[.)]\s+$');
    final hasOrderedListItemMatch = orderedListItemMatch.hasMatch(textBeforeCaret);

    editorOpsLog.fine('_convertParagraphIfDesired', ' - text before caret: "$textBeforeCaret"');
    if (hasUnorderedListItemMatch || hasOrderedListItemMatch) {
      editorOpsLog.fine('_convertParagraphIfDesired', ' - found unordered list item prefix');
      int startOfNewText = textBeforeCaret.length;
      while (startOfNewText < node.text.text.length && node.text.text[startOfNewText] == ' ') {
        startOfNewText += 1;
      }
      final adjustedText = node.text.copyText(startOfNewText);
      final newNode = hasUnorderedListItemMatch
          ? ListItemNode.unordered(id: node.id, text: adjustedText)
          : ListItemNode.ordered(id: node.id, text: adjustedText);

      editor.executeCommand(
        EditorCommandFunction((document, transaction) {
          transaction.replaceNode(oldNode: node, newNode: newNode);
        }),
      );

      // We removed some text at the beginning of the list item.
      // Move the selection back by that same amount.
      final textPosition = composer.selection!.extent.nodePosition as TextNodePosition;
      composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: textPosition.offset - startOfNewText),
        ),
      );

      return true;
    }

    final hrMatch = RegExp(r'^---*\s$');
    final hasHrMatch = hrMatch.hasMatch(textBeforeCaret);
    if (hasHrMatch) {
      editorOpsLog.fine('Paragraph has an HR match');
      // Insert an HR before this paragraph and then clear the
      // paragraph's content.
      final paragraphNodeIndex = editor.document.getNodeIndex(node);

      editor.executeCommand(
        EditorCommandFunction((document, transaction) {
          transaction.insertNodeAt(
            paragraphNodeIndex,
            HorizontalRuleNode(
              id: DocumentEditor.createNodeId(),
            ),
          );
        }),
      );

      node.text = node.text.removeRegion(startOffset: 0, endOffset: hrMatch.firstMatch(textBeforeCaret)!.end);

      composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      );

      return true;
    }

    final blockquoteMatch = RegExp(r'^>\s$');
    final hasBlockquoteMatch = blockquoteMatch.hasMatch(textBeforeCaret);
    if (hasBlockquoteMatch) {
      int startOfNewText = textBeforeCaret.length;
      while (startOfNewText < node.text.text.length && node.text.text[startOfNewText] == ' ') {
        startOfNewText += 1;
      }
      final adjustedText = node.text.copyText(startOfNewText);
      final newNode = ParagraphNode(
        id: node.id,
        text: adjustedText,
        metadata: {'blockType': blockquoteAttribution},
      );

      editor.executeCommand(
        EditorCommandFunction((document, transaction) {
          transaction.replaceNode(oldNode: node, newNode: newNode);
        }),
      );

      // We removed some text at the beginning of the list item.
      // Move the selection back by that same amount.
      final textPosition = composer.selection!.extent.nodePosition as TextNodePosition;
      composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: textPosition.offset - startOfNewText),
        ),
      );

      return true;
    }

    // URL match, e.g., images, social, etc.
    editorOpsLog.fine('Looking for URL match...');
    final extractedLinks = linkify(node.text.text,
        options: const LinkifyOptions(
          humanize: false,
        ));
    final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
    editorOpsLog.fine("Found $linkCount link(s)");
    final String nonEmptyText =
        extractedLinks.fold('', (value, element) => element is TextElement ? value + element.text.trim() : value);
    if (linkCount == 1 && nonEmptyText.isEmpty) {
      // This node's text is just a URL, try to interpret it
      // as a known type.
      editorOpsLog.fine("The whole node is one big URL. Trying to convert the node type based on pattern matching...");
      final link = extractedLinks.firstWhereOrNull((element) => element is UrlElement)!.text;
      _processUrlNode(
        document: editor.document,
        editor: editor,
        nodeId: node.id,
        originalText: node.text.text,
        url: link,
      );
      return true;
    }

    // No pattern match was found
    editorOpsLog.fine("ParagraphNode didn't match any conversion pattern.");
    return false;
  }

  Future<void> _processUrlNode({
    required Document document,
    required DocumentEditor editor,
    required String nodeId,
    required String originalText,
    required String url,
  }) async {
    late http.Response response;

    // This function throws [SocketException] when the [url] is not valid.
    // For instance, when typing for https://f|, it throws
    // Unhandled Exception: SocketException: Failed host lookup: 'f'
    //
    // It doesn't affect any functionality, but it throws exception and preventing
    // any related test to pass
    try {
      response = await http.get(Uri.parse(url));
    } on SocketException catch (e) {
      editorOpsLog.fine('Failed to load URL: ${e.message}');
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      editorOpsLog.fine('Failed to load URL: ${response.statusCode} - ${response.reasonPhrase}');
      return;
    }

    final contentType = response.headers['content-type'];
    if (contentType == null) {
      editorOpsLog.fine('Failed to determine URL content type.');
      return;
    }
    if (!contentType.startsWith('image/')) {
      editorOpsLog.fine('URL is not an image. Ignoring');
      return;
    }

    // The URL is an image. Convert the node.
    editorOpsLog.fine('The URL is an image. Converting the ParagraphNode to an ImageNode.');
    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      editorOpsLog.fine('The node has become something other than a ParagraphNode ($node). Can\'t convert ndoe.');
      return;
    }
    final currentText = node.text.text;
    if (currentText.trim() != originalText.trim()) {
      editorOpsLog.fine('The node content changed in a non-trivial way. Aborting node conversion.');
      return;
    }

    final imageNode = ImageNode(
      id: node.id,
      imageUrl: url,
    );

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction.replaceNode(oldNode: node, newNode: imageNode);
      }),
    );

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: node.id,
        nodePosition: imageNode.endPosition,
      ),
    );
  }

  bool _insertCharacterInTextComposable(
    String character, {
    bool ignoreComposerAttributions = false,
  }) {
    if (composer.selection == null) {
      return false;
    }
    if (!composer.selection!.isCollapsed) {
      return false;
    }
    if (!_isTextEntryNode(document: editor.document, selection: composer.selection!)) {
      return false;
    }

    final textNode = editor.document.getNode(composer.selection!.extent) as TextNode;
    final initialTextOffset = (composer.selection!.extent.nodePosition as TextNodePosition).offset;

    editor.executeCommand(
      InsertTextCommand(
        documentPosition: composer.selection!.extent,
        textToInsert: character,
        attributions: ignoreComposerAttributions ? {} : composer.preferences.currentAttributions,
      ),
    );

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextNodePosition(
          offset: initialTextOffset + character.length,
        ),
      ),
    );

    return true;
  }

  /// Inserts a new [ParagraphNode], or splits an existing node into two.
  ///
  /// If the [DocumentComposer] selection is collapsed, and the extent is
  /// at the end of a node, such as the end of a paragraph, then a new
  /// [ParagraphNode] is added after the current node and the selection
  /// extent is moved to the new [ParagraphNode].
  ///
  /// If the [DocumentComposer] selection is collapsed, and the extent is
  /// in the middle of a node, such as in the middle of a paragraph, list
  /// item, or blockquote, then the current node is split into two nodes
  /// of the same type at that position.
  ///
  /// If the current selection is not collapsed then the current selection
  /// is first deleted, then the aforementioned operation takes place.
  ///
  /// Returns [true] if a new node was inserted or a node was split into two.
  /// Returns [false] if there was no selection.
  bool insertBlockLevelNewline() {
    if (composer.selection == null) {
      return false;
    }

    // Ensure that the entire selection sits within the same node.
    final baseNode = editor.document.getNodeById(composer.selection!.base.nodeId)!;
    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId)!;
    if (baseNode.id != extentNode.id) {
      return false;
    }

    if (!composer.selection!.isCollapsed) {
      // The selection is not collapsed. Delete the selected content first,
      // then continue the process.
      _deleteExpandedSelection();
    }

    final newNodeId = DocumentEditor.createNodeId();

    if (extentNode is ListItemNode) {
      if (extentNode.text.text.isEmpty) {
        // The list item is empty. Convert it to a paragraph.
        return convertToParagraph();
      }

      // Split the list item into two.
      editor.executeCommand(
        SplitListItemCommand(
          nodeId: extentNode.id,
          splitPosition: composer.selection!.extent.nodePosition as TextNodePosition,
          newNodeId: newNodeId,
        ),
      );
    } else if (extentNode is ParagraphNode) {
      // Split the paragraph into two. This includes headers, blockquotes, and
      // any other block-level paragraph.
      final currentExtentPosition = composer.selection!.extent.nodePosition as TextNodePosition;
      final endOfParagraph = extentNode.endPosition;

      editor.executeCommand(
        SplitParagraphCommand(
          nodeId: extentNode.id,
          splitPosition: currentExtentPosition,
          newNodeId: newNodeId,
          replicateExistingMetadata: currentExtentPosition.offset != endOfParagraph.offset,
        ),
      );
    } else if (composer.selection!.extent.nodePosition is UpstreamDownstreamNodePosition) {
      final extentPosition = composer.selection!.extent.nodePosition as UpstreamDownstreamNodePosition;
      if (extentPosition.affinity == TextAffinity.downstream) {
        // The caret sits on the downstream edge of block-level content. Insert
        // a new paragraph after this node.
        editor.executeCommand(EditorCommandFunction((doc, transaction) {
          transaction.insertNodeAfter(
            existingNode: extentNode,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(text: ''),
            ),
          );
        }));
      } else {
        // The caret sits on the upstream edge of block-level content. Insert
        // a new paragraph before this node.
        editor.executeCommand(EditorCommandFunction((doc, transaction) {
          transaction.insertNodeBefore(
            existingNode: extentNode,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(text: ''),
            ),
          );
        }));
      }
    } else {
      // We don't know how to handle this type of node position. Do nothing.
      return false;
    }

    // Place the caret at the beginning of the new node.
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newNodeId,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );

    return true;
  }

  /// Inserts an image at the current selection extent.
  ///
  /// If the selection extent sits in an empty paragraph, that paragraph
  /// is converted into the desired image and a new empty paragraph is inserted
  /// after the image.
  ///
  /// If the selection extent sits at the end of a paragraph, the image is
  /// inserted as a new node after that paragraph, and then a new empty paragraph
  /// is inserted after the image.
  ///
  /// If the selection extent sits in the middle of a paragraph then the
  /// paragraph is split into two at that position, an image is inserted between
  /// the two paragraphs, the selection extent is placed at the beginning of the
  /// second paragraph.
  ///
  /// If the selection extent sits in any other kind of node, nothing happens.
  ///
  /// Returns [true] if an image was inserted, [false] if it wasn't.
  bool insertImage(String url) {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final nodeId = composer.selection!.base.nodeId;
    return _insertBlockLevelContent(ImageNode(id: nodeId, imageUrl: url));
  }

  /// Inserts horizontal rule at the current selection extent.
  ///
  /// If the selection extent sits in an empty paragraph, that paragraph
  /// is converted into the desired horizontal rule and a new empty paragraph
  /// is inserted after the horizontal rule.
  ///
  /// If the selection extent sits at the end of a paragraph, the horizontal
  /// rule is inserted as a new node after that paragraph, and then a new
  /// empty paragraph is inserted after the horizontal rule.
  ///
  /// If the selection extent sits in the middle of a paragraph then the
  /// paragraph is split into two at that position, a horizontal rule is
  /// inserted between the two paragraphs, the selection extent is placed
  /// at the beginning of the second paragraph.
  ///
  /// If the selection extent sits in any other kind of node, nothing happens.
  ///
  /// Returns [true] if a horizontal rule was inserted, [false] if it wasn't.
  bool insertHorizontalRule() {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final nodeId = composer.selection!.base.nodeId;
    return _insertBlockLevelContent(HorizontalRuleNode(id: nodeId));
  }

  /// Inserts the given [blockNode] after the caret.
  ///
  /// If the selection extent sits in an empty paragraph, that paragraph
  /// is converted into the given [blockNode] and a new empty paragraph
  /// is inserted after the [blockNode].
  ///
  /// If the selection extent sits at the end of a paragraph, the [blockNode]
  /// is inserted as a new node after that paragraph, and then a new
  /// empty paragraph is inserted after the [blockNode].
  ///
  /// If the selection extent sits in the middle of a paragraph then the
  /// paragraph is split into two at that position, the [blockNode] is
  /// inserted between the two paragraphs, the selection extent is placed
  /// at the beginning of the second paragraph.
  ///
  /// If the selection extent sits in any other kind of node, nothing happens.
  ///
  /// Returns [true] if the [blockNode] was inserted, [false] if it wasn't.
  bool _insertBlockLevelContent(DocumentNode blockNode) {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final nodeId = composer.selection!.base.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      return false;
    }

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        final paragraphPosition = composer.selection!.extent.nodePosition as TextNodePosition;
        final endOfParagraph = node.endPosition;

        DocumentSelection newSelection;
        if (node.text.text.isEmpty) {
          // Convert empty paragraph to block item.
          transaction.replaceNode(oldNode: node, newNode: blockNode);

          newSelection = DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: blockNode.endPosition,
            ),
          );
        } else if (paragraphPosition == endOfParagraph) {
          // Insert block item after the paragraph.
          transaction.insertNodeAfter(existingNode: node, newNode: blockNode);

          newSelection = DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: blockNode.endPosition,
            ),
          );
        } else {
          // Split the paragraph and inset image in between.
          final textBefore = node.text.copyText(0, paragraphPosition.offset);
          final textAfter = node.text.copyText(paragraphPosition.offset);

          final newParagraph = ParagraphNode(id: DocumentEditor.createNodeId(), text: textAfter);

          // TODO: node operations need to be a part of a transaction, somehow.
          node.text = textBefore;
          transaction
            ..insertNodeAfter(existingNode: node, newNode: blockNode)
            ..insertNodeAfter(existingNode: blockNode, newNode: newParagraph);

          newSelection = DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: newParagraph.beginningPosition,
            ),
          );
        }

        composer.selection = newSelection;
      }),
    );

    return true;
  }

  /// Indents the list item at the current selection extent, if the entire
  /// selection sits within a [ListItemNode].
  ///
  /// Returns [true] if a list item was indented. Returns [false] if
  /// the selection extent did not sit in a list item, or if the selection
  /// included more than just a list item.
  bool indentListItem() {
    if (composer.selection == null) {
      return false;
    }

    final baseNode = editor.document.getNodeById(composer.selection!.base.nodeId);
    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (baseNode is! ListItemNode || extentNode is! ListItemNode) {
      return false;
    }

    editor.executeCommand(
      IndentListItemCommand(nodeId: extentNode.id),
    );

    return true;
  }

  /// Indents the list item at the current selection extent, if the entire
  /// selection sits within a [ListItemNode].
  ///
  /// If the list item is not indented, the list item is converted to
  /// a [ParagraphNode].
  ///
  /// Returns [true] if a list item was un-indented. Returns [false] if
  /// the selection extent did not sit in a list item, or if the selection
  /// included more than just a list item.
  bool unindentListItem() {
    if (composer.selection == null) {
      return false;
    }

    final baseNode = editor.document.getNodeById(composer.selection!.base.nodeId);
    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId);
    if (baseNode!.id != extentNode!.id) {
      return false;
    }

    if (baseNode is! ListItemNode) {
      return false;
    }

    editor.executeCommand(
      UnIndentListItemCommand(nodeId: extentNode.id),
    );

    return true;
  }

  /// Converts the [TextNode] with the current [DocumentComposer] selection
  /// extent to a [ListItemNode] of the given [type], or does nothing if the
  /// current node is not a [TextNode], or if the current selection spans
  /// more than one node.
  ///
  /// Returns [true] if the selected node was converted to a [ListItemNode],
  /// or [false] if it wasn't.
  bool convertToListItem(ListItemType type, AttributedText text) {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final nodeId = composer.selection!.base.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node is! TextNode) {
      return false;
    }

    final newNode = ListItemNode(id: nodeId, itemType: type, text: text);

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction.replaceNode(oldNode: node, newNode: newNode);
      }),
    );

    return true;
  }

  /// Converts the [TextNode] with the current [DocumentComposer] selection
  /// extent to a [Paragraph] with a blockquote block type, or does nothing
  /// if the current node is not a [TextNode], or if the current selection
  /// spans more than one node.
  ///
  /// Returns [true] if the selected node was converted to a blockquote,
  /// or [false] if it wasn't.
  bool convertToBlockquote(AttributedText text) {
    if (composer.selection == null) {
      return false;
    }
    if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
      return false;
    }

    final nodeId = composer.selection!.base.nodeId;
    final node = editor.document.getNodeById(nodeId);
    if (node is! TextNode) {
      return false;
    }

    final newNode = ParagraphNode(id: nodeId, metadata: {'blockType': blockquoteAttribution}, text: text);

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction.replaceNode(oldNode: node, newNode: newNode);
      }),
    );

    return true;
  }

  /// Converts the [TextNode] with the current [DocumentComposer] selection
  /// extent to a [Paragraph], or does nothing if the current node is not
  /// a [TextNode], or if the current selection spans more than one node.
  ///
  /// Returns [true] if the selected node was converted to a [ParagraphNode],
  /// or [false] if it wasn't.
  bool convertToParagraph({
    Map<String, Attribution>? newMetadata,
  }) {
    if (composer.selection == null) {
      return false;
    }

    final baseNode = editor.document.getNodeById(composer.selection!.base.nodeId)!;
    final extentNode = editor.document.getNodeById(composer.selection!.extent.nodeId)!;
    if (baseNode.id != extentNode.id) {
      return false;
    }
    if (extentNode is! TextNode) {
      return false;
    }
    if (extentNode is ParagraphNode && extentNode.hasMetadataValue('blockType')) {
      // This content is already a regular paragraph.
      return false;
    }

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        if (extentNode is ParagraphNode) {
          extentNode.putMetadataValue('blockType', null);
          // TODO: find a way to alter nodes that automatically notifies listeners
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          extentNode.notifyListeners();
        } else {
          final newParagraphNode = ParagraphNode(
            id: extentNode.id,
            text: extentNode.text,
            metadata: newMetadata,
          );

          transaction.replaceNode(oldNode: extentNode, newNode: newParagraphNode);
        }
      }),
    );

    return true;
  }

  bool _isTextEntryNode({
    required Document document,
    required DocumentSelection selection,
  }) {
    final extentPosition = selection.extent;
    final extentNode = document.getNodeById(extentPosition.nodeId);
    return extentNode is TextNode;
  }

  /// Serializes the current selection to plain text, and adds it to the
  /// clipboard.
  void copy() {
    final textToCopy = _textInSelection(
      document: editor.document,
      documentSelection: composer.selection!,
    );
    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    _saveToClipboard(textToCopy);
  }

  /// Serializes the current selection to plain text, adds it to the
  /// clipboard, and then deletes the selected content.
  void cut() {
    final textToCut = _textInSelection(
      document: editor.document,
      documentSelection: composer.selection!,
    );
    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    _saveToClipboard(textToCut);

    deleteSelection();
  }

  Future<void> _saveToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  String _textInSelection({
    required Document document,
    required DocumentSelection documentSelection,
  }) {
    final selectedNodes = document.getNodesInside(
      documentSelection.base,
      documentSelection.extent,
    );

    final buffer = StringBuffer();
    for (int i = 0; i < selectedNodes.length; ++i) {
      final selectedNode = selectedNodes[i];
      dynamic nodeSelection;

      if (i == 0) {
        // This is the first node and it may be partially selected.
        final baseSelectionPosition = selectedNode.id == documentSelection.base.nodeId
            ? documentSelection.base.nodePosition
            : documentSelection.extent.nodePosition;

        final extentSelectionPosition =
            selectedNodes.length > 1 ? selectedNode.endPosition : documentSelection.extent.nodePosition;

        nodeSelection = selectedNode.computeSelection(
          base: baseSelectionPosition,
          extent: extentSelectionPosition,
        );
      } else if (i == selectedNodes.length - 1) {
        // This is the last node and it may be partially selected.
        final nodePosition = selectedNode.id == documentSelection.base.nodeId
            ? documentSelection.base.nodePosition
            : documentSelection.extent.nodePosition;

        nodeSelection = selectedNode.computeSelection(
          base: selectedNode.beginningPosition,
          extent: nodePosition,
        );
      } else {
        // This node is fully selected. Copy the whole thing.
        nodeSelection = selectedNode.computeSelection(
          base: selectedNode.beginningPosition,
          extent: selectedNode.endPosition,
        );
      }

      final nodeContent = selectedNode.copyContent(nodeSelection);
      if (nodeContent != null) {
        buffer.write(nodeContent);
        if (i < selectedNodes.length - 1) {
          buffer.writeln();
        }
      }
    }
    return buffer.toString();
  }

  /// Deletes all selected content, and then pastes the current clipboard
  /// content at the given location.
  ///
  /// The clipboard operation is asynchronous. As a result, if the user quickly
  /// moves the caret, it's possible that the clipboard content will be pasted
  /// at the wrong spot.
  void paste() {
    DocumentPosition pastePosition = composer.selection!.extent;

    // Delete all currently selected content.
    if (!composer.selection!.isCollapsed) {
      pastePosition = CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
        document: editor.document,
        selection: composer.selection!,
      );

      // Delete the selected content.
      editor.executeCommand(
        DeleteSelectionCommand(documentSelection: composer.selection!),
      );

      composer.selection = DocumentSelection.collapsed(position: pastePosition);
    }

    // TODO: figure out a general approach for asynchronous behaviors that
    //       need to be carried out in response to user input.
    _paste(
      document: editor.document,
      editor: editor,
      composer: composer,
      pastePosition: pastePosition,
    );
  }

  Future<void> _paste({
    required Document document,
    required DocumentEditor editor,
    required DocumentComposer composer,
    required DocumentPosition pastePosition,
  }) async {
    final content = (await Clipboard.getData('text/plain'))?.text ?? '';

    editor.executeCommand(
      _PasteEditorCommand(
        content: content,
        pastePosition: pastePosition,
        composer: composer,
      ),
    );
  }
}

class _PasteEditorCommand implements EditorCommand {
  _PasteEditorCommand({
    required String content,
    required DocumentPosition pastePosition,
    required DocumentComposer composer,
  })  : _content = content,
        _pastePosition = pastePosition,
        _composer = composer;

  final String _content;
  final DocumentPosition _pastePosition;
  final DocumentComposer _composer;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final currentNodeWithSelection = document.getNodeById(_pastePosition.nodeId);
    if (currentNodeWithSelection is! ParagraphNode) {
      throw Exception('Can\'t handle pasting text within node of type: $currentNodeWithSelection');
    }

    editorOpsLog.info("Pasting clipboard content in document.");

    // Split the pasted content at newlines, and apply attributions based
    // on inspection of the pasted content, e.g., link attributions.
    final attributedLines = _inferAttributionsForLinesOfPastedText(_content);

    final textNode = document.getNode(_pastePosition) as TextNode;
    final pasteTextOffset = (_pastePosition.nodePosition as TextPosition).offset;

    if (attributedLines.length > 1 && pasteTextOffset < textNode.endPosition.offset) {
      // There is more than 1 node of content being pasted. Therefore,
      // new nodes will need to be added, which means that the currently
      // selected text node will be split at the current text offset.
      // Configure a new node to be added at the end of the pasted content
      // which contains the trailing text from the currently selected
      // node.
      SplitParagraphCommand(
        nodeId: currentNodeWithSelection.id,
        splitPosition: TextPosition(offset: pasteTextOffset),
        newNodeId: DocumentEditor.createNodeId(),
        replicateExistingMetadata: true,
      ).execute(document, transaction);
    }

    // Paste the first piece of attributed content into the selected TextNode.
    InsertAttributedTextCommand(
      documentPosition: _pastePosition,
      textToInsert: attributedLines.first,
    ).execute(document, transaction);

    // The first line of pasted text was added to the selected paragraph.
    // Now, create new nodes for each additional line of pasted text and
    // insert those nodes.
    final pastedContentNodes = _convertLinesToParagraphs(attributedLines.sublist(1));
    DocumentNode previousNode = currentNodeWithSelection;
    for (final pastedNode in pastedContentNodes) {
      transaction.insertNodeAfter(
        existingNode: previousNode,
        newNode: pastedNode,
      );
      previousNode = pastedNode;
    }

    // Place the caret at the end of the pasted content.
    _composer.selection = DocumentSelection.collapsed(
      position: pastedContentNodes.isNotEmpty
          ? DocumentPosition(
              nodeId: previousNode.id,
              nodePosition: previousNode.endPosition,
            )
          : DocumentPosition(
              nodeId: currentNodeWithSelection.id,
              nodePosition: TextNodePosition(
                offset: pasteTextOffset + attributedLines.first.text.length,
              ),
            ),
    );
    editorOpsLog.fine('New selection after paste operation: ${_composer.selection}');

    editorOpsLog.fine('Done with paste command.');
  }

  /// Breaks the given [content] at each newline, then applies any inferred
  /// attributions based on content analysis, e.g., surrounds URLs with
  /// [LinkAttribution]s.
  List<AttributedText> _inferAttributionsForLinesOfPastedText(String content) {
    // Split the pasted content by newlines, because each new line of content
    // needs to placed in its own ParagraphNode.
    final lines = content.split('\n\n');
    editorOpsLog.fine("Breaking pasted content into lines and adding attributions:");
    editorOpsLog.fine("Lines of content:");
    for (final line in lines) {
      editorOpsLog.fine(' - "$line"');
    }

    final attributedLines = <AttributedText>[];
    for (final line in lines) {
      attributedLines.add(
        AttributedText(
          text: line,
          spans: _findUrlSpansInText(pastedText: lines.first),
        ),
      );
    }
    return attributedLines;
  }

  /// Finds all URLs in the [pastedText] and returns an [AttributedSpans], which
  /// contains [LinkAttribution]s that span each URL.
  AttributedSpans _findUrlSpansInText({required String pastedText}) {
    final AttributedSpans linkAttributionSpans = AttributedSpans();

    final wordBoundaries = pastedText.calculateAllWordBoundaries();

    for (final wordBoundary in wordBoundaries) {
      final word = wordBoundary.textInside(pastedText);
      final link = Uri.tryParse(word);

      if (link != null && link.hasScheme && link.hasAuthority) {
        // Valid url. Apply [LinkAttribution] to the url
        final linkAttribution = LinkAttribution(url: link);

        final startOffset = wordBoundary.start;
        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        final endOffset = wordBoundary.end - 1;

        // Add link attribution.
        linkAttributionSpans.addAttribution(
          newAttribution: linkAttribution,
          start: startOffset,
          end: endOffset,
        );
      }
    }

    return linkAttributionSpans;
  }

  Iterable<ParagraphNode> _convertLinesToParagraphs(Iterable<AttributedText> attributedLines) {
    return attributedLines.map(
      // TODO: create nodes based on content inspection (e.g., image, list item).
      (pastedLine) => ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: pastedLine,
      ),
    );
  }
}
