import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_value.dart';

import 'event_source_value.dart';

/// Selects all text in the editable.
class SelectAllCommand extends AttributedTextEditingValueCommand {
  TextSelection? _previousSelection;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _previousSelection = previousValue.selection;

    return AttributedTextEditingValue(
      text: previousValue.text.copy(),
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: previousValue.text.text.length,
      ),
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: currentValue.text,
      selection: _previousSelection!,
    );
  }
}

/// Toggles the given attributions on/off within the selected text region.
class ToggleSelectionAttributionsCommand extends AttributedTextEditingValueCommand {
  ToggleSelectionAttributionsCommand(this.toggleAttributions);

  /// The attributions that will be turned on/off within the current
  /// text selection.
  final Set<Attribution> toggleAttributions;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    final newText = previousValue.text.copy();
    final selectionRange = previousValue.selection.toSpanRange();
    for (final attribution in toggleAttributions) {
      newText.toggleAttribution(attribution, selectionRange);
    }

    return AttributedTextEditingValue(
      text: newText,
      selection: previousValue.selection,
      composingRegion: previousValue.composingRegion,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    final revertedText = currentValue.text.copy();
    final selectionRange = currentValue.selection.toSpanRange();
    for (final attribution in toggleAttributions) {
      revertedText.toggleAttribution(attribution, selectionRange);
    }

    return AttributedTextEditingValue(
      text: revertedText,
      selection: currentValue.selection,
      composingRegion: currentValue.composingRegion,
    );
  }
}

/// Inserts the given text at the current caret location.
///
/// The [AttributedTextEditingValue] must have a collapsed selection.
class InsertTextAtCaretCommand extends AttributedTextEditingValueCommand {
  InsertTextAtCaretCommand(
    this.textToInsert, {
    this.composingRegion,
  });

  /// The text to insert into the [AttributedTextEditingValue].
  final AttributedText textToInsert;

  /// The new composing region after the text is inserted.
  final TextRange? composingRegion;

  TextRange? _previousComposingRegion;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    assert(previousValue.selection.isValid);
    assert(previousValue.selection.isCollapsed);

    _previousComposingRegion = previousValue.composingRegion;

    final newValue = AttributedTextEditingValue(
      text: previousValue.text.insert(
        textToInsert: textToInsert,
        startOffset: previousValue.selection.extentOffset,
      ),
      selection: TextSelection.collapsed(
        offset: previousValue.selection.extentOffset + textToInsert.text.length,
      ),
      composingRegion: composingRegion ?? TextRange.empty,
    );

    return newValue;
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    final caretOffset = currentValue.selection.extentOffset;
    final removalLength = textToInsert.text.length;

    final newValue = AttributedTextEditingValue(
      text: currentValue.text.removeRegion(
        startOffset: caretOffset - removalLength,
        endOffset: caretOffset,
      ),
      selection: TextSelection.collapsed(offset: caretOffset - removalLength),
      composingRegion: _previousComposingRegion!,
    );

    _previousComposingRegion = null;

    return newValue;
  }
}

/// Inserts the given text at a desired text offset.
class InsertTextAtOffsetCommand extends AttributedTextEditingValueCommand {
  InsertTextAtOffsetCommand({
    required this.textToInsert,
    required this.insertionOffset,
    required this.selectionAfter,
    this.composingRegion,
  });

  /// The text to insert into the [AttributedTextEditingValue].
  final AttributedText textToInsert;

  /// The text offset where the new text should be inserted.
  final int insertionOffset;

  /// The selection that should be present after inserting the new text.
  final TextSelection selectionAfter;

  /// The new composing region after the text is inserted.
  final TextRange? composingRegion;

  TextSelection? _previousSelection;
  TextRange? _previousComposingRegion;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _previousSelection = previousValue.selection;
    _previousComposingRegion = previousValue.composingRegion;

    final newValue = AttributedTextEditingValue(
      text: previousValue.text.insert(
        textToInsert: textToInsert,
        startOffset: insertionOffset,
      ),
      selection: selectionAfter,
      composingRegion: composingRegion ?? TextRange.empty,
    );

    return newValue;
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    final newValue = AttributedTextEditingValue(
      text: currentValue.text.removeRegion(
        startOffset: insertionOffset - textToInsert.text.length,
        endOffset: insertionOffset,
      ),
      selection: _previousSelection!,
      composingRegion: _previousComposingRegion!,
    );

    _previousSelection = null;
    _previousComposingRegion = null;

    return newValue;
  }
}

extension on AttributedText {
  AttributedText copy() {
    return AttributedText(
      text: text,
      spans: spans.copy(),
    );
  }
}

/// Replaces the text, selection, and composing region in the editable.
class ReplaceContentCommands extends AttributedTextEditingValueCommand {
  ReplaceContentCommands({
    required this.newText,
    required this.newSelection,
    this.newComposingRegion = TextRange.empty,
  });

  final AttributedText newText;
  final TextSelection newSelection;
  final TextRange newComposingRegion;

  AttributedTextEditingValue? _previousValue;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _previousValue = AttributedTextEditingValue(
      text: previousValue.text.copy(),
      selection: previousValue.selection,
      composingRegion: previousValue.composingRegion,
    );

    return AttributedTextEditingValue(
      text: newText,
      selection: newSelection,
      composingRegion: newComposingRegion,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: _previousValue!.text.copy(),
      selection: _previousValue!.selection,
      composingRegion: _previousValue!.composingRegion,
    );
  }
}
