import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spell_checker_popover_controller.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_and_grammar_plugin.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

class SpellingErrorSuggestionOverlayBuilder implements SuperEditorLayerBuilder {
  const SpellingErrorSuggestionOverlayBuilder(
    this.suggestions,
    this.selectedWordLink, {
    this.toolbarBuilder = defaultSpellingSuggestionToolbarBuilder,
    this.popoverController,
  });

  final SpellingErrorSuggestions suggestions;
  final LeaderLink selectedWordLink;

  /// Builder that creates the spelling suggestion toolbar, which appears near
  /// the currently selected mis-spelled word.
  final SpellingErrorSuggestionToolbarBuilder toolbarBuilder;

  final SpellCheckerPopoverController? popoverController;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    return SpellingErrorSuggestionOverlay(
      editorFocusNode: editContext.editorFocusNode,
      editor: editContext.editor,
      suggestions: suggestions,
      selectedWordLink: selectedWordLink,
      popoverController: popoverController,
      toolbarBuilder: toolbarBuilder,
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
    this.popoverController,
    this.toolbarBuilder = defaultSpellingSuggestionToolbarBuilder,
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

  final SpellCheckerPopoverController? popoverController;

  /// Builder that creates the spelling suggestion toolbar, which appears near
  /// the currently selected mis-spelled word.
  final SpellingErrorSuggestionToolbarBuilder toolbarBuilder;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  DocumentLayoutLayerState<SpellingErrorSuggestionOverlay, SpellingErrorSuggestionLayout> createState() =>
      _SpellingErrorSuggestionOverlayState();
}

class _SpellingErrorSuggestionOverlayState
    extends DocumentLayoutLayerState<SpellingErrorSuggestionOverlay, SpellingErrorSuggestionLayout>
    implements SpellCheckerPopoverDelegate {
  final _suggestionToolbarOverlayController = OverlayPortalController();

  DocumentRange? _ignoredSpellingErrorRange;

  final _suggestionListenable = ValueNotifier<SpellingErrorSuggestion?>(null);

  final _boundsKey = GlobalKey();

  //DocumentRange? _requestedRange;
  SpellingErrorSuggestion? _spellingErrorSuggestionForRequestedRange;

  // DocumentRange? get _rangeToQuerySuggestions => widget.popoverController == null //
  //     ? widget.editor.context.composer.selection
  //     : _requestedRange;

  @override
  void initState() {
    super.initState();

    widget.editor.context.composer.selectionNotifier.addListener(_onSelectionChange);
    widget.editor.context.spellingErrorSuggestions.addListener(_onSpellingSuggestionsChange);

    widget.popoverController?.attach(this);

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

    if (widget.popoverController != oldWidget.popoverController) {
      oldWidget.popoverController?.detach();
      widget.popoverController?.attach(this);
    }
  }

  @override
  void dispose() {
    if (_suggestionToolbarOverlayController.isShowing) {
      _suggestionToolbarOverlayController.hide();
    }

    widget.editor.context.composer.selectionNotifier.removeListener(_onSelectionChange);
    widget.editor.context.spellingErrorSuggestions.removeListener(_onSpellingSuggestionsChange);

    widget.popoverController?.detach();

    super.dispose();
  }

  @override
  void hideSuggestionsPopover() {
    setState(() {
      //_requestedRange = null;
      _spellingErrorSuggestionForRequestedRange = null;
      //_wantsToShowSuggestionsPopover = false;
    });
  }

  @override
  void showSuggestionsForWordAt(DocumentRange targetRange) {
    setState(() {
      //_requestedRange = targetRange;
      //_wantsToShowSuggestionsPopover = true;
      _spellingErrorSuggestionForRequestedRange = _findSpellingSuggestionAtRange(widget.suggestions, targetRange);
    });
  }

  @override
  SpellingErrorSuggestion? findSuggestionsForWordAt(DocumentRange wordRange) {
    final spellingSuggestion = _findSpellingSuggestionAtRange(widget.suggestions, wordRange);
    if (spellingSuggestion == null) {
      // No selected mis-spelled word. Fizzle.
      return null;
    }

    final misspelledWordRange = spellingSuggestion.toDocumentRange;
    if (misspelledWordRange == _ignoredSpellingErrorRange) {
      // The user already cancelled the suggestions for this word.
      return null;
    }

    return spellingSuggestion;
  }

  @override
  void showSuggestions(SpellingErrorSuggestion suggestions) {
    setState(() {
      _spellingErrorSuggestionForRequestedRange = suggestions;
    });
  }

  void _onSelectionChange() {
    setState(() {
      // Re-compute layout data. The layout needs to be re-computed regardless
      // of any conditions that follow this comment.

      // If the selection was sitting in an ignored spelling error, and
      // now the selection is somewhere else, reset the ignored error.
      if (_ignoredSpellingErrorRange == null) {
        return;
      }

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

    // When there's no selected spelling error, we need to hide the toolbar overlay.
    // Rather than conditionally hide the toolbar based on the code below, we start
    // by hiding the toolbar overlay in all cases. Then, if it's needed, the code
    // below will bring it back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_suggestionToolbarOverlayController.isShowing) {
        _suggestionToolbarOverlayController.hide();
      }
    });

    if (widget.editor.context.composer.selection == null) {
      return null;
    }

    // final range = _rangeToQuerySuggestions;
    // if (range == null) {
    //   // No selection upon which to base spell check suggestions.
    //   return null;
    // }
    // if (range.start.nodeId != range.end.nodeId) {
    //   // Spelling error suggestions don't display when the user selects across nodes.
    //   return null;
    // }
    // if (range.end.nodePosition is! TextNodePosition) {
    //   // The user isn't selecting text. Fizzle.
    //   return null;
    // }

    // final spellingSuggestion = _findSpellingSuggestionAtRange(widget.suggestions, range);
    // if (spellingSuggestion == null) {
    //   // No selected mis-spelled word. Fizzle.
    //   return null;
    // }

    final spellingSuggestion = _spellingErrorSuggestionForRequestedRange;
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
      if (!mounted) {
        return;
      }

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

  SpellingErrorSuggestion? _findSpellingSuggestionAtRange(
    SpellingErrorSuggestions allSuggestions,
    DocumentRange selection,
  ) {
    if (selection.start.nodeId != selection.end.nodeId) {
      // It doesn't make sense to correct spelling across paragraphs. Fizzle.
      return null;
    }

    final textNode = widget.editor.context.document.getNodeById(selection.end.nodeId) as TextNode;

    final selectionBaseOffset = (selection.start.nodePosition as TextNodePosition).offset;
    final spellingSuggestionsAtBase = allSuggestions.getSuggestionsAtTextOffset(textNode.id, selectionBaseOffset);
    if (spellingSuggestionsAtBase == null) {
      return null;
    }

    final selectionExtentOffset = (selection.end.nodePosition as TextNodePosition).offset;
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
      selection.end.nodeId,
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

    // We display the Follower in an OverlayPortal for two reasons:
    //  1. Ensure the Follower is above all other content
    //  2. Ensure the Follower has access to the same theme as the editor
    return OverlayPortal(
      key: _boundsKey,
      controller: _suggestionToolbarOverlayController,
      overlayChildBuilder: (overlayContext) {
        if (layoutData.suggestions.isEmpty) {
          return const SizedBox();
        }

        return _buildFollower(
          child: widget.toolbarBuilder(
            context,
            editorFocusNode: widget.editorFocusNode,
            editor: widget.editor,
            selectedWordRange: layoutData.selectedWordRange!,
            suggestions: layoutData.suggestions,
            onCancelPressed: _onCancelPressed,
            closeToolbar: hideSuggestionsPopover,
            selectedWordBounds: layoutData.selectedWordBounds!,
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

  Widget _buildFollower({required Widget child}) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return Follower.withAligner(
          link: widget.selectedWordLink,
          aligner: CupertinoPopoverToolbarAligner(_boundsKey),
          boundary: ScreenFollowerBoundary(
            screenSize: MediaQuery.sizeOf(context),
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          child: child,
        );
      default:
        return Follower.withOffset(
          link: widget.selectedWordLink,
          leaderAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 16),
          boundary: ScreenFollowerBoundary(
            screenSize: MediaQuery.sizeOf(context),
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          child: child,
        );
    }
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

typedef SpellingErrorSuggestionToolbarBuilder = Widget Function(
  BuildContext context, {
  required FocusNode editorFocusNode,
  required Editor editor,
  required DocumentRange selectedWordRange,
  required List<String> suggestions,
  required VoidCallback onCancelPressed,
  required VoidCallback closeToolbar,
  required Rect selectedWordBounds,
});

Widget defaultSpellingSuggestionToolbarBuilder(
  BuildContext context, {
  required FocusNode editorFocusNode,
  required Editor editor,
  required DocumentRange selectedWordRange,
  required List<String> suggestions,
  required VoidCallback onCancelPressed,
  required VoidCallback closeToolbar,
  required Rect selectedWordBounds,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return IosSpellingSuggestionToolbar(
        editorFocusNode: editorFocusNode,
        editor: editor,
        selectedWordRange: selectedWordRange,
        suggestions: suggestions,
        selectedWordBounds: selectedWordBounds,
        closeToolbar: closeToolbar,
      );
    case TargetPlatform.android:
      return AndroidSpellingSuggestionToolbar(
        editorFocusNode: editorFocusNode,
        editor: editor,
        selectedWordRange: selectedWordRange,
        suggestions: suggestions,
        selectedWordBounds: selectedWordBounds,
        closeToolbar: closeToolbar,
      );
    default:
      return DesktopSpellingSuggestionToolbar(
        editorFocusNode: editorFocusNode,
        editor: editor,
        selectedWordRange: selectedWordRange,
        suggestions: suggestions,
        onCancelPressed: onCancelPressed,
        closeToolbar: closeToolbar,
      );
  }
}

Widget desktopSpellingSuggestionToolbarBuilder(
  BuildContext context, {
  required FocusNode editorFocusNode,
  required Editor editor,
  required DocumentRange selectedWordRange,
  required List<String> suggestions,
  required VoidCallback onCancelPressed,
  required VoidCallback closeToolbar,
}) {
  return DesktopSpellingSuggestionToolbar(
    editorFocusNode: editorFocusNode,
    editor: editor,
    selectedWordRange: selectedWordRange,
    suggestions: suggestions,
    onCancelPressed: onCancelPressed,
    closeToolbar: closeToolbar,
  );
}

/// A spelling suggestion toolbar, designed for desktop experiences,
/// which displays a list alternative spellings for a given mis-spelled
/// word.
///
/// When the user clicks on a suggested spelling, the mis-spelled word
/// is replaced by selected word.
class DesktopSpellingSuggestionToolbar extends StatefulWidget {
  const DesktopSpellingSuggestionToolbar({
    super.key,
    required this.editorFocusNode,
    this.tapRegionId,
    required this.editor,
    required this.selectedWordRange,
    required this.suggestions,
    required this.onCancelPressed,
    required this.closeToolbar,
  });

  final FocusNode editorFocusNode;
  final Object? tapRegionId;
  final Editor editor;
  final DocumentRange? selectedWordRange;
  final List<String> suggestions;
  final VoidCallback onCancelPressed;
  final VoidCallback closeToolbar;

  @override
  State<DesktopSpellingSuggestionToolbar> createState() => _DesktopSpellingSuggestionToolbarState();
}

class _DesktopSpellingSuggestionToolbarState extends State<DesktopSpellingSuggestionToolbar> {
  void _applySpellingFix(String replacement) {
    widget.editor.fixMisspelledWord(widget.selectedWordRange!, replacement);
    widget.closeToolbar();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Focus(
      parentNode: widget.editorFocusNode,
      child: TapRegion(
        groupId: widget.tapRegionId,
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(brightness),
            border: Border.all(color: _getBorderColor(brightness)),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(10),
              right: Radius.circular(34),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: 0.2),
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
                    VerticalDivider(width: 1, color: _getBorderColor(brightness)),
                  ],
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onCancelPressed,
                    child: Icon(
                      Icons.cancel_outlined,
                      size: 12,
                      color: _getTextColor(brightness),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.white;
      case Brightness.dark:
        return Colors.grey.shade900;
    }
  }

  Color _getBorderColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.black;
      case Brightness.dark:
        return Colors.grey.shade700;
    }
  }

  Color _getTextColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.black;
      case Brightness.dark:
        return Colors.white;
    }
  }
}

class AndroidSpellingSuggestionToolbar extends StatefulWidget {
  const AndroidSpellingSuggestionToolbar({
    super.key,
    required this.editorFocusNode,
    this.tapRegionId,
    required this.editor,
    required this.selectedWordRange,
    required this.suggestions,
    required this.selectedWordBounds,
    required this.closeToolbar,
  });

  final FocusNode editorFocusNode;
  final Object? tapRegionId;
  final Editor editor;
  final DocumentRange selectedWordRange;
  final List<String> suggestions;
  final Rect selectedWordBounds;
  final VoidCallback closeToolbar;

  @override
  State<AndroidSpellingSuggestionToolbar> createState() => _AndroidSpellingSuggestionToolbarState();
}

class _AndroidSpellingSuggestionToolbarState extends State<AndroidSpellingSuggestionToolbar> {
  void _applySpellingFix(String replacement) {
    widget.editor.fixMisspelledWord(widget.selectedWordRange, replacement);
    SuperEditorAndroidControlsScope.rootOf(context).allowSelectionHandles();
    widget.closeToolbar();
  }

  void _removeWord() {
    widget.editor.removeMisspelledWord(widget.selectedWordRange);
    SuperEditorAndroidControlsScope.rootOf(context).allowSelectionHandles();
    widget.closeToolbar();
  }

  Color _getTextColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.black;
      case Brightness.dark:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final suggestion in widget.suggestions) ...[
            _buildButton(
              title: suggestion,
              onPressed: () => _applySpellingFix(suggestion),
              brightness: brightness,
            ),
          ],
          _buildButton(
            title: 'Delete',
            onPressed: _removeWord,
            brightness: brightness,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
    required Brightness brightness,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
        padding: EdgeInsets.zero,
        foregroundColor: _getTextColor(brightness),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class IosSpellingSuggestionToolbar extends StatefulWidget {
  const IosSpellingSuggestionToolbar({
    super.key,
    required this.editorFocusNode,
    this.tapRegionId,
    required this.editor,
    required this.selectedWordRange,
    required this.suggestions,
    required this.selectedWordBounds,
    required this.closeToolbar,
  });

  final FocusNode editorFocusNode;
  final Object? tapRegionId;
  final Editor editor;
  final DocumentRange selectedWordRange;
  final List<String> suggestions;
  final Rect selectedWordBounds;
  final VoidCallback closeToolbar;

  @override
  State<IosSpellingSuggestionToolbar> createState() => _IosSpellingSuggestionToolbarState();
}

class _IosSpellingSuggestionToolbarState extends State<IosSpellingSuggestionToolbar> {
  void _applySpellingFix(String replacement) {
    widget.editor.fixMisspelledWord(widget.selectedWordRange, replacement);
    SuperEditorIosControlsScope.rootOf(context).allowSelectionHandles();
    widget.closeToolbar();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Focus(
      parentNode: widget.editorFocusNode,
      child: TapRegion(
        groupId: widget.tapRegionId,
        child: CupertinoPopoverToolbar(
          focalPoint: StationaryMenuFocalPoint(widget.selectedWordBounds.center),
          backgroundColor: _getBackgroundColor(brightness),
          activeButtonTextColor: brightness == Brightness.dark //
              ? iOSToolbarDarkArrowActiveColor
              : iOSToolbarLightArrowActiveColor,
          inactiveButtonTextColor: brightness == Brightness.dark //
              ? iOSToolbarDarkArrowInactiveColor
              : iOSToolbarLightArrowInactiveColor,
          elevation: 8.0,
          children: [
            for (final suggestion in widget.suggestions) ...[
              _buildButton(
                title: suggestion,
                onPressed: () => _applySpellingFix(suggestion),
                brightness: brightness,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.white;
      case Brightness.dark:
        return Colors.grey.shade900;
    }
  }

  Color _getTextColor(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return Colors.black;
      case Brightness.dark:
        return Colors.white;
    }
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
    required Brightness brightness,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinInteractiveDimension, 0),
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _getTextColor(brightness),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

const iOSToolbarDarkBackgroundColor = Color(0xFF333333);
const iOSToolbarLightBackgroundColor = Colors.white;

const iOSToolbarLightArrowActiveColor = Color(0xFF000000);
const iOSToolbarDarkArrowActiveColor = Color(0xFFFFFFFF);

const iOSToolbarLightArrowInactiveColor = Color(0xFF999999);
const iOSToolbarDarkArrowInactiveColor = Color(0xFF757575);
