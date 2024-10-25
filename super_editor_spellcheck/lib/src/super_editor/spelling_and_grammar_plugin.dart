import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/platform/spell_checker.dart';
import 'package:super_editor_spellcheck/src/super_editor/spell_checker_popover_controller.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestion_overlay.dart';
import 'package:super_editor_spellcheck/src/super_editor/spelling_error_suggestions.dart';

/// A [SuperEditorPlugin] that checks spelling and grammar across a [Document],
/// underlining spelling and grammar mistakes, and offering corrections.
class SpellingAndGrammarPlugin extends SuperEditorPlugin {
  static const spellingErrorSuggestionsKey = "SpellingAndGrammarPlugin.spellingErrorSuggestions";

  SpellingAndGrammarPlugin({
    bool isSpellingCheckEnabled = true,
    UnderlineStyle spellingErrorUnderlineStyle = defaultSpellingErrorUnderlineStyle,
    bool isGrammarCheckEnabled = true,
    UnderlineStyle grammarErrorUnderlineStyle = defaultGrammarErrorUnderlineStyle,
    SpellingErrorSuggestionToolbarBuilder toolbarBuilder = defaultSpellingSuggestionToolbarBuilder,
    Color selectedWordHighlightColor = Colors.transparent,
    SelectionStyles? selectionStyles,
    SuperEditorAndroidControlsController? androidControlsController,
    SuperEditorIosControlsController? iosControlsController,
  })  : _isSpellCheckEnabled = isSpellingCheckEnabled,
        _isGrammarCheckEnabled = isGrammarCheckEnabled {
    documentOverlayBuilders = <SuperEditorLayerBuilder>[
      SpellingErrorSuggestionOverlayBuilder(
        _spellingErrorSuggestions,
        _selectedWordLink,
        popoverController: _popoverController,
        toolbarBuilder: toolbarBuilder,
      ),
    ];
    _styler = SpellingAndGrammarStyler(
      selectionHighlightColor: selectedWordHighlightColor,
      selectionStyles: selectionStyles ?? defaultSelectionStyle,
    );

    _contentTapDelegate = switch (defaultTargetPlatform) {
      TargetPlatform.android => SuperEditorAndroidSpellCheckerTapHandler(
          popoverController: _popoverController,
          controlsController: androidControlsController!,
          styler: _styler,
        ),
      TargetPlatform.iOS => SuperEditorIosSpellCheckerTapHandler(
          popoverController: _popoverController,
          controlsController: iosControlsController!,
          styler: _styler,
        ),
      _ => SuperEditorDesktopSpellCheckerTapHandler(popoverController: _popoverController),
    };
  }

  final _popoverController = SpellCheckerPopoverController();

  final _spellingErrorSuggestions = SpellingErrorSuggestions();

  late final SpellingAndGrammarStyler _styler;

  /// Leader attached to an invisible rectangle around the currently selected
  /// misspelled word.
  final _selectedWordLink = LeaderLink();

  late final SpellingAndGrammarReaction _reaction;

  /// Whether this reaction checks spelling in the document.
  bool get isSpellCheckEnabled => _isSpellCheckEnabled;
  bool _isSpellCheckEnabled;
  set isSpellCheckEnabled(bool isEnabled) {
    _isSpellCheckEnabled = isEnabled;
    _reaction.isSpellCheckEnabled = isEnabled;
  }

  /// The [UnderlineStyle] applied to words of text that are mis-spelled.
  set spellingErrorUnderlineStyle(UnderlineStyle style) => _styler.spellingErrorUnderlineStyle = style;

  /// Whether this reaction checks grammar in the document.
  bool get isGrammarCheckEnabled => _isGrammarCheckEnabled;
  bool _isGrammarCheckEnabled;
  set isGrammarCheckEnabled(bool isEnabled) {
    _isGrammarCheckEnabled = isEnabled;
    _reaction.isGrammarCheckEnabled = isEnabled;
  }

  /// The [UnderlineStyle] applied to runs of text with incorrect grammar.
  set grammarErrorUnderlineStyle(UnderlineStyle style) => _styler.grammarErrorUnderlineStyle = style;

  /// A [SuperEditor] style phase that applies spelling error and grammar error
  /// underlines to text in the document.
  SpellingAndGrammarStyler get styler => _styler;

  /// [SuperEditor] overlay widgets that should be added to the [SuperEditor] this
  /// plugin is attached to.
  @override
  late final List<SuperEditorLayerBuilder> documentOverlayBuilders;

  @override
  ContentTapDelegate? get contentTapDelegate => _contentTapDelegate;
  late final _SpellCheckerContentTapDelegate? _contentTapDelegate;

  @override
  void attach(Editor editor) {
    editor.context.put(spellingErrorSuggestionsKey, _spellingErrorSuggestions);
    _contentTapDelegate?.editor = editor;

    _reaction = SpellingAndGrammarReaction(_spellingErrorSuggestions, _styler);
    editor.reactionPipeline.add(_reaction);
  }

  @override
  void detach(Editor editor) {
    _styler.clearAllErrors();
    editor.reactionPipeline.remove(_reaction);
    _contentTapDelegate?.editor = null;

    editor.context.remove(spellingErrorSuggestionsKey);
    _spellingErrorSuggestions.clear();
  }
}

extension SpellingAndGrammarEditableExtensions on EditContext {
  SpellingErrorSuggestions get spellingErrorSuggestions => find<SpellingErrorSuggestions>(
        SpellingAndGrammarPlugin.spellingErrorSuggestionsKey,
      );
}

extension SpellingAndGrammarEditorExtensions on Editor {
  /// Deletes the text within the given [wordRange] and replaces it with
  /// the given [correctSpelling].
  void fixMisspelledWord(DocumentRange wordRange, String correctSpelling) {
    execute([
      // Move caret to start of mis-spelled word so that we ensure the
      // caret location is legitimate after deleting the word. E.g.,
      // consider what would happen if the mis-spelled word is the last
      // word in the given paragraph.
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: wordRange.start,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      // Delete the mis-spelled word.
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: wordRange.start,
          end: wordRange.end.copyWith(
            nodePosition: TextNodePosition(
              // +1 to make end of range exclusive.
              offset: (wordRange.end.nodePosition as TextNodePosition).offset + 1,
            ),
          ),
        ),
      ),
      // Insert the correctly spelled word.
      InsertTextRequest(
        documentPosition: wordRange.start,
        textToInsert: correctSpelling,
        attributions: {},
      ),
      ChangeComposingRegionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: wordRange.start.nodeId,
            nodePosition: TextNodePosition(
              offset: (wordRange.start.nodePosition as TextNodePosition).offset + correctSpelling.length,
            ),
          ),
        ),
      ),
      // // Places the caret at the end of the corrected word.
      // ChangeSelectionRequest(
      //   DocumentSelection.collapsed(
      //     position: DocumentPosition(
      //       nodeId: wordRange.start.nodeId,
      //       nodePosition: TextNodePosition(
      //         offset: (wordRange.start.nodePosition as TextNodePosition).offset + correctSpelling.length,
      //       ),
      //     ),
      //   ),
      //   SelectionChangeType.alteredContent,
      //   SelectionReason.contentChange,
      // ),
    ]);
  }

  void removeMisspelledWord(DocumentRange wordRange) {
    execute([
      // Move caret to start of mis-spelled word so that we ensure the
      // caret location is legitimate after deleting the word. E.g.,
      // consider what would happen if the mis-spelled word is the last
      // word in the given paragraph.
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: wordRange.start,
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      // Delete the mis-spelled word.
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: wordRange.start,
          end: wordRange.end.copyWith(
            nodePosition: TextNodePosition(
              // +1 to make end of range exclusive.
              offset: (wordRange.end.nodePosition as TextNodePosition).offset + 1,
            ),
          ),
        ),
      ),
    ]);
  }
}

/// An [EditReaction] that runs spelling and grammar checks on all [TextNode]s
/// in a given [Document].
class SpellingAndGrammarReaction implements EditReaction {
  SpellingAndGrammarReaction(this._suggestions, this._styler);

  final SpellingErrorSuggestions _suggestions;

  final SpellingAndGrammarStyler _styler;

  bool isSpellCheckEnabled = true;

  set spellingErrorUnderlineStyle(UnderlineStyle style) => _styler.spellingErrorUnderlineStyle = style;

  bool isGrammarCheckEnabled = true;

  set grammarErrorUnderlineStyle(UnderlineStyle style) => _styler.grammarErrorUnderlineStyle = style;

  /// A map from a document node to the ID of the most recent spelling and grammar
  /// check request ID.
  ///
  /// This map is used to ignore spell and grammar check responses that arrive after
  /// later spelling and grammar checks. This is a concern because we cross an async
  /// boundary to the platform to run such checks, removing any guarantee about order
  /// of receipt.
  final _asyncRequestIds = <String, int>{};

  final _mobileSpellChecker = DefaultSpellCheckService();

  @override
  void modifyContent(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    // No-op - spelling and grammar checks style the document, they don't alter the document.
  }

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (kIsWeb ||
        !const [TargetPlatform.macOS, TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) {
      // We currently only support spell check when running on Mac desktop or mobile platforms.
      return;
    }

    // Clear our request cache for any nodes that were deleted.
    // Also clear suggestions for deleted nodes.
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeRemovedEvent) {
        continue;
      }

      _suggestions.clearNode(change.nodeId);
      _asyncRequestIds.remove(change.nodeId);
    }

    if (!isSpellCheckEnabled && !isGrammarCheckEnabled) {
      return;
    }

    final document = editorContext.document;

    final changedTextNodes = <String>{};
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeChangeEvent) {
        continue;
      }

      final node = document.getNodeById(change.nodeId);
      if (node is! TextNode) {
        continue;
      }

      // A TextNode was changed in some way. Queue it for spelling and grammar checks.
      changedTextNodes.add(node.id);
    }

    for (final textNodeId in changedTextNodes) {
      final textNode = document.getNodeById(textNodeId);
      if (textNode == null) {
        editorSpellingAndGrammarLog.warning(
            "A TextNode that was listed as changed in a transaction somehow disappeared from the Document before this Reaction ran.");
        continue;
      }
      if (textNode is! TextNode) {
        editorSpellingAndGrammarLog.warning(
            "A TextNode that was listed as changed in a transaction somehow became a non-text node before this Reaction ran.");
        continue;
      }

      _findSpellingAndGrammarErrors(textNode);
    }
  }

  Future<void> _findSpellingAndGrammarErrors(TextNode textNode) async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _findSpellingAndGrammarErrorsOnMac(textNode);
    } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      await _findSpellingAndGrammarErrorsOnMobile(textNode);
    }
  }

  Future<void> _findSpellingAndGrammarErrorsOnMac(TextNode textNode) async {
    final spellChecker = SuperEditorSpellCheckerPlugin().macSpellChecker;

    // TODO: Investigate whether we can parallelize spelling and grammar checks
    //       for a given node (and whether it's worth the complexity).
    final textErrors = <TextError>{};

    // Track this spelling and grammar request to make sure we don't process
    // the response out of order with other requests.
    _asyncRequestIds[textNode.id] ??= 0;
    final requestId = _asyncRequestIds[textNode.id]! + 1;
    _asyncRequestIds[textNode.id] = requestId;

    int startingOffset = 0;
    TextRange prevError = TextRange.empty;
    final locale = PlatformDispatcher.instance.locale;
    final language = spellChecker.convertDartLocaleToMacLanguageCode(locale)!;
    final spellingSuggestions = <TextRange, SpellingErrorSuggestion>{};
    if (isSpellCheckEnabled) {
      do {
        prevError = await spellChecker.checkSpelling(
          stringToCheck: textNode.text.text,
          startingOffset: startingOffset,
          language: language,
        );

        if (prevError.isValid) {
          final word = textNode.text.text.substring(prevError.start, prevError.end);

          // Ask platform for spelling correction guesses.
          final guesses = await spellChecker.guesses(range: prevError, text: textNode.text.text);

          textErrors.add(
            TextError.spelling(
              nodeId: textNode.id,
              range: prevError,
              value: word,
              suggestions: guesses,
            ),
          );

          spellingSuggestions[prevError] = SpellingErrorSuggestion(
            word: word,
            nodeId: textNode.id,
            range: prevError,
            suggestions: guesses,
          );

          startingOffset = prevError.end;
        }
      } while (prevError.isValid);
    }

    if (isGrammarCheckEnabled) {
      startingOffset = 0;
      prevError = TextRange.empty;
      do {
        final result = await spellChecker.checkGrammar(
          stringToCheck: textNode.text.text,
          startingOffset: startingOffset,
          language: language,
        );
        prevError = result.firstError ?? TextRange.empty;

        if (prevError.isValid) {
          for (final grammarError in result.details) {
            final errorRange = grammarError.range;
            final text = textNode.text.text.substring(errorRange.start, errorRange.end);
            textErrors.add(
              TextError.grammar(
                nodeId: textNode.id,
                range: errorRange,
                value: text,
              ),
            );
          }

          startingOffset = prevError.end;
        }
      } while (prevError.isValid);
    }

    if (requestId != _asyncRequestIds[textNode.id]) {
      // Another request was started for this node while we were running our
      // request. Fizzle.
      return;
    }
    // Reset the request ID counter to zero so that we avoid increasing infinitely.
    _asyncRequestIds[textNode.id] = 0;

    // Display underlines on spelling and grammar errors.
    _styler
      ..clearErrorsForNode(textNode.id)
      ..addErrors(textNode.id, textErrors);

    // Update the shared repository of spelling suggestions so that the user can
    // see suggestions and select them.
    _suggestions.putSuggestions(textNode.id, spellingSuggestions);
  }

  Future<void> _findSpellingAndGrammarErrorsOnMobile(TextNode textNode) async {
    final textErrors = <TextError>{};
    final spellingSuggestions = <TextRange, SpellingErrorSuggestion>{};

    // Track this spelling and grammar request to make sure we don't process
    // the response out of order with other requests.
    _asyncRequestIds[textNode.id] ??= 0;
    final requestId = _asyncRequestIds[textNode.id]! + 1;
    _asyncRequestIds[textNode.id] = requestId;

    final suggestions = await _mobileSpellChecker.fetchSpellCheckSuggestions(
      Locale('en', 'US'),
      textNode.text.text,
    );
    if (suggestions == null) {
      return;
    }

    for (final suggestion in suggestions) {
      final misspelledWord = textNode.text.substring(suggestion.range.start, suggestion.range.end);
      spellingSuggestions[suggestion.range] = SpellingErrorSuggestion(
        word: misspelledWord,
        nodeId: textNode.id,
        range: suggestion.range,
        suggestions: suggestion.suggestions,
      );
      textErrors.add(
        TextError.spelling(
          nodeId: textNode.id,
          range: suggestion.range,
          value: misspelledWord,
          suggestions: suggestion.suggestions,
        ),
      );
    }

    if (requestId != _asyncRequestIds[textNode.id]) {
      // Another request was started for this node while we were running our
      // request. Fizzle.
      return;
    }
    // Reset the request ID counter to zero so that we avoid increasing infinitely.
    _asyncRequestIds[textNode.id] = 0;

    // Display underlines on spelling and grammar errors.
    _styler
      ..clearErrorsForNode(textNode.id)
      ..addErrors(textNode.id, textErrors);

    // Update the shared repository of spelling suggestions so that the user can
    // see suggestions and select them.
    _suggestions.putSuggestions(textNode.id, spellingSuggestions);
  }
}

class SuperEditorIosSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  SuperEditorIosSpellCheckerTapHandler({
    required this.popoverController,
    required this.controlsController,
    required this.styler,
    super.editor,
  });

  final SpellCheckerPopoverController popoverController;
  final SuperEditorIosControlsController controlsController;
  final SpellingAndGrammarStyler styler;

  @override
  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final spelling = popoverController.findSuggestionsForWordAt(DocumentSelection.collapsed(position: tapPosition));
    if (spelling == null || spelling.suggestions.isEmpty) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    controlsController
      ..hideToolbar()
      ..hideMagnifier()
      ..preventSelectionHandles();

    editor!.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: tapPosition.nodeId,
            nodePosition: TextNodePosition(offset: spelling.range.start),
          ),
          extent: DocumentPosition(
            nodeId: tapPosition.nodeId,
            nodePosition: TextNodePosition(offset: spelling.range.end),
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    //controlsController.

    popoverController.show(DocumentSelection.collapsed(position: tapPosition));

    styler.overrideSelectionColor();

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentPosition tapPosition) {
    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    styler.useDefaultSelectionColor();
    popoverController.hide();
    controlsController.allowSelectionHandles();
  }
}

class SuperEditorAndroidSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  SuperEditorAndroidSpellCheckerTapHandler({
    required this.popoverController,
    required this.controlsController,
    required this.styler,
    super.editor,
  });

  final SpellCheckerPopoverController popoverController;
  final SuperEditorAndroidControlsController controlsController;
  final SpellingAndGrammarStyler styler;

  @override
  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final suggestions = popoverController.findSuggestionsForWordAt(DocumentSelection.collapsed(position: tapPosition));
    if (suggestions == null) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    controlsController
      ..hideToolbar()
      ..hideMagnifier()
      ..hideToolbar()
      ..preventSelectionHandles();

    final wordSelection = DocumentSelection(
      base: DocumentPosition(
        nodeId: tapPosition.nodeId,
        nodePosition: TextNodePosition(offset: suggestions.range.start),
      ),
      extent: DocumentPosition(
        nodeId: tapPosition.nodeId,
        nodePosition: TextNodePosition(offset: suggestions.range.end),
      ),
    );

    editor!.execute([
      ChangeSelectionRequest(
        wordSelection,
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
      ChangeComposingRegionRequest(wordSelection),
    ]);

    popoverController.show(DocumentSelection.collapsed(position: tapPosition));

    styler.overrideSelectionColor();

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentPosition tapPosition) {
    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    controlsController.allowSelectionHandles();
    styler.useDefaultSelectionColor();
    popoverController.hide();
  }
}

class SuperEditorDesktopSpellCheckerTapHandler extends _SpellCheckerContentTapDelegate {
  SuperEditorDesktopSpellCheckerTapHandler({
    required this.popoverController,
    super.editor,
  });

  final SpellCheckerPopoverController popoverController;

  @override
  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    if (editor == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final spelling = popoverController.findSuggestionsForWordAt(DocumentSelection.collapsed(position: tapPosition));
    if (spelling == null || spelling.suggestions.isEmpty) {
      _hideSpellCheckerPopover();
      return TapHandlingInstruction.continueHandling;
    }

    editor!.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: tapPosition),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    popoverController.show(DocumentSelection.collapsed(position: tapPosition));

    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentPosition tapPosition) {
    _hideSpellCheckerPopover();
    return TapHandlingInstruction.continueHandling;
  }

  void _hideSpellCheckerPopover() {
    popoverController.hide();
  }
}

class _SpellCheckerContentTapDelegate extends ContentTapDelegate {
  _SpellCheckerContentTapDelegate({
    this.editor,
  });

  Editor? editor;
}
