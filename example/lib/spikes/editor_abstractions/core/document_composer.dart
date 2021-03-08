// TODO: get rid of this import
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'document_selection.dart';

/// Maintains a `DocumentSelection` within a `Document` and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  DocumentComposer({
    DocumentSelection initialSelection,
  })  : _selection = ValueNotifier(initialSelection),
        _preferences = ComposerPreferences() {
    _selection.addListener(() {
      print('DocumentComposer: selection changed.');
      // _updateComposerPreferencesAtSelection();
      notifyListeners();
    });

    _preferences.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _selection.dispose();
    _preferences.dispose();
    super.dispose();
  }

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

  final ComposerPreferences _preferences;

  ComposerPreferences get preferences => _preferences;
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
