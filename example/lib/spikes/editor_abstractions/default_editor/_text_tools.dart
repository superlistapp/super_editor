import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/document/rich_text_document.dart';
import '../core/layout/document_layout.dart';
import '../core/selection/editor_selection.dart';
import '_document_traversal_tools.dart';
import 'text.dart';

void moveUpOneLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  print('_moveUpOneLine()');
  final selectedNode = document.getNodeById(currentSelection.value.extent.nodeId);
  print(' - selected node: $selectedNode');

  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move up a line for a selection of type: $extentSelection');
    return;
  }

  final textSelection = extentSelection as TextSelection;
  print(' - current selection: $textSelection');
  final component = documentLayout.getComponentByNodeId(selectedNode.id);
  print(' - selectable text at doc position: $component');

  DocumentNode oneLineUpNode = selectedNode;

  // Determine the TextPosition one line up.
  TextPosition oneLineUpPosition;
  print(' - current selection: ${textSelection}');
  if (component is TextComposable) {
    oneLineUpPosition = (component as TextComposable).getPositionOneLineUp(
      textSelection.extent,
    );
  }

  print(' - one line up: $oneLineUpPosition');
  if (oneLineUpPosition == null) {
    print(' - at rop of node. Moving to node above.');
    // The first line is selected. Move up to the component above.
    final nodeAbove = document.getNodeBefore(selectedNode);

    if (nodeAbove != null) {
      final componentAbove = documentLayout.getComponentByNodeId(nodeAbove.id);

      final offsetToMatch = component.getOffsetForPosition(
        TextPosition(
          offset: textSelection.extentOffset,
        ),
      );

      if (offsetToMatch == null) {
        // No (x,y) offset was provided. Place the selection at the
        // end of the node.
        oneLineUpPosition = componentAbove.getEndPosition();
      } else {
        // An (x,y) offset was provided. Place the selection as close
        // to the given x-value as possible within the node.
        oneLineUpPosition = componentAbove.getEndPositionNearX(offsetToMatch.dx);
      }
      oneLineUpNode = nodeAbove;
    } else {
      print(' - there is no node above. Ignoring.');
      // We're at the top of the document. Move the cursor to the beginning
      // of the paragraph.
      oneLineUpPosition = component.getBeginningPosition();
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

void moveDownOneLine({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  bool expandSelection = false,
}) {
  print('_moveDownOneLine()');
  final selectedNode = document.getNodeById(currentSelection.value.extent.nodeId);
  print(' - selected node: $selectedNode');

  final extentSelection =
      nodeSelections.first.isExtent ? nodeSelections.first.nodeSelection : nodeSelections.last.nodeSelection;
  if (extentSelection is! TextSelection) {
    print('WARNING: Cannot move down a line for a selection of type: $extentSelection');
    return;
  }

  final textSelection = extentSelection as TextSelection;
  print(' - current selection: $textSelection');
  final component = documentLayout.getComponentByNodeId(selectedNode.id);
  print(' - selectable text at doc position: $component');

  DocumentNode oneLineDownNode = selectedNode;

  // Determine the TextPosition one line down.
  TextPosition oneLineDownPosition;
  print(' - current selection: ${textSelection}');
  if (component is TextComposable) {
    oneLineDownPosition = (component as TextComposable).getPositionOneLineDown(
      textSelection.extent,
    );
  }

  print(' - one line down: $oneLineDownPosition');
  if (oneLineDownPosition == null) {
    print(' - at bottom of node. Moving to next node.');
    // The last line is selected. Move down to the component below.
    final nodeBelow = document.getNodeAfter(selectedNode);

    if (nodeBelow != null) {
      final componentBelow = documentLayout.getComponentByNodeId(nodeBelow.id);

      final offsetToMatch = component.getOffsetForPosition(
        TextPosition(
          offset: textSelection.extentOffset,
        ),
      );

      if (offsetToMatch == null) {
        // No (x,y) offset was provided. Place the selection at the
        // beginning of the node.
        oneLineDownPosition = componentBelow.getBeginningPosition();
      } else {
        // An (x,y) offset was provided. Place the selection as close
        // to the given x-value as possible within the node.
        oneLineDownPosition = componentBelow.getBeginningPositionNearX(offsetToMatch.dx);
      }
      oneLineDownNode = nodeBelow;
    } else {
      print(' - there is no next node. Ignoring.');
      // We're at the bottom of the document. Move the cursor to the end
      // of the paragraph.
      oneLineDownPosition = component.getEndPosition();
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

void moveBackOneWord({
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

  final component = documentLayout.getComponentByNodeId(currentSelection.value.extent.nodeId);
  if (component is! TextComposable) {
    print('WARNING: Cannot move back one word in component that is not TextComposable: $component');
    return;
  }
  final text = (component as TextComposable).getContiguousTextAt(extentDocPosition.nodePosition);

  if (extentTextPosition.offset > 0) {
    int newOffset = extentTextPosition.offset;
    newOffset -= 1; // we always want to jump at least 1 character.
    while (newOffset > 0 && latinCharacters.contains(text[newOffset])) {
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

// TODO: collapse this implementation with the "back" version.
void moveForwardOneWord({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move forward one word with position of type: $extentTextPosition');
    return;
  }

  final component = documentLayout.getComponentByNodeId(currentSelection.value.extent.nodeId);
  if (component is! TextComposable) {
    print('WARNING: Cannot move forward one word in component that is not TextComposable: $component');
    return;
  }
  final text = (component as TextComposable).getContiguousTextAt(extentDocPosition.nodePosition);

  if (extentTextPosition.offset < text.length) {
    int newOffset = extentTextPosition.offset;
    newOffset += 1; // we always want to jump at least 1 character.
    while (newOffset < text.length && latinCharacters.contains(text[newOffset])) {
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
    moveCursorToNextComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

void moveBackOneCharacter({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move back one character with position of type: $extentTextPosition');
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

void moveForwardOneCharacter({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  bool expandSelection = false,
}) {
  final extentDocPosition = currentSelection.value.extent;
  final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
  if (extentTextPosition is! TextPosition) {
    print('WARNING: Cannot move forward one character with position of type: $extentTextPosition');
    return;
  }

  final component = documentLayout.getComponentByNodeId(extentDocPosition.nodeId);
  final endTextPosition = component.getEndPosition() as TextPosition;
  if (endTextPosition == null) {
    print(
        'WARNING: Cannot move forward one character. The component did not provide an "end" TextPosition: $component');
    return;
  }

  if (extentTextPosition != endTextPosition) {
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
    moveCursorToNextComponent(
      document: document,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      moveFromNode: moveFromNode,
      expandSelection: expandSelection,
    );
  }
}

void moveToStartOfLine({
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
    print('WARNING: Cannot move to beginning of line for a selection of type: $extentSelection');
    return;
  }
  final textSelection = extentSelection as TextSelection;

  final component = documentLayout.getComponentByNodeId(selectedNode.id);
  if (component is! TextComposable) {
    print('WARNING: Cannot move to beginning of line in component that is not TextComposable: $component');
    return;
  }

  final newPosition = (component as TextComposable).getPositionAtStartOfLine(
    TextPosition(offset: textSelection.extentOffset),
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

void moveToEndOfLine({
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
    print('WARNING: Cannot move to end of line for a selection of type: $extentSelection');
    return;
  }
  final textSelection = extentSelection as TextSelection;

  final component = documentLayout.getComponentByNodeId(selectedNode.id);

  if (component is! TextComposable) {
    print('WARNING: Cannot move to end of line in component that is not TextComposable: $component');
    return;
  }

  TextPosition newPosition = (component as TextComposable).getPositionAtEndOfLine(
    TextPosition(offset: textSelection.extentOffset),
  );
  final TextPosition endPosition = component.getEndPosition() as TextPosition;
  final String text = (component as TextComposable).getContiguousTextAt(newPosition);
  // Note: we compare offset values because we don't care if the affinitys are equal
  final isAutoWrapLine = newPosition.offset != endPosition.offset && (text[newPosition.offset] != '\n');

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

bool isTextEntryNode({
  @required RichTextDocument document,
  @required ValueNotifier<DocumentSelection> selection,
}) {
  final extentPosition = selection.value.extent;
  final extentNode = document.getNodeById(extentPosition.nodeId);
  return extentNode is TextNode;
}

const latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

bool isCharacterKey(LogicalKeyboardKey key) {
  // keyLabel for a character should be: 'a', 'b',...,'A','B',...
  if (key.keyLabel.length != 1) {
    return false;
  }
  return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()-=_+<>?:"{}|'
      .contains(key.keyLabel);
}
