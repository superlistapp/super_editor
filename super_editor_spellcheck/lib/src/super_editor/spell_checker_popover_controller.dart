import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

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
  /// to register itself as the active delegate.
  void attach(SpellCheckerPopoverDelegate delegate) {
    _delegate = delegate;
  }

  /// Detaches this controller from the delegate.
  ///
  /// This controller can't show/hide the popover while detached from a delegate.
  ///
  /// A [SpellCheckerPopoverDelegate] must call this method to unregister itself
  /// when it can no longer be used.
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
/// to register itself as the active delegate, and [SpellCheckerPopoverController.detach]
/// to unregister itself when it can no longer be used.
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
