import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/strings.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../attributed_text_editing_value.dart';
import 'commands.dart';
import 'event_source_value.dart';

/// An [AttributedTextEditingController] that supports undo/redo.
class EventSourcedAttributedTextEditingController with ChangeNotifier implements AttributedTextEditingController {
  EventSourcedAttributedTextEditingController(
    AttributedTextEditingValue initialValue,
  ) : _value = EventSourcedAttributedTextEditingValue(initialValue);

  final EventSourcedAttributedTextEditingValue _value;

  /// Whether there are any commands in the history stack.
  bool get isUndoable => _value.isUndoable;

  /// Pops the top command off the history stack and reverses its
  /// effect on the current attributed text editing value.
  bool undo() => _value.undo();

  /// Whether there are any commands in the future stack.
  bool get isRedoable => _value.isRedoable;

  /// Pops the top command off the future stack and re-applies its
  /// effect on the current attributed text editing value.
  bool redo() => _value.redo();

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

  // TODO: this should probably be an extension method on AttributedText or something
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
    int newExtent;

    if (moveLeft) {
      if (selection.extentOffset <= 0 && selection.isCollapsed) {
        // Can't move further left.
        return;
      }

      if (!selection.isCollapsed && !expandSelection) {
        // The selection isn't collapsed and the user doesn't
        // want to continue expanding the selection. Move the
        // extent to the left side of the selection.
        newExtent = selection.start;
      } else if (movementModifier != null && movementModifier == MovementModifier.line) {
        newExtent = textLayout.getPositionAtStartOfLine(TextPosition(offset: selection.extentOffset)).offset;
      } else if (movementModifier != null && movementModifier == MovementModifier.word) {
        final plainText = text.text;

        newExtent = selection.extentOffset;
        newExtent -= 1; // we always want to jump at least 1 character.
        while (newExtent > 0 && plainText[newExtent - 1] != ' ' && plainText[newExtent - 1] != '\n') {
          newExtent -= 1;
        }
      } else {
        newExtent = text.text.moveOffsetUpstreamByCharacter(selection.extentOffset) ?? 0;
      }
    } else {
      if (selection.extentOffset >= text.text.length && selection.isCollapsed) {
        // Can't move further right.
        return;
      }

      if (!selection.isCollapsed && !expandSelection) {
        // The selection isn't collapsed and the user doesn't
        // want to continue expanding the selection. Move the
        // extent to the left side of the selection.
        newExtent = selection.end;
      } else if (movementModifier != null && movementModifier == MovementModifier.line) {
        final endOfLine = textLayout.getPositionAtEndOfLine(TextPosition(offset: selection.extentOffset));

        final endPosition = TextPosition(offset: text.text.length);
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
        newExtent = isAutoWrapLine ? endOfLine.offset - 1 : endOfLine.offset;
      } else if (movementModifier != null && movementModifier == MovementModifier.word) {
        final extentPosition = selection.extent;
        final plainText = text.text;

        newExtent = extentPosition.offset;
        newExtent += 1; // we always want to jump at least 1 character.
        while (newExtent < plainText.length && plainText[newExtent] != ' ' && plainText[newExtent] != '\n') {
          newExtent += 1;
        }
      } else {
        newExtent = text.text.moveOffsetDownstreamByCharacter(selection.extentOffset) ?? text.text.length;
      }
    }

    _value.execute(
      ChangeSelectionCommand(
        newSelection: TextSelection(
          baseOffset: expandSelection ? selection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      ),
    );
  }

  @override
  void moveCaretVertically({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveUp,
  }) {
    int? newExtent;

    if (moveUp) {
      newExtent = textLayout.getPositionOneLineUp(TextPosition(offset: selection.start))?.offset;

      // If there is no line above the current selection, move selection
      // to the beginning of the available text.
      newExtent ??= 0;
    } else {
      newExtent = textLayout.getPositionOneLineDown(TextPosition(offset: selection.end))?.offset;

      // If there is no line below the current selection, move selection
      // to the end of the available text.
      newExtent ??= text.text.length;
    }

    _value.execute(
      ChangeSelectionCommand(
        newSelection: TextSelection(
          baseOffset: expandSelection ? selection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      ),
    );
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

    _value.execute(
      ToggleSelectionAttributionsCommand(attributions.toSet()),
    );
  }

  /// Removes all attributions from the text that is currently selected.
  @override
  void clearSelectionAttributions() {
    if (selection.isCollapsed) {
      return;
    }

    _value.execute(RemoveSelectedAttributionsCommand());
  }

  @override
  void selectAll() {
    _value.execute(SelectAllCommand());
  }

  @override
  void updateTextAndSelection({
    required AttributedText text,
    required TextSelection selection,
    TextRange composingRegion = TextRange.empty,
  }) {
    _value.execute(
      ReplaceEverythingCommand(
        newText: text,
        newSelection: selection,
        newComposingRegion: composingRegion,
      ),
    );
  }

  @override
  void insertCharacter(String character) {
    insertAtCaretWithUpstreamAttributions(text: character);
  }

  @override
  void insertNewline() {
    insertAtCaretWithUpstreamAttributions(text: "\n");
  }

  /// Inserts the given [text] at the current caret position.
  ///
  /// The current [composingAttributions] are applied to the given
  /// [text] and the caret is moved to the end of the given [text].
  @override
  void insertAtCaret({
    required String text,
    TextRange? newComposingRegion,
  }) {
    _ensureCaretReadyForInsertion();

    final attributedText = AttributedText(text: text);
    final attributions = Set.from(composingAttributions);
    for (final attribution in attributions) {
      attributedText.addAttribution(
        attribution,
        SpanRange(start: 0, end: attributedText.text.length - 1),
      );
    }

    _value.execute(InsertTextAtCaretCommand(
      attributedText,
      composingRegion: newComposingRegion ?? TextRange.empty,
    ));
  }

  /// Inserts the given [text] at the current caret position, extending whatever
  /// attributions exist at the offset before the insertion.
  ///
  /// The caret is moved to the end of the inserted [text].
  @override
  void insertAtCaretWithUpstreamAttributions({
    required String text,
    TextRange? newComposingRegion,
  }) {
    _ensureCaretReadyForInsertion();

    final attributedText = AttributedText(text: text);
    final attributions = _value.text.getAllAttributionsAt(max(selection.extentOffset - 1, 0));
    for (final attribution in attributions) {
      attributedText.addAttribution(
        attribution,
        SpanRange(start: 0, end: attributedText.text.length - 1),
      );
    }

    _value.execute(InsertTextAtCaretCommand(
      attributedText,
      composingRegion: newComposingRegion ?? TextRange.empty,
    ));
  }

  /// Inserts the given [text] at the current caret position without any
  /// attributions applied to the [text].
  @override
  void insertAtCaretUnstyled({
    required String text,
    TextRange? newComposingRegion,
  }) {
    insertAttributedTextAtCaret(
      attributedText: AttributedText(text: text),
      newComposingRegion: newComposingRegion,
    );
  }

  /// Inserts the given [attributedText] at the current caret position.
  ///
  /// The caret is moved to the end of the inserted [text].
  @override
  void insertAttributedTextAtCaret({
    required AttributedText attributedText,
    TextRange? newComposingRegion,
  }) {
    _ensureCaretReadyForInsertion();

    _value.execute(InsertTextAtCaretCommand(
      attributedText,
      composingRegion: newComposingRegion ?? TextRange.empty,
    ));
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
    late final TextSelection updatedSelection;
    if (newSelection != null) {
      updatedSelection = newSelection;
    } else {
      int newBaseOffset = selection.baseOffset;
      if ((selection.baseOffset == insertIndex && selection.isCollapsed) || (selection.baseOffset > insertIndex)) {
        newBaseOffset = selection.baseOffset + newText.text.length;
      }

      final newExtentOffset =
          selection.extentOffset >= insertIndex ? selection.extentOffset + newText.text.length : selection.extentOffset;

      updatedSelection = TextSelection(
        baseOffset: newBaseOffset,
        extentOffset: newExtentOffset,
      );
    }

    _value.execute(InsertTextAtOffsetCommand(
      textToInsert: newText,
      insertionOffset: insertIndex,
      selectionAfter: updatedSelection,
      composingRegion: newComposingRegion ?? TextRange.empty,
    ));
  }

  void _ensureCaretReadyForInsertion() {
    if (!selection.isValid) {
      throw Exception("Attempted to insert text at the caret but there is no selection");
    }
    if (!selection.isCollapsed) {
      throw Exception('Attempted to insert text at the caret with an expanded selection. Selection: $selection');
    }
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

    final upstreamAttributions = _value.text.getAllAttributionsAt(
      max(selection.start - 1, 0),
    );
    final newStyledText = AttributedText(text: replacementText);
    final newTextRange = SpanRange(start: 0, end: newStyledText.text.length - 1);
    for (final attribution in upstreamAttributions) {
      newStyledText.addAttribution(attribution, newTextRange);
    }

    replaceSelectionWithAttributedText(
      attributedReplacementText: newStyledText,
      newComposingRegion: newComposingRegion,
    );
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

    _value.execute(BatchCommand([
      DeleteSelectedTextCommand(),
      InsertTextAtCaretCommand(attributedReplacementText, composingRegion: newComposingRegion),
    ]));
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

    _value.execute(BatchCommand([
      DeleteSelectedTextCommand(),
      InsertTextAtCaretCommand(AttributedText(text: replacementText), composingRegion: newComposingRegion),
    ]));
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
    _value.execute(
      ReplaceCommand(
        newText: newText,
        replacementRange: TextRange(start: from, end: to),
        newSelection: newSelection,
        newComposingRegion: newComposingRegion,
      ),
    );

    _updateComposingAttributions();
  }

  /// Deletes all the text on the current line that appears upstream from the
  /// caret.
  @override
  void deleteTextOnLineBeforeCaret({
    required ProseTextLayout textLayout,
  }) {
    assert(selection.isCollapsed);

    final startOfLinePosition = textLayout.getPositionAtStartOfLine(selection.extent);
    _value.execute(
      DeleteCommand(
        deletionRange: TextSelection(
          baseOffset: selection.extentOffset,
          extentOffset: startOfLinePosition.offset,
        ),
        newSelection: TextSelection.collapsed(offset: startOfLinePosition.offset),
      ),
    );
  }

  // TODO: either this method or the next one should be deleted
  @override
  void deleteSelectedText() {
    assert(!selection.isCollapsed);
    deleteSelection();
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

    _value.execute(
      DeleteCommand(
        deletionRange: TextRange(start: selection.start, end: selection.end + 1),
        newSelection: TextSelection.collapsed(offset: selection.start),
        newComposingRegion: newComposingRegion,
      ),
    );
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

    delete(
      from: selection.extentOffset - 1,
      to: selection.extentOffset,
      newSelection: TextSelection.collapsed(offset: selection.extentOffset - 1),
      newComposingRegion: newComposingRegion,
    );
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

    delete(
      from: selection.extentOffset,
      to: selection.extentOffset + 1,
      newSelection: TextSelection.collapsed(offset: selection.extentOffset),
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
  @override
  void delete({
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    _value.execute(DeleteCommand(
      deletionRange: TextRange(start: from, end: to),
      newSelection: newSelection ?? const TextSelection.collapsed(offset: -1),
      newComposingRegion: newComposingRegion,
    ));

    _updateComposingAttributions();
  }

  /// Sets the text to empty and removes the selection and composing region.
  @override
  void clear() {
    update(
      text: AttributedText(text: ""),
      selection: const TextSelection.collapsed(offset: -1),
      composingRegion: TextRange.empty,
    );
  }

  @override
  void update({
    AttributedText? text,
    TextSelection? selection,
    TextRange? composingRegion,
  }) {
    _value.execute(
      ReplaceEverythingCommand(
        newText: text ?? this.text,
        newSelection: selection ?? this.selection,
        newComposingRegion: composingRegion ?? this.composingRegion,
      ),
    );
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

      _value.execute(InsertTextAtOffsetCommand(
        textToInsert: text.insertString(
          textToInsert: textToPaste,
          startOffset: insertionOffset,
        ),
        insertionOffset: insertionOffset,
        selectionAfter: TextSelection.collapsed(
          offset: insertionOffset + textToPaste.length,
        ),
      ));
    }
  }

  @override
  TextSpan buildTextSpan(AttributionStyleBuilder styleBuilder) {
    return text.computeTextSpan(styleBuilder);
  }
}
