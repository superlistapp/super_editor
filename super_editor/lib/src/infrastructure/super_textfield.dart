import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:super_editor/src/default_editor/editor.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/composable_text.dart';
import 'package:super_editor/src/infrastructure/selectable_text.dart';

import 'attributed_text.dart';
import 'multi_tap_gesture.dart';

final _log = Logger(scope: 'super_textfield.dart');

// TODO: Split SuperTextField into multiple widgets
//       - widget for text painting, selection, caret painting, caret placement and movement
//       - widget that maps gestures to caret placement + scrolling, padding
//       - widget that adds hint and any other decorations
class SuperTextField extends StatefulWidget {
  const SuperTextField({
    Key? key,
    this.focusNode,
    this.controller,
    this.textAlign = TextAlign.left,
    this.textSelectionDecoration = const TextSelectionDecoration(
      selectionColor: Color(0xFFACCEF7),
    ),
    this.textCaretFactory = const TextCaretFactory(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
    this.hintBuilder,
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.onRightClick,
    this.keyboardActions = defaultTextfieldKeyboardActions,
  }) : super(key: key);

  final FocusNode? focusNode;

  final AttributedTextEditingController? controller;

  /// The alignment to use for `richText` display.
  final TextAlign textAlign;

  /// The visual decoration to apply to the `textSelection`.
  final TextSelectionDecoration textSelectionDecoration;

  /// Builds the visual representation of the caret in this
  /// `SelectableText` widget.
  final TextCaretFactory textCaretFactory;

  final WidgetBuilder? hintBuilder;
  final HintBehavior hintBehavior;

  final RightClickListener? onRightClick;

  final List<TextfieldKeyboardAction> keyboardActions;

  @override
  _SuperTextFieldState createState() => _SuperTextFieldState();
}

class _SuperTextFieldState extends State<SuperTextField> implements TextComposable {
  final _selectableTextKey = GlobalKey<SelectableTextState>();
  late FocusNode _focusNode;

  late AttributedTextEditingController _controller;

  final _cursorStyle = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  _SelectionType _selectionType = _SelectionType.position;
  Offset? _dragStartInViewport;
  Offset? _dragStartInText;
  Offset? _dragEndInViewport;
  Offset? _dragEndInText;
  Rect? _dragRectInViewport;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? AttributedTextEditingController();
  }

  @override
  void didUpdateWidget(SuperTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }

    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? AttributedTextEditingController();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  TextSelection getWordSelectionAt(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      throw Exception('Expected a node position of type TextPosition but received: $textPosition');
    }

    return _selectableTextKey.currentState!.getWordSelectionAt(textPosition);
  }

  TextSelection getParagraphSelectionAt(dynamic textPosition, TextAffinity affinity) {
    if (textPosition is! TextPosition) {
      throw Exception('Expected a node position of type TextPosition but received: $textPosition');
    }

    final plainText = _controller.text.text;

    // If the given position falls directly on a newline then return
    // just the newline character as the paragraph selection.
    if (textPosition.offset < plainText.length && plainText[textPosition.offset] == '\n') {
      return TextSelection.collapsed(offset: textPosition.offset);
    }

    int start = textPosition.offset;
    int end = textPosition.offset;

    while (start > 0 && plainText[start - 1] != '\n') {
      start -= 1;
    }
    while (end < plainText.length && plainText[end] != '\n') {
      end += 1;
    }

    return affinity == TextAffinity.downstream
        ? TextSelection(
            baseOffset: start,
            extentOffset: end,
          )
        : TextSelection(
            baseOffset: end,
            extentOffset: start,
          );
  }

  @override
  String getContiguousTextAt(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      throw Exception('Expected a node position of type TextPosition but received: $textPosition');
    }

    return getParagraphSelectionAt(textPosition, TextAffinity.downstream).textInside(_controller.text.text);
  }

  @override
  TextPosition? getPositionOneLineUp(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState!.getPositionOneLineUp(
      currentPosition: textPosition,
    );
  }

  @override
  TextPosition? getPositionOneLineDown(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState!.getPositionOneLineDown(
      currentPosition: textPosition,
    );
  }

  @override
  TextPosition? getPositionAtEndOfLine(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState!.getPositionAtEndOfLine(currentPosition: textPosition);
  }

  @override
  TextPosition? getPositionAtStartOfLine(dynamic textPosition) {
    if (textPosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState!.getPositionAtStartOfLine(currentPosition: textPosition);
  }

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    _log.log('_onKeyPressed', 'keyEvent: ${keyEvent.character}');
    if (keyEvent is! RawKeyDownEvent) {
      _log.log('_onKeyPressed', ' - not a "down" event. Ignoring.');
      return KeyEventResult.handled;
    }

    TextFieldActionResult instruction = TextFieldActionResult.notHandled;
    int index = 0;
    while (instruction == TextFieldActionResult.notHandled && index < widget.keyboardActions.length) {
      instruction = widget.keyboardActions[index](
        controller: _controller,
        textFieldState: this,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    return instruction == TextFieldActionResult.handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onTapDown(TapDownDetails details) {
    _log.log('_onTapDown', 'EditableDocument: onTapDown()');
    _clearSelection();
    _selectionType = _SelectionType.position;

    final textOffset = _getTextOffset(details.localPosition);
    final tapTextPosition = _getPositionNearestToTextOffset(textOffset);

    setState(() {
      _controller.selection = TextSelection.collapsed(offset: tapTextPosition.offset);
    });

    _focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.word;

    _log.log('_onDoubleTapDown', 'EditableDocument: onDoubleTap()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        _controller.selection = getWordSelectionAt(tapTextPosition);
      });
    } else {
      _clearSelection();
    }

    _focusNode.requestFocus();
  }

  void _onDoubleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.paragraph;

    _log.log('_onTripleTapDown', 'EditableDocument: onTripleTapDown()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        _controller.selection = getParagraphSelectionAt(tapTextPosition, TextAffinity.downstream);
      });
    } else {
      _clearSelection();
    }

    _focusNode.requestFocus();
  }

  void _onTripleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onRightClick(TapUpDetails details) {
    widget.onRightClick?.call(context, _controller, details.localPosition);
  }

  void _onPanStart(DragStartDetails details) {
    _log.log('_onPanStart', '_onPanStart()');
    _dragStartInViewport = details.localPosition;
    _dragStartInText = _getTextOffset(_dragStartInViewport!);

    _dragRectInViewport = Rect.fromLTWH(_dragStartInViewport!.dx, _dragStartInViewport!.dy, 1, 1);

    _focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.log('_onPanUpdate', '_onPanUpdate()');
    setState(() {
      _dragEndInViewport = details.localPosition;
      _dragEndInText = _getTextOffset(_dragEndInViewport!);
      _dragRectInViewport = Rect.fromPoints(_dragStartInViewport!, _dragEndInViewport!);
      _log.log('_onPanUpdate', ' - drag rect: $_dragRectInViewport');
      _updateCursorStyle(details.localPosition);
      _updateDragSelection();

      // _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    // _stopScrollingUp();
    // _stopScrollingDown();
  }

  void _onPanCancel() {
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    // _stopScrollingUp();
    // _stopScrollingDown();
  }

  Offset _getTextOffset(Offset textFieldOffset) {
    final textFieldBox = context.findRenderObject() as RenderBox;
    final textBox = _selectableTextKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(textFieldOffset, ancestor: textFieldBox);
  }

  TextPosition? _getPositionAtOffset(Offset textFieldOffset) {
    final textOffset = _getTextOffset(textFieldOffset);
    final textBox = _selectableTextKey.currentContext!.findRenderObject() as RenderBox;

    return textBox.size.contains(textOffset) ? _selectableTextKey.currentState!.getPositionAtOffset(textOffset) : null;
  }

  TextPosition _getPositionNearestToTextOffset(Offset textOffset) {
    return _selectableTextKey.currentState!.getPositionAtOffset(textOffset);
  }

  void _updateDragSelection() {
    if (_dragStartInText == null || _dragEndInText == null) {
      return;
    }

    setState(() {
      final startDragOffset = _getPositionNearestToTextOffset(_dragStartInText!).offset;
      final endDragOffset = _getPositionNearestToTextOffset(_dragEndInText!).offset;
      final affinity = startDragOffset <= endDragOffset ? TextAffinity.downstream : TextAffinity.upstream;

      if (_selectionType == _SelectionType.paragraph) {
        final baseParagraphSelection = getParagraphSelectionAt(TextPosition(offset: startDragOffset), affinity);
        final extentParagraphSelection = getParagraphSelectionAt(TextPosition(offset: endDragOffset), affinity);

        _controller.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else if (_selectionType == _SelectionType.word) {
        final baseParagraphSelection = getWordSelectionAt(TextPosition(offset: startDragOffset));
        final extentParagraphSelection = getWordSelectionAt(TextPosition(offset: endDragOffset));

        _controller.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else {
        _controller.selection = TextSelection(
          baseOffset: startDragOffset,
          extentOffset: endDragOffset,
        );
      }
    });
  }

  TextSelection _combineSelections(
    TextSelection selection1,
    TextSelection selection2,
    TextAffinity affinity,
  ) {
    return affinity == TextAffinity.downstream
        ? TextSelection(
            baseOffset: min(selection1.start, selection2.start),
            extentOffset: max(selection1.end, selection2.end),
          )
        : TextSelection(
            baseOffset: max(selection1.end, selection2.end),
            extentOffset: min(selection1.start, selection2.start),
          );
  }

  void _clearSelection() {
    setState(() {
      _controller.selection = TextSelection.collapsed(offset: -1);
    });
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  void _updateCursorStyle(Offset cursorOffset) {
    final textPositionAtOffset = _getPositionAtOffset(cursorOffset);

    if (textPositionAtOffset != null) {
      _cursorStyle.value = SystemMouseCursors.text;
    } else {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (_, __) => true,
      child: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKeyPressed,
        child: GestureDetector(
          onSecondaryTapUp: _onRightClick,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
                () => TapSequenceGestureRecognizer(),
                (TapSequenceGestureRecognizer recognizer) {
                  recognizer
                    ..onTapDown = _onTapDown
                    ..onDoubleTapDown = _onDoubleTapDown
                    ..onDoubleTap = _onDoubleTap
                    ..onTripleTapDown = _onTripleTapDown
                    ..onTripleTap = _onTripleTap;
                },
              ),
              PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(),
                (PanGestureRecognizer recognizer) {
                  recognizer
                    ..onStart = _onPanStart
                    ..onUpdate = _onPanUpdate
                    ..onEnd = _onPanEnd
                    ..onCancel = _onPanCancel;
                },
              ),
            },
            child: Listener(
              onPointerHover: _onMouseMove,
              child: MouseRegion(
                cursor: _cursorStyle.value,
                child: ListenableBuilder(
                    listenable: _focusNode,
                    builder: (context) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _focusNode.hasFocus ? Colors.blue : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: ListenableBuilder(
                            listenable: _controller,
                            builder: (context) {
                              final isTextEmpty = _controller.text.text.isEmpty;
                              final showHint = widget.hintBuilder != null &&
                                  ((isTextEmpty && widget.hintBehavior == HintBehavior.displayHintUntilTextEntered) ||
                                      (isTextEmpty &&
                                          !_focusNode.hasFocus &&
                                          widget.hintBehavior == HintBehavior.displayHintUntilFocus));

                              return Stack(
                                children: [
                                  if (showHint) widget.hintBuilder!(context),
                                  SelectableText(
                                    key: _selectableTextKey,
                                    textSpan: _controller.text
                                        .computeTextSpan((attributions) => defaultStyleBuilder(attributions)),
                                    textAlign: widget.textAlign,
                                    textSelection: _controller.selection,
                                    textSelectionDecoration: widget.textSelectionDecoration,
                                    showCaret: _focusNode.hasFocus,
                                    textCaretFactory: widget.textCaretFactory,
                                  ),
                                ],
                              );
                            }),
                      );
                    }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum HintBehavior {
  /// Display a hint when the text field is empty until
  /// the text field receives focus, then hide the hint.
  displayHintUntilFocus,

  /// Display a hint when the text field is empty until
  /// at least 1 character is entered into the text field.
  displayHintUntilTextEntered,

  /// Do not display a hint.
  noHint,
}

typedef RightClickListener = void Function(
    BuildContext textFieldContext, AttributedTextEditingController textController, Offset textFieldOffset);

enum _SelectionType {
  position,
  word,
  paragraph,
}

enum TextFieldActionResult {
  handled,
  notHandled,
}

typedef TextfieldKeyboardAction = TextFieldActionResult Function({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
});

const defaultTextfieldKeyboardActions = <TextfieldKeyboardAction>[
  copyTextWhenCmdCIsPressed,
  pasteTextWhenCmdVIsPressed,
  moveUpDownLeftAndRightWithArrowKeysInTextField,
  deleteTextWhenBackspaceOrDeleteIsPressedInTextField,
  insertNewlineInTextField,
  insertCharacterInTextField,
];

TextFieldActionResult copyTextWhenCmdCIsPressed({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isMetaPressed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
    return TextFieldActionResult.notHandled;
  }

  Clipboard.setData(ClipboardData(
    text: controller.selection.textInside(controller.text.text),
  ));

  return TextFieldActionResult.handled;
}

TextFieldActionResult pasteTextWhenCmdVIsPressed({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isMetaPressed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return TextFieldActionResult.notHandled;
  }

  final insertionOffset = controller.selection.extentOffset;
  Clipboard.getData('utf8').then((clipboardData) {
    if (clipboardData != null && clipboardData.text != null) {
      controller.text.insertString(
        textToInsert: clipboardData.text!,
        startOffset: insertionOffset,
      );
    }
  });

  return TextFieldActionResult.handled;
}

TextFieldActionResult moveUpDownLeftAndRightWithArrowKeysInTextField({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  const arrowKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ];
  if (!arrowKeys.contains(keyEvent.logicalKey)) {
    return TextFieldActionResult.notHandled;
  }
  if (controller.selection.extentOffset == -1) {
    return TextFieldActionResult.notHandled;
  }

  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling left arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      controller: controller,
      textFieldState: textFieldState,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: true,
      movementModifiers: movementModifiers,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling right arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      controller: controller,
      textFieldState: textFieldState,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: false,
      movementModifiers: movementModifiers,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling up arrow key');
    _moveVertically(
      controller: controller,
      textFieldState: textFieldState,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: true,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling down arrow key');
    _moveVertically(
      controller: controller,
      textFieldState: textFieldState,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: false,
    );
  }

  return TextFieldActionResult.handled;
}

void _moveHorizontally({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required bool expandSelection,
  required bool moveLeft,
  Map<String, dynamic> movementModifiers = const {},
}) {
  int newExtent;

  if (moveLeft) {
    if (movementModifiers['movement_unit'] == 'line') {
      newExtent = textFieldState
          .getPositionAtStartOfLine(
            TextPosition(offset: controller.selection.extentOffset),
          )!
          .offset;
    } else if (movementModifiers['movement_unit'] == 'word') {
      final text = controller.text.text;

      newExtent = controller.selection.extentOffset;
      newExtent -= 1; // we always want to jump at least 1 character.
      while (newExtent > 0 && text[newExtent - 1] != ' ' && text[newExtent - 1] != '\n') {
        newExtent -= 1;
      }
    } else {
      newExtent = controller.selection.extentOffset - 1;
    }
  } else {
    if (controller.selection.extentOffset >= controller.text.text.length) {
      // Can't move further right.
      return null;
    }

    if (movementModifiers['movement_unit'] == 'line') {
      final endOfLine = textFieldState.getPositionAtEndOfLine(
        TextPosition(offset: controller.selection.extentOffset),
      );
      if (endOfLine == null) {
        _log.log('movePositionRight',
            'Tried to move text position right to end of line but getPositionAtEndOfLine() returned null');
        return null;
      }

      final endPosition = TextPosition(offset: controller.text.text.length);
      final text = controller.text.text;

      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (text[endOfLine.offset] != '\n');

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
    } else if (movementModifiers['movement_unit'] == 'word') {
      final extentPosition = controller.selection.extent;
      final text = controller.text.text;

      newExtent = extentPosition.offset;
      newExtent += 1; // we always want to jump at least 1 character.
      while (newExtent < text.length && text[newExtent] != ' ' && text[newExtent] != '\n') {
        newExtent += 1;
      }
    } else {
      newExtent = controller.selection.extentOffset + 1;
    }
  }

  controller.selection = TextSelection(
    baseOffset: expandSelection ? controller.selection.baseOffset : newExtent,
    extentOffset: newExtent,
  );
}

void _moveVertically({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required bool expandSelection,
  required bool moveUp,
}) {
  int? newExtent;

  if (moveUp) {
    newExtent = textFieldState.getPositionOneLineUp(controller.selection.extent)?.offset;

    // If there is no line above the current selection, move selection
    // to the beginning of the available text.
    newExtent ??= 0;
  } else {
    newExtent = textFieldState.getPositionOneLineDown(controller.selection.extent)?.offset;

    // If there is no line below the current selection, move selection
    // to the end of the available text.
    newExtent ??= controller.text.text.length;
  }

  controller.selection = TextSelection(
    baseOffset: expandSelection ? controller.selection.baseOffset : newExtent,
    extentOffset: newExtent,
  );
}

TextFieldActionResult insertCharacterInTextField({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.isMetaPressed || keyEvent.isControlPressed) {
    return TextFieldActionResult.notHandled;
  }

  if (!controller.selection.isCollapsed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.character == null || keyEvent.character == '') {
    return TextFieldActionResult.notHandled;
  }

  final initialTextOffset = controller.selection.extentOffset;

  controller.text = controller.text.insertString(textToInsert: keyEvent.character!, startOffset: initialTextOffset);
  controller.selection = TextSelection.collapsed(offset: initialTextOffset + 1);

  return TextFieldActionResult.handled;
}

TextFieldActionResult deleteTextWhenBackspaceOrDeleteIsPressedInTextField({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  final isBackspace = keyEvent.logicalKey == LogicalKeyboardKey.backspace;
  final isDelete = keyEvent.logicalKey == LogicalKeyboardKey.delete;
  if (!isBackspace && !isDelete) {
    return TextFieldActionResult.notHandled;
  }
  if (controller.selection.extentOffset < 0) {
    return TextFieldActionResult.notHandled;
  }

  // If the current selection is not collapsed, then delete that
  // selection. If the selection is collapsed, calculate a selection
  // that includes the next or previous character depending on
  // whether the user pressed backspace or delete.
  final deletionSelection = controller.selection.isCollapsed
      ? TextSelection(
          baseOffset: controller.selection.extentOffset,
          extentOffset:
              (controller.selection.extentOffset + (isBackspace ? -1 : 1)).clamp(0, controller.text.text.length),
        )
      : controller.selection;

  final newSelectionExtent = isBackspace && controller.selection.isCollapsed
      ? controller.selection.extentOffset - 1
      : controller.selection.start;

  controller.text = controller.text.removeRegion(
    startOffset: min(deletionSelection.baseOffset, deletionSelection.extentOffset),
    endOffset: max(deletionSelection.baseOffset, deletionSelection.extentOffset),
  );
  controller.selection = TextSelection.collapsed(offset: newSelectionExtent);

  return TextFieldActionResult.handled;
}

TextFieldActionResult insertNewlineInTextField({
  required AttributedTextEditingController controller,
  required _SuperTextFieldState textFieldState,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return TextFieldActionResult.notHandled;
  }
  if (!controller.selection.isCollapsed) {
    return TextFieldActionResult.notHandled;
  }

  final currentSelectionExtent = controller.selection.extent;

  controller.text = controller.text.insertString(
    textToInsert: '\n',
    startOffset: currentSelectionExtent.offset,
  );
  controller.selection = TextSelection.collapsed(offset: currentSelectionExtent.offset + 1);

  return TextFieldActionResult.handled;
}

class AttributedTextEditingController with ChangeNotifier {
  AttributedTextEditingController({
    AttributedText? text,
    TextSelection? selection,
  })  : _text = text ?? AttributedText(),
        _selection = selection ?? TextSelection.collapsed(offset: -1);

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newValue) {
    if (newValue != _text) {
      _text = newValue;
      notifyListeners();
    }
  }

  TextSelection _selection;
  TextSelection get selection => _selection;
  set selection(TextSelection newValue) {
    if (newValue != _selection) {
      _selection = newValue;
      notifyListeners();
    }
  }
}
