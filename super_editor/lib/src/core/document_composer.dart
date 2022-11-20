import 'dart:async';

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
  })  : imeConfiguration = ValueNotifier(imeConfiguration ?? const ImeConfiguration()),
        _preferences = ComposerPreferences() {
    _streamController = StreamController<DocumentSelectionChange>.broadcast();
    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);
    selectionNotifier.value = initialSelection;
    _preferences.addListener(() {
      editorLog.fine("Composer preferences changed");
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _preferences.dispose();
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);
    super.dispose();
  }

  /// Returns the current [DocumentSelection] for a [Document].
  DocumentSelection? get selection => selectionNotifier.value;

  /// Sets the current [selection] for a [Document] using [SelectionReason.userInteraction] as the reason.
  set selection(DocumentSelection? newSelection) {
    if (newSelection != selectionNotifier.value) {
      selectionNotifier.value = newSelection;
      notifyListeners();
    }
  }

  /// Sets the current [selection] for a [Document].
  ///
  /// [reason] represents what caused the selection change to happen.
  void setSelectionWithReason(DocumentSelection? newSelection, [Object reason = SelectionReason.userInteraction]) {
    _latestSelectionChange = DocumentSelectionChange(
      selection: newSelection,
      reason: reason,
    );
    _streamController.sink.add(_latestSelectionChange);

    // Remove the listener, so we don't emit another DocumentSelectionChange.
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);

    // Updates the selection, so both _latestSelectionChange and selectionNotifier are in sync.
    selectionNotifier.value = newSelection;

    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);
  }

  /// Returns the reason for the most recent selection change in the composer.
  ///
  /// For example, a selection might change as a result of user interaction, or as
  /// a result of another user editing content, or some other reason.
  Object? get latestSelectionChangeReason => _latestSelectionChange.reason;

  /// Returns the most recent selection change in the composer.
  ///
  /// The [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  DocumentSelectionChange get latestSelectionChange => _latestSelectionChange;
  late DocumentSelectionChange _latestSelectionChange;

  /// A stream of document selection changes.
  ///
  /// Each new [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  ///
  /// Listen to this [Stream] when the selection reason is needed. Otherwise, use [selectionNotifier].
  Stream<DocumentSelectionChange> get selectionChanges => _streamController.stream;
  late StreamController<DocumentSelectionChange> _streamController;

  /// Notifies whenever the current [DocumentSelection] changes.
  ///
  /// If the selection change reason is needed, use [selectionChanges] instead.
  final selectionNotifier = ValueNotifier<DocumentSelection?>(null);

  /// Clears the current [selection].
  void clearSelection() {
    selection = null;
  }

  void _onSelectionChangedBySelectionNotifier() {
    _latestSelectionChange = DocumentSelectionChange(
      selection: selectionNotifier.value,
      reason: SelectionReason.userInteraction,
    );
    _streamController.sink.add(_latestSelectionChange);
  }

  final ValueNotifier<ImeConfiguration> imeConfiguration;

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

/// Represents a change of a [DocumentSelection].
///
/// The [reason] represents what cause the selection to change.
/// For example, [SelectionReason.userInteraction] represents
/// a selection change caused by the user interacting with the editor.
class DocumentSelectionChange {
  DocumentSelectionChange({
    this.selection,
    required this.reason,
  });

  final DocumentSelection? selection;
  final Object reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelectionChange && selection == other.selection && reason == other.reason;

  @override
  int get hashCode => (selection?.hashCode ?? 0) ^ reason.hashCode;
}

/// Holds common reasons for selection changes.
/// Developers aren't limited to these selection change reasons. Any object can be passed as
/// a reason for a selection change. However, some Super Editor behavior is based on [userInteraction].
class SelectionReason {
  /// Represents a change caused by an user interaction.
  static const userInteraction = "userInteraction";

  /// Represents a changed caused by an event which was not initiated by the user.
  static const contentChange = "contentChange";
}
