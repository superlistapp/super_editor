import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

class SpellingErrorSuggestionOverlayBuilder implements SuperEditorLayerBuilder {
  const SpellingErrorSuggestionOverlayBuilder(
    this.suggestions,
    this.selectedWordLink,
  );

  final SpellingErrorSuggestions suggestions;
  final LeaderLink selectedWordLink;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    return SpellingErrorSuggestionOverlay(
      editorFocusNode: editContext.editorFocusNode,
      editor: editContext.editor,
      suggestions: suggestions,
      selectedWordLink: selectedWordLink,
    );
  }
}

class SpellingErrorSuggestionOverlay extends DocumentLayoutLayerStatefulWidget {
  const SpellingErrorSuggestionOverlay({
    super.key,
    required this.editorFocusNode,
    required this.editor,
    required this.suggestions,
    required this.selectedWordLink,
    this.showDebugLeaderBounds = true,
  });

  final FocusNode editorFocusNode;

  final Editor editor;

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
  final _suggestionToolbarOverlayController = OverlayPortalController();

  final _suggestionListenable = ValueNotifier<SpellingErrorSuggestion?>(null);

  @override
  void initState() {
    super.initState();

    widget.editor.context.composer.selectionNotifier.addListener(_onSelectionChange);

    _suggestionToolbarOverlayController.show();
  }

  @override
  void didUpdateWidget(SpellingErrorSuggestionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor.context.composer.selectionNotifier != oldWidget.editor.context.composer.selectionNotifier) {
      oldWidget.editor.context.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editor.context.composer.selectionNotifier.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    if (_suggestionToolbarOverlayController.isShowing) {
      _suggestionToolbarOverlayController.hide();
    }

    widget.editor.context.composer.selectionNotifier.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onSelectionChange() {
    print("Selection changed - setting state to recompute layout data");
    setState(() {
      // Re-compute layout data.
    });
  }

  @override
  SpellingErrorSuggestionLayout? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    print("Computing layout data...");
    print("Changing _suggestionListenable to null");
    _suggestionListenable.value = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_suggestionToolbarOverlayController.isShowing) {
        _suggestionToolbarOverlayController.hide();
      }
    });

    final documentSelection = widget.editor.context.composer.selectionNotifier.value;
    if (documentSelection == null) {
      // No selection upon which to base spell check suggestions.
      print("There's no selection");
      return null;
    }
    if (documentSelection.base.nodeId != documentSelection.extent.nodeId) {
      // Spelling error suggestions don't display when the user selects across nodes.
      print("Selection crosses node boundary");
      return null;
    }
    if (documentSelection.extent.nodePosition is! TextNodePosition) {
      // The user isn't selecting text. Fizzle.
      print("Selection isn't a text selection");
      return null;
    }

    final spellingSuggestion = _findSpellingSuggestionAtSelection(documentSelection);
    if (spellingSuggestion == null) {
      // No selected mis-spelled word. Fizzle.
      print("There's no selected mis-spelled word. Fizzling.");
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(
      widget.editor.context.composer.selectionNotifier.value!.extent.nodeId,
    );
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method to run again in a moment
      // to correct for this.
      print("Selected component is null");
      return null;
    }

    final misspelledWordRange = spellingSuggestion.toDocumentRange;

    print("Changing suggestion listenable from ${_suggestionListenable.value} to $spellingSuggestion");
    _suggestionListenable.value = spellingSuggestion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestionToolbarOverlayController.show();
    });

    print("Misspelled word range: $misspelledWordRange");
    return SpellingErrorSuggestionLayout(
      selectedWordBounds: documentLayout.getRectForSelection(
        misspelledWordRange.start,
        misspelledWordRange.end.copyWith(
          nodePosition: TextNodePosition(
            // +1 to make end exclusive.
            offset: (misspelledWordRange.end.nodePosition as TextNodePosition).offset + 1,
          ),
        ),
      ),
      selectedWordRange: misspelledWordRange,
      suggestions: spellingSuggestion.suggestions,
    );
  }

  SpellingErrorSuggestion? _findSpellingSuggestionAtSelection(DocumentSelection selection) {
    print("Looking for a spelling error around the selection...");
    final textNode = widget.editor.context.document.getNodeById(selection.extent.nodeId) as TextNode;
    final text = textNode.text.text;
    final selectionBaseOffset = (selection.base.nodePosition as TextNodePosition).offset;
    final selectionExtentOffset = (selection.extent.nodePosition as TextNodePosition).offset;

    final searchStartOffset = selectionExtentOffset;
    bool searchingForStart = true;
    int wordStartOffset = searchStartOffset;
    print("Looking for start of word, beginning at index: $wordStartOffset");
    while (wordStartOffset > 0 && searchingForStart) {
      // Move one character upstream.
      final upstreamCharacterIndex = getCharacterStartBounds(text, wordStartOffset);
      print(" - upstream index: $upstreamCharacterIndex");
      if (text[upstreamCharacterIndex] == " ") {
        // We found a space, which means the current value of `wordStartOffset`
        // is the start of the word.
        print("Searching for start of word - found space at index $upstreamCharacterIndex");
        searchingForStart = false;
        continue;
      }

      print(" - final word start offset: $wordStartOffset");
      wordStartOffset = upstreamCharacterIndex;
    }
    if (selectionBaseOffset < wordStartOffset || selectionExtentOffset < wordStartOffset) {
      // The selection extends beyond the start of the word. Fizzle.
      print("Selection extends beyond the start of the word. Fizzling.");
      return null;
    }

    bool searchingForEnd = searchStartOffset < text.length && text[searchStartOffset] != " ";
    int wordEndOffset = searchStartOffset;
    print("Text: '$text', Length: ${text.length}");
    while (wordEndOffset < text.length && searchingForEnd) {
      // Move one character downstream.
      print(" - searching for end of character that starts at $wordEndOffset");
      final downstreamCharacterIndex = getCharacterEndBounds(text, wordEndOffset);
      print(" - downstream character index: $downstreamCharacterIndex");
      if (downstreamCharacterIndex >= text.length) {
        // We reached the end of the text without finding a space.
        wordEndOffset = text.length;
        continue;
      }

      if (text[downstreamCharacterIndex] == " ") {
        // We found a space, which means the current value of `wordEndOffset`
        // is the end of the word.
        print(" - found a space at index: $downstreamCharacterIndex");
        searchingForEnd = false;

        // +1 to make end exclusive.
        wordEndOffset += 1;

        continue;
      }

      wordEndOffset = downstreamCharacterIndex;
    }
    if (selectionBaseOffset > wordEndOffset || selectionExtentOffset > wordEndOffset) {
      // The selection extends beyond the end of the word. Fizzle.
      print("Selection extends beyond end of the word. Fizzling.");
      return null;
    }

    print("Word start: $wordStartOffset, end: $wordEndOffset");
    print("Searching for suggestions for word: '${text.substring(wordStartOffset, wordEndOffset)}'");

    // The user's selection sits somewhere within a word. Check if it's mis-spelled.
    final suggestions = widget.suggestions.getSuggestionsForWord(
      selection.extent.nodeId,
      TextRange(
        start: wordStartOffset,
        end: wordEndOffset,
      ),
    );
    print("Suggestions for word: ${suggestions?.suggestions}");

    return suggestions;
  }

  @override
  Widget doBuild(BuildContext context, SpellingErrorSuggestionLayout? layoutData) {
    print("Building spelling suggestion overlay - layout data: $layoutData");
    if (layoutData == null) {
      return const SizedBox();
    }

    return OverlayPortal(
      controller: _suggestionToolbarOverlayController,
      overlayChildBuilder: (overlayContext) {
        print("Building OverlayPortal entry");
        if (layoutData.suggestions.isEmpty) {
          print("No spelling suggestions to show");
          return const SizedBox();
        }

        print("Showing spelling suggestions");
        return Follower.withOffset(
          link: widget.selectedWordLink,
          leaderAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 16),
          child: SpellingSuggestionToolbar(
            editorFocusNode: widget.editorFocusNode,
            editor: widget.editor,
            selectedWordRange: layoutData.selectedWordRange,
            suggestions: layoutData.suggestions,
          ),
        );
      },
      child: IgnorePointer(
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
      ),
    );
  }
}

class SpellingErrorSuggestionLayout {
  SpellingErrorSuggestionLayout({
    required this.selectedWordBounds,
    required this.selectedWordRange,
    required this.suggestions,
  });

  final Rect? selectedWordBounds;
  final DocumentRange? selectedWordRange;
  final List<String> suggestions;
}

class SpellingSuggestionToolbar extends StatefulWidget {
  const SpellingSuggestionToolbar({
    super.key,
    required this.editorFocusNode,
    required this.editor,
    required this.selectedWordRange,
    required this.suggestions,
  });

  final FocusNode editorFocusNode;
  final Editor editor;
  final DocumentRange? selectedWordRange;
  final List<String> suggestions;

  @override
  State<SpellingSuggestionToolbar> createState() => _SpellingSuggestionToolbarState();
}

class _SpellingSuggestionToolbarState extends State<SpellingSuggestionToolbar> {
  void _applySpellingFix(String replacement) {
    print("Applying spelling replacement: '$replacement'");

    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: widget.selectedWordRange!.start,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: widget.selectedWordRange!.start,
          end: widget.selectedWordRange!.end.copyWith(
            nodePosition: TextNodePosition(
              // +1 to make end of range exclusive.
              offset: (widget.selectedWordRange!.end.nodePosition as TextNodePosition).offset + 1,
            ),
          ),
        ),
      ),
      InsertTextRequest(
        documentPosition: widget.selectedWordRange!.start,
        textToInsert: replacement,
        attributions: {},
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      parentNode: widget.editorFocusNode,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(10),
            right: Radius.circular(34),
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final suggestion in widget.suggestions) ...[
                  GestureDetector(
                    onTap: () => _applySpellingFix(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.grey),
                ],
                const SizedBox(width: 6),
                const Icon(Icons.cancel_outlined, size: 12),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
