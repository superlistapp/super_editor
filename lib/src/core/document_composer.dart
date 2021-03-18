import 'package:flutter/foundation.dart';

import 'document_selection.dart';

/// Maintains a `DocumentSelection` within a `Document` and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  /// Constructs a `DocumentComposer` with the given `initialSelection`.
  ///
  /// The `initialSelection` may be omitted if no initial selection is
  /// desired.
  DocumentComposer({
    DocumentSelection? initialSelection,
  })  : _selection = initialSelection,
        _preferences = ComposerPreferences() {
    _preferences.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  DocumentSelection? _selection;

  /// Returns the current `DocumentSelection` for a `Document`.
  DocumentSelection? get selection => _selection;

  /// Sets the current `selection` for a `Document`.
  set selection(DocumentSelection? newSelection) {
    if (newSelection != _selection) {
      _selection = newSelection;
      notifyListeners();
    }
  }

  /// Clears the current `selection`.
  void clearSelection() {
    selection = null;
  }

  final ComposerPreferences _preferences;

  /// Returns the composition preferences for this composer.
  ComposerPreferences get preferences => _preferences;
}

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<dynamic> _currentStyles = {};

  /// Returns the styles that should be applied to the next
  /// character that is entered in a `Document`.
  Set<dynamic> get currentStyles => _currentStyles;

  /// Adds `name` to `currentStyles`.
  void addStyle(dynamic name) {
    _currentStyles.add(name);
    notifyListeners();
  }

  /// Adds all `names` to `currentStyles`.
  void addStyles(Set<dynamic> names) {
    _currentStyles.addAll(names);
    notifyListeners();
  }

  /// Removes `name` from `currentStyles`.
  void removeStyle(dynamic name) {
    _currentStyles.remove(name);
    notifyListeners();
  }

  /// Removes all `names` from `currentStyles`.
  void removeStyles(Set<dynamic> names) {
    _currentStyles.removeAll(names);
    notifyListeners();
  }

  /// Adds or removes `name` to/from `currentStyles` depending
  /// on whether `name` is already in `currentStyles`.
  void toggleStyle(dynamic name) {
    if (_currentStyles.contains(name)) {
      _currentStyles.remove(name);
    } else {
      _currentStyles.add(name);
    }
    notifyListeners();
  }

  /// Removes all styles from `currentStyles`.
  void clearStyles() {
    _currentStyles.clear();
    notifyListeners();
  }
}
