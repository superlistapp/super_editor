import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Widget that applies policies to an editor's focus and selection, such as placing the
/// caret at the end of a document when the editor receives focus, and clearing the
/// selection when the editor loses focus.
class EditorSelectionAndFocusPolicy extends StatefulWidget {
  const EditorSelectionAndFocusPolicy({
    Key? key,
    required this.focusNode,
    required this.selection,
    required this.getDocumentLayout,
    this.placeCaretAtEndOfDocumentOnGainFocus = true,
    this.restorePreviousSelectionOnGainFocus = true,
    this.clearSelectionWhenEditorLosesFocus = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode].
  ///
  /// When focus is lost, this widget may clear the editor's selection.
  final FocusNode focusNode;

  /// The document editor's current selection.
  final ValueNotifier<DocumentSelection?> selection;

  /// Document layout, used to locate the last selectable piece of content in a document,
  /// which is needed for [placeCaretAtEndOfDocumentOnGainFocus].
  final DocumentLayoutResolver getDocumentLayout;

  /// Whether the editor should automatically place the caret at the end of the document,
  /// if the editor receives focus without an existing selection.
  ///
  /// [restorePreviousSelectionOnGainFocus] takes priority over this policy.
  final bool placeCaretAtEndOfDocumentOnGainFocus;

  /// Whether the editor's previous selection should be restored when the editor re-gains
  /// focus, after having previous lost focus.
  final bool restorePreviousSelectionOnGainFocus;

  /// Whether the editor's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  final Widget child;

  @override
  State<EditorSelectionAndFocusPolicy> createState() => _EditorSelectionAndFocusPolicyState();
}

class _EditorSelectionAndFocusPolicyState extends State<EditorSelectionAndFocusPolicy> {
  bool _wasFocused = false;
  DocumentSelection? _previousSelection;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _wasFocused = widget.focusNode.hasFocus;

    widget.selection.addListener(_onSelectionChange);
    _previousSelection = widget.selection.value;
  }

  @override
  void didUpdateWidget(EditorSelectionAndFocusPolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _onFocusChange();
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onFocusChange);
      widget.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.selection.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onFocusChange() {
    // Ensure the editor has a selection when focused.
    if (!_wasFocused && widget.focusNode.hasFocus) {
      if (widget.restorePreviousSelectionOnGainFocus && _previousSelection != null) {
        // Restore the previous selection.
        editorPoliciesLog
            .info("[${widget.runtimeType}] - restoring previous editor selection because the editor re-gained focus");
        widget.selection.value = _previousSelection;
      } else if (widget.placeCaretAtEndOfDocumentOnGainFocus) {
        // Place the caret at the end of the document.
        editorPoliciesLog
            .info("[${widget.runtimeType}] - placing caret at end of document because the editor gained focus");
        DocumentPosition? position = widget.getDocumentLayout().findLastSelectablePosition();
        if (position != null) {
          widget.selection.value = DocumentSelection.collapsed(
            position: position,
          );
        }
      }
    }

    // (Maybe) remove the editor's selection when it loses focus.
    if (!widget.focusNode.hasFocus && widget.clearSelectionWhenEditorLosesFocus) {
      editorPoliciesLog.info("[${widget.runtimeType}] - clearing editor selection because the editor lost all focus");
      widget.selection.value = null;
    }

    _wasFocused = widget.focusNode.hasFocus;
  }

  void _onSelectionChange() {
    // TODO: avoiding null selections isn't always the right thing to do. If the editor purposefully clears
    //       its selection, we wouldn't want to restore the previous selection when focus changes.
    if (widget.selection.value != null) {
      _previousSelection = widget.selection.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
