import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../document/rich_text_document.dart';
import '../document/document_editor.dart';
import '../layout/document_layout.dart';
import '../selection/editor_selection.dart';

// TODO: should nodes be in core?
import '../document/document_nodes.dart';

// TODO: get rid of this import
import '../../selectable_text/selectable_text.dart';

class ComposerKeyboardAction {
  const ComposerKeyboardAction.simple({
    @required SimpleComposerKeyboardAction action,
  }) : _action = action;

  final SimpleComposerKeyboardAction _action;

  /// Executes this action, if the action wants to run, and returns
  /// a desired `ExecutionInstruction` to either continue or halt
  /// execution of actions.
  ///
  /// It is possible that an action makes changes and then returns
  /// `ExecutionInstruction.continueExecution` to continue execution.
  ///
  /// It is possible that an action does nothing and then returns
  /// `ExecutionInstruction.haltExecution` to prevent further execution.
  ExecutionInstruction execute({
    @required RichTextDocument document,
    @required DocumentEditor editor,
    @required DocumentLayoutState documentLayout,
    @required ValueNotifier<DocumentSelection> currentSelection,
    @required List<DocumentNodeSelection> nodeSelections,
    @required RawKeyEvent keyEvent,
  }) {
    return _action(
      document: document,
      editor: editor,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      nodeSelections: nodeSelections,
      keyEvent: keyEvent,
    );
  }
}

/// Executes an action, if the action wants to run, and returns
/// `true` if further execution should stop, or `false` if further
/// execution should continue.
///
/// It is possible that an action makes changes and then returns
/// `false` to continue execution.
///
/// It is possible that an action does nothing and then returns
/// `true` to prevent further execution.
typedef SimpleComposerKeyboardAction = ExecutionInstruction Function({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
});

enum ExecutionInstruction {
  continueExecution,
  haltExecution,
}

// TODO: restricting what the user can do probably makes sense after an
//       action takes place, but before the action is applied, e.g. by
//       inspecting an event-sourced change before applying it to the doc.
//
//       or, consider a post-edit action that "heals" the document.
ExecutionInstruction preventDeletionOfFirstParagraph({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (document.nodes.length < 2) {
    // We are already in a bad state. Let the user do whatever.
    print('WARNING: Cannot prevent deletion of 1st paragraph because it doesn\'t exist.');
    return ExecutionInstruction.continueExecution;
  }

  final titleNode = document.nodes.first;
  final titleSelection = nodeSelections.firstWhere((element) => element.nodeId == titleNode.id, orElse: () => null);

  final firstParagraphNode = document.nodes[1];
  final firstParagraphSelection =
      nodeSelections.firstWhere((element) => element.nodeId == firstParagraphNode.id, orElse: () => null);

  if (titleSelection == null && firstParagraphSelection == null) {
    // Title isn't selected, nor is the first paragraph. Whatever the
    // user is doing won't effect the title.
    return ExecutionInstruction.continueExecution;
  }

  if (currentSelection.value.isCollapsed) {
    if (document.nodes.length > 2) {
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
        (titleSelection.nodeSelection as TextSelection).extentOffset == title.length &&
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
    if (nodeSelections.length < document.nodes.length) {
      return ExecutionInstruction.continueExecution;
    }

    // This is a selection that covers all but one node. If this
    // key would result in a deletion, and that deletion fully removes
    // at least n-1 nodes, then we should prevent the operation.
    if (keyEvent.logicalKey == LogicalKeyboardKey.backspace ||
        keyEvent.logicalKey == LogicalKeyboardKey.delete ||
        _isCharacterKey(keyEvent.logicalKey)) {
      // This event will cause a deletion. If it will delete too many nodes
      // then we need to prevent the operation.
      final fullySelectedNodeCount = nodeSelections.fold(0, (previousValue, element) {
        final textSelection = element.nodeSelection as TextSelection;
        final paragraphNode = document.getNodeById(element.nodeId) as TextNode;

        // If there is no TextSelection then this isn't a ParagraphNode
        // and we don't know how to count it. We know it's selected, but
        // we don't know what the selection means. Assume its fully selected.
        if (textSelection == null || paragraphNode == null) {
          return previousValue + 1;
        }

        if (textSelection.start == 0 && textSelection.end == paragraphNode.text.length) {
          // The entire paragraph is selected. +1.
          return previousValue + 1;
        }

        return previousValue;
      });

      if (fullySelectedNodeCount >= document.nodes.length - 1) {
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
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (currentSelection.value == null) {
    print(' - no selection. Returning.');
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction collapseSelectionWhenDirectionalKeyIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  final isDirectionalKey = keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowUp ||
      keyEvent.logicalKey == LogicalKeyboardKey.arrowDown;
  print(' - is directional key? $isDirectionalKey');
  print(' - is editor selection collapsed? ${currentSelection.value.isCollapsed}');
  print(' - is shift pressed? ${keyEvent.isShiftPressed}');
  if (isDirectionalKey && !currentSelection.value.isCollapsed && !keyEvent.isShiftPressed && !keyEvent.isMetaPressed) {
    print('Collapsing editor selection, then returning.');
    currentSelection.value = currentSelection.value.collapse();
    return ExecutionInstruction.haltExecution;
  } else {
    print('Selection is collapsed. Letting directional key move to another composer action.');
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
// Handle delete and backspace for a selection.
// TODO: add all characters to this condition.
  final isDestructiveKey =
      keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
  final shouldDeleteSelection = isDestructiveKey || _isCharacterKey(keyEvent.logicalKey);
  if (!currentSelection.value.isCollapsed && shouldDeleteSelection) {
    currentSelection.value = editor.deleteSelection(
      document: document,
      selection: currentSelection.value,
    );
    ;

    return isDestructiveKey ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
  }
  return ExecutionInstruction.continueExecution;
}

ExecutionInstruction insertCharacterInParagraph({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (_isTextEntryNode(document: document, selection: currentSelection) &&
      _isCharacterKey(keyEvent.logicalKey) &&
      currentSelection.value.isCollapsed) {
    currentSelection.value = editor.addCharacter(
      document: document,
      position: currentSelection.value.extent,
      character: keyEvent.character,
    );
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction insertNewlineInParagraph({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (_isTextEntryNode(document: document, selection: currentSelection) &&
      keyEvent.logicalKey == LogicalKeyboardKey.enter &&
      keyEvent.isShiftPressed &&
      currentSelection.value.isCollapsed) {
    currentSelection.value = editor.addCharacter(
      document: document,
      position: currentSelection.value.extent,
      character: '\n',
    );
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction splitParagraphWhenEnterPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (_isTextEntryNode(document: document, selection: currentSelection) &&
      keyEvent.logicalKey == LogicalKeyboardKey.enter &&
      currentSelection.value.isCollapsed) {
    final node = document.getNodeById(currentSelection.value.extent.nodeId);
    if (node is! TextNode) {
      print('WARNING: Cannot split node of type: $node');
      return ExecutionInstruction.continueExecution;
    }
    final paragraphNode = node as TextNode;

    final text = paragraphNode.text;
    final caretIndex = (currentSelection.value.extent.nodePosition as TextPosition).offset;
    final startText = text.substring(0, caretIndex);
    final endText = caretIndex < text.length ? text.substring(caretIndex) : '';
    print('Splitting paragraph:');
    print(' - start text: "$startText"');
    print(' - end text: "$endText"');

    // Change the current nodes content to just the text before the caret.
    paragraphNode.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = TextNode(
      id: RichTextDocument.createNodeId(),
      text: endText,
    );

    // Insert the new node after the current node.
    document.insertNodeAfter(
      previousNode: paragraphNode,
      newNode: newNode,
    );

    // Place the caret at the beginning of the new paragraph node.
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newNode.id,
        nodePosition: TextPosition(offset: 0),
      ),
    );

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction deleteCharacterWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(document: document, selection: currentSelection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if ((currentSelection.value.extent.nodePosition as TextPosition).offset <= 0) {
    return ExecutionInstruction.continueExecution;
  }

  currentSelection.value = editor.deleteSelection(
    document: document,
    selection: DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: currentSelection.value.base.nodeId,
        nodePosition: TextPosition(
          offset: (currentSelection.value.base.nodePosition as TextPosition).offset - 1,
        ),
      ),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction mergeNodeWithPreviousWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot combine node of type: $node');
    return ExecutionInstruction.continueExecution;
  }
  final paragraphNode = node as TextNode;

  final nodeAbove = document.getNodeBefore(paragraphNode);
  if (nodeAbove == null) {
    print('At top of document. Cannot merge with node above.');
    return ExecutionInstruction.continueExecution;
  }
  if (nodeAbove is! TextNode) {
    print('Cannot merge ParagraphNode into node of type: $nodeAbove');
    return ExecutionInstruction.continueExecution;
  }

  final paragraphNodeAbove = nodeAbove as TextNode;
  final aboveParagraphLength = paragraphNodeAbove.text.length;

  // Combine the text and delete the currently selected node.
  paragraphNodeAbove.text += paragraphNode.text;
  bool didRemove = document.deleteNode(paragraphNode);
  if (!didRemove) {
    print('ERROR: Failed to delete the currently selected node from the document.');
  }

  // Place the cursor at the point where the text came together.
  currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeAbove.id,
      nodePosition: TextPosition(offset: aboveParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction deleteCharacterWhenDeleteIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(document: document, selection: currentSelection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  final text = (document.getNodeById(currentSelection.value.extent.nodeId) as TextNode).text;
  final textPosition = (currentSelection.value.extent.nodePosition as TextPosition);
  if (textPosition.offset >= text.length) {
    return ExecutionInstruction.continueExecution;
  }

  currentSelection.value = editor.deleteSelection(
    document: document,
    selection: DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: currentSelection.value.base.nodeId,
        nodePosition: TextPosition(
          offset: (currentSelection.value.base.nodePosition as TextPosition).offset + 1,
        ),
      ),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction mergeNodeWithNextWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot combine node of type: $node');
    return ExecutionInstruction.continueExecution;
  }
  final paragraphNode = node as TextNode;

  final nodeBelow = document.getNodeAfter(paragraphNode);
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
  final currentParagraphLength = paragraphNode.text.length;

  // Combine the text and delete the currently selected node.
  paragraphNode.text += paragraphNodeBelow.text;
  final didRemove = document.deleteNode(nodeBelow);
  if (!didRemove) {
    print('ERROR: failed to remove next node from document.');
  }

  // Place the cursor at the point where the text came together.
  currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: paragraphNode.id,
      nodePosition: TextPosition(offset: currentParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction moveUpDownLeftAndRightWithArrowKeys({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
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
      _moveToStartOfLine(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        nodeSelections: nodeSelections,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.isAltPressed) {
      _moveBackOneWord(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else {
      _moveBackOneCharacter(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    print(' - handling right arrow key');
    if (keyEvent.isMetaPressed) {
      _moveToEndOfLine(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        nodeSelections: nodeSelections,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.isAltPressed) {
      _moveForwardOneWord(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else {
      _moveForwardOneCharacter(
        document: document,
        documentLayout: documentLayout,
        currentSelection: currentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    print(' - handling up arrow key');
    _moveUpOneLine(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      nodeSelections: nodeSelections,
      expandSelection: keyEvent.isShiftPressed,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    print(' - handling down arrow key');
    _moveDownOneLine(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      nodeSelections: nodeSelections,
      expandSelection: keyEvent.isShiftPressed,
    );
  }

  return ExecutionInstruction.haltExecution;
}

void _moveUpOneLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  final selectedNode = document.getNodeById(currentSelection.value.extent.nodeId);
  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move up a line for a selection of type: $extentSelection');
    return;
  }
  final textSelection = extentSelection as TextSelection;
  final selectableText = documentLayout.getSelectableTextByNodeId(selectedNode.id);

  DocumentNode oneLineUpNode = selectedNode;

  // Determine the TextPosition one line up.
  TextPosition oneLineUpPosition = selectableText.getPositionOneLineUp(
    currentPosition: TextPosition(
      offset: textSelection.extentOffset,
    ),
  );
  if (oneLineUpPosition == null) {
    // The first line is selected. Move up to the component above.
    final nodeAbove = document.getNodeBefore(selectedNode) as TextNode;

    if (nodeAbove != null) {
      final offsetToMatch = selectableText.getOffsetForPosition(
        TextPosition(
          offset: textSelection.extentOffset,
        ),
      );

      if (offsetToMatch == null) {
        // No (x,y) offset was provided. Place the selection at the
        // end of the node.
        oneLineUpPosition = TextPosition(offset: nodeAbove.text.length);
      } else {
        // An (x,y) offset was provided. Place the selection as close
        // to the given x-value as possible within the node.
        final selectableText = documentLayout.getSelectableTextByNodeId(nodeAbove.id);
        oneLineUpPosition = selectableText.getPositionInLastLineAtX(offsetToMatch.dx);
      }
      oneLineUpNode = nodeAbove;
    } else {
      // We're at the top of the document. Move the cursor to the beginning
      // of the paragraph.
      oneLineUpPosition = TextPosition(offset: 0);
    }
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: oneLineUpNode.id,
        nodePosition: oneLineUpPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: oneLineUpNode.id,
        nodePosition: oneLineUpPosition,
      ),
    );
  }
}

// previousCursorOffset: if non-null, the cursor is positioned in
//      the previous component at the same horizontal location. If
//      null then cursor is placed at end of previous component.
void moveCursorToPreviousComponent({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required DocumentNode moveFromNode,
  @required bool expandSelection,
  Offset previousCursorOffset,
}) {
  print('Moving to previous node');
  print(' - move from node: $moveFromNode');
  final nodeAbove = document.getNodeBefore(moveFromNode) as TextNode;
  if (nodeAbove == null) {
    print(' - at top of document. Can\'t move up to node above.');
    return;
  }
  print(' - node above: ${nodeAbove.id}');

  if (nodeAbove == null) {
    return;
  }

  TextPosition newTextPosition;
  if (previousCursorOffset == null) {
    // No (x,y) offset was provided. Place the selection at the
    // end of the node.
    newTextPosition = TextPosition(offset: nodeAbove.text.length);
  } else {
    // An (x,y) offset was provided. Place the selection as close
    // to the given x-value as possible within the node.
    final selectableText = documentLayout.getSelectableTextByNodeId(nodeAbove.id);

    newTextPosition = selectableText.getPositionInLastLineAtX(previousCursorOffset.dx);
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: nodeAbove.id,
        nodePosition: newTextPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeAbove.id,
        nodePosition: newTextPosition,
      ),
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

TextSelection moveSelectionFromEndToOffset({
  @required SelectableTextState selectableText,
  @required String text,
  TextSelection currentSelection,
  @required bool expandSelection,
  @required Offset localOffset,
}) {
  final extentOffset = selectableText.getPositionInLastLineAtX(localOffset.dx).offset;

  if (currentSelection != null) {
    return TextSelection(
      baseOffset: expandSelection ? currentSelection.baseOffset : extentOffset,
      extentOffset: extentOffset,
    );
  } else {
    return TextSelection(
      baseOffset: expandSelection ? text.length : extentOffset,
      extentOffset: extentOffset,
    );
  }
}

void _moveDownOneLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  print('_moveDownOneLine()');
  final selectedNode = document.getNodeById(currentSelection.value.extent.nodeId);
  print(' - selected node: $selectedNode');

  if (selectedNode is! TextNode) {
    print('WARNING: cannot move down one line in node of type: $selectedNode');
    return;
  }
  final paragraphNode = selectedNode as TextNode;

  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move down a line for a selection of type: $extentSelection');
    return;
  }

  final textSelection = extentSelection as TextSelection;
  print(' - current selection: $textSelection');
  final selectableText = documentLayout.getSelectableTextByNodeId(selectedNode.id);
  print(' - selectable text at doc position: $selectableText');

  DocumentNode oneLineDownNode = selectedNode;

  // Determine the TextPosition one line up.
  print(' - current selection: ${textSelection}');
  TextPosition oneLineDownPosition = selectableText.getPositionOneLineDown(
    currentPosition: TextPosition(
      offset: textSelection.extentOffset,
    ),
  );
  print(' - one line down: $oneLineDownPosition');
  if (oneLineDownPosition == null) {
    print(' - at bottom of paragraph. Moving to next node.');
    // The last line is selected. Move down to the component below.
    final nodeBelow = document.getNodeAfter(selectedNode) as TextNode;

    if (nodeBelow != null) {
      final offsetToMatch = selectableText.getOffsetForPosition(
        TextPosition(
          offset: textSelection.extentOffset,
        ),
      );

      if (offsetToMatch == null) {
        // No (x,y) offset was provided. Place the selection at the
        // beginning of the node.
        oneLineDownPosition = TextPosition(offset: 0);
      } else {
        // An (x,y) offset was provided. Place the selection as close
        // to the given x-value as possible within the node.
        final selectableText = documentLayout.getSelectableTextByNodeId(nodeBelow.id);
        oneLineDownPosition = selectableText.getPositionInFirstLineAtX(offsetToMatch.dx);
      }
      oneLineDownNode = nodeBelow;
    } else {
      print(' - there is no next node. Ignoring.');
      // We're at the bottom of the document. Move the cursor to the end
      // of the paragraph.
      oneLineDownPosition = TextPosition(offset: paragraphNode.text.length);
    }
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: oneLineDownNode.id,
        nodePosition: oneLineDownPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: oneLineDownNode.id,
        nodePosition: oneLineDownPosition,
      ),
    );
  }
}

void _moveBackOneCharacter({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move back one word with position of type: $extentTextPosition');
    return;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot move back one word in node of type: $node');
    return;
  }

  if (extentTextPosition.offset > 0) {
    final newPosition = TextPosition(offset: extentTextPosition.offset - 1);

    if (expandSelection) {
      currentSelection.value = DocumentSelection(
        base: currentSelection.value.base,
        extent: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    } else {
      currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    }
  } else {
    print(' - at start of paragraph. Trying to move to end of paragraph above.');
    final moveFromNode = document.getNodeById(currentSelection.value.extent.nodeId);
    moveCursorToPreviousComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

void _moveBackOneWord({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move back one word with position of type: $extentTextPosition');
    return;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot move back one word in node of type: $node');
    return;
  }
  final paragraphNode = node as TextNode;
  final text = paragraphNode.text;

  if (extentTextPosition.offset > 0) {
    int newOffset = extentTextPosition.offset;
    newOffset -= 1; // we always want to jump at least 1 character.
    while (newOffset > 0 && _latinCharacters.contains(text[newOffset])) {
      newOffset -= 1;
    }
    final newPosition = TextPosition(offset: newOffset);

    if (expandSelection) {
      currentSelection.value = DocumentSelection(
        base: currentSelection.value.base,
        extent: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    } else {
      currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    }
  } else {
    final moveFromNode = document.getNodeById(currentSelection.value.extent.nodeId);
    moveCursorToPreviousComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

void _moveToStartOfLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot split node of type: $node');
    return;
  }
  final selectedNode = node as TextNode;
  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move to beginning of line for a selection of type: $extentSelection');
    return;
  }
  final textSelection = extentSelection as TextSelection;

  final selectableText = documentLayout.getSelectableTextByNodeId(selectedNode.id);

  final newPosition = selectableText.getPositionAtStartOfLine(
    currentPosition: TextPosition(offset: textSelection.extentOffset),
  );

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: newPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: newPosition,
      ),
    );
  }
}

void _moveForwardOneCharacter({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move back one word with position of type: $extentTextPosition');
    return;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot move back one word in node of type: $node');
    return;
  }
  final paragraphNode = node as TextNode;
  final text = paragraphNode.text;

  if (extentTextPosition.offset < text.length) {
    final newPosition = TextPosition(offset: extentTextPosition.offset + 1);

    if (expandSelection) {
      currentSelection.value = DocumentSelection(
        base: currentSelection.value.base,
        extent: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    } else {
      currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    }
  } else {
    final moveFromNode = document.getNodeById(currentSelection.value.extent.nodeId);
    _moveCursorToNextComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

// previousCursorOffset: if non-null, the cursor is positioned in
//      the next component at the same horizontal location. If
//      null then cursor is placed at beginning of next component.
void _moveCursorToNextComponent({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required DocumentNode moveFromNode,
  @required bool expandSelection,
  Offset previousCursorOffset,
}) {
  print('Moving to next node');
  final nodeBelow = document.getNodeAfter(moveFromNode) as TextNode;
  print(' - node above: $nodeBelow');

  if (nodeBelow == null) {
    return;
  }

  TextPosition newTextPosition;
  if (previousCursorOffset == null) {
    // No (x,y) offset was provided. Place the selection at the
    // beginning of the node.
    newTextPosition = TextPosition(offset: 0);
  } else {
    // An (x,y) offset was provided. Place the selection as close
    // to the given x-value as possible within the node.
    final selectableText = documentLayout.getSelectableTextByNodeId(nodeBelow.id);

    newTextPosition = selectableText.getPositionInFirstLineAtX(previousCursorOffset.dx);
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: nodeBelow.id,
        nodePosition: newTextPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeBelow.id,
        nodePosition: newTextPosition,
      ),
    );
  }
}

// TODO: collapse this implementation with the "back" version.
void _moveForwardOneWord({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move back one word with position of type: $extentTextPosition');
    return;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot move back one word in node of type: $node');
    return;
  }
  final paragraphNode = node as TextNode;
  final text = paragraphNode.text;

  if (extentTextPosition.offset < text.length) {
    int newOffset = extentTextPosition.offset;
    newOffset += 1; // we always want to jump at least 1 character.
    while (newOffset < text.length && _latinCharacters.contains(text[newOffset])) {
      newOffset += 1;
    }
    final newPosition = TextPosition(offset: newOffset);

    if (expandSelection) {
      currentSelection.value = DocumentSelection(
        base: currentSelection.value.base,
        extent: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    } else {
      currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: extentDocPosition.nodeId,
          nodePosition: newPosition,
        ),
      );
    }
  } else {
    final moveFromNode = document.getNodeById(currentSelection.value.extent.nodeId);
    _moveCursorToNextComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

void _moveToEndOfLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! TextNode) {
    print('WARNING: Cannot split node of type: $node');
    return;
  }
  final selectedNode = node as TextNode;
  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move to end of line for a selection of type: $extentSelection');
    return;
  }
  final textSelection = extentSelection as TextSelection;

  final selectableText = documentLayout.getSelectableTextByNodeId(selectedNode.id);

  TextPosition newPosition = selectableText.getPositionAtEndOfLine(
    currentPosition: TextPosition(offset: textSelection.extentOffset),
  );
  final isAutoWrapLine = newPosition.offset < selectedNode.text.length &&
      (selectedNode.text.isNotEmpty && selectedNode.text[newPosition.offset] != '\n');

  // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
  //       cursor to jump to the next line because the cursor is placed after
  //       the final selected character. We don't want this, so in this case
  //       we `-1`.
  //
  //       However, if the line that is selected ends with an explicit `\n`,
  //       or if the line is the terminal line for the paragraph then we don't
  //       want to `-1` because that would leave a dangling character after the
  //       selection.
  // TODO: this is the concept of text affinity. Implement support for affinity.
  newPosition = isAutoWrapLine ? TextPosition(offset: newPosition.offset - 1) : newPosition;

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: newPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: newPosition,
      ),
    );
  }
}

bool _isTextEntryNode({
  @required RichTextDocument document,
  @required ValueNotifier<DocumentSelection> selection,
}) {
  final extentPosition = selection.value.extent;
  final extentNode = document.getNodeById(extentPosition.nodeId);
  return extentNode is TextNode;
}

const _latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

bool _isCharacterKey(LogicalKeyboardKey key) {
  // keyLabel for a character should be: 'a', 'b',...,'A','B',...
  if (key.keyLabel.length != 1) {
    return false;
  }
  return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()_+<>?:"{}|'
      .contains(key.keyLabel);
}
