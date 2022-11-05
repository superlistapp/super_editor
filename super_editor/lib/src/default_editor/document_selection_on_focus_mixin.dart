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
  DocumentSelectionChange? _previousSelection;

  FocusNode? _focusNode;
  DocumentLayoutResolver? _getDocumentLayout;
  late ValueNotifier<DocumentSelectionChange> _selectionChange;

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
    required ValueNotifier<DocumentSelectionChange> selectionChange,
  }) {
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
    _getDocumentLayout = getDocumentLayout;
    _selectionChange = selectionChange;
    _selectionChange.addListener(_onSelectionChange);

    // If we already start focused we need to check if the selection update is needed.
    // This is happening on desktop when the editor uses autofocus.
    if (focusNode.hasFocus) {
      _onFocusChange();
    }
  }

  // Stops watching and synchronizing focus with selection.
  void stopSyncingSelectionWithFocus() {
    _focusNode?.removeListener(_onFocusChange);
    _selectionChange.removeListener(_onSelectionChange);
  }

  /// Should be called whenever the editor `focusNode` is replaced.
  void onFocusNodeReplaced(FocusNode? focusNode) {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
  }

  /// Should be called whenever the editor selection notifier is replaced.
  void onDocumentSelectionNotifierReplaced(ValueNotifier<DocumentSelectionChange> selection) {
    _selectionChange.removeListener(_onSelectionChange);
    _selectionChange = selection;
    _selectionChange.addListener(_onSelectionChange);
  }

  /// Should be called whenever the [DocumentLayoutResolver] is replaced.
  void onDocumentLayoutResolverReplaced(DocumentLayoutResolver? layoutResolver) {
    _getDocumentLayout = layoutResolver;
  }

  void _onFocusChange() {
    if (!_focusNode!.hasFocus) {
      _selectionChange.value = DocumentSelectionChange();
      return;
    }

    // We move the selection in the next frame, so we don't try to access the
    // DocumentLayout before it is available when the editor has autofocus
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // We only update the selection when it's null
      // because, when the user taps at the document the selection is
      // already set to the correct position, so we don't override it.
      if (mounted && _focusNode!.hasFocus && _selectionChange.value.selection == null) {
        if (_previousSelection != null) {
          _selectionChange.value = _previousSelection ?? DocumentSelectionChange();
          return;
        }

        DocumentPosition? position = _getDocumentLayout?.call().findLastSelectablePosition();
        if (position != null) {
          _selectionChange.value = DocumentSelectionChange(
            selection: DocumentSelection.collapsed(
              position: position,
            ),
          );
        }
      }
    });
  }

  void _onSelectionChange() {
    // We store the last selection so the next time the editor is focused
    // the selection is restored.
    if (_selectionChange.value.selection != null) {
      _previousSelection = _selectionChange.value;
    }
  }
}
