import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../attributed_text_editing_value.dart';

class EventSourcedAttributedTextEditingController with ChangeNotifier implements AttributedTextEditingController {
  EventSourcedAttributedTextEditingController(this._value);

  AttributedTextEditingValue _value;

  @override
  AttributedText get text => _value.text;

  // TODO: remove from interface
  @override
  set text(AttributedText _) => throw UnimplementedError();

  @override
  TextSelection get selection => _value.selection;

  // TODO: remove from interface
  @override
  set selection(TextSelection _) => throw UnimplementedError();

  @override
  TextRange get composingRegion => _value.composingRegion;

  // TODO: remove from interface
  @override
  set composingRegion(TextRange _) => throw UnimplementedError();

  // TODO: this should probably an extension method on AttributedText or something
  // like that.
  @override
  bool isSelectionWithinTextBounds(TextSelection selection) {
    return selection.start <= text.text.length && selection.end <= text.text.length;
  }

  /// Updates the [composingAttributions] based on the current [selection]
  /// and [text].
  void _updateComposingAttributions() {
    if (selection.isCollapsed) {
      _composingAttributions
        ..clear()
        ..addAll(text.getAllAttributionsAt(
          max(selection.extentOffset - 1, 0),
        ));
    } else {
      _composingAttributions
        ..clear()
        ..addAll(text.getAllAttributionsThroughout(
          SpanRange(start: selection.start, end: selection.end),
        ));
    }
  }

  final _composingAttributions = <Attribution>{};

  // TODO: good litmus test - what if a developer wanted composing attribution
  // presence to be undo/redo-able? Or the same for some other editing configuration?

  /// Attributions that will be applied to the next inserted character(s).
  @override
  Set<Attribution> get composingAttributions => Set.from(_composingAttributions);

  /// Replaces all existing [composingAttributions] with the given [attributions].
  @override
  set composingAttributions(Set<Attribution> attributions) {
    _composingAttributions
      ..clear()
      ..addAll(attributions);
    notifyListeners();
  }

  /// Adds the given [attributions] to [composingAttributions].
  @override
  void addComposingAttributions(Set<Attribution> attributions) {
    _composingAttributions.addAll(attributions);
    notifyListeners();
  }

  /// Toggles the presence of each of the given [attributions] within
  /// the [composingAttributions].
  @override
  void toggleComposingAttributions(Set<Attribution> attributions) {
    if (attributions.isEmpty) {
      return;
    }

    for (final attribution in attributions) {
      if (_composingAttributions.contains(attribution)) {
        _composingAttributions.remove(attribution);
      } else {
        _composingAttributions.add(attribution);
      }
    }

    notifyListeners();
  }

  /// Removes the given [attributions] from [composingAttributions].
  @override
  void removeComposingAttributions(Set<Attribution> attributions) {
    _composingAttributions.removeWhere((attribution) => attributions.contains(attribution));
    notifyListeners();
  }

  /// Removes all attributions from [composingAttributions].
  @override
  void clearComposingAttributions() {
    if (_composingAttributions.isNotEmpty) {
      _composingAttributions.clear();
      notifyListeners();
    }
  }

  @override
  void moveCaretHorizontally({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveLeft,
    required MovementModifier? movementModifier,
  }) {
    // TODO: create a command
  }

  @override
  void moveCaretVertically({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveUp,
  }) {
    // TODO: create a command
  }

  @override
  void selectAll() {
    // TODO: create a command
  }

  /// Toggles the presence of each of the given [attributions] within
  /// the text in the [selection].
  @override
  void toggleSelectionAttributions(List<Attribution> attributions) {
    if (attributions.isEmpty) {
      return;
    }

    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  /// Removes all attributions from the text that is currently selected.
  @override
  void clearSelectionAttributions() {
    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  @override
  void updateTextAndSelection({
    required AttributedText text,
    required TextSelection selection,
  }) {
    // TODO: create a command
  }

  @override
  void insertCharacter(String character) {
    // TODO: create a command
  }

  @override
  void insertNewline() {
    // TODO: create a command
  }

  /// Inserts the given [text] at the current caret position.
  ///
  /// The current [composingAttributions] are applied to the given
  /// [text] and the caret is moved to the end of the given [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  @override
  void insertAtCaret({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
      return;
    }

    // TODO: create a command
  }

  /// Inserts the given [text] at the current caret position, extending whatever
  /// attributions exist at the offset before the insertion.
  ///
  /// The caret is moved to the end of the inserted [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  @override
  void insertAtCaretWithUpstreamAttributions({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
      return;
    }

    // TODO: create a command
  }

  /// Inserts the given [attributedText] at the current caret position.
  ///
  /// The caret is moved to the end of the inserted [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  @override
  void insertAttributedTextAtCaret({
    required AttributedText attributedText,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
      return;
    }

    // TODO: create a command
  }

  /// Inserts the given [text] at the current caret position without any
  /// attributions applied to the [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  @override
  void insertAtCaretUnstyled({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
      return;
    }

    // TODO: create a command
  }

  /// Inserts [newText], starting at the given [insertIndex].
  ///
  /// The [selection] is updated to [newSelection], if provided, otherwise
  /// a best-guess attempt is made to adjust the selection based on an
  /// insertion action.
  ///
  /// The [composingRegion] is updated to [newComposingRegion], if provided,
  /// otherwise the [composingRegion] is set to `TextRange.empty`.
  @override
  void insert({
    required AttributedText newText,
    required int insertIndex,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    // TODO: create a command
  }

  /// Replaces the currently selected text with [replacementText] and collapses
  /// the selection at the end of [replacementText].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  @override
  void replaceSelectionWithTextAndUpstreamAttributions({
    required String replacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  /// Replaces the currently selected text with [attributedReplacementText] and
  /// collapses the selection at the end of [attributedReplacementText].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  @override
  void replaceSelectionWithAttributedText({
    required AttributedText attributedReplacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  /// Replaces the currently selected text with un-styled [text] and collapses
  /// the selection at the end of the [text].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  @override
  void replaceSelectionWithUnstyledText({
    required String replacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  /// Removes the text between [from] (inclusive) and [to] (exclusive), and replaces that
  /// text with [newText].
  ///
  /// The [selection] is updated to [newSelection], if provided, otherwise
  /// a best-guess attempt is made to adjust the selection based on an
  /// insertion action.
  ///
  /// The [composingRegion] is updated to [newComposingRegion], if provided,
  /// otherwise the [composingRegion] is set to `TextRange.empty`.
  @override
  void replace({
    required AttributedText newText,
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    // TODO: create a command
  }

  @override
  void deleteTextOnLineBeforeCaret({
    required ProseTextLayout textLayout,
  }) {
    assert(selection.isCollapsed);

    // TODO: create a command
  }

  @override
  void deleteSelectedText() {
    assert(!selection.isCollapsed);

    // TODO: create a command
  }

  @override
  void deleteCharacter(TextAffinity direction) {
    assert(selection.isCollapsed);
    if (!selection.isCollapsed) {
      return;
    }

    if (direction == TextAffinity.downstream) {
      deleteNextCharacter();
    } else {
      deletePreviousCharacter();
    }
  }

  /// Deletes the character before the currently collapsed [selection] and
  /// moves [selection] upstream by one character.
  ///
  /// Does nothing if [selection] is not collapsed.
  @override
  void deletePreviousCharacter({
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      return;
    }

    if (selection.extentOffset == 0) {
      return;
    }

    // TODO: create a command
  }

  /// Deletes the character after the currently collapsed [selection].
  ///
  /// Does nothing if [selection] is not collapsed.
  @override
  void deleteNextCharacter({
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      return;
    }

    if (selection.extentOffset >= text.text.length) {
      return;
    }

    // TODO: create a command
  }

  /// Deletes the text within the current [selection].
  ///
  /// Does nothing if [selection] is collapsed.
  @override
  void deleteSelection({
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    // TODO: create a command
  }

  /// Removes the text between [from] (inclusive) and [to] (exclusive).
  ///
  /// The [selection] is updated to [newSelection], if provided, otherwise
  /// a best-guess attempt is made to adjust the selection based on an
  /// insertion action.
  ///
  /// The [composingRegion] is updated to [newComposingRegion], if provided,
  /// otherwise the [composingRegion] is set to `TextRange.empty`.
  @override
  void delete({
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    // TODO: create a command
  }

  @override
  void update({
    AttributedText? text,
    TextSelection? selection,
    TextRange? composingRegion,
  }) {
    // TODO: create a command
  }

  @override
  void clear() {
    // TODO: create a command
  }

  @override
  void copySelectedTextToClipboard() {
    if (selection.extentOffset == -1) {
      // Nothing selected to copy.
      return;
    }

    Clipboard.setData(ClipboardData(
      text: selection.textInside(text.text),
    ));
  }

  @override
  Future<void> pasteClipboard() async {
    final insertionOffset = selection.extentOffset;
    final clipboardData = await Clipboard.getData('text/plain');

    if (clipboardData != null && clipboardData.text != null) {
      final textToPaste = clipboardData.text!;

      // TODO: create a command
    }
  }

  @override
  TextSpan buildTextSpan(AttributionStyleBuilder styleBuilder) {
    return text.computeTextSpan(styleBuilder);
  }
}
