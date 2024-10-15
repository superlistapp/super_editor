import 'package:super_editor/src/core/document_selection.dart';

/// Shows/hides a popover with spelling suggestions.
class SpellCheckerPopoverController {
  SpellCheckerPopoverDelegate? _delegate;

  /// Attaches this controller to a delegate that knows how to
  /// show a popover with spelling suggestions.
  void attach(SpellCheckerPopoverDelegate delegate) {
    _delegate = delegate;
  }

  /// Detaches this controller from the delegate.
  void detach() {
    _delegate = null;
  }

  /// Shows spelling suggestions for the word at [wordRange].
  void show(DocumentRange wordRange) {
    _delegate?.showSuggestionsForWordAt(wordRange);
  }

  /// Hides the spelling suggestions popover.
  void hide() {
    _delegate?.hideSuggestionsPopover();
  }
}

abstract class SpellCheckerPopoverDelegate {
  /// Shows spelling suggestions for the word at [wordRange].
  void showSuggestionsForWordAt(DocumentRange wordRange) {}

  /// Hides the spelling suggestions popover.
  void hideSuggestionsPopover() {}
}
