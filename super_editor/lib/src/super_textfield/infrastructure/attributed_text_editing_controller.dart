import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/strings.dart';
import 'package:super_text_layout/super_text_layout.dart';

class AttributedTextEditingController with ChangeNotifier {
  AttributedTextEditingController({
    AttributedText? text,
    TextSelection? selection,
    TextRange? composingRegion,
  })  : _text = text ?? AttributedText(),
        _selection = selection ?? const TextSelection.collapsed(offset: -1),
        _composingRegion = composingRegion ?? TextRange.empty {
    _updateComposingAttributions();
    text?.addListener(notifyListeners);
  }

  TextSelection _selection;
  TextSelection get selection => _selection;
  set selection(TextSelection newValue) {
    if (newValue != _selection) {
      _selection = newValue;
      _updateComposingAttributions();
      notifyListeners();
    }
  }

  bool isSelectionWithinTextBounds(TextSelection selection) {
    return selection.start <= text.length && selection.end <= text.length;
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
          selection.toSpanRange(),
        ));
    }
  }

  final _composingAttributions = <Attribution>{};

  /// Attributions that will be applied to the next inserted character(s).
  Set<Attribution> get composingAttributions => Set.from(_composingAttributions);

  /// Replaces all existing [composingAttributions] with the given [attributions].
  set composingAttributions(Set<Attribution> attributions) {
    _composingAttributions
      ..clear()
      ..addAll(attributions);
    notifyListeners();
  }

  /// Adds the given [attributions] to [composingAttributions].
  void addComposingAttributions(Set<Attribution> attributions) {
    _composingAttributions.addAll(attributions);
    notifyListeners();
  }

  /// Toggles the presence of each of the given [attributions] within
  /// the [composingAttributions].
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
  void removeComposingAttributions(Set<Attribution> attributions) {
    _composingAttributions.removeWhere((attribution) => attributions.contains(attribution));
    notifyListeners();
  }

  /// Removes all attributions from [composingAttributions].
  void clearComposingAttributions() {
    if (_composingAttributions.isNotEmpty) {
      _composingAttributions.clear();
      notifyListeners();
    }
  }

  /// Toggles the presence of each of the given [attributions] within
  /// the text in the [selection].
  void toggleSelectionAttributions(List<Attribution> attributions) {
    if (attributions.isEmpty) {
      return;
    }

    if (selection.isCollapsed) {
      return;
    }

    for (final attribution in attributions) {
      _text.toggleAttribution(
        attribution,
        SpanRange(selection.start, selection.end - 1),
      );
    }

    notifyListeners();
  }

  /// Removes all attributions from the text that is currently selected.
  void clearSelectionAttributions() {
    if (selection.isCollapsed) {
      return;
    }

    _text.clearAttributions(
      SpanRange(selection.start, selection.end - 1),
    );

    notifyListeners();
  }

  TextRange _composingRegion;
  TextRange get composingRegion => _composingRegion;
  set composingRegion(TextRange newValue) {
    if (newValue != _composingRegion) {
      _composingRegion = newValue;
      notifyListeners();
    }
  }

  void updateTextAndSelection({
    required AttributedText text,
    required TextSelection selection,
  }) {
    if (text == _text && selection == _selection) {
      return;
    }

    _switchText(text);
    _selection = selection;

    _updateComposingAttributions();

    notifyListeners();
  }

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newValue) {
    if (newValue != _text) {
      _switchText(newValue);

      // Ensure that the existing selection does not overshoot
      // the end of the new text value
      if (_selection.end > _text.text.length) {
        _selection = _selection.copyWith(
          baseOffset: _selection.affinity == TextAffinity.downstream ? _selection.baseOffset : _text.text.length,
          extentOffset: _selection.affinity == TextAffinity.downstream ? _text.text.length : _selection.extentOffset,
        );
      }

      notifyListeners();
    }
  }

  void _switchText(AttributedText newText) {
    _text.removeListener(notifyListeners);
    _text = newText;
    _text.addListener(notifyListeners);
  }

  /// Inserts the given [text] at the current caret position.
  ///
  /// The current [composingAttributions] are applied to the given
  /// [text] and the caret is moved to the end of the given [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  void insertAtCaret({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
    }

    final updatedText = _text.insertString(
      textToInsert: text,
      startOffset: selection.extentOffset,
      applyAttributions: Set.from(composingAttributions),
    );

    final updatedSelection = _moveSelectionForInsertion(
      selection: selection,
      insertIndex: selection.extentOffset,
      newTextLength: text.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Inserts the given [text] at the current caret position, extending whatever
  /// attributions exist at the offset before the insertion.
  ///
  /// The caret is moved to the end of the inserted [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  void insertAtCaretWithUpstreamAttributions({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
    }

    final upstreamAttributions = _text.getAllAttributionsAt(max(selection.extentOffset - 1, 0));

    final updatedText = _text.insertString(
      textToInsert: text,
      startOffset: selection.extentOffset,
      applyAttributions: upstreamAttributions,
    );

    final updatedSelection = _moveSelectionForInsertion(
      selection: selection,
      insertIndex: selection.extentOffset,
      newTextLength: text.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Inserts the given [attributedText] at the current caret position.
  ///
  /// The caret is moved to the end of the inserted [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  void insertAttributedTextAtCaret({
    required AttributedText attributedText,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
    }

    final updatedText = _text.insert(
      textToInsert: attributedText,
      startOffset: selection.extentOffset,
    );

    final updatedSelection = _moveSelectionForInsertion(
      selection: selection,
      insertIndex: selection.extentOffset,
      newTextLength: text.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Inserts the given [text] at the current caret position without any
  /// attributions applied to the [text].
  ///
  /// If the current [selection] is expanded, this method does nothing,
  /// because there is no conceptual caret with an expanded selection.
  void insertAtCaretUnstyled({
    required String text,
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      textFieldLog.warning('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
    }

    final updatedText = _text.insertString(
      textToInsert: text,
      startOffset: selection.extentOffset,
    );

    final updatedSelection = _moveSelectionForInsertion(
      selection: selection,
      insertIndex: selection.extentOffset,
      newTextLength: text.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Inserts [newText], starting at the given [insertIndex].
  ///
  /// The [selection] is updated to [newSelection], if provided, otherwise
  /// a best-guess attempt is made to adjust the selection based on an
  /// insertion action.
  ///
  /// The [composingRegion] is updated to [newComposingRegion], if provided,
  /// otherwise the [composingRegion] is set to `TextRange.empty`.
  void insert({
    required AttributedText newText,
    required int insertIndex,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    final updatedText = _text.insert(
      textToInsert: newText,
      startOffset: insertIndex,
    );

    final updatedSelection = newSelection ??
        _moveSelectionForInsertion(
          selection: _selection,
          insertIndex: insertIndex,
          newTextLength: newText.text.length,
        );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion ?? TextRange.empty,
    );
  }

  TextSelection _moveSelectionForInsertion({
    required TextSelection selection,
    required int insertIndex,
    required int newTextLength,
  }) {
    int newBaseOffset = selection.baseOffset;
    if ((selection.baseOffset == insertIndex && selection.isCollapsed) || (selection.baseOffset > insertIndex)) {
      newBaseOffset = selection.baseOffset + newTextLength;
    }

    final newExtentOffset =
        selection.extentOffset >= insertIndex ? selection.extentOffset + newTextLength : selection.extentOffset;

    return TextSelection(
      baseOffset: newBaseOffset,
      extentOffset: newExtentOffset,
    );
  }

  /// Replaces the currently selected text with [replacementText] and collapses
  /// the selection at the end of [replacementText].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  void replaceSelectionWithTextAndUpstreamAttributions({
    required String replacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    final upstreamAttributions = _text.getAllAttributionsAt(max(selection.extentOffset - 1, 0));

    var updatedText = _text.removeRegion(
      startOffset: selection.baseOffset,
      endOffset: selection.extentOffset,
    );
    updatedText = updatedText.insertString(
      textToInsert: replacementText,
      startOffset: selection.baseOffset,
      applyAttributions: upstreamAttributions,
    );
    final updatedSelection = TextSelection.collapsed(
      offset: selection.baseOffset + replacementText.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Replaces the currently selected text with [attributedReplacementText] and
  /// collapses the selection at the end of [attributedReplacementText].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  void replaceSelectionWithAttributedText({
    required AttributedText attributedReplacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    var updatedText = _text.removeRegion(
      startOffset: selection.baseOffset,
      endOffset: selection.extentOffset,
    );
    updatedText = updatedText.insert(
      textToInsert: attributedReplacementText,
      startOffset: selection.baseOffset,
    );
    final updatedSelection = TextSelection.collapsed(
      offset: selection.baseOffset + attributedReplacementText.text.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
  }

  /// Replaces the currently selected text with un-styled [text] and collapses
  /// the selection at the end of the [text].
  ///
  /// To insert text after a caret (collapsed selection), use [insertAtCaret].
  void replaceSelectionWithUnstyledText({
    required String replacementText,
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    var updatedText = _text.removeRegion(
      startOffset: selection.baseOffset,
      endOffset: selection.extentOffset,
    );
    updatedText = updatedText.insertString(
      textToInsert: replacementText,
      startOffset: selection.baseOffset,
    );
    final updatedSelection = TextSelection.collapsed(
      offset: selection.baseOffset + replacementText.length,
    );

    update(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion,
    );
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
  void replace({
    required AttributedText newText,
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    var updatedText = _text.removeRegion(startOffset: from, endOffset: to);
    var updatedSelection =
        newSelection ?? _moveSelectionForDeletion(selection: selection, deleteFrom: from, deleteTo: to);
    updatedText = updatedText.insert(textToInsert: newText, startOffset: from);
    updatedSelection = newSelection ??
        _moveSelectionForInsertion(selection: updatedSelection, insertIndex: from, newTextLength: newText.text.length);

    text = updatedText;
    selection = updatedSelection;
    _updateComposingAttributions();
    // TODO: do we need to implement composing region update behavior like selections?
    composingRegion = newComposingRegion ?? TextRange.empty;
  }

  /// Deletes the character before the currently collapsed [selection] and
  /// moves [selection] upstream by one character.
  ///
  /// Does nothing if [selection] is not collapsed.
  void deletePreviousCharacter({
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      return;
    }

    if (selection.extentOffset == 0) {
      return;
    }

    final previousCharacterOffset = getCharacterStartBounds(_text.text, selection.extentOffset);

    delete(
      from: previousCharacterOffset,
      to: selection.extentOffset,
      newSelection: TextSelection.collapsed(offset: previousCharacterOffset),
      newComposingRegion: newComposingRegion,
    );
  }

  /// Deletes the character after the currently collapsed [selection].
  ///
  /// Does nothing if [selection] is not collapsed.
  void deleteNextCharacter({
    TextRange? newComposingRegion,
  }) {
    if (!selection.isCollapsed) {
      return;
    }

    if (selection.extentOffset >= text.length) {
      return;
    }

    final nextCharacterOffset = getCharacterEndBounds(_text.text, selection.extentOffset);

    delete(
      from: selection.extentOffset,
      to: nextCharacterOffset,
      newSelection: TextSelection.collapsed(offset: selection.extentOffset),
      newComposingRegion: newComposingRegion,
    );
  }

  /// Deletes the text within the current [selection].
  ///
  /// Does nothing if [selection] is collapsed.
  void deleteSelection({
    TextRange? newComposingRegion,
  }) {
    if (selection.isCollapsed) {
      return;
    }

    delete(
      from: selection.baseOffset,
      to: selection.extentOffset,
      newSelection: TextSelection.collapsed(offset: selection.baseOffset),
      newComposingRegion: newComposingRegion,
    );
  }

  /// Removes the text between [from] (inclusive) and [to] (exclusive).
  ///
  /// The [selection] is updated to [newSelection], if provided, otherwise
  /// a best-guess attempt is made to adjust the selection based on an
  /// insertion action.
  ///
  /// The [composingRegion] is updated to [newComposingRegion], if provided,
  /// otherwise the [composingRegion] is set to `TextRange.empty`.
  void delete({
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    final updatedText = _text.removeRegion(startOffset: from, endOffset: to);
    // We must calculate the updated position before changing the text value
    // to avoid (possibly) automatically altering the current selection.
    final updatedSelection =
        newSelection ?? _moveSelectionForDeletion(selection: _selection, deleteFrom: from, deleteTo: to);

    updateTextAndSelection(
      text: updatedText,
      selection: updatedSelection,
    );

    _updateComposingAttributions();
    // TODO: do we need to implement composing region update behavior like selections?
    composingRegion = newComposingRegion ?? TextRange.empty;
  }

  TextSelection _moveSelectionForDeletion({
    required TextSelection selection,
    required int deleteFrom,
    required int deleteTo,
  }) {
    return TextSelection(
      baseOffset: _moveCaretForDeletion(caretOffset: selection.baseOffset, deleteFrom: deleteFrom, deleteTo: deleteTo),
      extentOffset:
          _moveCaretForDeletion(caretOffset: selection.extentOffset, deleteFrom: deleteFrom, deleteTo: deleteTo),
    );
  }

  int _moveCaretForDeletion({
    required int caretOffset,
    required int deleteFrom,
    required int deleteTo,
  }) {
    if (caretOffset <= deleteFrom) {
      return caretOffset;
    } else if (caretOffset <= deleteTo) {
      // The caret is sitting within the deleted text region.
      // Move the caret to the beginning of the deleted region.
      return deleteFrom;
    } else {
      // The caret is sitting beyond the deleted text region.
      // Move the caret so that its new distance to deleteFrom
      // is equal to its current distance from deleteTo.
      return deleteFrom + (caretOffset - deleteTo);
    }
  }

  void update({
    AttributedText? text,
    TextSelection? selection,
    TextRange? composingRegion,
  }) {
    if ((text == null || text == _text) &&
        (selection == null || selection == _selection) &&
        (composingRegion == null || composingRegion == _composingRegion)) {
      // The updated values are the same as existing values. Do nothing.
      return;
    }

    if (text != null) {
      _switchText(text);
    }
    if (selection != null) {
      _selection = selection;
    }
    if (composingRegion != null) {
      _composingRegion = composingRegion;
    }

    _updateComposingAttributions();

    notifyListeners();
  }

  TextSpan buildTextSpan(AttributionStyleBuilder styleBuilder) {
    return text.computeTextSpan(styleBuilder);
  }

  /// Clears the text, composing attributions, composing region, and moves
  /// the collapsed selection to the start of the now empty text controller.
  void clearText() {
    _text = AttributedText();
    _selection = const TextSelection.collapsed(offset: 0);
    _composingAttributions.clear();
    _composingRegion = TextRange.empty;

    notifyListeners();
  }

  /// Clears the text, selection, composing attributions, and composing region.
  void clearTextAndSelection() {
    _text = AttributedText();
    _selection = const TextSelection.collapsed(offset: -1);
    _composingAttributions.clear();
    _composingRegion = TextRange.empty;

    notifyListeners();
  }

  /// Clears the text, selection, composing attributions, and composing region.
  @Deprecated('This will be removed in a future release. Use clearText or clearTextAndSelection instead')
  void clear() {
    clearTextAndSelection();
  }

  //------ START: Methods moved here from extension methods ---------
  void copySelectedTextToClipboard() {
    if (selection.extentOffset == -1) {
      // Nothing selected to copy.
      return;
    }

    Clipboard.setData(ClipboardData(
      text: selection.textInside(text.text),
    ));
  }

  Future<void> pasteClipboard() async {
    final insertionOffset = selection.extentOffset;
    final clipboardData = await Clipboard.getData('text/plain');

    if (clipboardData != null && clipboardData.text != null) {
      final textToPaste = clipboardData.text!;

      text = text.insertString(
        textToInsert: textToPaste,
        startOffset: insertionOffset,
      );

      selection = TextSelection.collapsed(
        offset: insertionOffset + textToPaste.length,
      );
    }
  }

  void selectAll() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  void moveCaretHorizontally({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveLeft,
    required MovementModifier? movementModifier,
  }) {
    if (moveLeft) {
      _moveCaretUpstream(
        textLayout: textLayout,
        expandSelection: expandSelection,
        movementModifier: movementModifier,
      );
    } else {
      _moveCaretDownstream(
        textLayout: textLayout,
        expandSelection: expandSelection,
        movementModifier: movementModifier,
      );
    }
  }

  void _moveCaretUpstream({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required MovementModifier? movementModifier,
  }) {
    if (!selection.isCollapsed && !expandSelection) {
      // The selection isn't collapsed and the user doesn't
      // want to continue expanding the selection. Move the
      // extent to the left side of the selection.
      selection = TextSelection.collapsed(offset: selection.start);
      return;
    }

    if (selection.extentOffset <= 0) {
      // Can't move further left.
      return;
    }

    if (movementModifier == MovementModifier.line) {
      final newExtent = textLayout.getPositionAtStartOfLine(TextPosition(offset: selection.extentOffset)).offset;
      selection = TextSelection(
        baseOffset: expandSelection ? selection.baseOffset : newExtent,
        extentOffset: newExtent,
      );
      return;
    }

    if (movementModifier == MovementModifier.word) {
      final plainText = text.text;

      int newExtent = selection.extentOffset;
      newExtent -= 1; // we always want to jump at least 1 character.
      while (newExtent > 0 && plainText[newExtent - 1] != ' ' && plainText[newExtent - 1] != '\n') {
        newExtent -= 1;
      }

      selection = TextSelection(
        baseOffset: expandSelection ? selection.baseOffset : newExtent,
        extentOffset: newExtent,
      );
      return;
    }

    final newExtent = text.text.moveOffsetUpstreamByCharacter(selection.extentOffset) ?? 0;
    selection = TextSelection(
      baseOffset: expandSelection ? selection.baseOffset : newExtent,
      extentOffset: newExtent,
    );
  }

  void _moveCaretDownstream({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required MovementModifier? movementModifier,
  }) {
    if (!selection.isCollapsed && !expandSelection) {
      // The selection isn't collapsed and the user doesn't
      // want to continue expanding the selection. Move the
      // extent to the right side of the selection.
      selection = TextSelection.collapsed(offset: selection.end);
      return;
    }

    if (selection.extentOffset >= text.length) {
      // Can't move further right.
      return;
    }

    if (movementModifier == MovementModifier.line) {
      final endOfLine = textLayout.getPositionAtEndOfLine(TextPosition(offset: selection.extentOffset));

      final endPosition = TextPosition(offset: text.length);
      final plainText = text.text;

      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (plainText[endOfLine.offset] != '\n');

      // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
      //       cursor to jump to the next line because the cursor is placed after
      //       the final selected character. We don't want this, so in this case
      //       we `-1`.
      //
      //       However, if the line that is selected ends with an explicit `\n`,
      //       or if the line is the terminal line for the paragraph then we don't
      //       want to `-1` because that would leave a dangling character after the
      //       selection.
      // TODO: this is the concept of text affinity. Implement support for affinity.
      // TODO: with affinity, ensure it works as expected for right-aligned text
      // TODO: this logic fails for justified text - find a solution for that (#55)
      final newExtent = isAutoWrapLine ? endOfLine.offset - 1 : endOfLine.offset;

      selection = TextSelection(
        baseOffset: expandSelection ? selection.baseOffset : newExtent,
        extentOffset: newExtent,
      );
      return;
    }

    if (movementModifier == MovementModifier.word) {
      final extentPosition = selection.extent;
      final plainText = text.text;

      int newExtent = extentPosition.offset;
      newExtent += 1; // we always want to jump at least 1 character.
      while (newExtent < plainText.length && plainText[newExtent] != ' ' && plainText[newExtent] != '\n') {
        newExtent += 1;
      }

      selection = TextSelection(
        baseOffset: expandSelection ? selection.baseOffset : newExtent,
        extentOffset: newExtent,
      );
      return;
    }

    final newExtent = text.text.moveOffsetDownstreamByCharacter(selection.extentOffset) ?? text.length;
    selection = TextSelection(
      baseOffset: expandSelection ? selection.baseOffset : newExtent,
      extentOffset: newExtent,
    );
  }

  void moveCaretVertically({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveUp,
  }) {
    int? newExtent;

    if (moveUp) {
      newExtent = textLayout.getPositionOneLineUp(selection.extent)?.offset;

      // If there is no line above the current selection, move selection
      // to the beginning of the available text.
      newExtent ??= 0;
    } else {
      newExtent = textLayout.getPositionOneLineDown(selection.extent)?.offset;

      // If there is no line below the current selection, move selection
      // to the end of the available text.
      newExtent ??= text.length;
    }

    selection = TextSelection(
      baseOffset: expandSelection ? selection.baseOffset : newExtent,
      extentOffset: newExtent,
    );
  }

  void insertCharacter(String character) {
    final initialTextOffset = selection.start;

    final existingAttributions = text.getAllAttributionsAt(initialTextOffset);

    if (!selection.isCollapsed) {
      text = text.removeRegion(startOffset: selection.start, endOffset: selection.end);
      selection = TextSelection.collapsed(offset: selection.start);
    }

    text = text.insertString(
      textToInsert: character,
      startOffset: initialTextOffset,
      applyAttributions: existingAttributions,
    );

    selection = TextSelection.collapsed(offset: initialTextOffset + 1);
  }

  void deleteCharacter(TextAffinity direction) {
    assert(selection.isCollapsed);

    int deleteStartIndex;
    int deleteEndIndex;

    if (direction == TextAffinity.upstream) {
      // Delete the character before the caret
      deleteEndIndex = selection.extentOffset;
      deleteStartIndex = getCharacterStartBounds(text.text, deleteEndIndex);
    } else {
      // Delete the character after the caret
      deleteStartIndex = selection.extentOffset;
      deleteEndIndex = getCharacterEndBounds(text.text, deleteStartIndex);
    }

    delete(
      from: deleteStartIndex,
      to: deleteEndIndex,
      newSelection: TextSelection.collapsed(offset: deleteStartIndex),
    );
  }

  void deleteTextOnLineBeforeCaret({
    required ProseTextLayout textLayout,
  }) {
    assert(selection.isCollapsed);

    final startOfLinePosition = textLayout.getPositionAtStartOfLine(selection.extent);
    selection = TextSelection(
      baseOffset: selection.extentOffset,
      extentOffset: startOfLinePosition.offset,
    );

    if (!selection.isCollapsed) {
      deleteSelectedText();
    }
  }

  void deleteTextOnLineAfterCaret({
    required ProseTextLayout textLayout,
  }) {
    assert(selection.isCollapsed);

    final endOfLinePosition = textLayout.getPositionAtEndOfLine(selection.extent);
    selection = TextSelection(
      baseOffset: selection.extentOffset,
      extentOffset: endOfLinePosition.offset,
    );

    if (!selection.isCollapsed) {
      deleteSelectedText();
    }
  }

  void deleteSelectedText() {
    assert(!selection.isCollapsed);

    final deleteStartIndex = selection.start;
    final deleteEndIndex = selection.end;

    delete(
      from: deleteStartIndex,
      to: deleteEndIndex,
      newSelection: TextSelection.collapsed(offset: deleteStartIndex),
    );
  }

  void insertNewline() {
    final currentSelectionExtent = selection.extent;

    text = text.insertString(
      textToInsert: '\n',
      startOffset: currentSelectionExtent.offset,
    );
    selection = TextSelection.collapsed(offset: currentSelectionExtent.offset + 1);
  }
  //------ END: Methods moved here from extension methods -------
}
