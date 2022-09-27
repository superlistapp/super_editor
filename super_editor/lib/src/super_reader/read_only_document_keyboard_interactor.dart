import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';

/// Governs document input that comes from a physical keyboard.
///
/// Keyboard input won't work on a mobile device with a software
/// keyboard because the software keyboard sends input through
/// the operating system's Input Method Engine. For mobile use-cases,
/// see super_editor's IME input support.

/// Receives all keyboard input, when focused, and changes the read-only
/// document display, as needed.
///
/// [keyboardActions] determines the mapping from keyboard key presses
/// to document editing behaviors. [keyboardActions] operates as a
/// Chain of Responsibility.
class ReadOnlyDocumentKeyboardInteractor extends StatelessWidget {
  const ReadOnlyDocumentKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.documentContext,
    required this.keyboardActions,
    required this.child,
    this.autofocus = false,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode focusNode;

  /// Service locator for document display dependencies.
  final DocumentContext documentContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [ReadOnlyDocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [ReadOnlyDocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [ReadOnlyDocumentKeyboardAction].
  final List<ReadOnlyDocumentKeyboardAction> keyboardActions;

  /// Whether or not the [ReadOnlyDocumentKeyboardInteractor] should autofocus
  final bool autofocus;

  /// The [child] widget, which is expected to include the document UI
  /// somewhere in the sub-tree.
  final Widget child;

  KeyEventResult _onKeyPressed(FocusNode node, RawKeyEvent keyEvent) {
    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < keyboardActions.length) {
      instruction = keyboardActions[index](
        documentContext: documentContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    switch (instruction) {
      case ExecutionInstruction.haltExecution:
        return KeyEventResult.handled;
      case ExecutionInstruction.continueExecution:
      case ExecutionInstruction.blocked:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKey: _onKeyPressed,
      autofocus: autofocus,
      child: child,
    );
  }
}

/// Executes this action, if the action wants to run, and returns
/// a desired [ExecutionInstruction] to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// [ExecutionInstruction.continueExecution] to continue execution.
///
/// It is possible that an action does nothing and then returns
/// [ExecutionInstruction.haltExecution] to prevent further execution.
typedef ReadOnlyDocumentKeyboardAction = ExecutionInstruction Function({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
});

enum ExecutionInstruction {
  /// The handler has no relation to the key event and
  /// took no action.
  ///
  /// Other handlers should be given a chance to act on
  /// the key press.
  continueExecution,

  /// The handler recognized the key event but chose to
  /// take no action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **should** bubble up the tree to
  /// (possibly) be handled by other keyboard/shortcut
  /// listeners.
  blocked,

  /// The handler recognized the key event and chose to
  /// take an action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **shouldn't** bubble up the tree.
  haltExecution,
}

/// A [ReadOnlyDocumentKeyboardAction] that reports [ExecutionInstruction.blocked]
/// for any key combination that matches one of the given [keys].
ReadOnlyDocumentKeyboardAction ignoreKeyCombos(List<ShortcutActivator> keys) {
  return ({
    required DocumentContext documentContext,
    required RawKeyEvent keyEvent,
  }) {
    for (final key in keys) {
      if (key.accepts(keyEvent, RawKeyboard.instance)) {
        return ExecutionInstruction.blocked;
      }
    }
    return ExecutionInstruction.continueExecution;
  };
}

/// Keyboard actions for the standard [SuperEditor].
final readOnlyDefaultKeyboardActions = <ReadOnlyDocumentKeyboardAction>[
  removeCollapsedSelectionWhenShiftIsReleased,
  scrollUpDownWithArrowKeys,
  expandSelectionWithArrowKeys,
  expandSelectionToLineStartWithHome,
  expandSelectionToLineEndWithEnd,
  expandSelectionToLineStartOrEndWithCtrlAOrE,
  selectAllWhenCmdAIsPressed,
  copyWhenCmdCIsPressed,
];

ExecutionInstruction removeCollapsedSelectionWhenShiftIsReleased({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyUpEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.shift &&
      keyEvent.logicalKey != LogicalKeyboardKey.shiftLeft &&
      keyEvent.logicalKey != LogicalKeyboardKey.shiftRight) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = documentContext.selection.value;
  if (selection == null || !selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  // The selection is collapsed, and the shift key was released. We don't
  // want to retain the selection any longer. Remove it.
  documentContext.selection.value = null;
  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction copyWhenCmdCIsPressed({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
    return ExecutionInstruction.continueExecution;
  }
  if (documentContext.selection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (documentContext.selection.value!.isCollapsed) {
    // Nothing to copy, but we technically handled the task.
    return ExecutionInstruction.haltExecution;
  }

  copy(
    document: documentContext.document,
    selection: documentContext.selection.value!,
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction selectAllWhenCmdAIsPressed({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyA) {
    return ExecutionInstruction.continueExecution;
  }

  final didSelectAll = selectAll(documentContext.document, documentContext.selection);
  return didSelectAll ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

/// Sets the [selection]'s value to include the entire [Document].
///
/// Always returns [true].
bool selectAll(Document document, ValueNotifier<DocumentSelection?> selection) {
  final nodes = document.nodes;
  if (nodes.isEmpty) {
    return false;
  }

  selection.value = DocumentSelection(
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

ExecutionInstruction expandSelectionWithArrowKeys({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  const arrowKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ];
  if (!arrowKeys.contains(keyEvent.logicalKey)) {
    return ExecutionInstruction.continueExecution;
  }

  if (defaultTargetPlatform == TargetPlatform.windows && keyEvent.isAltPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (defaultTargetPlatform == TargetPlatform.linux &&
      keyEvent.isAltPressed &&
      (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft || keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    MovementModifier? movementModifier;
    if ((defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) &&
        keyEvent.isControlPressed) {
      movementModifier = MovementModifier.word;
    } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isMetaPressed) {
      movementModifier = MovementModifier.line;
    } else if (defaultTargetPlatform == TargetPlatform.macOS && keyEvent.isAltPressed) {
      movementModifier = MovementModifier.word;
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Move the caret left/upstream.
      didMove = _moveCaretUpstream(
        document: documentContext.document,
        documentLayout: documentContext.documentLayout,
        selectionNotifier: documentContext.selection,
        movementModifier: movementModifier,
        retainCollapsedSelection: keyEvent.isShiftPressed,
      );
    } else {
      // Move the caret right/downstream.
      didMove = _moveCaretDownstream(
        document: documentContext.document,
        documentLayout: documentContext.documentLayout,
        selectionNotifier: documentContext.selection,
        movementModifier: movementModifier,
        retainCollapsedSelection: keyEvent.isShiftPressed,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    didMove = _moveCaretUp(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    didMove = _moveCaretDown(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

bool _moveCaretUpstream({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getUpstreamSelectableNodeBefore(document, documentLayout, node);

    if (nextNode == null) {
      // We're at the beginning of the document and can't go anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      return false;
    }
    newExtentNodePosition = nextComponent.getEndPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

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
bool _moveCaretUp({
  required Document document,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  required DocumentLayout documentLayout,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionUp(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getUpstreamSelectableNodeBefore(document, documentLayout, node);
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
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

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Returns the first [DocumentNode] before [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getUpstreamSelectableNodeBefore(
    Document document, DocumentLayout documentLayout, DocumentNode startingNode) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeBefore(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayout.getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
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
bool _moveCaretDownstream({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionRight(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getDownstreamSelectableNodeAfter(document, documentLayout, node);

    if (nextNode == null) {
      // We're at the beginning/end of the document and can't go
      // anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      throw Exception('Could not find next component to move the selection horizontally. Next node ID: ${nextNode.id}');
    }
    newExtentNodePosition = nextComponent.getBeginningPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

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
bool _moveCaretDown({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionDown(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getDownstreamSelectableNodeAfter(document, documentLayout, node);
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
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

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Returns the first [DocumentNode] after [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getDownstreamSelectableNodeAfter(
    Document document, DocumentLayout documentLayout, DocumentNode startingNode) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeAfter(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayout.getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}

ExecutionInstruction scrollUpDownWithArrowKeys({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.arrowUp && keyEvent.logicalKey != LogicalKeyboardKey.arrowDown) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.isShiftPressed) {
    // When shift is pressed, the user wants a selection change, not scrolling.
    return ExecutionInstruction.continueExecution;
  }

  final delta = keyEvent.logicalKey == LogicalKeyboardKey.arrowDown ? 20.0 : -20.0;
  documentContext.scrollController.jumpBy(delta);

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction expandSelectionToLineStartWithHome({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isShiftPressed) {
    // Read-only documents only support expanded selections. Shift isn't
    // pressed. This action doesn't apply to an expanding selection.
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.home) {
    didMove = _moveCaretUpstream(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction expandSelectionToLineEndWithEnd({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isShiftPressed) {
    // Read-only documents only support expanded selections. Shift isn't
    // pressed. This action doesn't apply to an expanding selection.
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.end) {
    didMove = _moveCaretDownstream(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction expandSelectionToLineStartOrEndWithCtrlAOrE({
  required DocumentContext documentContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent is! RawKeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (Platform.instance.isMac) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isControlPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isShiftPressed) {
    // Read-only documents only support expanded selections. Shift isn't
    // pressed. This action doesn't apply to an expanding selection.
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.keyA) {
    didMove = _moveCaretUpstream(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  }

  if (keyEvent.logicalKey == LogicalKeyboardKey.keyE) {
    didMove = _moveCaretDownstream(
      document: documentContext.document,
      documentLayout: documentContext.documentLayout,
      selectionNotifier: documentContext.selection,
      movementModifier: MovementModifier.line,
      retainCollapsedSelection: keyEvent.isShiftPressed,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

/// Serializes the current selection to plain text, and adds it to the
/// clipboard.
void copy({
  required Document document,
  required DocumentSelection selection,
}) {
  final textToCopy = _textInSelection(
    document: document,
    documentSelection: selection,
  );
  // TODO: figure out a general approach for asynchronous behaviors that
  //       need to be carried out in response to user input.
  _saveToClipboard(textToCopy);
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

Future<void> _saveToClipboard(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
