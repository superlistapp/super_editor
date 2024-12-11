import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A [SingleColumnLayoutStylePhase] that applies spelling and grammar error
/// underlines to [TextNode]s in the document that have reported errors.
///
/// Provide a [spellingErrorUnderlineStyle] and/or [grammarErrorUnderlineStyle]
/// to override all other style preferences for spelling and grammar error underline
/// styles across all text components.
class SpellingAndGrammarStyler extends SingleColumnLayoutStylePhase {
  SpellingAndGrammarStyler({
    UnderlineStyle? spellingErrorUnderlineStyle,
    UnderlineStyle? grammarErrorUnderlineStyle,
    this.selectionHighlightColor = Colors.transparent,
  })  : _spellingErrorUnderlineStyle = spellingErrorUnderlineStyle,
        _grammarErrorUnderlineStyle = grammarErrorUnderlineStyle;

  UnderlineStyle? _spellingErrorUnderlineStyle;
  set spellingErrorUnderlineStyle(UnderlineStyle? style) {
    if (style == _spellingErrorUnderlineStyle) {
      return;
    }

    _spellingErrorUnderlineStyle = style;
    markDirty();
  }

  UnderlineStyle? _grammarErrorUnderlineStyle;
  set grammarErrorUnderlineStyle(UnderlineStyle? style) {
    if (style == _grammarErrorUnderlineStyle) {
      return;
    }

    _grammarErrorUnderlineStyle = style;
    markDirty();
  }

  /// Whether or not we should override the default selection color with [selectionHighlightColor].
  ///
  /// On mobile platforms, when the suggestions popover is opened, the selected text uses a different
  /// highlight color.
  bool _overrideSelectionColor = false;

  /// The color to use for the selection highlight [overrideSelectionColor] is called.
  final Color selectionHighlightColor;

  final _errorsByNode = <String, Set<TextError>>{};
  final _dirtyNodes = <String>{};

  void addErrors(String nodeId, Set<TextError> errors) {
    _errorsByNode[nodeId] ??= <TextError>{};
    _errorsByNode[nodeId]!.addAll(errors);
    _dirtyNodes.add(nodeId);

    markDirty();
  }

  void clearErrorsForNode(String nodeId) {
    _errorsByNode.remove(nodeId);
    _dirtyNodes.add(nodeId);

    markDirty();
  }

  void clearAllErrors() {
    _dirtyNodes.addAll(_errorsByNode.keys);
    _errorsByNode.clear();

    markDirty();
  }

  /// Configure this styler to override the default selection color with [selectionHighlightColor].
  ///
  /// The default editor selection styler phase configures a selection color for all selections.
  /// Call this method to use [selectionHighlightColor] instead. This is useful to highlight a
  /// selected misspelled word with a color that is different from the default selection color.
  ///
  /// Call [useDefaultSelectionColor] to stop overriding the default selection color.
  void overrideSelectionColor() {
    _overrideSelectionColor = true;
    markDirty();
  }

  /// Stop overriding the default selection color.
  ///
  /// After calling this method, all selections will use the default selection color.
  void useDefaultSelectionColor() {
    _overrideSelectionColor = false;
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    final updatedViewModel = SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applyErrors(previousViewModel.copy()),
      ],
    );

    _dirtyNodes.clear();

    return updatedViewModel;
  }

  SingleColumnLayoutComponentViewModel _applyErrors(SingleColumnLayoutComponentViewModel viewModel) {
    if (!_errorsByNode.containsKey(viewModel.nodeId)) {
      return viewModel;
    }
    if (viewModel is! TextComponentViewModel) {
      editorSpellingAndGrammarLog
          .warning("Tried to apply spelling/grammar errors to a non-text view model: ${viewModel.runtimeType}");
      return viewModel;
    }

    final spellingErrors = _errorsByNode[viewModel.nodeId]!.where((error) => error.type == TextErrorType.spelling);
    if (_spellingErrorUnderlineStyle != null) {
      // The user explicitly requested this style be used for spelling errors.
      // Apply it.
      viewModel.spellingErrorUnderlineStyle = _spellingErrorUnderlineStyle!;
    }
    viewModel.spellingErrors
      ..clear()
      ..addAll([
        for (final spellingError in spellingErrors) spellingError.range,
      ]);

    if (_overrideSelectionColor) {
      viewModel.selectionColor = selectionHighlightColor;
    }

    final grammarErrors = _errorsByNode[viewModel.nodeId]!.where((error) => error.type == TextErrorType.grammar);
    if (_grammarErrorUnderlineStyle != null) {
      // The user explicitly requested this style be used for grammar errors.
      // Apply it.
      viewModel.grammarErrorUnderlineStyle = _grammarErrorUnderlineStyle!;
    }
    viewModel.grammarErrors
      ..clear()
      ..addAll([
        for (final grammarError in grammarErrors) grammarError.range,
      ]);

    return viewModel;
  }
}

/// A spelling or grammar error within a [TextNode].
///
/// Each error refers to the node with the error, the text range in the node that
/// constitutes the error, the type of error, the text with the error, and (possibly)
/// suggested corrections for that error.
class TextError {
  const TextError.spelling({
    required this.nodeId,
    required this.range,
    required this.value,
    this.suggestions = const [],
  }) : type = TextErrorType.spelling;

  const TextError.grammar({
    required this.nodeId,
    required this.range,
    required this.value,
    this.suggestions = const [],
  }) : type = TextErrorType.grammar;

  const TextError({
    required this.nodeId,
    required this.range,
    required this.type,
    required this.value,
    this.suggestions = const [],
  });

  final String nodeId;
  final TextRange range;
  final TextErrorType type;
  final String value;
  final List<String> suggestions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextError &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          range == other.range &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => nodeId.hashCode ^ range.hashCode ^ type.hashCode ^ value.hashCode;
}

enum TextErrorType {
  spelling,
  grammar;
}

const defaultSpellingErrorUnderlineStyle = SquiggleUnderlineStyle(color: Colors.red);
const defaultGrammarErrorUnderlineStyle = SquiggleUnderlineStyle(color: Colors.blue);
