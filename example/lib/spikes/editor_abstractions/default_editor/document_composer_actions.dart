import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/composition/document_composer.dart';
import '../core/document/rich_text_document.dart';
import '../core/selection/editor_selection.dart';
import '_text_tools.dart';
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

  final titleNode = composerContext.document.nodes.first;
  final titleSelection =
      composerContext.nodeSelections.firstWhere((element) => element.nodeId == titleNode.id, orElse: () => null);

  final firstParagraphNode = composerContext.document.nodes[1];
  final firstParagraphSelection = composerContext.nodeSelections
      .firstWhere((element) => element.nodeId == firstParagraphNode.id, orElse: () => null);

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
    if (composerContext.nodeSelections.length < composerContext.document.nodes.length) {
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
      final fullySelectedNodeCount = composerContext.nodeSelections.fold(0, (previousValue, element) {
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
  if (keyEvent.character?.toLowerCase() == 'b' && keyEvent.isMetaPressed) {
    if (composerContext.currentSelection.value.isCollapsed) {
      composerContext.composerPreferences.toggleStyle('bold');
      return ExecutionInstruction.haltExecution;
    }

    for (final nodeSelection in composerContext.nodeSelections) {
      final node = composerContext.document.getNodeById(nodeSelection.nodeId);
      if (node is TextNode) {
        final textSelection = nodeSelection.nodeSelection as TextSelection;
        // -1 on `end` because text selection uses an exclusive `end` but
        // attributions use inclusive `end`.
        final textRange = TextRange(start: textSelection.start, end: textSelection.end - 1);
        node.text.toggleAttribution('bold', textRange);

        // TODO: create an appropriate change notification mechanism
        //       instead of hijacking the current selection.
        //       The reason this action hijacks the selection is
        //       because selection doesn't change, and altering an
        //       attribution doesn't currently trigger a doc change event.
        composerContext.currentSelection.notifyListeners();
      }
    }

    return ExecutionInstruction.haltExecution;
  }
  return ExecutionInstruction.continueExecution;
}

ExecutionInstruction applyItalicsWhenCmdIIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.character?.toLowerCase() == 'i' && keyEvent.isMetaPressed) {
    if (composerContext.currentSelection.value.isCollapsed) {
      composerContext.composerPreferences.toggleStyle('italics');
      return ExecutionInstruction.haltExecution;
    }

    for (final nodeSelection in composerContext.nodeSelections) {
      final node = composerContext.document.getNodeById(nodeSelection.nodeId);
      if (node is TextNode) {
        final textSelection = nodeSelection.nodeSelection as TextSelection;
        // -1 on `end` because text selection uses an exclusive `end` but
        // attributions use inclusive `end`.
        final textRange = TextRange(start: textSelection.start, end: textSelection.end - 1);
        node.text.toggleAttribution('italics', textRange);

        // TODO: create an appropriate change notification mechanism
        //       instead of hijacking the current selection.
        //       The reason this action hijacks the selection is
        //       because selection doesn't change, and altering an
        //       attribution doesn't currently trigger a doc change event.
        composerContext.currentSelection.notifyListeners();
      }
    }

    return ExecutionInstruction.haltExecution;
  }
  return ExecutionInstruction.continueExecution;
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
  if (!composerContext.currentSelection.value.isCollapsed && shouldDeleteSelection) {
    composerContext.currentSelection.value = composerContext.editor.deleteSelection(
      document: composerContext.document,
      documentLayout: composerContext.documentLayout,
      selection: composerContext.currentSelection.value,
    );

    return isDestructiveKey ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  }
  return ExecutionInstruction.continueExecution;
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
  final paragraphNode = node as TextNode;

  final nodeAbove = composerContext.document.getNodeBefore(paragraphNode);
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

  // Combine the text and delete the currently selected node.
  paragraphNodeAbove.text = paragraphNodeAbove.text.copyAndAppend(paragraphNode.text);
  bool didRemove = composerContext.document.deleteNode(paragraphNode);
  if (!didRemove) {
    print('ERROR: Failed to delete the currently selected node from the document.');
  }

  // Place the cursor at the point where the text came together.
  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeAbove.id,
      nodePosition: TextPosition(offset: aboveParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction mergeNodeWithNextWhenBackspaceIsPressed({
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
  final paragraphNodeBelow = nodeBelow as TextNode;

  print('Combining node with next.');
  final currentParagraphLength = paragraphNode.text.text.length;

  // Combine the text and delete the currently selected node.
  paragraphNode.text.copyAndAppend(paragraphNodeBelow.text);
  final didRemove = composerContext.document.deleteNode(nodeBelow);
  if (!didRemove) {
    print('ERROR: failed to remove next node from document.');
  }

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

  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
    print(' - handling left arrow key');
    if (keyEvent.isMetaPressed) {
      moveToStartOfLine(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        nodeSelections: composerContext.nodeSelections,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.isAltPressed) {
      moveBackOneWord(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else {
      moveBackOneCharacter(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    print(' - handling right arrow key');
    if (keyEvent.isMetaPressed) {
      moveToEndOfLine(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        nodeSelections: composerContext.nodeSelections,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.isAltPressed) {
      moveForwardOneWord(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else {
      moveForwardOneCharacter(
        document: composerContext.document,
        documentLayout: composerContext.documentLayout,
        currentSelection: composerContext.currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    print(' - handling up arrow key');
    moveUpOneLine(
      document: composerContext.document,
      documentLayout: composerContext.documentLayout,
      currentSelection: composerContext.currentSelection,
      nodeSelections: composerContext.nodeSelections,
      expandSelection: keyEvent.isShiftPressed,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    print(' - handling down arrow key');
    moveDownOneLine(
      document: composerContext.document,
      documentLayout: composerContext.documentLayout,
      currentSelection: composerContext.currentSelection,
      nodeSelections: composerContext.nodeSelections,
      expandSelection: keyEvent.isShiftPressed,
    );
  }

  return ExecutionInstruction.haltExecution;
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
