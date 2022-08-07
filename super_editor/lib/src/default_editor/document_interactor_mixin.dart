import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Mixin for common operations on document interactors
mixin DocumentInteractorMixin<T extends StatefulWidget> on State<T> {
  // Holds the last selection, so we can restore it when the editor is re-focused.
  DocumentSelection? _previousSelection;

  // Indicates if we are requesting focus by tapping the editor.
  bool requestingFocusByTap = false;

  FocusNode? _focusNode;
  DocumentComposer? _composer;
  DocumentLayout Function()? _getDocumentLayout;

  /// Initializes the mixin internal state. Should be called at `initState`.
  void initDocumentInteractorMixin({
    required FocusNode focusNode,
    required DocumentComposer composer,
    required DocumentLayout Function() getDocumentLayout,
  }) {
    _focusNode = focusNode;
    _focusNode!.addListener(_onFocusChange);
    _composer = composer;
    _composer!.selectionNotifier.addListener(_onSelectionChange);
    _getDocumentLayout = getDocumentLayout;
  }

  /// Updates the mixin internal state. Should be called at `didUpdateWidget`.
  void updateDocumentInteractorMixin({
    required FocusNode focusNode,
    required DocumentComposer composer,
    required DocumentLayout Function() getDocumentLayout,
  }) {
    if (_focusNode != focusNode) {
      _focusNode?.removeListener(_onFocusChange);
      _focusNode = focusNode;
      _focusNode!.addListener(_onFocusChange);
    }
    if (_composer != composer){
      _composer?.removeListener(_onSelectionChange);
      _composer = composer;
      _composer!.addListener(_onSelectionChange);
    }
    _getDocumentLayout = getDocumentLayout;
  }

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocusChange);
    _composer?.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
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
      if (mounted && _focusNode!.hasFocus && _composer!.selection == null) {
        _moveSelectionAfterFocus();
      }
    });
  }

  void _onSelectionChange() {
    if (_composer?.selection != null) {
      _previousSelection = _composer?.selection;
    }
  }

  DocumentSelection? _findNewSelectionAfterFocus(DocumentLayout? layout) {
    if (_previousSelection != null) {
      return _previousSelection!;
    }

    DocumentPosition? position = layout?.findLastSelectablePosition();

    if (position == null) {
      return null;
    }

    return DocumentSelection.collapsed(
      position: position,
    );
  }

  void _moveSelectionAfterFocus() {
    final newSelection = _findNewSelectionAfterFocus(_getDocumentLayout?.call());
    if (newSelection != null) {
      _composer?.selection = newSelection;
    }
  }
}
