import 'dart:math';

import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/composition/document_composer.dart';
import '../core/document/rich_text_document.dart';
import '../core/selection/editor_selection.dart';
import '_text_tools.dart';
import 'multi_node_editing.dart';
import 'paragraph.dart';
import 'text.dart';

// TODO: restricting what the user can do probably makes sense after an
//       action takes place, but before the action is applied, e.g. by
//       inspecting an event-sourced change before applying it to the doc.
//
//       or, consider a post-edit action that "heals" the document.
ExecutionInstruction preventDeletionOfFirstParagraph({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.document.nodes.length < 2) {
    // We are already in a bad state. Let the user do whatever.
    print('WARNING: Cannot prevent deletion of 1st paragraph because it doesn\'t exist.');
    return ExecutionInstruction.continueExecution;
  }

  final nodeSelections = composerContext.documentLayout.computeNodeSelections(
    selection: composerContext.currentSelection.value,
  );
  final titleNode = composerContext.document.nodes.first;
  final titleSelection = nodeSelections.firstWhere((element) => element.nodeId == titleNode.id, orElse: () => null);

  final firstParagraphNode = composerContext.document.nodes[1];
  final firstParagraphSelection =
      nodeSelections.firstWhere((element) => element.nodeId == firstParagraphNode.id, orElse: () => null);

  if (titleSelection == null && firstParagraphSelection == null) {
    // Title isn't selected, nor is the first paragraph. Whatever the
    // user is doing won't effect the title.
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.currentSelection.value.isCollapsed) {
    if (composerContext.document.nodes.length > 2) {
      // With more than 2 nodes, and a collapsed selection, no
      // matter what the user does, there will be at least 2 nodes
      // remaining. So we don't care.
      return ExecutionInstruction.continueExecution;
    }

    // With a collapsed selection, the only possible situations we
    // care about are:
    //
    // 1. The user pressed delete at the end of the title node, which
    //    would normally pull the first paragraph up into the title.
    //
    // 2. The user pressed backspace at the beginning of the first
    //    paragraph, which will combine it with the title, and there
    //    are no paragraphs after the first one.
    final title = (titleNode as TextNode).text;
    if (titleSelection != null &&
        (titleSelection.nodeSelection as TextSelection).extentOffset == title.text.length &&
        keyEvent.logicalKey == LogicalKeyboardKey.delete) {
      // Prevent this operation.
      return ExecutionInstruction.haltExecution;
    }

    if (firstParagraphSelection != null &&
        (firstParagraphSelection.nodeSelection as TextSelection).extentOffset == 0 &&
        keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      // Prevent this operation.
      return ExecutionInstruction.haltExecution;
    }

    // We don't care about this interaction.
    return ExecutionInstruction.continueExecution;
  } else {
    // With an expanded selection, the only deletion that's a concern is
    // one that selects all but one node.
    if (nodeSelections.length < composerContext.document.nodes.length) {
      return ExecutionInstruction.continueExecution;
    }

    // This is a selection that covers all but one node. If this
    // key would result in a deletion, and that deletion fully removes
    // at least n-1 nodes, then we should prevent the operation.
    if (keyEvent.logicalKey == LogicalKeyboardKey.backspace ||
        keyEvent.logicalKey == LogicalKeyboardKey.delete ||
        isCharacterKey(keyEvent.logicalKey)) {
      // This event will cause a deletion. If it will delete too many nodes
      // then we need to prevent the operation.
      final fullySelectedNodeCount = nodeSelections.fold(0, (previousValue, element) {
        final textSelection = element.nodeSelection as TextSelection;
        final paragraphNode = composerContext.document.getNodeById(element.nodeId) as TextNode;

        // If there is no TextSelection then this isn't a ParagraphNode
        // and we don't know how to count it. We know it's selected, but
        // we don't know what the selection means. Assume its fully selected.
        if (textSelection == null || paragraphNode == null) {
          return previousValue + 1;
        }

        if (textSelection.start == 0 && textSelection.end == paragraphNode.text.text.length) {
          // The entire paragraph is selected. +1.
          return previousValue + 1;
        }

        return previousValue;
      });

      if (fullySelectedNodeCount >= composerContext.document.nodes.length - 1) {
        // Prevent this operation.
        return ExecutionInstruction.haltExecution;
      } else {
        // Allow this operation.
        return ExecutionInstruction.continueExecution;
      }
    }

    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction doNothingWhenThereIsNoSelection({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (composerContext.currentSelection.value == null) {
    print(' - no selection. Returning.');
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction collapseSelectionWhenDirectionalKeyIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  final isDirectionalKey = keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowUp ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowDown;
  print(' - is directional key? $isDirectionalKey');
  print(' - is editor selection collapsed? ${composerContext.currentSelection.value.isCollapsed}');
  print(' - is shift pressed? ${keyEvent.isShiftPressed}');
  if (isDirectionalKey &&
      !composerContext.currentSelection.value.isCollapsed &&
      !keyEvent.isShiftPressed &&
      !keyEvent.isMetaPressed) {
    print('Collapsing editor selection, then returning.');
    composerContext.currentSelection.value = composerContext.currentSelection.value.collapse();

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction applyBoldWhenCmdBIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.character?.toLowerCase() != 'b' || !keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.currentSelection.value.isCollapsed) {
    composerContext.composerPreferences.toggleStyle('bold');
    return ExecutionInstruction.haltExecution;
  }

  // Toggle the selected content with a bold attribution.
  composerContext.editor.executeCommand(
    ToggleTextAttributionsCommand(
      documentSelection: composerContext.currentSelection.value,
      attributions: {'bold'},
    ),
  );

  composerContext.currentSelection.notifyListeners();

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction applyItalicsWhenCmdIIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.character?.toLowerCase() != 'i' || !keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.currentSelection.value.isCollapsed) {
    composerContext.composerPreferences.toggleStyle('italics');
    return ExecutionInstruction.haltExecution;
  }

  // Toggle the selected content with a bold attribution.
  composerContext.editor.executeCommand(
    ToggleTextAttributionsCommand(
      documentSelection: composerContext.currentSelection.value,
      attributions: {'italics'},
    ),
  );

  composerContext.currentSelection.notifyListeners();

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
// Handle delete and backspace for a selection.
// TODO: add all characters to this condition.
  final isDestructiveKey =
      keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
  final shouldDeleteSelection = isDestructiveKey || isCharacterKey(keyEvent.logicalKey);

  if (composerContext.currentSelection.value.isCollapsed || !shouldDeleteSelection) {
    return ExecutionInstruction.continueExecution;
  }

  // Figure out where the caret should appear after the
  // deletion.
  // TODO: This calculation depends upon the first
  // selected node still existing after the deletion. This
  // is a fragile expectation and should be revisited.
  final basePosition = composerContext.currentSelection.value.base;
  final baseNode = composerContext.document.getNode(basePosition);
  final baseNodeIndex = composerContext.document.getNodeIndex(baseNode);

  final extentPosition = composerContext.currentSelection.value.extent;
  final extentNode = composerContext.document.getNode(extentPosition);
  final extentNodeIndex = composerContext.document.getNodeIndex(extentNode);
  DocumentPosition newSelectionPosition;

  if (baseNodeIndex != extentNodeIndex) {
    // Place the caret at the current position within the
    // first node in the selection.
    newSelectionPosition = baseNodeIndex <= extentNodeIndex
        ? composerContext.currentSelection.value.base
        : composerContext.currentSelection.value.extent;

    // If it's a binary selection node then that node will
    // be replaced by a ParagraphNode with the same ID.
    if (newSelectionPosition.nodePosition is BinaryPosition) {
      // Assume that the node was replaced with an empty paragraph.
      newSelectionPosition = DocumentPosition(
        nodeId: newSelectionPosition.nodeId,
        nodePosition: TextPosition(offset: 0),
      );
    }
  } else {
    // Selection is within a single node. If it's a binary
    // selection node then that node will be replaced by
    // a ParagraphNode with the same ID. Otherwise, it must
    // be a TextNode, in which case we need to figure out
    // which DocumentPosition contains the earlier TextPosition.
    if (basePosition.nodePosition is BinaryPosition) {
      // Assume that the node was replace with an empty paragraph.
      newSelectionPosition = DocumentPosition(
        nodeId: baseNode.id,
        nodePosition: TextPosition(offset: 0),
      );
    } else if (basePosition.nodePosition is TextPosition) {
      final baseOffset = (basePosition.nodePosition as TextPosition).offset;
      final extentOffset = (extentPosition.nodePosition as TextPosition).offset;

      newSelectionPosition = DocumentPosition(
        nodeId: baseNode.id,
        nodePosition: TextPosition(offset: min(baseOffset, extentOffset)),
      );
    } else {
      throw Exception(
          'Unknown selection position type: $basePosition, for node: $baseNode, within document selection: ${composerContext.currentSelection.value}');
    }
  }

  // Delete the selected content.
  composerContext.editor.executeCommand(
    DeleteSelectionCommand(documentSelection: composerContext.currentSelection.value),
  );

  print(' - new document selection position: ${newSelectionPosition.nodePosition}');
  composerContext.currentSelection.value = DocumentSelection.collapsed(position: newSelectionPosition);

  return isDestructiveKey ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction mergeNodeWithPreviousWhenBackspaceIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot merge node of type: $node into node above.');
    return ExecutionInstruction.continueExecution;
  }

  print('All nodes in order:');
  composerContext.document.nodes.forEach((aNode) {
    print(' - node: ${aNode.id}');
  });
  print('Looking for node above: ${node.id}');
  final nodeAbove = composerContext.document.getNodeBefore(node);
  if (nodeAbove == null) {
    print('At top of document. Cannot merge with node above.');
    return ExecutionInstruction.continueExecution;
  }
  if (nodeAbove is! TextNode) {
    print('Cannot merge ParagraphNode into node of type: $nodeAbove');
    return ExecutionInstruction.continueExecution;
  }

  final paragraphNodeAbove = nodeAbove as TextNode;
  final aboveParagraphLength = paragraphNodeAbove.text.text.length;

  // Send edit command.
  composerContext.editor.executeCommand(
    CombineParagraphsCommand(
      firstNodeId: nodeAbove.id,
      secondNodeId: node.id,
    ),
  );

  // Place the cursor at the point where the text came together.
  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeAbove.id,
      nodePosition: TextPosition(offset: aboveParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction mergeNodeWithNextWhenDeleteIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot combine node of type: $node');
    return ExecutionInstruction.continueExecution;
  }
  final paragraphNode = node as TextNode;

  final nodeBelow = composerContext.document.getNodeAfter(paragraphNode);
  if (nodeBelow == null) {
    print('At bottom of document. Cannot merge with node above.');
    return ExecutionInstruction.continueExecution;
  }
  if (nodeBelow is! TextNode) {
    print('Cannot merge ParagraphNode into node of type: $nodeBelow');
    return ExecutionInstruction.continueExecution;
  }

  print('Combining node with next.');
  final currentParagraphLength = paragraphNode.text.text.length;

  // Send edit command.
  composerContext.editor.executeCommand(
    CombineParagraphsCommand(
      firstNodeId: node.id,
      secondNodeId: nodeBelow.id,
    ),
  );

  // Place the cursor at the point where the text came together.
  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: paragraphNode.id,
      nodePosition: TextPosition(offset: currentParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction moveUpDownLeftAndRightWithArrowKeys({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  const arrowKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ];
  if (!arrowKeys.contains(keyEvent.logicalKey)) {
    return ExecutionInstruction.continueExecution;
  }
  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
    print(' - handling left arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      composerContext: composerContext,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: true,
      movementModifiers: movementModifiers,
    );

    // if (keyEvent.isMetaPressed) {
    //   moveToStartOfLine(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     nodeSelections: composerContext.nodeSelections,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // } else if (keyEvent.isAltPressed) {
    //   moveBackOneWord(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // } else {
    //   moveBackOneCharacter(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    print(' - handling right arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      composerContext: composerContext,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: false,
      movementModifiers: movementModifiers,
    );

    // if (keyEvent.isMetaPressed) {
    //   moveToEndOfLine(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     nodeSelections: composerContext.nodeSelections,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // } else if (keyEvent.isAltPressed) {
    //   moveForwardOneWord(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // } else {
    //   moveForwardOneCharacter(
    //     document: composerContext.document,
    //     documentLayout: composerContext.documentLayout,
    //     currentSelection: composerContext.currentSelection,
    //     expandSelection: keyEvent.isShiftPressed,
    //   );
    // }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    print(' - handling up arrow key');
    _moveVertically(
      composerContext: composerContext,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: true,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    print(' - handling down arrow key');
    _moveVertically(
      composerContext: composerContext,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: false,
    );
  }

  return ExecutionInstruction.haltExecution;
}

void _moveHorizontally({
  @required ComposerContext composerContext,
  @required bool expandSelection,
  @required bool moveLeft,
  Map<String, dynamic> movementModifiers,
}) {
  final currentExtent = composerContext.currentSelection.value.extent;
  final nodeId = currentExtent.nodeId;
  final node = composerContext.document.getNodeById(nodeId);
  final extentComponent = composerContext.documentLayout.getComponentByNodeId(nodeId);

  String newExtentNodeId = nodeId;
  dynamic newExtentNodePosition = moveLeft
      ? extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifiers)
      : extentComponent.movePositionRight(currentExtent.nodePosition, movementModifiers);

  if (newExtentNodePosition == null) {
    print(' - moving to next node');
    // Move to next node
    final nextNode =
        moveLeft ? composerContext.document.getNodeBefore(node) : composerContext.document.getNodeAfter(node);

    if (nextNode == null) {
      // We're at the beginning/end of the document and can't go
      // anywhere.
      return;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = composerContext.documentLayout.getComponentByNodeId(nextNode.id);
    newExtentNodePosition = moveLeft ? nextComponent.getEndPosition() : nextComponent.getBeginningPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  if (expandSelection) {
    // Selection should be expanded.
    composerContext.currentSelection.value = composerContext.currentSelection.value.expandTo(
      newExtent,
    );
  } else {
    // Selection should be replaced by new collapsed position.
    composerContext.currentSelection.value = DocumentSelection.collapsed(
      position: newExtent,
    );
  }
}

void _moveVertically({
  @required ComposerContext composerContext,
  @required bool expandSelection,
  @required bool moveUp,
}) {
  final currentExtent = composerContext.currentSelection.value.extent;
  final nodeId = currentExtent.nodeId;
  final node = composerContext.document.getNodeById(nodeId);
  final extentComponent = composerContext.documentLayout.getComponentByNodeId(nodeId);

  String newExtentNodeId = nodeId;
  dynamic newExtentNodePosition = moveUp
      ? extentComponent.movePositionUp(currentExtent.nodePosition)
      : extentComponent.movePositionDown(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    print(' - moving to next node');
    // Move to next node
    final nextNode =
        moveUp ? composerContext.document.getNodeBefore(node) : composerContext.document.getNodeAfter(node);
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = composerContext.documentLayout.getComponentByNodeId(nextNode.id);
      final offsetToMatch = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
      print(' - offset to match');

      if (offsetToMatch == null) {
        // No (x,y) offset was provided. Place the selection at the
        // beginning or end of the node, depending on direction.
        newExtentNodePosition = moveUp ? nextComponent.getEndPosition() : nextComponent.getBeginningPosition();
      } else {
        // An (x,y) offset was provided. Place the selection as close
        // to the given x-value as possible within the node.
        newExtentNodePosition = moveUp
            ? nextComponent.getEndPositionNearX(offsetToMatch.dx)
            : nextComponent.getBeginningPositionNearX(offsetToMatch.dx);
      }
    } else {
      print(' - there is no next node. Ignoring.');
      // We're at the top/bottom of the document. Move the cursor to the
      // beginning/end of the current node.
      newExtentNodePosition = moveUp ? extentComponent.getBeginningPosition() : extentComponent.getEndPosition();
    }
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  if (expandSelection) {
    // Selection should be expanded.
    composerContext.currentSelection.value = composerContext.currentSelection.value.expandTo(
      newExtent,
    );
  } else {
    // Selection should be replaced by new collapsed position.
    composerContext.currentSelection.value = DocumentSelection.collapsed(
      position: newExtent,
    );
  }
}

TextSelection moveSelectionToEnd({
  @required String text,
  TextSelection previousSelection,
  bool expandSelection = false,
}) {
  if (previousSelection != null && expandSelection) {
    return TextSelection(
      baseOffset: expandSelection ? previousSelection.baseOffset : text.length,
      extentOffset: text.length,
    );
  } else {
    return TextSelection.collapsed(
      offset: text.length,
    );
  }
}
