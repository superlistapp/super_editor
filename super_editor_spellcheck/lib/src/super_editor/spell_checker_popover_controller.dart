import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';

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

  void showSuggestions(SpellingErrorSuggestion suggestions) {
    _delegate?.showSuggestions(suggestions);
  }

  /// Hides the spelling suggestions popover.
  void hide() {
    _delegate?.hideSuggestionsPopover();
  }

  SpellingErrorSuggestion? findSuggestionsForWordAt(DocumentRange wordRange) {
    return _delegate?.findSuggestionsForWordAt(wordRange);
  }
}

abstract class SpellCheckerPopoverDelegate {
  /// Shows spelling suggestions for the word at [wordRange].
  void showSuggestionsForWordAt(DocumentRange wordRange) {}

  void showSuggestions(SpellingErrorSuggestion suggestions) {}

  /// Hides the spelling suggestions popover.
  void hideSuggestionsPopover() {}

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
