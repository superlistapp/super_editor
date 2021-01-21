import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Spike:
/// Create a prototype of a custom text widget for reference purposes.
///
/// Features:
///  - displays I-beam cursor when hovering over text
///  - inserts caret where the user taps on text
///
///  - all latin characters, numbers, and special symbols can be entered into the field
///  - backspace key deletes the previous character when the selection is collapsed
///  - backspace key deletes all selected characters when the selection is not collapsed
///  - delete key deletes the previous character when the selection is collapsed
///  - delete key deletes all selected characters when the selection is not collapsed
///
///  - arrow keys move caret left, right, up, and down
///  - shift + arrow keys expands selection in desired direction
///  - shift + cmd + left/right selects by word
///  - shift + alt + left/right selects to beginning/end of line, respectively
///  - pressing left or right with a selection span causes the selection to collapse to a single caret
///
///  - drag selection of text

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: CustomTextWidgetSpike(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class CustomTextWidgetSpike extends StatefulWidget {
  @override
  _CustomTextWidgetSpikeState createState() => _CustomTextWidgetSpikeState();
}

class _CustomTextWidgetSpikeState extends State<CustomTextWidgetSpike> {
  FocusNode _rootFocusNode;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _rootFocusNode.requestFocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Focus(
        focusNode: _rootFocusNode,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  style: TextStyle(
                    color: const Color(0xFF312F2C),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomText extends StatefulWidget {
  const CustomText({
    Key key,
    this.style,
  }) : super(key: key);

  final TextStyle style;

  @override
  _CustomTextState createState() => _CustomTextState();
}

class _CustomTextState extends State<CustomText> {
  final GlobalKey _textKey = GlobalKey();
  TextEditingController _editingController;
  FocusNode _focusNode;
  bool _isHoveringOverText = false;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_onKeyPressed);
    _focusNode.dispose();
    _editingController.dispose();
    super.dispose();
  }

  RenderParagraph get renderParagraph => _textKey.currentContext?.findRenderObject() as RenderParagraph;

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      RawKeyboard.instance.addListener(_onKeyPressed);

      // If no cursor position exists at all, place the cursor at the end of the
      // existing text as a default.
      if (_editingController.value.selection.extent.offset < 0) {
        _editingController.value = _editingController.value.copyWith(
          selection: TextSelection.collapsed(offset: _editingController.text.length),
        );
      }
    } else {
      RawKeyboard.instance.removeListener(_onKeyPressed);
      _editingController.value = _editingController.value.copyWith(
        selection: TextSelection.collapsed(offset: -1),
      );
    }
  }

  void _onKeyPressed(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      return;
    }

    final cursorPosition = _editingController.selection.extent.offset;
    String newText = _editingController.text;
    TextSelection newSelection;

    final key = keyEvent.logicalKey;
    if (_isAdditiveKey(key)) {
      // The user entered a latin character, digit, symbol, new-line,
      // or some other additive character.
      final currentSelection = _editingController.selection;
      newText = _insertStringInString(
        index: currentSelection.isCollapsed ? cursorPosition : null,
        existing: _editingController.text,
        addition: _getAdditiveCharacter(key),
        replaceFrom:
            currentSelection.isCollapsed ? null : min(currentSelection.baseOffset, currentSelection.extentOffset),
        replaceTo:
            currentSelection.isCollapsed ? null : max(currentSelection.baseOffset, currentSelection.extentOffset),
      );

      newSelection = TextSelection.collapsed(
        offset: currentSelection.isCollapsed ? cursorPosition + 1 : currentSelection.extentOffset + 1,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      final currentText = _editingController.text;

      if (currentText.isEmpty) {
        print('Text is empty. Nothing to backspace: "$currentText"');
        return;
      }

      final currentSelection = _editingController.selection;

      if (currentSelection.isCollapsed && currentSelection.extentOffset == 0) {
        print('Caret is at the beginning of the paragraph. Nothing to backspace.');
        return;
      }

      final from = currentSelection.isCollapsed
          ? cursorPosition - 1
          : min(currentSelection.baseOffset, currentSelection.extentOffset);
      final to = currentSelection.isCollapsed
          ? cursorPosition
          : max(currentSelection.baseOffset, currentSelection.extentOffset);
      newText = _removeStringSubsection(
        from: from,
        to: to,
        text: currentText,
      );
      newSelection = TextSelection.collapsed(
        offset: currentSelection.isCollapsed ? cursorPosition - 1 : from,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.delete) {
      final currentText = _editingController.text;

      if (currentText.isEmpty) {
        print('Text is empty. Nothing to delete: "$currentText"');
        return;
      }

      final currentSelection = _editingController.selection;

      if (currentSelection.isCollapsed && currentSelection.extentOffset == currentText.length) {
        print('Caret is at end of text. Nothing to delete.');
        return;
      }

      final from = currentSelection.isCollapsed
          ? cursorPosition
          : min(currentSelection.baseOffset, currentSelection.extentOffset);
      final to = currentSelection.isCollapsed
          ? cursorPosition + 1
          : max(currentSelection.baseOffset, currentSelection.extentOffset);
      newText = _removeStringSubsection(
        from: from,
        to: to,
        text: currentText,
      );
      newSelection = TextSelection.collapsed(
        offset: currentSelection.isCollapsed ? cursorPosition : from,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      int newCursorPosition;
      if (keyEvent.isMetaPressed) {
        newCursorPosition = _moveToStartOfLine();
      } else if (keyEvent.isAltPressed) {
        newCursorPosition = _moveToStartOfWord();
      } else if (!_editingController.selection.isCollapsed && !keyEvent.isShiftPressed) {
        // A text range is selected. Pressing the left arrow collapses
        // that selection and places the caret at the start of the selection.
        newCursorPosition = min(_editingController.selection.baseOffset, _editingController.selection.extentOffset);
      } else {
        newCursorPosition = _moveToPreviousCharacter();
      }

      newSelection = TextSelection(
        baseOffset: keyEvent.isShiftPressed ? _editingController.selection.baseOffset : newCursorPosition,
        extentOffset: newCursorPosition,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      int newCursorPosition;
      if (keyEvent.isMetaPressed) {
        newCursorPosition = _moveToEndOfLine();
      } else if (keyEvent.isAltPressed) {
        newCursorPosition = _moveToEndOfWord();
      } else if (!_editingController.selection.isCollapsed && !keyEvent.isShiftPressed) {
        // A text range is selected. Pressing the right arrow collapses
        // that selection and places the caret at the end of the selection.
        newCursorPosition = max(_editingController.selection.baseOffset, _editingController.selection.extentOffset);
      } else {
        newCursorPosition = _moveToNextCharacter();
      }

      newSelection = TextSelection(
        baseOffset: keyEvent.isShiftPressed ? _editingController.selection.baseOffset : newCursorPosition,
        extentOffset: newCursorPosition,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      // TODO: use TextPainter to get real line height.
      final lineHeight = widget.style.fontSize * widget.style.height;
      // Note: add half the line height to the current offset to help deal with
      //       line heights that aren't accurate.
      final currentSelectionOffset = renderParagraph.getOffsetForCaret(
              TextPosition(offset: _editingController.selection.extentOffset), Rect.zero) +
          Offset(0, lineHeight / 2);
      final oneLineUpOffset = currentSelectionOffset - Offset(0, lineHeight);
      final oneLineUpTextPosition = renderParagraph.getPositionForOffset(oneLineUpOffset);

      if (keyEvent.isShiftPressed) {
        newSelection = TextSelection(
          baseOffset: _editingController.selection.baseOffset,
          extentOffset: oneLineUpTextPosition.offset,
        );
      } else {
        newSelection = TextSelection.collapsed(offset: oneLineUpTextPosition.offset);
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      // TODO: use TextPainter to get real line height.
      final lineHeight = widget.style.fontSize * widget.style.height;
      // Note: add half the line height to the current offset to help deal with
      //       line heights that aren't accurate.
      final currentSelectionOffset = renderParagraph.getOffsetForCaret(
              TextPosition(offset: _editingController.selection.extentOffset), Rect.zero) +
          Offset(0, lineHeight / 2);
      final oneLineDownOffset = currentSelectionOffset + Offset(0, lineHeight);
      final oneLineDownTextPosition = renderParagraph.getPositionForOffset(oneLineDownOffset);

      if (keyEvent.isShiftPressed) {
        newSelection = TextSelection(
          baseOffset: _editingController.selection.baseOffset,
          extentOffset: oneLineDownTextPosition.offset,
        );
      } else {
        newSelection = TextSelection.collapsed(offset: oneLineDownTextPosition.offset);
      }
    } else {
      // This is not a key we care about. Return.
      return;
    }

    _editingController.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );
  }

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

  bool _isAdditiveKey(LogicalKeyboardKey key) {
    return _isCharacterKey(key) || key == LogicalKeyboardKey.enter;
  }

  String _getAdditiveCharacter(LogicalKeyboardKey key) {
    if (_isCharacterKey(key)) {
      return key.keyLabel;
    } else if (key == LogicalKeyboardKey.enter) {
      return '\n';
    } else {
      throw Exception('"key" does not correspond to an additive charcter: $key');
    }
  }

  bool _isCharacterKey(LogicalKeyboardKey key) {
    // keyLabel for a character should be: 'a', 'b',...,'A','B',...
    if (key.keyLabel.length != 1) {
      return false;
    }
    return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()_+<>?:"{}|'
        .contains(key.keyLabel);
  }

  int _moveToPreviousCharacter() {
    return max(_editingController.selection.extent.offset - 1, 0);
  }

  int _moveToStartOfWord() {
    int index = _editingController.selection.extentOffset;
    if (index == 0) {
      return index;
    }
    index -= 1; // we always want to jump at least 1 character.

    while (index > 0 && latinCharacters.contains(_editingController.text[index])) {
      index -= 1;
    }

    return index;
  }

  int _moveToStartOfLine() {
    final cursorOffset =
        renderParagraph.getOffsetForCaret(TextPosition(offset: _editingController.selection.extentOffset), Rect.zero);
    final endOfLineOffset = Offset(0, cursorOffset.dy);
    final endOfLineTextPosition = renderParagraph.getPositionForOffset(endOfLineOffset);

    return endOfLineTextPosition.offset;
  }

  int _moveToNextCharacter() {
    return min(_editingController.selection.extent.offset + 1, _editingController.text.length);
  }

  static const latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  int _moveToEndOfWord() {
    int index = _editingController.selection.extentOffset;
    if (index == _editingController.text.length) {
      return index;
    }
    index += 1; // we always want to jump at least 1 character.

    while (index < _editingController.text.length - 1 && latinCharacters.contains(_editingController.text[index])) {
      index += 1;
    }
    return index + 1;
  }

  int _moveToEndOfLine() {
    final text = _editingController.text;
    final cursorOffset =
        renderParagraph.getOffsetForCaret(TextPosition(offset: _editingController.selection.extentOffset), Rect.zero);
    final endOfLineOffset = Offset(renderParagraph.size.width, cursorOffset.dy);
    final endOfLineTextPosition = renderParagraph.getPositionForOffset(endOfLineOffset);
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
    return (isAutoWrapLine) ? endOfLineTextPosition.offset - 1 : endOfLineTextPosition.offset;
  }

  void _onPanStart(DragStartDetails details) {
    _insertCaretAtOffset(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _expandSelectionToOffset(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    // TODO:
  }

  void _onTapUp(TapUpDetails details) {
    _focusNode.requestFocus();
    _insertCaretAtOffset(details.localPosition);
  }

  void _insertCaretAtOffset(Offset localOffset) {
    final selectedTextPosition = renderParagraph.getPositionForOffset(localOffset);
    _editingController.value = _editingController.value.copyWith(
      selection: TextSelection.collapsed(offset: selectedTextPosition.offset),
    );
  }

  void _expandSelectionToOffset(Offset localOffset) {
    final selectedTextPosition = renderParagraph.getPositionForOffset(localOffset);
    _editingController.value = _editingController.value.copyWith(
      selection: TextSelection(
        baseOffset: _editingController.value.selection.baseOffset,
        extentOffset: selectedTextPosition.offset,
      ),
    );
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    final hoveredParagraph = renderParagraph;
    final positionInParagraph = hoveredParagraph.globalToLocal(pointerEvent.position);
    final hoveredTextOffset = hoveredParagraph.getPositionForOffset(positionInParagraph);

    if (hoveredTextOffset != null) {
      List<TextBox> boxes = hoveredParagraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: _editingController.text.length,
        ),
      );

      for (final box in boxes) {
        if (box.toRect().contains(positionInParagraph)) {
          if (!_isHoveringOverText) {
            setState(() {
              _isHoveringOverText = true;
            });
          }
          return;
        }
      }
    }

    if (_isHoveringOverText) {
      setState(() {
        _isHoveringOverText = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: _onMouseMove,
      child: MouseRegion(
        cursor: _isHoveringOverText ? SystemMouseCursors.text : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapUp: _onTapUp,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: FocusManager.instance,
            builder: (context, child) {
              return Focus(
                focusNode: _focusNode,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _focusNode.hasFocus ? Colors.blue : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: AnimatedBuilder(
              animation: _editingController,
              builder: (context, child) {
                return Stack(
                  children: [
                    CustomPaint(
                      painter: TextSelectionPainter(
                        paragraph: renderParagraph,
                        editingValue: _editingController.value,
                      ),
                    ),
                    Text(
                      _editingController.text,
                      key: _textKey,
                      style: widget.style ?? Theme.of(context).textTheme.bodyText1,
                    ),
                    CustomPaint(
                      painter: CursorPainter(
                        paragraph: renderParagraph,
                        editingValue: _editingController.value,
                        lineHeight: widget.style.fontSize * widget.style.height,
                        caretHeight: (widget.style.fontSize * widget.style.height) * 0.8,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class TextSelectionPainter extends CustomPainter {
  TextSelectionPainter({
    @required this.paragraph,
    @required this.editingValue,
  });

  final RenderParagraph paragraph;
  final TextEditingValue editingValue;
  final Paint selectionPaint = Paint()..color = Colors.lightGreenAccent;

  @override
  void paint(Canvas canvas, Size size) {
    if (paragraph == null ||
        editingValue == null ||
        editingValue.selection.baseOffset == editingValue.selection.extentOffset) {
      return;
    }

    final selectionBoxes = paragraph.getBoxesForSelection(editingValue.selection);

    for (final box in selectionBoxes) {
      final rect = box.toRect();
      canvas.drawRect(
        // Note: If the rect has no width then we've selected an empty line. Give
        //       that line a slight width for visibility.
        rect.width > 0 ? rect : Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
        selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TextSelectionPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph || editingValue != oldDelegate.editingValue;
  }
}

class CursorPainter extends CustomPainter {
  CursorPainter({
    @required this.paragraph,
    @required this.editingValue,
    @required this.caretHeight,
    @required this.lineHeight,
  });

  final RenderParagraph paragraph;
  final TextEditingValue editingValue;
  final double caretHeight; // TODO: find a way to get this from the TextPainter, which is the correct place to get it.
  final double lineHeight; // TODO: this should probably also come from the TextPainter.
  final Paint cursorPaint = Paint()..color = Colors.black54;

  @override
  void paint(Canvas canvas, Size size) {
    if (paragraph == null || editingValue == null || editingValue.selection.extent.offset < 0) {
      return;
    }

    final caretOffset = editingValue.text.isNotEmpty
        ? paragraph.getOffsetForCaret(editingValue.selection.extent, Rect.zero)
        : Offset(0, (lineHeight - caretHeight) / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        caretOffset.dx.roundToDouble(),
        caretOffset.dy.roundToDouble(),
        1,
        caretHeight.roundToDouble(),
      ),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(CursorPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph || editingValue != oldDelegate.editingValue;
  }
}
