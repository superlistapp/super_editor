import 'package:example/spikes/editor_abstractions/core/composition/document_composer.dart';
import 'package:example/spikes/editor_abstractions/core/document/rich_text_document.dart';
import 'package:example/spikes/editor_abstractions/core/layout/document_layout.dart';
import 'package:example/spikes/editor_abstractions/core/selection/editor_selection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/rendering/mouse_cursor.dart';
import 'package:flutter/widgets.dart';

import 'multi_node_editing.dart';

class BoxComponent extends StatefulWidget {
  const BoxComponent({
    Key key,
    this.child,
  }) : super(key: key);

  final Widget child;

  @override
  _BoxComponentState createState() => _BoxComponentState();
}

class _BoxComponentState extends State<BoxComponent> with DocumentComponent {
  @override
  BinaryPosition getBeginningPosition() {
    return BinaryPosition.included();
  }

  @override
  BinaryPosition getBeginningPositionNearX(double x) {
    return BinaryPosition.included();
  }

  @override
  BinaryPosition movePositionLeft(dynamic currentPosition, [Map<String, dynamic> movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition movePositionRight(dynamic currentPosition, [Map<String, dynamic> movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition movePositionUp(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition movePositionDown(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinarySelection getCollapsedSelectionAt(nodePosition) {
    if (nodePosition is! BinaryPosition) {
      return null;
    }

    return BinarySelection.all();
  }

  @override
  MouseCursor getDesiredCursorAtOffset(Offset localOffset) {
    return null;
  }

  @override
  BinaryPosition getEndPosition() {
    return BinaryPosition.included();
  }

  @override
  getEndPositionNearX(double x) {
    return BinaryPosition.included();
  }

  @override
  Offset getOffsetForPosition(nodePosition) {
    if (nodePosition is! BinaryPosition) {
      return null;
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset(myBox.size.width / 2, myBox.size.height / 2);
  }

  @override
  BinaryPosition getPositionAtOffset(Offset localOffset) {
    return BinaryPosition.included();
  }

  @override
  BinarySelection getSelectionBetween({basePosition, extentPosition}) {
    if (basePosition is! BinaryPosition || extentPosition is! BinaryPosition) {
      return null;
    }

    return BinarySelection.all();
  }

  @override
  BinarySelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return BinarySelection.all();
  }

  @override
  BinarySelection getSelectionOfEverything() {
    return BinarySelection.all();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class BinaryPosition {
  const BinaryPosition.included() : isIncluded = true;
  const BinaryPosition.notIncluded() : isIncluded = false;

  final bool isIncluded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryPosition && runtimeType == other.runtimeType && isIncluded == other.isIncluded;

  @override
  int get hashCode => isIncluded.hashCode;
}

class BinarySelection {
  const BinarySelection.all() : position = const BinaryPosition.included();
  const BinarySelection.none() : position = const BinaryPosition.notIncluded();

  final BinaryPosition position;

  bool get isCollapsed => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinarySelection && runtimeType == other.runtimeType && position == other.position;

  @override
  int get hashCode => position.hashCode;
}

ExecutionInstruction deleteBoxWhenBackspaceOrDeleteIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace && keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }
  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!composerContext.currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if (composerContext.currentSelection.value.extent.nodePosition is! BinaryPosition) {
    return ExecutionInstruction.continueExecution;
  }
  if (!(composerContext.currentSelection.value.extent.nodePosition as BinaryPosition).isIncluded) {
    return ExecutionInstruction.continueExecution;
  }

  print('Deleting a box component');

  final node = composerContext.document.getNode(composerContext.currentSelection.value.extent);
  final newSelectionPosition = _getAnotherSelectionAfterNodeDeletion(
    document: composerContext.document,
    documentLayout: composerContext.documentLayout,
    deletedNodeIndex: composerContext.document.getNodeIndex(node),
  );

  composerContext.editor.executeCommand(
    DeleteSelectionCommand(
      documentSelection: composerContext.currentSelection.value,
    ),
  );

  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: newSelectionPosition,
  );

  return ExecutionInstruction.haltExecution;
}

DocumentPosition _getAnotherSelectionAfterNodeDeletion({
  @required RichTextDocument document,
  @required DocumentLayoutState documentLayout,
  @required int deletedNodeIndex,
}) {
  if (deletedNodeIndex > 0) {
    final newSelectionNodeIndex = deletedNodeIndex - 1;
    final newSelectionNode = document.getNodeAt(newSelectionNodeIndex);
    final component = documentLayout.getComponentByNodeId(newSelectionNode.id);
    return DocumentPosition(
      nodeId: newSelectionNode.id,
      nodePosition: component.getEndPosition(),
    );
  } else if (document.nodes.isNotEmpty) {
    // There is no node above the start node. It's at the top
    // of the document. Try to place the selection in whatever
    // is now the first node in the document.
    final newSelectionNode = document.getNodeAt(0);
    final component = documentLayout.getComponentByNodeId(newSelectionNode.id);
    return DocumentPosition(
      nodeId: newSelectionNode.id,
      nodePosition: component.getEndPosition(),
    );
  } else {
    // The document is empty. Null out the position.
    return null;
  }
}
