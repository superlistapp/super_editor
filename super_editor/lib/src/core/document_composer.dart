import 'package:flutter/foundation.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';

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
  final Set<Attribution> _currentAttributions = {};

  /// Returns the styles that should be applied to the next
  /// character that is entered in a `Document`.
  Set<Attribution> get currentAttributions => _currentAttributions;

  /// Adds [attribution] to [currentAttributions].
  void addStyle(Attribution attribution) {
    _currentAttributions.add(attribution);
    notifyListeners();
  }

  /// Adds all [attributions] to [currentAttributions].
  void addStyles(Set<Attribution> attributions) {
    _currentAttributions.addAll(attributions);
    notifyListeners();
  }

  /// Removes [attributions] from [currentAttributions].
  void removeStyle(Attribution attributions) {
    _currentAttributions.remove(attributions);
    notifyListeners();
  }

  /// Removes all [attributions] from [currentAttributions].
  void removeStyles(Set<Attribution> attributions) {
    _currentAttributions.removeAll(attributions);
    notifyListeners();
  }

  /// Adds or removes [attribution] to/from [currentAttributions] depending
  /// on whether [attribution] is already in [currentAttributions].
  void toggleStyle(Attribution attribution) {
    if (_currentAttributions.contains(attribution)) {
      _currentAttributions.remove(attribution);
    } else {
      _currentAttributions.add(attribution);
    }
    notifyListeners();
  }

  /// Adds or removes all [attributions] to/from [currentAttributions] depending
  /// on whether each attribution is already in [currentAttributions].
  void toggleStyles(Set<Attribution> attributions) {
    for (final attribution in attributions) {
      if (_currentAttributions.contains(attribution)) {
        _currentAttributions.remove(attribution);
      } else {
        _currentAttributions.add(attribution);
      }
    }
    notifyListeners();
  }

  /// Removes all styles from `currentStyles`.
  void clearStyles() {
    _currentAttributions.clear();
    notifyListeners();
  }
}
