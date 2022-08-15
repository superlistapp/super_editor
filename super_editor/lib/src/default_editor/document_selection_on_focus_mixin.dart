import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Provides the functionality of updating the selection when the editor receives focus.
///
/// Whenever the editor receives focus, if it was previously selected, the previous selection
/// will be restored.
/// If there is no previous selection, the caret will move to the end of the document.
///
/// `startSyncingSelectionWithFocus` must be called to start this behavior and
/// `stopSyncingSelectionWithFocus` to stop it. 
/// 
/// Whenever the [FocusNode] of the widget using this mixin is replaced, `onFocusNodeReplaced` must be called.
/// 
/// Whenever the [DocumentComposer] of the widget using this mixin is replaced, `onDocumentComposerReplaced` must be called.
/// 
/// Whenever the [DocumentLayoutResolver] of the widget using this mixin is replaced, `onDocumentLayoutResolverReplaced` must be called.
mixin DocumentSelectionOnFocusMixin<T extends StatefulWidget> on State<T> {
  // Holds the last selection, so we can restore it when the editor is re-focused.
  DocumentSelection? _previousSelection;

  FocusNode? _focusNode;
  DocumentComposer? _composer;
  DocumentLayoutResolver? _getDocumentLayout;

  /// Starts the behavior of updating the selection when the editor is focused.
  void startSyncingSelectionWithFocus({
    required FocusNode focusNode,
    required DocumentComposer composer,
    required DocumentLayoutResolver getDocumentLayout,
  }) {
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
    _composer = composer;
    _composer!.selectionNotifier.addListener(_onSelectionChange);
    _getDocumentLayout = getDocumentLayout;
  }

  /// Stops the behavior of updating the selection when the editor is focused.
  void stopSyncingSelectionWithFocus() {
    _focusNode?.removeListener(_onFocusChange);
    _composer?.selectionNotifier.removeListener(_onSelectionChange);
  }

  /// Should be called whenever the editor `focusNode` is replaced.
  void onFocusNodeReplaced(FocusNode? focusNode) {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
  }

  /// Should be called whenever the editor `composer` is replaced.
  void onDocumentComposerReplaced(DocumentComposer? composer) {
    _composer?.removeListener(_onSelectionChange);
    _composer = composer;
    _composer!.addListener(_onSelectionChange);
  }

  /// Should be called whenever the [DocumentLayoutResolver] is replaced.
  void onDocumentLayoutResolverReplaced(DocumentLayoutResolver? layoutResolver) {
    _getDocumentLayout = layoutResolver;
  }

  void _onFocusChange() {
    if (!_focusNode!.hasFocus) {
      return;
    }

    // We move the selection in the next frame, so we don't try to access the
    // DocumentLayout before it is available when the editor has autofocus
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // We only update the selection when it's null
      // because, when the user taps at the document the selection is
      // already set to the correct position, so we don't override it.
      if (mounted && _focusNode!.hasFocus && _composer!.selection == null) {
        if (_previousSelection != null) {
          _composer?.selection = _previousSelection;
          return;
        }

        DocumentPosition? position = _getDocumentLayout?.call().findLastSelectablePosition();
        if (position != null) {
          _composer?.selection = DocumentSelection.collapsed(
            position: position,
          );
        }
      }
    });
  }

  void _onSelectionChange() {
    // We store the last selection so the next time the editor is focused
    // the selection is restored.
    if (_composer?.selection != null) {
      _previousSelection = _composer?.selection;
    }
  }
}
