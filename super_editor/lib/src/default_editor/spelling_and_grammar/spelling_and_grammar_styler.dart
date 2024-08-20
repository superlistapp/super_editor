import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A [SingleColumnLayoutStylePhase] that applies spelling and grammar error
/// underlines to [TextNode]s in the document that have reported errors.
class SpellingAndGrammarStyler extends SingleColumnLayoutStylePhase {
  SpellingAndGrammarStyler({
    UnderlineStyle spellingErrorUnderlineStyle = defaultSpellingErrorUnderlineStyle,
    UnderlineStyle grammarErrorUnderlineStyle = defaultGrammarErrorUnderlineStyle,
  })  : _spellingErrorUnderlineStyle = spellingErrorUnderlineStyle,
        _grammarErrorUnderlineStyle = grammarErrorUnderlineStyle;

  UnderlineStyle _spellingErrorUnderlineStyle;
  set spellingErrorUnderlineStyle(UnderlineStyle style) {
    _spellingErrorUnderlineStyle = style;
    markDirty();
  }

  UnderlineStyle _grammarErrorUnderlineStyle;
  set grammarErrorUnderlineStyle(UnderlineStyle style) {
    _grammarErrorUnderlineStyle = style;
    markDirty();
  }

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

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    final updatedViewModel = SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applyErrors(previousViewModel),
      ],
    );

    _dirtyNodes.clear();

    return updatedViewModel;
  }

  SingleColumnLayoutComponentViewModel _applyErrors(SingleColumnLayoutComponentViewModel viewModel) {
    print("Applying errors to node: ${viewModel.nodeId}");
    if (!_errorsByNode.containsKey(viewModel.nodeId)) {
      return viewModel;
    }
    if (viewModel is! TextComponentViewModel) {
      // TODO: log error about component type
      return viewModel;
    }

    final spellingErrors = _errorsByNode[viewModel.nodeId]!.where((error) => error.type == TextErrorType.spelling);
    print("Styling node with ${spellingErrors.length} spelling errors");
    viewModel.spellingErrorUnderlineStyle = _spellingErrorUnderlineStyle;
    viewModel.spellingErrors
      ..clear()
      ..addAll([
        for (final spellingError in spellingErrors) spellingError.range,
      ]);

    final grammarErrors = _errorsByNode[viewModel.nodeId]!.where((error) => error.type == TextErrorType.grammar);
    print("Styling component view model (${viewModel.runtimeType}) with ${grammarErrors.length} grammar errors");
    viewModel.grammarErrorUnderlineStyle = _grammarErrorUnderlineStyle;
    viewModel.grammarErrors
      ..clear()
      ..addAll([
        for (final grammarError in grammarErrors) grammarError.range,
      ]);

    return viewModel;
  }
}

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
