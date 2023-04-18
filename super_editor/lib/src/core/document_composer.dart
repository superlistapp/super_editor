import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'editor.dart';
import 'document_selection.dart';

/// Maintains a [DocumentSelection] within a [Document] and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier implements Editable {
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

  @override
  void onTransactionStart() {
    // no-op
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {
    if (!edits.any((edit) => edit is SelectionChangeEvent)) {
      return;
    }

    selectionComponent.notifySelectionListeners();
  }
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

/// A [ChangeSelectionRequest] that represents a user's desire to push the caret upstream
/// or downstream, such as when pressing LEFT or RIGHT.
///
/// It's useful to capture the user's desire to push the caret because sometimes the caret
/// needs to jump past a piece of content that doesn't allow partial selection, such as a
/// user tag. In the case of pushing the caret, we know which direction to jump over that
/// content.
class PushCaretRequest extends ChangeSelectionRequest {
  PushCaretRequest(
    DocumentPosition newPosition,
    this.direction,
  ) : super(DocumentSelection.collapsed(position: newPosition), SelectionChangeType.pushCaret,
            SelectionReason.userInteraction);

  final TextAffinity direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is PushCaretRequest && runtimeType == other.runtimeType && direction == other.direction;

  @override
  int get hashCode => super.hashCode ^ direction.hashCode;
}

/// A [ChangeSelectionRequest] that represents a user's desire to expand an existing selection
/// further upstream or downstream, such as when pressing SHIFT+LEFT or SHIFT+RIGHT.
///
/// It's useful to capture the user's desire to expand the current selection because sometimes
/// the selection needs to jump past a piece of content that doesn't allow partial selection,
/// such as a user tag. In the case of expanding the selection, we know which direction to jump
/// over that content.
class ExpandSelectionRequest extends ChangeSelectionRequest {
  const ExpandSelectionRequest(
    DocumentSelection newSelection,
  ) : super(newSelection, SelectionChangeType.expandSelection, SelectionReason.userInteraction);
}

/// A [ChangeSelectionRequest] that represents a user's desire to expand an existing selection
/// further upstream or downstream, such as when pressing SHIFT+LEFT or SHIFT+RIGHT.
///
/// It's useful to capture the user's desire to expand the current selection because sometimes
/// the selection needs to jump past a piece of content that doesn't allow partial selection,
/// such as a user tag. In the case of expanding the selection, we know which direction to jump
/// over that content.
class CollapseSelectionRequest extends ChangeSelectionRequest {
  CollapseSelectionRequest(
    DocumentPosition newPosition,
  ) : super(DocumentSelection.collapsed(position: newPosition), SelectionChangeType.collapseSelection,
            SelectionReason.userInteraction);
}

/// [EditRequest] that changes the [DocumentSelection] to the given [newSelection].
class ChangeSelectionRequest implements EditRequest {
  const ChangeSelectionRequest(
    this.newSelection,
    this.changeType,
    this.reason, {
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  final SelectionChangeType changeType;

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

/// An [EditCommand] that changes the [DocumentSelection] in the [DocumentComposer]
/// to the [newSelection].
class ChangeSelectionCommand implements EditCommand {
  const ChangeSelectionCommand(
    this.newSelection,
    this.changeType,
    this.reason, {
    this.notifyListeners = true,
  });

  final DocumentSelection? newSelection;

  /// Whether to notify [DocumentComposer] listeners when the selection is changed.
  // TODO: configure the composer so it plugs into the editor in way that this is unnecessary.
  final bool notifyListeners;

  final SelectionChangeType changeType;

  final String reason;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final composer = context.find<DocumentComposer>(Editor.composerKey);
    final initialSelection = composer.selectionComponent.selection;
    composer.selectionComponent.updateSelection(newSelection);

    executor.logChanges([
      SelectionChangeEvent(
        oldSelection: initialSelection,
        newSelection: newSelection,
        changeType: changeType,
        reason: reason,
      )
    ]);
  }
}

/// A [EditEvent] that represents a change to the user's selection within a document.
class SelectionChangeEvent implements EditEvent {
  const SelectionChangeEvent({
    required this.oldSelection,
    required this.newSelection,
    required this.changeType,
    required this.reason,
  });

  final DocumentSelection? oldSelection;
  final DocumentSelection? newSelection;
  final SelectionChangeType changeType;
  // TODO: can we replace the concept of a `reason` with `changeType`
  final String reason;

  @override
  String toString() => "[SelectionChangeEvent] - New selection: $newSelection, change type: $changeType";
}

enum SelectionChangeType {
  /// Place the caret, or an expanded selection, somewhere in the document, with no relationship to the previous selection.
  place,

  /// Place the caret based on a desire to move the previous caret position upstream or downstream.
  pushCaret,

  /// Expand a caret to an expanded selection, or move the base or extent of an already expanded selection.
  expandSelection,

  /// Collapse an expanded selection down to a caret.
  collapseSelection,

  /// Change the selection as the result of inserting content, e.g., typing a character, pasting content.
  insertContent,

  /// Change the selection by deleting content, e.g., pressing backspace or delete.
  deleteContent,

  /// Clears the document selection, such as when a user taps in a textfield outside the editor.
  clearSelection,
}
