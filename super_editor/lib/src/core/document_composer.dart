import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_editor.dart';
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
  })  : selectionComponent = SelectionComponent(initialSelection),
        imeConfiguration = ValueNotifier(imeConfiguration ?? const ImeConfiguration()),
        _preferences = ComposerPreferences() {
    _preferences.addListener(() {
      editorLog.fine("Composer preferences changed");
      notifyListeners();
    });
  }

  @override
  void dispose() {
    selectionComponent.dispose();
    _preferences.dispose();
    super.dispose();
  }

  final SelectionComponent selectionComponent;

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

/// [EditorRequest] that changes the [DocumentSelection] to the given [newSelection].
class ChangeSelectionRequest implements EditorRequest {
  const ChangeSelectionRequest(
    this.newSelection,
    this.reason, {
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  /// The reason that the selection changed, such as "user interaction".
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeSelectionRequest &&
          runtimeType == other.runtimeType &&
          newSelection == other.newSelection &&
          notifyListeners == other.notifyListeners &&
          reason == other.reason;

  @override
  int get hashCode => newSelection.hashCode ^ notifyListeners.hashCode ^ reason.hashCode;
}

/// An [EditorCommand] that changes the [DocumentSelection] in the [DocumentComposer]
/// to the [newSelection].
class ChangeSelectionCommand implements EditorCommand {
  const ChangeSelectionCommand(
    this.newSelection,
    this.reason, {
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  final String reason;

  @override
  void execute(EditorContext context, RequestDispatcher requestDispatcher, CommandExecutor executor) {
    final composer = context.find<DocumentComposer>(EditorContext.composer);
    final initialSelection = composer.selectionComponent.selection;
    composer.selectionComponent.updateSelection(
      newSelection,
      notifyListeners: notifyListeners,
    );
    executor.logChanges([
      SelectionChangeEvent(
        oldSelection: initialSelection,
        newSelection: newSelection,
        reason: reason,
      )
    ]);
  }
}

/// A [DocumentChangeEvent] that represents a change to the user's selection within a document.
class SelectionChangeEvent implements DocumentChangeEvent {
  const SelectionChangeEvent({
    required this.oldSelection,
    required this.newSelection,
    required this.reason,
  });

  final DocumentSelection? oldSelection;
  final DocumentSelection? newSelection;
  final String reason;

  @override
  String toString() => "[SelectionChangeEvent] - New selection: $newSelection";
}
