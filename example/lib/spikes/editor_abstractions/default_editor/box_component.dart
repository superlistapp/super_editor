import 'package:example/spikes/editor_abstractions/core/composition/document_composer.dart';
import 'package:example/spikes/editor_abstractions/core/document/document_editor.dart';
import 'package:example/spikes/editor_abstractions/core/document/rich_text_document.dart';
import 'package:example/spikes/editor_abstractions/core/layout/document_layout.dart';
import 'package:example/spikes/editor_abstractions/core/selection/editor_selection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/rendering/mouse_cursor.dart';
import 'package:flutter/widgets.dart';

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
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  print('Considering deleting box');
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace && keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }
  if (currentSelection.value == null) {
    print(' - current selection is null. Returning');
    return ExecutionInstruction.continueExecution;
  }
  if (!currentSelection.value.isCollapsed) {
    print(' - current selection is not collapsed. Returning.');
    return ExecutionInstruction.continueExecution;
  }
  if (currentSelection.value.extent.nodePosition is! BinaryPosition) {
    print(' - current extent is not a BinaryPosition. Returning.');
    return ExecutionInstruction.continueExecution;
  }
  if (!(currentSelection.value.extent.nodePosition as BinaryPosition).isIncluded) {
    print(' - current position does not include the box. Returning.');
    return ExecutionInstruction.continueExecution;
  }

  print('Deleting a box component');
  currentSelection.value = editor.deleteSelection(
    document: document,
    documentLayout: documentLayout,
    selection: DocumentSelection.collapsed(
      position: currentSelection.value.extent,
    ),
  );

  return ExecutionInstruction.haltExecution;
}
