import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Governs document input that comes from a physical keyboard.
///
/// Keyboard input won't work on a mobile device with a software
/// keyboard because the software keyboard sends input through
/// the operating system's Input Method Engine. For mobile use-cases,
/// see super_editor's IME input support.

/// Receives all keyboard input, when focused, and invokes relevant document
/// editing actions on the given [editContext.editor].
///
/// [keyboardActions] determines the mapping from keyboard key presses
/// to document editing behaviors. [keyboardActions] operates as a
/// Chain of Responsibility.
class DocumentKeyboardInteractor extends StatelessWidget {
  const DocumentKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.editContext,
    required this.keyboardActions,
    required this.child,
    this.autofocus = false,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode focusNode;

  /// Whether or not the [DocumentKeyboardInteractor] should autofocus
  final bool autofocus;

  /// Service locator for document editing dependencies.
  final EditContext editContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> keyboardActions;

  /// The [child] widget, which is expected to include the document UI
  /// somewhere in the sub-tree.
  final Widget child;

  KeyEventResult _onKeyPressed(FocusNode node, RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      editorKeyLog.finer("Received key event, but ignoring because it's not a down event: $keyEvent");
      return KeyEventResult.handled;
    }

    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < keyboardActions.length) {
      instruction = keyboardActions[index](
        editContext: editContext,
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
/// a desired `ExecutionInstruction` to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// `ExecutionInstruction.continueExecution` to continue execution.
///
/// It is possible that an action does nothing and then returns
/// `ExecutionInstruction.haltExecution` to prevent further execution.
typedef DocumentKeyboardAction = ExecutionInstruction Function({
  required EditContext editContext,
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

/// A [DocumentKeyboardAction] that reports [ExecutionInstruction.blocked]
/// for any key combination that matches one of the given [keys].
DocumentKeyboardAction ignoreKeyCombos(List<ShortcutActivator> keys) {
  return ({
    required EditContext editContext,
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
