// TODO: get rid of this import
import 'package:example/spikes/editor_abstractions/default_editor/text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'document.dart';
import 'document_selection.dart';

/// Maintains a `DocumentSelection` within a `Document` and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  DocumentComposer({
    @required Document document,
    DocumentSelection initialSelection,
  })  : _document = document,
        _selection = ValueNotifier(initialSelection) {
    _selection.addListener(() {
      print('DocumentComposer: selection changed.');
      _updateComposerPreferencesAtSelection();
      notifyListeners();
    });
  }

  final Document _document;

  final ValueNotifier<DocumentSelection> _selection;

  DocumentSelection get selection => _selection.value;

  set selection(DocumentSelection newSelection) {
    if (newSelection != _selection.value) {
      _selection.value = newSelection;
    }
  }

  void clearSelection() {
    selection = null;
  }

  final ComposerPreferences _preferences = ComposerPreferences();

  ComposerPreferences get preferences => _preferences;

  // TODO: this text selection logic probably belongs in some place
  //       that is specific to text content
  void _updateComposerPreferencesAtSelection() {
    _preferences.clearStyles();

    if (_selection.value == null || !_selection.value.isCollapsed) {
      return;
    }

    final node = _document.getNodeById(_selection.value.extent.nodeId);
    if (node is! TextNode) {
      return;
    }

    final textPosition = _selection.value.extent.nodePosition as TextPosition;
    if (textPosition.offset == 0) {
      return;
    }

    print('Looking up styles. Caret at: ${textPosition.offset}, looking back one place at: ${textPosition.offset - 1}');
    final allStyles = (node as TextNode).text.getAllAttributionsAt(textPosition.offset - 1);
    print(' - styles: $allStyles');
    _preferences.addStyles(allStyles);
  }
}

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<dynamic> _currentStyles = {};
  Set<dynamic> get currentStyles => _currentStyles;

  void addStyle(dynamic name) {
    _currentStyles.add(name);
    notifyListeners();
  }

  void addStyles(Set<dynamic> names) {
    _currentStyles.addAll(names);
    notifyListeners();
  }

  void removeStyle(dynamic name) {
    _currentStyles.remove(name);
    notifyListeners();
  }

  void removeStyles(Set<dynamic> names) {
    _currentStyles.removeAll(names);
    notifyListeners();
  }

  void toggleStyle(dynamic name) {
    if (_currentStyles.contains(name)) {
      _currentStyles.remove(name);
    } else {
      _currentStyles.add(name);
    }
    notifyListeners();
  }

  void clearStyles() {
    _currentStyles.clear();
    notifyListeners();
  }
}
