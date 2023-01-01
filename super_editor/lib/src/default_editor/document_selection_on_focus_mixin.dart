import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Synchronizes document focus with document selection.
///
/// Whenever the editor receives focus, if it was previously selected, the previous selection is restored.
///
/// If there is no previous selection, the caret is moved to the end of the document.
///
/// Start watching and synchronizing focus with selection by calling `startSyncingSelectionWithFocus`.
///
/// Stop watching and synchronizing focus with selection by calling `stopSyncingSelectionWithFocus`.
///
/// When the document's [FocusNode] changes, provide the new [FocusNode] to [onFocusNodeReplaced].
///
/// When the document's [DocumentComposer] changes, provide the new [DocumentComposer] to [onDocumentSelectionNotifierReplaced].
///
/// When the document's [DocumentLayoutResolver] changes, provide the new [DocumentLayoutResolver] to [onDocumentLayoutResolverReplaced].
mixin DocumentSelectionOnFocusMixin<T extends StatefulWidget> on State<T> {
  // Holds the last selection, so we can restore it when the editor is re-focused.
  DocumentSelection? _previousSelection;

  FocusNode? _focusNode;
  DocumentLayoutResolver? _getDocumentLayout;
  ValueNotifier<DocumentSelection?>? _selection;

  /// Starts watching and synchronizing focus with selection.
  ///
  /// Watches the document selection, so it can be restored after
  /// the editor receives focus.
  ///
  /// If the previous selection isn't avaible when the editor receives focus,
  /// the caret is moved to the end of the document.
  void startSyncingSelectionWithFocus({
    required FocusNode focusNode,
    required DocumentLayoutResolver getDocumentLayout,
    required ValueNotifier<DocumentSelection?> selection,
  }) {
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
    _getDocumentLayout = getDocumentLayout;
    _selection = selection;
    _selection!.addListener(_onSelectionChange);

    // If we already start focused we need to check if the selection update is needed.
    // This is happening on desktop when the editor uses autofocus.
    if (focusNode.hasFocus) {
      _onFocusChange();
    }
  }

  // Stops watching and synchronizing focus with selection.
  void stopSyncingSelectionWithFocus() {
    _focusNode?.removeListener(_onFocusChange);
    _selection?.removeListener(_onSelectionChange);
  }

  /// Should be called whenever the editor `focusNode` is replaced.
  void onFocusNodeReplaced(FocusNode? focusNode) {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
  }

  /// Should be called whenever the editor selection notifier is replaced.
  void onDocumentSelectionNotifierReplaced(ValueNotifier<DocumentSelection?>? selection) {
    _selection?.removeListener(_onSelectionChange);
    _selection = selection;
    _selection?.addListener(_onSelectionChange);
  }

  /// Should be called whenever the [DocumentLayoutResolver] is replaced.
  void onDocumentLayoutResolverReplaced(DocumentLayoutResolver? layoutResolver) {
    _getDocumentLayout = layoutResolver;
  }

  void _onFocusChange() {
    print("SuperEditor focus change. Is focused? ${_focusNode?.hasFocus}. Previous selection: $_previousSelection");
    if (!_focusNode!.hasFocus) {
      _selection?.value = null;
      return;
    }

    // We move the selection in the next frame, so we don't try to access the
    // DocumentLayout before it is available when the editor has autofocus
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      print("On next frame. Has focus? ${_focusNode!.hasFocus}, Current selection :${_selection!.value}");
      if (!mounted) {
        return;
      }

      if (!_focusNode!.hasFocus || _selection!.value != null) {
        return;
      }

      // The editor has focus, but there's no selection. Whenever the editor
      // is focused, there needs to be a place for user input to go. Place
      // the caret at the end of the document.
      if (_previousSelection != null) {
        print("Restoring previous selection");
        _selection?.value = _previousSelection;
        return;
      }

      print("Placing caret at end of document because we didn't have a previous selection");
      DocumentPosition? position = _getDocumentLayout?.call().findLastSelectablePosition();
      if (position != null) {
        _selection?.value = DocumentSelection.collapsed(
          position: position,
        );
      }
    });
  }

  void _onSelectionChange() {
    print("On selection change");
    // We store the last selection so the next time the editor is focused
    // the selection is restored.
    if (_selection?.value != null) {
      print("Setting previous selection to :${_selection?.value}");
      _previousSelection = _selection?.value;
      print("Previous selection is now: $_previousSelection");
    }
  }
}
