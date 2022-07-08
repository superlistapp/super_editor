import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';

import 'document_input_keyboard.dart';
import 'paragraph.dart';
import 'text.dart';

ExecutionInstruction doNothingWhenThereIsNoSelection({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction pasteWhenCmdVIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.commonOps.paste();

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction selectAllWhenCmdAIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyA) {
    return ExecutionInstruction.continueExecution;
  }

  final didSelectAll = editContext.commonOps.selectAll();
  return didSelectAll ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction copyWhenCmdCIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection!.isCollapsed) {
    // Nothing to copy, but we technically handled the task.
    return ExecutionInstruction.haltExecution;
  }

  editContext.commonOps.copy();

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction cutWhenCmdXIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyX) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection!.isCollapsed) {
    // Nothing to cut, but we technically handled the task.
    return ExecutionInstruction.haltExecution;
  }

  editContext.commonOps.cut();

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction cmdBToToggleBold({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyB) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection!.isCollapsed) {
    editContext.commonOps.toggleComposerAttributions({boldAttribution});
    return ExecutionInstruction.haltExecution;
  } else {
    editContext.commonOps.toggleAttributionsOnSelection({boldAttribution});
    return ExecutionInstruction.haltExecution;
  }
}

ExecutionInstruction cmdIToToggleItalics({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyI) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection!.isCollapsed) {
    editContext.commonOps.toggleComposerAttributions({italicsAttribution});
    return ExecutionInstruction.haltExecution;
  } else {
    editContext.commonOps.toggleAttributionsOnSelection({italicsAttribution});
    return ExecutionInstruction.haltExecution;
  }
}

ExecutionInstruction anyCharacterOrDestructiveKeyToDeleteSelection({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null || editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (keyEvent.isControlPressed || keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }

  // Flutter reports a character for ESC, but we don't want to add a character
  // for ESC. Ignore this key press
  if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
    return ExecutionInstruction.continueExecution;
  }

  // Specifically exclude situations where shift is pressed because shift
  // needs to alter the selection, not delete content. We have to explicitly
  // look for this because when shift is pressed along with an arrow key,
  // Flutter reports a non-null character.
  if (keyEvent.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final isDestructiveKey =
      keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
  final isCharacterKey =
      keyEvent.character != null && keyEvent.character != '' && !isKeyEventCharacterBlacklisted(keyEvent.character);

  final shouldDeleteSelection = isDestructiveKey || isCharacterKey;
  if (!shouldDeleteSelection) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.commonOps.deleteSelection();

  if (isCharacterKey) {
    // We continue handler execution even though we deleted the selection.
    // If the user pressed a character key, we want to let the character entry
    // behavior run.
    return ExecutionInstruction.continueExecution;
  }

  // We deleted a selection in response to an explicit deletion key, e.g.,
  // BACKSPACE or DELETE. We don't want any other handlers to respond to
  // this key.
  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction backspaceToRemoveUpstreamContent({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.isMetaPressed || keyEvent.isAltPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final didDelete = editContext.commonOps.deleteUpstream();

  return didDelete ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction mergeNodeWithNextWhenDeleteIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! TextNode) {
    return ExecutionInstruction.continueExecution;
  }

  final nextNode = editContext.editor.document.getNodeAfter(node);
  if (nextNode == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (nextNode is! TextNode) {
    return ExecutionInstruction.continueExecution;
  }

  final currentParagraphLength = node.text.text.length;

  // Send edit command.
  editContext.editor.executeCommand(
    CombineParagraphsCommand(
      firstNodeId: node.id,
      secondNodeId: nextNode.id,
    ),
  );

  // Place the cursor at the point where the text came together.
  editContext.composer.selection = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: currentParagraphLength),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction moveUpDownLeftAndRightWithArrowKeys({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
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
      didMove = editContext.commonOps.moveCaretUpstream(
        expand: keyEvent.isShiftPressed,
        movementModifier: movementModifier,
      );
    } else {
      // Move the caret right/downstream.
      didMove = editContext.commonOps.moveCaretDownstream(
        expand: keyEvent.isShiftPressed,
        movementModifier: movementModifier,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    didMove = editContext.commonOps.moveCaretUp(expand: keyEvent.isShiftPressed);
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    didMove = editContext.commonOps.moveCaretDown(expand: keyEvent.isShiftPressed);
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction moveToLineStartOrEndWithCtrlAOrE({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (Platform.instance.isMac) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isControlPressed) {
    return ExecutionInstruction.continueExecution;
  }
  bool didMove = false;

  if (keyEvent.logicalKey == LogicalKeyboardKey.keyA) {
    didMove = editContext.commonOps.moveCaretUpstream(
      expand: keyEvent.isShiftPressed,
      movementModifier: MovementModifier.line,
    );
  }

  if (keyEvent.logicalKey == LogicalKeyboardKey.keyE) {
    didMove = editContext.commonOps.moveCaretDownstream(
      expand: keyEvent.isShiftPressed,
      movementModifier: MovementModifier.line,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction moveToLineStartWithHome({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.home) {
    didMove = editContext.commonOps.moveCaretUpstream(
      expand: keyEvent.isShiftPressed,
      movementModifier: MovementModifier.line,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction moveToLineEndWithEnd({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.end) {
    didMove = editContext.commonOps.moveCaretDownstream(
      expand: keyEvent.isShiftPressed,
      movementModifier: MovementModifier.line,
    );
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction deleteLineWithCmdBksp({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;

  didMove = editContext.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );

  if (didMove) {
    return editContext.commonOps.deleteSelection()
        ? ExecutionInstruction.haltExecution
        : ExecutionInstruction.continueExecution;
  }
  return ExecutionInstruction.continueExecution;
}

ExecutionInstruction deleteWordWithAltBksp({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isAltPressed || keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  bool didMove = false;

  didMove = editContext.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );

  if (didMove) {
    return editContext.commonOps.deleteSelection()
        ? ExecutionInstruction.haltExecution
        : ExecutionInstruction.continueExecution;
  }
  return ExecutionInstruction.continueExecution;
}

/// When the ESC key is pressed, the editor should collapse the expanded selection.
///
/// Do nothing if selection is already collapsed.
ExecutionInstruction collapseSelectionWhenEscIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.escape) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null || editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.commonOps.collapseSelection();
  return ExecutionInstruction.haltExecution;
}
