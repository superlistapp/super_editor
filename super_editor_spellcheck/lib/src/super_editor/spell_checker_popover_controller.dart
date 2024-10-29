import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';

/// Shows/hides a popover with spelling suggestions.
///
/// A [SpellCheckerPopoverController] must be attached to a [SpellCheckerPopoverDelegate],
/// which will effectively show/hide the popover.
class SpellCheckerPopoverController {
  SpellCheckerPopoverDelegate? _delegate;

  /// Attaches this controller to a delegate that knows how to
  /// show a popover with spelling suggestions.
  ///
  /// A [SpellCheckerPopoverDelegate] must call this method after
  /// being mounted to the widget tree.
  void attach(SpellCheckerPopoverDelegate delegate) {
    _delegate = delegate;
  }

  /// Detaches this controller from the delegate.
  ///
  /// This controller can't show/hide the popover while detached from a delegate.
  ///
  /// A [SpellCheckerPopoverDelegate] must call this method after
  /// being unmounted from the widget tree.
  void detach() {
    _delegate = null;
  }

  /// Shows the spelling suggestions popover with the suggetions
  /// provided by [SpellingErrorSuggestion.suggestions].
  ///
  /// Does nothing if [spelling] doesn't have any suggestions.
  void showSuggestions(SpellingErrorSuggestion spelling) {
    _delegate?.showSuggestions(spelling);
  }

  /// Hides the spelling suggestions popover if it's visible.
  void hide() {
    _delegate?.hideSuggestionsPopover();
  }

  /// Finds spelling suggestions for the word at the given [wordRange].
  ///
  /// Returns `null` if no suggestions are found.
  SpellingErrorSuggestion? findSuggestionsForWordAt(DocumentRange wordRange) {
    return _delegate?.findSuggestionsForWordAt(wordRange);
  }
}

/// Delegate that's attached to a [SpellCheckerPopoverController], to show/hide
/// a popover with spelling suggestions.
///
/// A [SpellCheckerPopoverDelegate] must call [SpellCheckerPopoverController.attach]
/// after being mounted to the widget tree, and [SpellCheckerPopoverController.detach]
/// after being unmounted.
///
/// The popover should be displayed only upon a [showSuggestions] call. The delegate
/// should not display the popover on its own when selection changes.
abstract class SpellCheckerPopoverDelegate {
  /// Shows the spelling suggestions popover with the suggetions
  /// provided by [SpellingErrorSuggestion.suggestions].
  ///
  /// If the popover is already visible, this method should update
  /// the suggestions with the new ones.
  ///
  /// If the document changes while the popover is visible, the popover
  /// should be closed.
  ///
  /// This method should not update the document selection.
  void showSuggestions(SpellingErrorSuggestion suggestions) {}

  /// Hides the spelling suggestions popover if it's visible.
  void hideSuggestionsPopover() {}

  /// Finds spelling suggestions for the word at the given [wordRange].
  ///
  /// Returns `null` if no suggestions are found.
  SpellingErrorSuggestion? findSuggestionsForWordAt(DocumentRange wordRange) => null;
}

class SpellingErrorSuggestion {
  const SpellingErrorSuggestion({
    required this.word,
    required this.nodeId,
    required this.range,
    required this.suggestions,
  });

  final String word;
  final String nodeId;
  final TextRange range;
  final List<String> suggestions;

  DocumentRange get toDocumentRange => DocumentRange(
        start: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: range.start)),
        end: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: range.end - 1),
          // -1 because range is exclusive and doc positions are inclusive
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellingErrorSuggestion &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          nodeId == other.nodeId &&
          range == other.range &&
          const DeepCollectionEquality().equals(suggestions, other.suggestions);

  @override
  int get hashCode => word.hashCode ^ nodeId.hashCode ^ range.hashCode ^ suggestions.hashCode;
}
