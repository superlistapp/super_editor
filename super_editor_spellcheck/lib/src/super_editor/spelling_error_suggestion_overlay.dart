import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

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
    this.showDebugLeaderBounds = false,
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

  DocumentRange? _ignoredSpellingErrorRange;

  final _suggestionListenable = ValueNotifier<SpellingErrorSuggestion?>(null);

  @override
  void initState() {
    super.initState();

    widget.editor.context.composer.selectionNotifier.addListener(_onSelectionChange);
    widget.editor.context.spellingErrorSuggestions.addListener(_onSpellingSuggestionsChange);

    _suggestionToolbarOverlayController.show();
  }

  @override
  void didUpdateWidget(SpellingErrorSuggestionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor.context.composer.selectionNotifier != oldWidget.editor.context.composer.selectionNotifier) {
      oldWidget.editor.context.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editor.context.composer.selectionNotifier.addListener(_onSelectionChange);
    }

    if (widget.editor.context.spellingErrorSuggestions != oldWidget.editor.context.spellingErrorSuggestions) {
      oldWidget.editor.context.spellingErrorSuggestions.removeListener(_onSpellingSuggestionsChange);
      widget.editor.context.spellingErrorSuggestions.addListener(_onSpellingSuggestionsChange);
    }
  }

  @override
  void dispose() {
    if (_suggestionToolbarOverlayController.isShowing) {
      _suggestionToolbarOverlayController.hide();
    }

    widget.editor.context.composer.selectionNotifier.removeListener(_onSelectionChange);
    widget.editor.context.spellingErrorSuggestions.removeListener(_onSpellingSuggestionsChange);

    super.dispose();
  }

  void _onSelectionChange() {
    setState(() {
      // If the selection was sitting in an ignored spelling error, and
      // now the selection is somewhere else, reset the ignored error.
      if (_ignoredSpellingErrorRange != null) {
        final selection = widget.editor.context.composer.selection;
        if (selection == null) {
          // There's no selection. Therefore, the user isn't still selecting
          // the mis-spelled word. Reset the ignored word.
          _ignoredSpellingErrorRange = null;
        } else {
          // There's a selection. If it's not still in the ignored word, reset
          // the ignored word.
          final ignoredWordAsSelection = DocumentSelection(
            base: _ignoredSpellingErrorRange!.start,
            extent: _ignoredSpellingErrorRange!.end.copyWith(
              // Add one to the downstream offset so that when the caret sits immediately
              // after the mis-spelled word, it's still considered to sit within the word.
              // We do this because we don't want to reset the ignored word when the caret
              // sits immediately after it.
              nodePosition: TextNodePosition(
                offset: (_ignoredSpellingErrorRange!.end.nodePosition as TextNodePosition).offset + 1,
              ),
            ),
          );
          final isBaseInWord =
              widget.editor.document.doesSelectionContainPosition(ignoredWordAsSelection, selection.base);
          final isExtentInWord =
              widget.editor.document.doesSelectionContainPosition(ignoredWordAsSelection, selection.extent);

          if (!isBaseInWord || !isExtentInWord) {
            _ignoredSpellingErrorRange = null;
          }
        }
      }

      // Also, re-compute layout data.
    });
  }

  void _onSpellingSuggestionsChange() {
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
    _suggestionListenable.value = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_suggestionToolbarOverlayController.isShowing) {
        _suggestionToolbarOverlayController.hide();
      }
    });

    final documentSelection = widget.editor.context.composer.selectionNotifier.value;
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

    final spellingSuggestion = _findSpellingSuggestionAtSelection(widget.suggestions, documentSelection);
    if (spellingSuggestion == null) {
      // No selected mis-spelled word. Fizzle.
      return null;
    }

    final misspelledWordRange = spellingSuggestion.toDocumentRange;
    if (misspelledWordRange == _ignoredSpellingErrorRange) {
      // The user already cancelled the suggestions for this word.
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(
      widget.editor.context.composer.selectionNotifier.value!.extent.nodeId,
    );
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method to run again in a moment
      // to correct for this.
      return null;
    }

    _suggestionListenable.value = spellingSuggestion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestionToolbarOverlayController.show();
    });

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

  SpellingErrorSuggestion? _findSpellingSuggestionAtSelection(
    SpellingErrorSuggestions allSuggestions,
    DocumentSelection selection,
  ) {
    if (selection.base.nodeId != selection.extent.nodeId) {
      // It doesn't make sense to correct spelling across paragraphs. Fizzle.
      return null;
    }

    final textNode = widget.editor.context.document.getNodeById(selection.extent.nodeId) as TextNode;

    final selectionBaseOffset = (selection.base.nodePosition as TextNodePosition).offset;
    final spellingSuggestionsAtBase = allSuggestions.getSuggestionsAtTextOffset(textNode.id, selectionBaseOffset);
    if (spellingSuggestionsAtBase == null) {
      return null;
    }

    final selectionExtentOffset = (selection.extent.nodePosition as TextNodePosition).offset;
    final spellingSuggestionsAtExtent = allSuggestions.getSuggestionsAtTextOffset(textNode.id, selectionExtentOffset);
    if (spellingSuggestionsAtExtent == null) {
      return null;
    }

    if (spellingSuggestionsAtBase.range != spellingSuggestionsAtExtent.range) {
      // We found different spelling errors. This probably means the selection
      // spans multiple words, including multiple spelling errors. We can't
      // suggest a single fix. Fizzle.
      return null;
    }
    final spellingErrorRange = spellingSuggestionsAtExtent.range;

    // The user's selection sits somewhere within a word. Check if it's mis-spelled.
    final suggestions = widget.suggestions.getSuggestionsForWord(
      selection.extent.nodeId,
      TextRange(start: spellingErrorRange.start, end: spellingErrorRange.end),
    );

    return suggestions;
  }

  // Called when the user presses the "x" (cancel) button on the spelling
  // correction suggestion toolbar.
  //
  // The expected behavior is that cancelling the toolbar will hide it,
  // the toolbar will not re-appear as long as the user's selection remains
  // within the mis-spelled word, but the toolbar will come back if the
  // selection moves away and then moves back to the mis-spelled word.
  void _onCancelPressed() {
    _suggestionToolbarOverlayController.hide();
    _ignoredSpellingErrorRange = layoutData?.selectedWordRange;
  }

  @override
  Widget doBuild(BuildContext context, SpellingErrorSuggestionLayout? layoutData) {
    if (layoutData == null) {
      return const SizedBox();
    }

    return OverlayPortal(
      controller: _suggestionToolbarOverlayController,
      overlayChildBuilder: (overlayContext) {
        if (layoutData.suggestions.isEmpty) {
          return const SizedBox();
        }

        return Follower.withOffset(
          link: widget.selectedWordLink,
          leaderAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 16),
          boundary: ScreenFollowerBoundary(
            screenSize: MediaQuery.sizeOf(context),
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          child: SpellingSuggestionToolbar(
            editorFocusNode: widget.editorFocusNode,
            editor: widget.editor,
            selectedWordRange: layoutData.selectedWordRange,
            suggestions: layoutData.suggestions,
            onCancelPressed: _onCancelPressed,
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
    required this.onCancelPressed,
  });

  final FocusNode editorFocusNode;
  final Editor editor;
  final DocumentRange? selectedWordRange;
  final List<String> suggestions;
  final VoidCallback onCancelPressed;

  @override
  State<SpellingSuggestionToolbar> createState() => _SpellingSuggestionToolbarState();
}

class _SpellingSuggestionToolbarState extends State<SpellingSuggestionToolbar> {
  void _applySpellingFix(String replacement) {
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
                GestureDetector(
                  onTap: widget.onCancelPressed,
                  child: const Icon(Icons.cancel_outlined, size: 12),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
