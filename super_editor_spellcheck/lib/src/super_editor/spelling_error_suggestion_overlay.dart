import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

class SpellingErrorSuggestionOverlayBuilder implements SuperEditorLayerBuilder {
  const SpellingErrorSuggestionOverlayBuilder(this.suggestions, this.selectedWordLink);

  final SpellingErrorSuggestions suggestions;
  final LeaderLink selectedWordLink;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    return SpellingErrorSuggestionOverlay(
      document: editContext.document,
      selection: editContext.composer.selectionNotifier,
      suggestions: suggestions,
      selectedWordLink: selectedWordLink,
    );
  }
}

class SpellingErrorSuggestionOverlay extends DocumentLayoutLayerStatefulWidget {
  const SpellingErrorSuggestionOverlay({
    super.key,
    required this.document,
    required this.selection,
    required this.suggestions,
    required this.selectedWordLink,
    this.showDebugLeaderBounds = true,
  });

  /// The editor's [Document], which is used to find the start and end of
  /// the user's expanded selection.
  final Document document;

  /// The current user's selection within a document.
  final ValueListenable<DocumentSelection?> selection;

  /// Repository of specific mis-spelled words in the document, and suggested
  /// corrections.
  final SpellingErrorSuggestions suggestions;

  /// A [LeaderLink] that's bound to a rectangle around the currently selected
  /// misspelled word - if the selection isn't currently within a word, or if the
  /// selected word isn't misspelled, then this link is left unattached.
  final LeaderLink selectedWordLink;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  DocumentLayoutLayerState<SpellingErrorSuggestionOverlay, SpellingErrorSuggestionLayout> createState() =>
      _SpellingErrorSuggestionOverlayState();
}

class _SpellingErrorSuggestionOverlayState
    extends DocumentLayoutLayerState<SpellingErrorSuggestionOverlay, SpellingErrorSuggestionLayout> {
  @override
  SpellingErrorSuggestionLayout? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final documentSelection = widget.selection.value;
    if (documentSelection == null) {
      // No selection upon which to base spell check suggestions.
      return null;
    }
    if (documentSelection.base.nodeId != documentSelection.extent.nodeId) {
      // Spelling error suggestions don't display when the user selects across nodes.
      return null;
    }
    if (documentSelection.extent.nodePosition is! TextNodePosition) {
      // The user isn't selecting text. Fizzle.
      return null;
    }

    final spellingSuggestion = _findSpellingSuggestionAtSelection(documentSelection);
    if (spellingSuggestion == null) {
      // No selected mis-spelled word. Fizzle.
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(widget.selection.value!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method to run again in a moment
      // to correct for this.
      return null;
    }

    final misspelledWordRange = spellingSuggestion.toDocumentRange;
    return SpellingErrorSuggestionLayout(
      selectedWordBounds: documentLayout.getRectForSelection(
        misspelledWordRange.start,
        misspelledWordRange.end,
      ),
    );
  }

  SpellingErrorSuggestion? _findSpellingSuggestionAtSelection(DocumentSelection selection) {
    final textNode = widget.document.getNodeById(selection.extent.nodeId) as TextNode;
    final text = textNode.text.text;
    final selectionBaseOffset = (selection.base.nodePosition as TextNodePosition).offset;
    final selectionExtentOffset = (selection.extent.nodePosition as TextNodePosition).offset;

    final searchStarOffset = selectionExtentOffset;
    bool searchingForStart = true;
    int wordStartOffset = searchStarOffset;
    while (wordStartOffset > 0 && searchingForStart) {
      // Move one character upstream.
      final upstreamCharacterIndex = getCharacterStartBounds(text, wordStartOffset - 1);
      if (text[upstreamCharacterIndex] == " ") {
        // We found a space, which means the current value of `wordStartOffset`
        // is the start of the word.
        searchingForStart = false;
        continue;
      }

      wordStartOffset = upstreamCharacterIndex;
    }
    if (selectionBaseOffset < wordStartOffset || selectionExtentOffset < wordStartOffset) {
      // The selection extends beyond the start of the word. Fizzle.
      return null;
    }

    bool searchingForEnd = true;
    int wordEndOffset = searchStarOffset;
    while (wordEndOffset < text.length && searchingForEnd) {
      // Move one character downstream.
      final downstreamCharacterIndex = getCharacterEndBounds(text, wordEndOffset + 1);
      if (text[downstreamCharacterIndex] == " ") {
        // We found a space, which means the current value of `wordEndOffset`
        // is the end of the word.
        searchingForEnd = false;
        continue;
      }

      wordEndOffset = downstreamCharacterIndex;
    }
    if (selectionBaseOffset > wordEndOffset || selectionExtentOffset > wordEndOffset) {
      // The selection extends beyond the end of the word. Fizzle.
      return null;
    }

    // The user's selection sits somewhere within a word. Check if it's mis-spelled.
    return widget.suggestions.getSuggestionsForWord(
      selection.extent.nodeId,
      TextRange(start: wordStartOffset, end: wordEndOffset),
    );
  }

  @override
  Widget doBuild(BuildContext context, SpellingErrorSuggestionLayout? layoutData) {
    if (layoutData == null) {
      return const SizedBox();
    }

    return IgnorePointer(
      child: Stack(
        children: [
          if (layoutData.selectedWordBounds != null)
            Positioned.fromRect(
              rect: layoutData.selectedWordBounds!,
              child: Leader(
                link: widget.selectedWordLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFFFF00FF))),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class SpellingErrorSuggestionLayout {
  SpellingErrorSuggestionLayout({
    this.selectedWordBounds,
  });

  final Rect? selectedWordBounds;
}
