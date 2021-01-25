import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'editor_layout_model.dart';
import 'paragraph/editor_paragraph_component.dart';
import 'paragraph/selectable_text.dart';

class EditorSelection with ChangeNotifier {
  EditorSelection({
    @required this.displayNodes,
    this.baseOffsetNode,
    this.extentOffsetNode,
  });

  final List<DocDisplayNode> displayNodes;
  DocDisplayNode nodeWithCursor;

  void updateCursorComponentSelection(EditorComponentSelection newSelection) {
    print('Updating node ${nodeWithCursor.key} with selection: ${newSelection.componentSelection}');
    nodeWithCursor.selection = newSelection;
    notifyListeners();
  }

  DocDisplayNode baseOffsetNode;
  DocDisplayNode extentOffsetNode;

  // previousCursorOffset: if non-null, the cursor is positioned in
  //      the previous component at the same horizontal location. If
  //      null then cursor is placed at end of previous component.
  bool moveCursorToPreviousComponent({
    @required bool expandSelection,
    Offset previousCursorOffset,
  }) {
    print('Moving to previous node');
    final currentNodeIndex = displayNodes.indexOf(nodeWithCursor);
    print(' - current node index: $currentNodeIndex');
    if (currentNodeIndex > 0) {
      final previousNode = displayNodes[currentNodeIndex - 1];
      EditorComponentSelection previousNodeSelection;
      if (previousCursorOffset == null) {
        previousNodeSelection = moveSelectionToEnd(
          text: (previousNode.key.currentState as SelectableTextState).widget.text,
          currentSelection: previousNode.selection,
          expandSelection: expandSelection,
        );
      } else {
        previousNodeSelection = moveSelectionFromEndToOffset(
          selectableText: previousNode.key.currentState as TextLayout,
          text: (previousNode.key.currentState as SelectableTextState).widget.text,
          currentSelection: previousNode.selection,
          expandSelection: expandSelection,
          localOffset: previousCursorOffset,
        );
      }

      final isCurrentNodeTheExtent = nodeWithCursor == extentOffsetNode;
      final isSelectionGoingDownward = displayNodes.indexOf(baseOffsetNode) < displayNodes.indexOf(extentOffsetNode);

      previousNode.selection = previousNodeSelection;

      extentOffsetNode = previousNode;
      if (!expandSelection) {
        baseOffsetNode = extentOffsetNode;
        nodeWithCursor.selection = null;
      } else if (isCurrentNodeTheExtent && isSelectionGoingDownward) {
        nodeWithCursor.selection = null;
      }

      nodeWithCursor = previousNode;

      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  ParagraphEditorComponentSelection moveSelectionToEnd({
    String text,
    EditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : text.length,
          extentOffset: text.length,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  ParagraphEditorComponentSelection moveSelectionFromEndToOffset({
    @required TextLayout selectableText,
    @required String text,
    EditorComponentSelection currentSelection,
    @required bool expandSelection,
    @required Offset localOffset,
  }) {
    final extentOffset = selectableText.getPositionInLastLineAtX(localOffset.dx).offset;

    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? text.length : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    }
  }

  // previousCursorOffset: if non-null, the cursor is positioned in
  //      the next component at the same horizontal location. If
  //      null then cursor is placed at beginning of next component.
  bool moveCursorToNextComponent({
    @required bool expandSelection,
    Offset previousCursorOffset,
  }) {
    print('Moving to next node');
    final currentNodeIndex = displayNodes.indexOf(nodeWithCursor);
    if (currentNodeIndex < displayNodes.length - 1) {
      final nextNode = displayNodes[currentNodeIndex + 1];
      print(' - current selection: ${nextNode.selection?.componentSelection}');
      EditorComponentSelection nextNodeSelection;
      if (previousCursorOffset == null) {
        nextNodeSelection = moveSelectionToStart(
          currentSelection: nextNode.selection,
          expandSelection: expandSelection,
        );
      } else {
        nextNodeSelection = moveSelectionFromStartToOffset(
          selectableText: nextNode.key.currentState as TextLayout,
          currentSelection: nextNode.selection,
          expandSelection: expandSelection,
          localOffset: previousCursorOffset,
        );
      }

      nextNode.selection = nextNodeSelection;

      final isCurrentNodeTheExtent = nodeWithCursor == extentOffsetNode;
      final isSelectionGoingUpward = displayNodes.indexOf(extentOffsetNode) < displayNodes.indexOf(baseOffsetNode);

      extentOffsetNode = nextNode;
      if (!expandSelection) {
        baseOffsetNode = extentOffsetNode;
        nodeWithCursor.selection = null;
      } else if (isCurrentNodeTheExtent && isSelectionGoingUpward) {
        nodeWithCursor.selection = null;
      }

      nodeWithCursor = nextNode;

      print(' - base node: ${baseOffsetNode.key}');
      print(' - base selection: ${baseOffsetNode.selection.componentSelection}');
      print(' - extent node: ${extentOffsetNode.key}');
      print(' - extent selection: ${extentOffsetNode.selection.componentSelection}');

      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  ParagraphEditorComponentSelection moveSelectionToStart({
    EditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    print('Move selection to start. Current selection: ${currentSelection?.componentSelection}');
    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : 0,
          extentOffset: 0,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection.collapsed(offset: 0),
      );
    }
  }

  ParagraphEditorComponentSelection moveSelectionFromStartToOffset({
    TextLayout selectableText,
    EditorComponentSelection currentSelection,
    @required bool expandSelection,
    @required Offset localOffset,
  }) {
    final extentOffset = selectableText.getPositionInFirstLineAtX(localOffset.dx).offset;

    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? 0 : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    }
  }

  // TODO: what does it mean if selection is null? that's not collapsed, because
  //       it's not a selection.
  bool get isCollapsed =>
      isEmpty ||
      (baseOffsetNode != null &&
          baseOffsetNode == extentOffsetNode &&
          (baseOffsetNode.selection == null || baseOffsetNode.selection.isCollapsed));

  void collapse() {
    if (isCollapsed) {
      return;
    }
    if (isEmpty) {
      return;
    }

    print('Collapsing editor selection');
    print('Extent node: ${extentOffsetNode.key}');
    print('Extent selection: ${extentOffsetNode.selection.componentSelection}');
    baseOffsetNode = extentOffsetNode;

    extentOffsetNode.selection.collapse();

    print('Base offset: ${baseOffsetNode.key}');
    print('Extent offset: ${extentOffsetNode.key}');
    print('Extent selection: ${extentOffsetNode.selection.componentSelection}');

    for (final displayNode in displayNodes) {
      if (displayNode.key != nodeWithCursor.key) {
        print(' - Nullifying selection for ${displayNode.key}');
        displayNode.selection = null;
      }
    }

    notifyListeners();
  }

  bool get isEmpty => baseOffsetNode == null && extentOffsetNode == null;

  void clear() {
    print('Clearing editor selection');
    baseOffsetNode?.selection?.clear();
    baseOffsetNode = null;
    extentOffsetNode?.selection?.clear();
    extentOffsetNode = null;
  }

  DocDisplayNode insertNewNodeAfter(DocDisplayNode existingNode) {
    final newNode = DocDisplayNode(key: GlobalKey(), paragraph: '');
    displayNodes.insert(
      displayNodes.indexOf(existingNode) + 1,
      newNode,
    );
    return newNode;
  }

  void deleteSelection() {
    print('EditorSelection: deleteSelection()');
    if (!isCollapsed) {
      print(' - editor selection is not collapsed. Deleting across nodes...');
      // Delete all nodes between the base offset node and the extent
      // offset node.
      final baseIndex = displayNodes.indexOf(baseOffsetNode);
      final extentIndex = displayNodes.indexOf(extentOffsetNode);
      final startIndex = min(baseIndex, extentIndex);
      final firstNode = displayNodes[startIndex];
      final endIndex = max(baseIndex, extentIndex);
      final lastNode = displayNodes[endIndex];

      print(' - selected nodes $startIndex to $endIndex');
      print(' - first node: ${firstNode.key}');
      print(' - last node: ${lastNode.key}');
      print(' - initially ${displayNodes.length} nodes');

      for (int i = endIndex - 1; i > startIndex; --i) {
        print(' - deleting node $i: ${displayNodes[i].key}');
        _deleteNode(i);
      }

      baseOffsetNode.deleteSelection();
      extentOffsetNode.deleteSelection();

      final shouldTryToCombineNodes = firstNode != lastNode;
      if (shouldTryToCombineNodes) {
        print(' - trying to combine nodes');
        final didCombine = firstNode.tryToCombineWithNextNode(lastNode);
        if (didCombine) {
          print(' - nodes were successfully combined');
          print(' - deleting end node $endIndex');
          final didRemoveLast = displayNodes.remove(lastNode);
          print(' - did remove ending node? $didRemoveLast');
          print(' - finally ${displayNodes.length} nodes');
          baseOffsetNode = firstNode;
          extentOffsetNode = firstNode;
          nodeWithCursor = firstNode;
        }
      }

      print(
          'Resulting extent text selection (${extentOffsetNode.key}): ${extentOffsetNode.selection.componentSelection}');
      print('Node with cursor: ${nodeWithCursor.key}');

      notifyListeners();
    }
  }

  bool combineCursorNodeWithPrevious() {
    final cursorNodeIndex = displayNodes.indexOf(nodeWithCursor);
    bool didCombine = false;
    if (cursorNodeIndex > 0) {
      final previousNode = displayNodes[cursorNodeIndex - 1];
      print('Combining...');
      didCombine = previousNode.tryToCombineWithNextNode(nodeWithCursor);
      print('Did combine: $didCombine');
      if (didCombine) {
        displayNodes.removeAt(cursorNodeIndex);
        baseOffsetNode = previousNode;
        extentOffsetNode = previousNode;
        nodeWithCursor = previousNode;
      }
    }
    return didCombine;
  }

  bool combineCursorNodeWithNext() {
    final cursorNodeIndex = displayNodes.indexOf(nodeWithCursor);
    final nextNodeIndex = cursorNodeIndex + 1;
    bool didCombine = false;
    if (nextNodeIndex < displayNodes.length) {
      didCombine = nodeWithCursor.tryToCombineWithNextNode(displayNodes[cursorNodeIndex + 1]);
      if (didCombine) {
        displayNodes.removeAt(nextNodeIndex);
        baseOffsetNode = nodeWithCursor;
        extentOffsetNode = nodeWithCursor;
      }
    }
    return didCombine;
  }

  DocDisplayNode _findFirstNode(DocDisplayNode node1, DocDisplayNode node2) {
    if (displayNodes.indexOf(node1) < displayNodes.indexOf(node2)) {
      return node1;
    } else {
      return node2;
    }
  }

  void _deleteNode(int index) {
    displayNodes.removeAt(index);
    // TODO: adjust selection if the base node or extent node
    //       are deleted.
  }
}

abstract class TextLayout {
  TextPosition getPositionAtOffset(Offset localOffset);

  Offset getOffsetForPosition(TextPosition position);

  TextPosition getPositionAtStartOfLine({
    TextPosition currentPosition,
  });

  TextPosition getPositionAtEndOfLine({
    TextPosition currentPosition,
  });

  TextPosition getPositionOneLineUp({
    TextPosition currentPosition,
  });

  TextPosition getPositionOneLineDown({
    TextPosition currentPosition,
  });

  TextPosition getPositionInFirstLineAtX(double x);

  TextPosition getPositionInLastLineAtX(double x);

  bool isTextAtOffset(Offset localOffset);

  Rect calculateLocalOverlap({
    Rect region,
    RenderObject ancestorCoordinateSpace,
  });

  TextSelection getSelectionInRect(Rect selectionArea, bool isDraggingDown);
}

abstract class EditorComponentSelection {
  dynamic get componentSelection;
  set componentSelection(dynamic selection);

  bool get isCollapsed;

  void collapse();

  void clear();
}
