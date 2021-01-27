import 'package:flutter/material.dart';

import '../../../selection/editor_selection.dart';

class ParagraphEditorComponentSelection implements EditorComponentSelection {
  ParagraphEditorComponentSelection({
    @required TextSelection selection,
  }) : _selection = selection;

  TextSelection _selection;
  @override
  TextSelection get componentSelection => _selection;
  @override
  set componentSelection(dynamic newSelection) {
    if (newSelection != null && newSelection is! TextSelection) {
      print('Invalid selection type. Expected TextSelection but received ${newSelection.runtimeType}');
      return;
    }
    if (newSelection != _selection) {
      _selection = newSelection;
    }
  }

  @override
  bool get isCollapsed => _selection.isCollapsed;

  @override
  void collapse() {
    if (!_selection.isCollapsed) {
      print('Collapsing text selection from $_selection...');
      componentSelection = TextSelection.collapsed(offset: _selection.extentOffset);
      print('...to $componentSelection');
    }
  }

  @override
  void clear() {
    print('Clearing component selection. Was $componentSelection');
    componentSelection = TextSelection.collapsed(offset: -1);
  }
}
