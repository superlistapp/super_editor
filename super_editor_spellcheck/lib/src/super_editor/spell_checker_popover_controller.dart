import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

/// Shows/hides a popover with spelling suggestions.
///
/// A [SpellCheckerPopoverController] must be attached to a [SpellCheckerPopoverDelegate],
/// which will effectively show/hide the popover.
class SpellCheckerPopoverController {
  SpellCheckerPopoverController();

  SpellCheckerPopoverDelegate? _delegate;

  var _orientation = SpellcheckToolbarOrientation.auto;

  /// Whether or not the popover is currently showing.
  bool get isShowing => _isShowing;
  bool _isShowing = false;

  /// Attaches this controller to a delegate that knows how to
  /// show a popover with spelling suggestions.
  ///
  /// A [SpellCheckerPopoverDelegate] must call this method after
  /// to register itself as the active delegate.
  void attach(SpellCheckerPopoverDelegate delegate) {
    // Detach from the previous delegate, if any.
    detach();

    _delegate = delegate;
    _delegate!.setOrientation(_orientation);
  }

  /// Detaches this controller from the delegate.
  ///
  /// This controller can't show/hide the popover while detached from a delegate.
  ///
  /// A [SpellCheckerPopoverDelegate] must call this method to unregister itself
  /// when it can no longer be used.
  void detach() {
    _delegate?.onDetached();
    _delegate = null;
  }

  /// Shows the spelling suggestions popover with the suggetions
  /// provided by [SpellingError.suggestions].
  ///
  /// Does nothing if [spelling] doesn't have any suggestions.
  ///
  /// Provide a [onDismiss] callback to be called when the popover
  /// is dismissed by tapping outside of the suggestions popover.
  /// For example, restoring the previous selection when the popover
  /// is dismissed.
  void showSuggestions(
    SpellingError spelling, {
    VoidCallback? onDismiss,
  }) {
    _delegate?.showSuggestions(
      spelling,
      onDismiss: onDismiss,
    );
    _isShowing = true;
  }

  @Deprecated("This is a temporary behavior until we generalize the control (June 19, 2025)")
  void setOrientation(SpellcheckToolbarOrientation orientation) {
    _orientation = orientation;
    _delegate?.setOrientation(orientation);
  }

  /// Hides the spelling suggestions popover if it's visible.
  void hide() {
    _delegate?.hideSuggestionsPopover();
    _isShowing = false;
  }

  /// Finds spelling suggestions for the word at the given [wordRange].
  ///
  /// Returns `null` if no suggestions are found.
  SpellingError? findSuggestionsForWordAt(DocumentRange wordRange) {
    return _delegate?.findSuggestionsForWordAt(wordRange);
  }
}

enum SpellcheckToolbarOrientation {
  // Use whatever the standard is.
  auto,
  // Display toolbar above the misspelled word.
  above,
  // Display toolbar below the misspelled word.
  below,
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
  /// Called on this delegate by the [SpellCheckerPopoverController] when the controller
  /// attaches to the delegate.
  void onAttached(SpellCheckerPopoverController controller);

  /// Called on this delegate by the [SpellCheckerPopoverController] when the controller
  /// detaches from the delegate.
  ///
  /// The delegate should hide the popover when detached, if it's visible.
  void onDetached();

  /// Shows the spelling suggestions popover with the suggetions
  /// provided by [SpellingError.suggestions].
  ///
  /// If the popover is already visible, this method should update
  /// the suggestions with the new ones.
  ///
  /// If the document changes while the popover is visible, the popover
  /// should be closed.
  ///
  /// This method should not update the document selection.
  ///
  /// Provide a [onDismiss] callback to be called when the popover
  /// is dismissed by tapping outside of the suggestions popover.
  /// For example, restoring the previous selection when the popover
  /// is dismissed.
  void showSuggestions(
    SpellingError suggestions, {
    VoidCallback? onDismiss,
  }) {}

  @Deprecated("This is a temporary behavior until we generalize the control (June 19, 2025)")
  void setOrientation(SpellcheckToolbarOrientation orientation);

  /// Hides the spelling suggestions popover if it's visible.
  void hideSuggestionsPopover() {}

  /// Finds spelling suggestions for the word at the given [wordRange].
  ///
  /// Returns `null` if no suggestions are found.
  SpellingError? findSuggestionsForWordAt(DocumentRange wordRange) => null;
}
