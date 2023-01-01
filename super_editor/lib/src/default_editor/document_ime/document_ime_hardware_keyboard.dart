import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/document_input_keyboard.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

/// Applies appropriate edits to a document and selection when the user presses
/// hardware keys during IME editing.
///
/// Hardware key events are dispatched through [FocusNode]s, therefore, this
/// widget's [FocusNode] needs to be focused for key events to be applied. A
/// [FocusNode] can be provided, or this widget will create its own [FocusNode]
/// internally, which is wrapped around the given [child].
///
/// Flutter reports certain IME key presses as if they were physical key presses.
/// For example, we might receive arrow key or tab presses through the standard
/// hardware key reporting system, even though the user is typing on a software
/// keyboard.
class DocumentImeHardwareKeyEditor extends StatefulWidget {
  const DocumentImeHardwareKeyEditor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    this.hardwareKeyboardActions = const [],
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  final EditContext editContext;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  final Widget child;

  @override
  State<DocumentImeHardwareKeyEditor> createState() => _DocumentImeHardwareKeyEditorState();
}

class _DocumentImeHardwareKeyEditorState extends State<DocumentImeHardwareKeyEditor> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKeyPressed(FocusNode node, RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      editorKeyLog.finer("Received key event, but ignoring because it's not a down event: $keyEvent");
      return KeyEventResult.handled;
    }

    editorKeyLog.fine("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < widget.hardwareKeyboardActions.length) {
      instruction = widget.hardwareKeyboardActions[index](
        editContext: widget.editContext,
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
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: widget.hardwareKeyboardActions.isEmpty ? null : _onKeyPressed,
      child: widget.child,
    );
  }
}
