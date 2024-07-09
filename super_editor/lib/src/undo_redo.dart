import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

/// Undoes the most recent change within the [Editor].
ExecutionInstruction undoWhenCmdZOrCtrlZIsPressed({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.keyZ ||
      !keyEvent.isPrimaryShortcutKeyPressed ||
      HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.undo();

  return ExecutionInstruction.haltExecution;
}

/// Re-runs the most recently undone change within the [Editor].
ExecutionInstruction redoWhenCmdShiftZOrCtrlShiftZIsPressed({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.keyZ ||
      !keyEvent.isPrimaryShortcutKeyPressed ||
      !HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.redo();

  return ExecutionInstruction.haltExecution;
}
