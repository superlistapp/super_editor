import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_value.dart';

import 'event_source_value.dart';

/// Changes the text selection from its current value to the given selection.
class ChangeSelectionCommand extends AttributedTextEditingValueCommand {
  ChangeSelectionCommand({
    required this.newSelection,
    this.newComposingRange,
  });

  final TextSelection newSelection;
  final TextRange? newComposingRange;

  TextSelection? _previousSelection;
  TextRange? _previousComposingRange;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _previousSelection = previousValue.selection;
    _previousComposingRange = previousValue.composingRegion;

    return AttributedTextEditingValue(
      text: previousValue.text.copy(),
      selection: newSelection,
      composingRegion: newComposingRange ?? TextRange.empty,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: currentValue.text.copy(),
      selection: _previousSelection!,
      composingRegion: _previousComposingRange!,
    );
  }
}

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

/// Removes all attributions within the current selection.
class RemoveSelectedAttributionsCommand extends AttributedTextEditingValueCommand {
  RemoveSelectedAttributionsCommand();

  Set<AttributionSpan>? _previousAttributionSpans;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    final selectionRange = previousValue.selection.toSpanRange();
    _previousAttributionSpans =
        previousValue.text.getAttributionSpansInRange(attributionFilter: (_) => true, range: selectionRange).toSet();
    final newText = previousValue.text.copy()..clearAttributions(selectionRange);

    return AttributedTextEditingValue(
      text: newText,
      selection: previousValue.selection,
      composingRegion: previousValue.composingRegion,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    final revertedText = currentValue.text.copy();
    for (final attributionSpan in _previousAttributionSpans!) {
      revertedText.addAttribution(
        attributionSpan.attribution,
        SpanRange(
          start: attributionSpan.start,
          end: attributionSpan.end,
        ),
      );
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
      composingRegion: composingRegion ?? _previousComposingRegion!,
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
      composingRegion: composingRegion ?? _previousComposingRegion!,
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

/// Deletes the currently selected text, collapsing the selection to a caret
/// at the selection base.
class DeleteSelectedTextCommand extends AttributedTextEditingValueCommand {
  DeleteSelectedTextCommand({
    this.newComposingRegion,
  });

  final TextRange? newComposingRegion;

  AttributedText? _deletedText;
  TextSelection? _previousSelection;
  TextRange? _previousComposingRegion;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _deletedText = previousValue.text.copyText(
      previousValue.selection.start,
      previousValue.selection.end,
    );

    _previousSelection = previousValue.selection;
    _previousComposingRegion = previousValue.composingRegion;

    return AttributedTextEditingValue(
      text: previousValue.text.removeRegion(
        startOffset: previousValue.selection.start,
        endOffset: previousValue.selection.end,
      ),
      selection: TextSelection.collapsed(offset: previousValue.selection.baseOffset),
      composingRegion: newComposingRegion ?? _previousComposingRegion!,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: currentValue.text.insert(
        textToInsert: _deletedText!,
        startOffset: _previousSelection!.baseOffset,
      ),
      selection: _previousSelection!,
      composingRegion: _previousComposingRegion!,
    );
  }
}

/// Deletes text within a given range, and updates the selection and composing
/// region to the given values.
class DeleteCommand extends AttributedTextEditingValueCommand {
  DeleteCommand({
    required this.deletionRange,
    required this.newSelection,
    this.newComposingRegion,
  });

  final TextRange deletionRange;
  final TextSelection newSelection;
  final TextRange? newComposingRegion;

  AttributedText? _deletedText;
  TextSelection? _previousSelection;
  TextRange? _previousComposingRegion;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _deletedText = previousValue.text.copyText(deletionRange.start, deletionRange.end);
    _previousSelection = previousValue.selection;
    _previousComposingRegion = previousValue.composingRegion;

    final updatedText = previousValue.text.removeRegion(startOffset: deletionRange.start, endOffset: deletionRange.end);
    final updatedSelection = newSelection.isValid
        ? newSelection
        : _moveSelectionForDeletion(
            selection: previousValue.selection, deleteFrom: deletionRange.start, deleteTo: deletionRange.end);

    return AttributedTextEditingValue(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion ?? TextRange.empty,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: currentValue.text.insert(textToInsert: _deletedText!, startOffset: deletionRange.start),
      selection: _previousSelection!,
      composingRegion: _previousComposingRegion!,
    );
  }
}

class ReplaceCommand extends AttributedTextEditingValueCommand {
  ReplaceCommand({
    required this.newText,
    required this.replacementRange,
    this.newSelection,
    this.newComposingRegion,
  });

  final AttributedText newText;
  final TextRange replacementRange;
  final TextSelection? newSelection;
  final TextRange? newComposingRegion;

  AttributedText? _replacedText;
  TextSelection? _previousSelection;
  TextRange? _previousComposingRegion;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue) {
    _replacedText = previousValue.text.copyText(replacementRange.start, replacementRange.end);
    _previousSelection = previousValue.selection;
    _previousComposingRegion = previousValue.composingRegion;

    AttributedText updatedText =
        previousValue.text.removeRegion(startOffset: replacementRange.start, endOffset: replacementRange.end);
    TextSelection updatedSelection = newSelection ??
        _moveSelectionForDeletion(
          selection: previousValue.selection,
          deleteFrom: replacementRange.start,
          deleteTo: replacementRange.end,
        );
    updatedText = updatedText.insert(textToInsert: newText, startOffset: replacementRange.start);
    updatedSelection = newSelection ??
        _moveSelectionForInsertion(
          selection: updatedSelection,
          insertIndex: replacementRange.start,
          newTextLength: newText.text.length,
        );

    return AttributedTextEditingValue(
      text: updatedText,
      selection: updatedSelection,
      composingRegion: newComposingRegion ?? TextRange.empty,
    );
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    return AttributedTextEditingValue(
      text: currentValue.text
          .removeRegion(startOffset: replacementRange.start, endOffset: replacementRange.start + newText.text.length)
          .insert(textToInsert: _replacedText!, startOffset: replacementRange.start),
      selection: _previousSelection!,
      composingRegion: _previousComposingRegion!,
    );
  }
}

/// Replaces the text, selection, and composing region in the editable.
class ReplaceEverythingCommand extends AttributedTextEditingValueCommand {
  ReplaceEverythingCommand({
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

TextSelection _moveSelectionForDeletion({
  required TextSelection selection,
  required int deleteFrom,
  required int deleteTo,
}) {
  return TextSelection(
    baseOffset: _moveCaretForDeletion(
      caretOffset: selection.baseOffset,
      deleteFrom: deleteFrom,
      deleteTo: deleteTo,
    ),
    extentOffset: _moveCaretForDeletion(
      caretOffset: selection.extentOffset,
      deleteFrom: deleteFrom,
      deleteTo: deleteTo,
    ),
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

extension on AttributedText {
  AttributedText copy() {
    return AttributedText(
      text: text,
      spans: spans.copy(),
    );
  }
}
