import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_selection.dart';

/// Maintains a [DocumentSelection] within a [Document] and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  /// Constructs a [DocumentComposer] with the given [initialSelection].
  ///
  /// The [initialSelection] may be omitted if no initial selection is
  /// desired.
  DocumentComposer({
    DocumentSelection? initialSelection,
    ImeConfiguration? imeConfiguration,
  })  : _selection = initialSelection,
        imeConfiguration = ValueNotifier(imeConfiguration ?? const ImeConfiguration()),
        _preferences = ComposerPreferences() {
    _preferences.addListener(() {
      editorLog.fine("Composer preferences changed");
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  DocumentSelection? _selection;

  /// Returns the current [DocumentSelection] for a [Document].
  DocumentSelection? get selection => _selection;

  /// Sets the current [selection] for a [Document].
  set selection(DocumentSelection? newSelection) {
    if (newSelection != _selection) {
      _selection = newSelection;
      selectionNotifier.value = newSelection;
      notifyListeners();
    }
  }

  final selectionNotifier = ValueNotifier<DocumentSelection?>(null);

  /// Clears the current [selection].
  void clearSelection() {
    selection = null;
  }

  final _nonPrimarySelections = <String, NonPrimarySelection>{};
  final _nonPrimarySelectionListeners = <NonPrimarySelectionListener>{};

  /// Returns the [NonPrimarySelection] for the given [id], or `null` if no
  /// such selection exists in the composer.
  DocumentSelection? getNonPrimarySelectionById(String id) {
    return _nonPrimarySelections[id]?.selection;
  }

  /// Returns all the [NonPrimarySelection]s in the composer.
  Set<NonPrimarySelection> getAllNonPrimarySelections() {
    return _nonPrimarySelections.values.toSet();
  }

  /// Puts the given [selection] in the composer as a [NonPrimarySelection]
  /// with the given [id].
  ///
  /// If the given [selection] is `null`, the corresponding [NonPrimarySelection]
  /// is removed from the composer.
  void setNonPrimarySelection(String id, DocumentSelection? selection) {
    if (selection != null) {
      final nonPrimarySelection = NonPrimarySelection(id, selection);
      if (_nonPrimarySelections.containsKey(id)) {
        // Update an existing selection.
        _nonPrimarySelections[id] = nonPrimarySelection;
        _notifyNonPrimarySelectionChange(nonPrimarySelection);
      } else {
        // This is a new selection.
        _nonPrimarySelections[id] = nonPrimarySelection;
        _notifyNonPrimarySelectionAdded(nonPrimarySelection);
      }
    } else if (_nonPrimarySelections.containsKey(id)) {
      // Remove an existing selection.
      _nonPrimarySelections.remove(id);
      _notifyNonPrimarySelectionRemoval(id);
    }
  }

  /// Adds the given [listener] to the composer.
  void addNonPrimarySelectionListener(NonPrimarySelectionListener listener) {
    _nonPrimarySelectionListeners.add(listener);
  }

  /// Removes the given [listener] from the composer.
  void removeNonPrimarySelectionListener(NonPrimarySelectionListener listener) {
    _nonPrimarySelectionListeners.remove(listener);
  }

  void _notifyNonPrimarySelectionAdded(NonPrimarySelection selection) {
    for (final listener in _nonPrimarySelectionListeners) {
      listener.onSelectionAdded(selection);
    }
  }

  void _notifyNonPrimarySelectionChange(NonPrimarySelection selection) {
    for (final listener in _nonPrimarySelectionListeners) {
      listener.onSelectionChanged(selection);
    }
  }

  void _notifyNonPrimarySelectionRemoval(String id) {
    for (final listener in _nonPrimarySelectionListeners) {
      listener.onSelectionRemoved(id);
    }
  }

  final ValueNotifier<ImeConfiguration> imeConfiguration;

  final ComposerPreferences _preferences;

  /// Returns the composition preferences for this composer.
  ComposerPreferences get preferences => _preferences;
}

/// A selection within a document that's owned by an actor that's not the
/// primary user.
class NonPrimarySelection {
  const NonPrimarySelection(this.id, this.selection);

  /// ID of the actor responsible for this selection.
  ///
  /// The actor may, or may not be a human user.
  final String id;

  /// A selection within a document.
  final DocumentSelection selection;
}

/// Listener for changes to non-primary user selections.
abstract class NonPrimarySelectionListener {
  /// The given [selection] was added to the composer.
  void onSelectionAdded(NonPrimarySelection selection);

  /// An existing selection was changed to the new [selection].
  void onSelectionChanged(NonPrimarySelection selection);

  /// The selection with the given [id] was removed from the document.
  void onSelectionRemoved(String id);
}

/// A [NonPrimarySelectionListener] that delegates to given callbacks.
abstract class CallbackNonPrimarySelectionListener implements NonPrimarySelectionListener {
  CallbackNonPrimarySelectionListener({
    void Function(NonPrimarySelection selection)? onSelectionAdded,
    void Function(NonPrimarySelection selection)? onSelectionChanged,
    void Function(String id)? onSelectionRemoved,
  })  : _onSelectionAdded = onSelectionAdded,
        _onSelectionChanged = onSelectionChanged,
        _onSelectionRemoved = onSelectionRemoved;

  final void Function(NonPrimarySelection selection)? _onSelectionAdded;
  @override
  void onSelectionAdded(NonPrimarySelection selection) => _onSelectionAdded?.call(selection);

  final void Function(NonPrimarySelection selection)? _onSelectionChanged;
  @override
  void onSelectionChanged(NonPrimarySelection selection) => _onSelectionChanged?.call(selection);

  final void Function(String id)? _onSelectionRemoved;
  @override
  void onSelectionRemoved(String id) => _onSelectionRemoved?.call(id);
}

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<Attribution> _currentAttributions = {};

  /// Returns the styles that should be applied to the next
  /// character that is entered in a [Document].
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

  /// Removes all styles from [currentAttributions].
  void clearStyles() {
    _currentAttributions.clear();
    notifyListeners();
  }
}
