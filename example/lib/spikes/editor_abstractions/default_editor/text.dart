import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/document/rich_text_document.dart';
import '../core/document/document_editor.dart';
import '../core/layout/document_layout.dart';
import '../core/selection/editor_selection.dart';
import '../core/composition/document_composer.dart';
import '_text_tools.dart';
import '../selectable_text/attributed_text.dart';
import '../selectable_text/selectable_text.dart';

class TextNode with ChangeNotifier implements DocumentNode {
  TextNode({
    @required this.id,
    AttributedText text,
    TextAlign textAlign = TextAlign.left,
    String textType = 'paragraph',
  })  : _text = text,
        _textAlign = textAlign,
        _textType = textType;

  final String id;

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newText) {
    if (newText != _text) {
      print('Text changed. Notifying listeners.');
      _text = newText;
      notifyListeners();
    }
  }

  TextAlign _textAlign;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign newAlign) {
    if (newAlign != _textAlign) {
      _textAlign = newAlign;
      notifyListeners();
    }
  }

  String _textType;
  String get textType => _textType;
  set textType(String newTextType) {
    if (newTextType != _textType) {
      _textType = newTextType;
      notifyListeners();
    }
  }
}

/// Displays text in a document.
///
/// This is the standard component for text display.
class TextComponent extends StatefulWidget {
  const TextComponent({
    Key key,
    this.textKey,
    this.text,
    this.textType,
    this.textAlign,
    this.textStyle,
    this.textSelection,
    this.hasCursor = false,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: textKey);

  // TODO: go back to just taking a single key
  final GlobalKey textKey;
  final AttributedText text;
  final String textType;
  final TextAlign textAlign;
  final TextStyle textStyle;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  _TextComponentState createState() => _TextComponentState();
}

class _TextComponentState extends State<TextComponent> with DocumentComponent implements TextComposable {
  final _selectableTextKey = GlobalKey<SelectableTextState>();

  @override
  TextPosition getPositionAtOffset(Offset localOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.getPositionAtOffset(localOffset);
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getOffsetForPosition(nodePosition);
  }

  @override
  TextPosition getBeginningPosition() {
    return TextPosition(offset: 0);
  }

  @override
  TextPosition getBeginningPositionNearX(double x) {
    return _selectableTextKey.currentState.getPositionInFirstLineAtX(x);
  }

  @override
  TextPosition getEndPosition() {
    return TextPosition(offset: widget.text.text.length);
  }

  @override
  TextPosition getEndPositionNearX(double x) {
    return _selectableTextKey.currentState.getPositionInLastLineAtX(x);
  }

  @override
  TextSelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.getSelectionInRect(localBaseOffset, localExtentOffset);
  }

  @override
  TextSelection getCollapsedSelectionAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return TextSelection.fromPosition(nodePosition);
  }

  @override
  TextSelection getSelectionBetween({
    @required dynamic basePosition,
    @required dynamic extentPosition,
  }) {
    if (basePosition is! TextPosition || extentPosition is! TextPosition) {
      return null;
    }

    return TextSelection(
      baseOffset: (basePosition as TextPosition).offset,
      extentOffset: (extentPosition as TextPosition).offset,
    );
  }

  @override
  TextSelection getSelectionOfEverything() {
    return TextSelection(
      baseOffset: 0,
      extentOffset: widget.text.text.length,
    );
  }

  @override
  MouseCursor getDesiredCursorAtOffset(Offset localOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.isTextAtOffset(localOffset) ? SystemMouseCursors.text : null;
  }

  @override
  TextSelection getWordSelectionAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getWordSelectionAt(nodePosition as TextPosition);
  }

  @override
  String getContiguousTextAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    // This component only displays a single contiguous span of text.
    // Therefore, all of our text is contiguous regardless of position.
    return widget.text.text;
  }

  TextPosition getPositionOneLineUp(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getPositionOneLineUp(
      currentPosition: nodePosition,
    );
  }

  TextPosition getPositionOneLineDown(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getPositionOneLineDown(
      currentPosition: nodePosition,
    );
  }

  @override
  TextPosition getPositionAtEndOfLine(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getPositionAtEndOfLine(currentPosition: nodePosition);
  }

  @override
  TextPosition getPositionAtStartOfLine(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getPositionAtStartOfLine(currentPosition: nodePosition);
  }

  @override
  Widget build(BuildContext context) {
    TextStyle baseStyle = (widget.textStyle ?? Theme.of(context).textTheme.bodyText1).copyWith(
      height: 1.4,
    );
    switch (widget.textType) {
      case 'header1':
        baseStyle = baseStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.0,
        );
        break;
      default:
        break;
    }

    final richText = widget.text.computeTextSpan(baseStyle);

    return SelectableText(
      key: _selectableTextKey,
      richText: richText,
      textAlign: widget.textAlign,
      textSelection: widget.textSelection,
      hasCursor: widget.hasCursor,
      highlightWhenEmpty: widget.highlightWhenEmpty,
      showDebugPaint: widget.showDebugPaint,
    );
  }
}

ExecutionInstruction insertCharacterInTextComposable({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required ComposerPreferences composerPreferences,
  @required RawKeyEvent keyEvent,
}) {
  if (isTextEntryNode(document: document, selection: currentSelection) &&
      isCharacterKey(keyEvent.logicalKey) &&
      currentSelection.value.isCollapsed) {
    currentSelection.value = editor.addCharacter(
      document: document,
      position: currentSelection.value.extent,
      character: keyEvent.character,
      styles: composerPreferences.currentStyles.toList(),
    );

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction deleteCharacterWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required ComposerPreferences composerPreferences,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!isTextEntryNode(document: document, selection: currentSelection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if ((currentSelection.value.extent.nodePosition as TextPosition).offset <= 0) {
    return ExecutionInstruction.continueExecution;
  }

  currentSelection.value = editor.deleteSelection(
    document: document,
    documentLayout: documentLayout,
    selection: DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: currentSelection.value.base.nodeId,
        nodePosition: TextPosition(
          offset: (currentSelection.value.base.nodePosition as TextPosition).offset - 1,
        ),
      ),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction deleteCharacterWhenDeleteIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required ComposerPreferences composerPreferences,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!isTextEntryNode(document: document, selection: currentSelection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  final text = (document.getNodeById(currentSelection.value.extent.nodeId) as TextNode).text;
  final textPosition = (currentSelection.value.extent.nodePosition as TextPosition);
  if (textPosition.offset >= text.text.length) {
    return ExecutionInstruction.continueExecution;
  }

  currentSelection.value = editor.deleteSelection(
    document: document,
    documentLayout: documentLayout,
    selection: DocumentSelection(
      base: currentSelection.value.base,
      extent: DocumentPosition(
        nodeId: currentSelection.value.base.nodeId,
        nodePosition: TextPosition(
          offset: (currentSelection.value.base.nodePosition as TextPosition).offset + 1,
        ),
      ),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction insertNewlineInParagraph({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required ComposerPreferences composerPreferences,
  @required RawKeyEvent keyEvent,
}) {
  if (isTextEntryNode(document: document, selection: currentSelection) &&
      keyEvent.logicalKey == LogicalKeyboardKey.enter &&
      keyEvent.isShiftPressed &&
      currentSelection.value.isCollapsed) {
    currentSelection.value = editor.addCharacter(
      document: document,
      position: currentSelection.value.extent,
      character: '\n',
    );
    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}
