import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_value.dart';

import 'event_source_value.dart';

/// Inserts the given text at the current caret location.
///
/// The [AttributedTextEditingValue] must have a collapsed selection.
class TextFieldInsertTextCommand extends AttributedTextEditingValueCommand {
  TextFieldInsertTextCommand(this.textToInsert);

  final AttributedText textToInsert;

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
