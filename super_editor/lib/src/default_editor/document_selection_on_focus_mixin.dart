import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Provides the functionality of updating the selection when the editor is focused.
/// 
/// It moves the caret to the end of the document or restores the last selection, 
/// if available.
mixin DocumentSelectionOnFocusMixin<T extends StatefulWidget> on State<T> {
  // Holds the last selection, so we can restore it when the editor is re-focused.
  DocumentSelection? _previousSelection;

  // Indicates if we are requesting focus by tapping the editor.
  bool requestingFocusByTap = false;

  FocusNode? _focusNode;
  DocumentComposer? _composer;
  DocumentLayoutResolver? _getDocumentLayout;

  /// Starts the behavior of updating the selection when the editor is focused.
  void startUpdateSelectionOnFocus({
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

  /// Stops the behavior of updating the selection when the editor is focused.
  void stopUpdateSelectionOnFocus() {
    _focusNode?.removeListener(_onFocusChange);
    _composer?.selectionNotifier.removeListener(_onSelectionChange);    
  }

  void _onFocusChange() {
    final shouldMoveSelection = !requestingFocusByTap;
    requestingFocusByTap = false;

    if (!_focusNode!.hasFocus || !shouldMoveSelection) {
      return;
    }

    // We move the selection in the next frame, so we don't try to access the
    // DocumentLayout before it is available when the editor has autofocus
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // We only update the selection when it's null
      // because, when the user taps at the document the selection is
      // already set to the correct position, so we don't override it.
      if (mounted && _focusNode!.hasFocus && _composer!.selection == null) {
        _updateDocumentSelection();
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

  void _updateDocumentSelection() {
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
}
