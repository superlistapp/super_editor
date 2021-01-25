import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../editor_selection.dart';
import 'editor_paragraph_component.dart';
import 'selectable_text.dart';

/// Wraps a `SelectableText` widget with editor APIs to behave
/// as an `EditorComponent`.
///
/// Examples of editor behaviors:
///  -
class EditorParagraph extends StatefulWidget {
  const EditorParagraph({
    @required Key key,
    this.text = '',
    this.textSelection = const TextSelection.collapsed(offset: -1),
    this.hasCursor = false,
    this.style,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final String text;
  final TextSelection textSelection;
  final bool hasCursor;
  final TextStyle style;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  EditorParagraphState createState() => EditorParagraphState();
}

class EditorParagraphState extends State<EditorParagraph> implements EditorComponent {
  final GlobalKey<SelectableTextState> _textKey = GlobalKey();
  TextEditingController _editingController;
  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController(text: widget.text)
      ..selection = widget.textSelection ?? TextSelection.collapsed(offset: -1);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(EditorParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text) {
      _editingController
        ..text = widget.text
        ..selection = widget.textSelection ?? TextSelection.collapsed(offset: -1);
    } else if (widget.textSelection != oldWidget.textSelection) {
      _editingController.selection = widget.textSelection ?? TextSelection.collapsed(offset: -1);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  SelectableTextState get _selectableText => _textKey.currentState;

  @override
  ParagraphEditorComponentSelection getSelectionAtOffset(Offset localOffset) {
    return ParagraphEditorComponentSelection(
      selection: TextSelection.collapsed(
        offset: _selectableText.getPositionAtOffset(localOffset).offset,
      ),
    );
  }

  @override
  ParagraphEditorComponentSelection moveSelectionFromStartToOffset({
    EditorComponentSelection currentSelection,
    @required bool expandSelection,
    @required Offset localOffset,
  }) {
    final extentOffset = _selectableText
        .getPositionAtOffset(
          Offset(localOffset.dx, 0.0),
        )
        .offset;

    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? 0 : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    }
  }

  @override
  ParagraphEditorComponentSelection moveSelectionFromEndToOffset({
    EditorComponentSelection currentSelection,
    @required bool expandSelection,
    @required Offset localOffset,
  }) {
    final extentOffset = _selectableText
        .getPositionAtOffset(
          Offset(localOffset.dx, _selectableText.size.height),
        )
        .offset;

    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? widget.text.length : extentOffset,
          extentOffset: extentOffset,
        ),
      );
    }
  }

  @override
  ParagraphEditorComponentSelection getSelectionInRect(Rect selectionArea, bool isDraggingDown) {
    final selection = _selectableText.getSelectionInRect(selectionArea, isDraggingDown);

    return ParagraphEditorComponentSelection(
      selection: selection,
    );
  }

  @override
  ParagraphEditorComponentSelection moveSelectionToStart({
    EditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    print('Move selection to start. Current selection: ${currentSelection?.componentSelection}');
    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : 0,
          extentOffset: 0,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  ParagraphEditorComponentSelection moveSelectionToEnd({
    EditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection != null && currentSelection is ParagraphEditorComponentSelection) {
      return ParagraphEditorComponentSelection(
        selection: TextSelection(
          baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : widget.text.length,
          extentOffset: widget.text.length,
        ),
      );
    } else {
      return ParagraphEditorComponentSelection(
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  MouseCursor getCursorForOffset(Offset localCursorOffset) {
    return _selectableText.isTextAtOffset(localCursorOffset) ? SystemMouseCursors.text : null;
  }

  @override
  void onKeyPressed({
    @required RawKeyEvent keyEvent,
    @required EditorSelection editorSelection,
    @required EditorComponentSelection currentComponentSelection,
  }) {
    if (keyEvent is! RawKeyDownEvent) {
      return;
    }

    if (_isCharacterKey(keyEvent.logicalKey)) {
      final newParagraph = _insertStringInString(
        index: (currentComponentSelection.componentSelection as TextSelection).extentOffset,
        existing: widget.text,
        addition: keyEvent.character,
      );

      editorSelection.nodeWithCursor.paragraph = newParagraph;

      final currentSelection = (currentComponentSelection.componentSelection as TextSelection);
      editorSelection.updateCursorComponentSelection(
        ParagraphEditorComponentSelection(
          selection: TextSelection(
            baseOffset: currentSelection.extentOffset + 1,
            extentOffset: currentSelection.extentOffset + 1,
          ),
        ),
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
      final textSelection = (currentComponentSelection.componentSelection as TextSelection);

      final cursorIndex = textSelection.start;
      final startText = widget.text.substring(0, cursorIndex);
      final endText = cursorIndex < widget.text.length ? widget.text.substring(textSelection.end) : '';
      print('Splitting paragraph:');
      print(' - start text: "$startText"');
      print(' - end text: "$endText"');

      final newNode = editorSelection.insertNewNodeAfter(editorSelection.nodeWithCursor);

      editorSelection.nodeWithCursor.paragraph = startText;
      newNode.paragraph = endText;

      editorSelection.nodeWithCursor.selection = null;
      editorSelection.baseOffsetNode = newNode;
      editorSelection.extentOffsetNode = newNode;
      editorSelection.nodeWithCursor = newNode;
      editorSelection.updateCursorComponentSelection(
        ParagraphEditorComponentSelection(
          selection: TextSelection.collapsed(
            offset: 0,
          ),
        ),
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      final currentSelection = currentComponentSelection.componentSelection as TextSelection;
      if (currentSelection.extentOffset > 0) {
        final newParagraph = _removeStringSubsection(
          from: currentSelection.extentOffset - 1,
          to: currentSelection.extentOffset,
          text: widget.text,
        );

        editorSelection.nodeWithCursor.paragraph = newParagraph;

        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: TextSelection(
              baseOffset: currentSelection.extentOffset - 1,
              extentOffset: currentSelection.extentOffset - 1,
            ),
          ),
        );
      } else {
        print('Combining node with previous.');
        final originalParagraphLength = editorSelection.nodeWithCursor.paragraph.length;

        editorSelection.combineCursorNodeWithPrevious();

        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: TextSelection.collapsed(
              offset: editorSelection.nodeWithCursor.paragraph.length - originalParagraphLength,
            ),
          ),
        );
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.delete) {
      final currentSelection = currentComponentSelection.componentSelection as TextSelection;
      if (currentSelection.extentOffset < widget.text.length - 1) {
        final newParagraph = _removeStringSubsection(
          from: currentSelection.extentOffset,
          to: currentSelection.extentOffset + 1,
          text: widget.text,
        );

        editorSelection.nodeWithCursor.paragraph = newParagraph;

        editorSelection.notifyListeners();
      } else {
        print('Combining node with next.');
        final originalParagraphLength = editorSelection.nodeWithCursor.paragraph.length;

        editorSelection.combineCursorNodeWithNext();

        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: TextSelection.collapsed(
              offset: originalParagraphLength,
            ),
          ),
        );
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      dynamic newSelection;
      if (keyEvent.isMetaPressed) {
        newSelection = moveToStartOfLine(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = moveBackOneWord(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = moveBackOneCharacter(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      }

      editorSelection.updateCursorComponentSelection(newSelection);
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      dynamic newSelection;
      if (keyEvent.isMetaPressed) {
        newSelection = moveToEndOfLine(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = moveForwardOneWord(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = moveForwardOneCharacter(
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      }

      editorSelection.updateCursorComponentSelection(newSelection);
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      moveUpOneLine(
        editorSelection: editorSelection,
        currentSelection: currentComponentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      moveDownOneLine(
        editorSelection: editorSelection,
        currentSelection: currentComponentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  }

  void moveUpOneLine({
    EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    final oneLineUpPosition = _selectableText.getPositionOneLineUp(
      currentPosition: TextPosition(
        offset: _editingController.selection.extentOffset,
      ),
    );

    if (oneLineUpPosition == null) {
      // The first line is selected. There is no line above that.
      // Select any remaining text on this line.
      if (expandSelection) {
        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: currentSelection.componentSelection.copyWith(
              extentOffset: 0,
            ),
          ),
        );
      }

      // Move up to the previous component in the editor.
      final currentSelectionOffset = _selectableText.getOffsetForPosition(
        TextPosition(
          offset: currentSelection.componentSelection.extentOffset,
        ),
      );
      final didMove = editorSelection.moveCursorToPreviousComponent(
        expandSelection: expandSelection,
        previousCursorOffset: currentSelectionOffset,
      );

      if (!didMove) {
        // There is no component above us. Move our selection to the
        // beginning of the paragraph.
        final newSelection = ParagraphEditorComponentSelection(
          selection: TextSelection(
            baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : 0,
            extentOffset: 0,
          ),
        );

        editorSelection.updateCursorComponentSelection(newSelection);
      }

      return;
    }

    final newSelection = ParagraphEditorComponentSelection(
      selection: currentSelection.componentSelection.copyWith(
        baseOffset: expandSelection ? _editingController.selection.baseOffset : oneLineUpPosition.offset,
        extentOffset: oneLineUpPosition.offset,
      ),
    );

    editorSelection.updateCursorComponentSelection(newSelection);
  }

  void moveDownOneLine({
    EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    final oneLineDownPosition = _selectableText.getPositionOneLineDown(
      currentPosition: TextPosition(
        offset: _editingController.selection.extentOffset,
      ),
    );

    if (oneLineDownPosition == null) {
      // The last line is selected. There is no line below that.
      if (expandSelection) {
        // Select any remaining text on this line.
        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: currentSelection.componentSelection.copyWith(
              extentOffset: widget.text.length,
            ),
          ),
        );
      }

      // Move down to next component in editor.
      final currentSelectionOffset = _selectableText.getOffsetForPosition(
        TextPosition(
          offset: currentSelection.componentSelection.extentOffset,
        ),
      );
      final didMove = editorSelection.moveCursorToNextComponent(
        expandSelection: expandSelection,
        previousCursorOffset: currentSelectionOffset,
      );

      if (!didMove) {
        // There is no component below us. Move our selection to the
        // end of the paragraph.
        final newSelection = ParagraphEditorComponentSelection(
          selection: TextSelection(
            baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : widget.text.length,
            extentOffset: widget.text.length,
          ),
        );

        editorSelection.updateCursorComponentSelection(newSelection);
      }

      return;
    }

    final newSelection = ParagraphEditorComponentSelection(
      selection: currentSelection.componentSelection.copyWith(
        baseOffset: expandSelection ? _editingController.selection.baseOffset : oneLineDownPosition.offset,
        extentOffset: oneLineDownPosition.offset,
      ),
    );

    editorSelection.updateCursorComponentSelection(newSelection);
  }

  ParagraphEditorComponentSelection moveBackOneCharacter({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    final newExtent = (textSelection.extentOffset - 1).clamp(0.0, widget.text.length).toInt();
    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
        extentOffset: newExtent,
      ),
    );
  }

  ParagraphEditorComponentSelection moveBackOneWord({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    int newExtent = textSelection.extentOffset;
    if (newExtent == 0) {
      return currentSelection;
    }
    newExtent -= 1; // we always want to jump at least 1 character.

    while (newExtent > 0 && latinCharacters.contains(_editingController.text[newExtent])) {
      newExtent -= 1;
    }

    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
        extentOffset: newExtent,
      ),
    );
  }

  ParagraphEditorComponentSelection moveToStartOfLine({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;
    final startOfLinePosition = _selectableText.getPositionAtStartOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );

    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : startOfLinePosition.offset,
        extentOffset: startOfLinePosition.offset,
      ),
    );
  }

  ParagraphEditorComponentSelection moveForwardOneCharacter({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    final newExtent = (textSelection.extentOffset + 1).clamp(0.0, widget.text.length).toInt();
    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
        extentOffset: newExtent,
      ),
    );
  }

  ParagraphEditorComponentSelection moveForwardOneWord({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    int newExtent = currentSelection.componentSelection.extentOffset;
    if (newExtent == widget.text.length) {
      return currentSelection;
    }
    newExtent += 1; // we always want to jump at least 1 character.

    while (newExtent < widget.text.length - 1 && latinCharacters.contains(widget.text[newExtent])) {
      newExtent += 1;
    }

    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
        extentOffset: newExtent,
      ),
    );
  }

  ParagraphEditorComponentSelection moveToEndOfLine({
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    final text = widget.text;
    final endOfLineTextPosition = _selectableText.getPositionAtEndOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );
    final isAutoWrapLine =
        endOfLineTextPosition.offset < text.length && (text.isNotEmpty && text[endOfLineTextPosition.offset] != '\n');

    // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
    //       cursor to jump to the next line because the cursor is placed after
    //       the final selected character. We don't want this, so in this case
    //       we `-1`.
    //
    //       However, if the line that is selected ends with an explicit `\n`,
    //       or if the line is the terminal line for the paragraph then we don't
    //       want to `-1` because that would leave a dangling character after the
    //       selection.
    final newExtent = (isAutoWrapLine) ? endOfLineTextPosition.offset - 1 : endOfLineTextPosition.offset;

    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
        extentOffset: newExtent,
      ),
    );
  }

  static const latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  String _insertStringInString({
    int index,
    int replaceFrom,
    int replaceTo,
    String existing,
    String addition,
  }) {
    assert(index == null || (replaceFrom == null && replaceTo == null));
    assert((replaceFrom == null && replaceTo == null) || (replaceFrom < replaceTo));

    if (index == 0) {
      return addition + existing;
    } else if (index == existing.length) {
      return existing + addition;
    } else if (index != null) {
      return existing.substring(0, index) + addition + existing.substring(index);
    } else {
      return existing.substring(0, replaceFrom) + addition + existing.substring(replaceTo);
    }
  }

  String _removeStringSubsection({
    int from,
    int to,
    String text,
  }) {
    String left = '';
    String right = '';
    if (from > 0) {
      left = text.substring(0, from);
    }
    if (to < text.length - 1) {
      right = text.substring(to, text.length);
    }
    return left + right;
  }

  bool _isCharacterKey(LogicalKeyboardKey key) {
    // keyLabel for a character should be: 'a', 'b',...,'A','B',...
    if (key.keyLabel.length != 1) {
      return false;
    }
    return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()_+<>?:"{}|'
        .contains(key.keyLabel);
  }

  @override
  Widget build(BuildContext context) {
    return _buildFocusDecoration(
      child: _buildText(),
    );
  }

  Widget _buildFocusDecoration({
    Widget child,
  }) {
    return AnimatedBuilder(
      animation: FocusManager.instance,
      builder: (context, child) {
        return Focus(
          focusNode: _focusNode,
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildText() {
    return AnimatedBuilder(
      animation: _editingController,
      builder: (context, child) {
        return SelectableText(
          key: _textKey,
          text: widget.text,
          textSelection: widget.textSelection,
          hasCursor: widget.hasCursor,
          style: widget.style,
          highlightWhenEmpty: widget.highlightWhenEmpty,
          showDebugPaint: widget.showDebugPaint,
        );
      },
    );
  }
}
