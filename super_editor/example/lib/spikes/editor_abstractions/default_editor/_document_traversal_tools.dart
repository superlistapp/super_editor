// previousCursorOffset: if non-null, the cursor is positioned in
//      the next component at the same horizontal location. If
//      null then cursor is placed at beginning of next component.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/document.dart';
import '../core/document_layout.dart';
import '../core/document_selection.dart';

// previousCursorOffset: if non-null, the cursor is positioned in
//      the previous component at the same horizontal location. If
//      null then cursor is placed at end of previous component.
void moveCursorToPreviousComponent({
  @required Document document,
  @required DocumentLayout documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required DocumentNode moveFromNode,
  @required bool expandSelection,
  Offset previousCursorOffset,
}) {
  print('Moving to previous node');
  print(' - move from node: $moveFromNode');
  final nodeAbove = document.getNodeBefore(moveFromNode);
  if (nodeAbove == null) {
    print(' - at top of document. Can\'t move up to node above.');
    return;
  }
  print(' - node above: ${nodeAbove.id}');

  final previousComponent = documentLayout.getComponentByNodeId(nodeAbove.id);
  print(' - component below: $previousComponent');
  if (previousComponent == null) {
    return;
  }

  dynamic newPosition;
  if (previousCursorOffset == null) {
    // No (x,y) offset was provided. Place the selection at the
    // end of the component.
    newPosition = previousComponent.getEndPosition();
  } else {
    // An (x,y) offset was provided. Place the selection as close
    // to the given x-value as possible within the component.
    newPosition = previousComponent.getEndPositionNearX(previousCursorOffset.dx);
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: nodeAbove.id,
        nodePosition: newPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeAbove.id,
        nodePosition: newPosition,
      ),
    );
  }
}

void moveCursorToNextComponent({
  @required Document document,
  @required DocumentLayout documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required DocumentNode moveFromNode,
  @required bool expandSelection,
  Offset previousCursorOffset,
}) {
  print('Moving to next node');
  final nextNode = document.getNodeAfter(moveFromNode);
  print(' - node below: $nextNode');
  if (nextNode == null) {
    return;
  }

  final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
  print(' - component below: $nextComponent');
  if (nextComponent == null) {
    return;
  }

  dynamic newPosition;
  if (previousCursorOffset == null) {
    // No (x,y) offset was provided. Place the selection at the
    // beginning of the component.
    newPosition = nextComponent.getBeginningPosition();
  } else {
    // An (x,y) offset was provided. Place the selection as close
    // to the given x-value as possible within the component.
    newPosition = nextComponent.getBeginningPositionNearX(previousCursorOffset.dx);
  }

  if (expandSelection) {
    currentSelection.value = DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: nextNode.id,
        nodePosition: newPosition,
      ),
    );
  } else {
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nextNode.id,
        nodePosition: newPosition,
      ),
    );
  }
}
