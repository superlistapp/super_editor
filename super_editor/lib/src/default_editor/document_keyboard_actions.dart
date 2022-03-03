import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

import 'document_input_keyboard.dart';
import 'paragraph.dart';
import 'text.dart';

final _log = Logger(scope: 'document_keyboard_actions.dart');

ExecutionInstruction doNothingWhenThereIsNoSelection({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null) {
    _log.log('doNothingWhenThereIsNoSelection', ' - no selection. Returning.');
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

  _log.log('pasteWhenCmdVIsPressed', 'Pasting clipboard content...');
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
  _log.log('deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed', 'Running...');
  if (editContext.composer.selection == null || editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (keyEvent.isControlPressed || keyEvent.isMetaPressed) {
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
      keyEvent.character != null && keyEvent.character != '' && !webBugBlacklistCharacters.contains(keyEvent.character);

  final shouldDeleteSelection = isDestructiveKey || isCharacterKey;
  if (!shouldDeleteSelection) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.commonOps.deleteSelection();

  // If the user pressed a character, insert it.
  String? character = keyEvent.character;
  // On web, keys like shift and alt are sending their full name
  // as a character, e.g., "Shift" and "Alt". This check prevents
  // those keys from inserting their name into content.
  //
  // This filter is a blacklist, and therefore it will fail to
  // catch any key that isn't explicitly listed. The eventual solution
  // to this is for the web to honor the standard key event contract,
  // but that's out of our control.
  if (character != null && (!kIsWeb || webBugBlacklistCharacters.contains(character))) {
    // The web reports a tab as "Tab". Intercept it and translate it to a space.
    if (character == 'Tab') {
      character = ' ';
    }

    editContext.commonOps.insertCharacter(character);
  }

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction backspaceToRemoveUpstreamContent({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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
    _log.log('mergeNodeWithNextWhenDeleteIsPressed', 'WARNING: Cannot combine node of type: $node');
    return ExecutionInstruction.continueExecution;
  }

  final nextNode = editContext.editor.document.getNodeAfter(node);
  if (nextNode == null) {
    _log.log('mergeNodeWithNextWhenDeleteIsPressed', 'At bottom of document. Cannot merge with node above.');
    return ExecutionInstruction.continueExecution;
  }
  if (nextNode is! TextNode) {
    _log.log('mergeNodeWithNextWhenDeleteIsPressed', 'Cannot merge ParagraphNode into node of type: $nextNode');
    return ExecutionInstruction.continueExecution;
  }

  _log.log('mergeNodeWithNextWhenDeleteIsPressed', 'Combining node with next.');
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

  bool didMove = false;
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft || keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling left arrow key');

    final movementModifiers = <MovementModifier>{};
    if (keyEvent.isPrimaryShortcutKeyPressed) {
      movementModifiers.add(MovementModifier.line);
    } else if (keyEvent.isAltPressed) {
      movementModifiers.add(MovementModifier.word);
    }

    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Move the caret left/upstream.
      didMove = editContext.commonOps.moveCaretUpstream(
        expand: keyEvent.isShiftPressed,
        movementModifiers: movementModifiers,
      );
    } else {
      // Move the caret right/downstream.
      didMove = editContext.commonOps.moveCaretDownstream(
        expand: keyEvent.isShiftPressed,
        movementModifiers: movementModifiers,
      );
    }
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling up arrow key');

    didMove = editContext.commonOps.moveCaretUp(expand: keyEvent.isShiftPressed);
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling down arrow key');

    didMove = editContext.commonOps.moveCaretDown(expand: keyEvent.isShiftPressed);
  }

  return didMove ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}
