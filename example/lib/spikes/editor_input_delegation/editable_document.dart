import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'components/paragraph/editor_paragraph_component.dart';
import 'components/paragraph/selectable_text.dart';
import 'editor_layout_model.dart';
import 'selection/editor_selection.dart';

class EditableDocument extends StatefulWidget {
  const EditableDocument({
    Key key,
    this.initialDocument,
    this.showDebugPaint = false,
  }) : super(key: key);

  final List<DocDisplayNode> initialDocument;
  final showDebugPaint;

  @override
  _EditableDocumentState createState() => _EditableDocumentState();
}

class _EditableDocumentState extends State<EditableDocument> {
  FocusNode _rootFocusNode;

  final _displayNodes = <DocDisplayNode>[];

  Offset _dragStart;
  Rect _dragRect;

  final _cursorStyle = ValueNotifier(SystemMouseCursors.basic);

  EditorSelection _editorSelection;

  @override
  void initState() {
    super.initState();
    _displayNodes.addAll(widget.initialDocument);

    _rootFocusNode = FocusNode();

    _editorSelection = EditorSelection(
      displayNodes: _displayNodes,
    );
  }

  @override
  void didUpdateWidget(EditableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDocument != oldWidget.initialDocument) {
      setState(() {
        _editorSelection.clear();
        _displayNodes
          ..clear()
          ..addAll(widget.initialDocument);
      });
    }
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      return KeyEventResult.handled;
    }

    print('Key pressed');

    if (_editorSelection.nodeWithCursor == null) {
      print(' - no node with cursor. Returning.');
      return KeyEventResult.handled;
    }

    final isDirectionalKey = keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowUp ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowDown;
    print(' - is directional key? $isDirectionalKey');
    print(' - is editor selection collapsed? ${_editorSelection.isCollapsed}');
    print(' - is shift pressed? ${keyEvent.isShiftPressed}');
    if (isDirectionalKey && !_editorSelection.isCollapsed && !keyEvent.isShiftPressed && !keyEvent.isMetaPressed) {
      print('Collapsing editor selection, then returning.');
      _editorSelection.collapse();
      return KeyEventResult.handled;
    }

    // Handle delete and backspace for a selection.
    // TODO: add all characters to this condition.
    final isDestructiveKey =
        keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
    final shouldDeleteSelection = isDestructiveKey || _isCharacterKey(keyEvent.logicalKey);
    if (!_editorSelection.isCollapsed && shouldDeleteSelection) {
      _editorSelection.deleteSelection();

      if (isDestructiveKey) {
        // Destructive keys only want deletion. The deletion is done.
        // Return.
        return KeyEventResult.handled;
      }
    }

    // Delegate key processing to the component with the cursor.
    final componentWithCursor = (_editorSelection.nodeWithCursor?.key?.currentState);
    if (componentWithCursor != null) {
      print('Delegating key press');
      onParagraphKeyPressed(
        displayNode: _editorSelection.nodeWithCursor,
        keyEvent: keyEvent,
        editorSelection: _editorSelection,
        currentComponentSelection: _editorSelection.nodeWithCursor.selection,
      );
    }

    return KeyEventResult.handled;
  }

  // ------------------- START EditorParagraph onKeyPressed
  void onParagraphKeyPressed({
    @required DocDisplayNode displayNode,
    @required RawKeyEvent keyEvent,
    @required EditorSelection editorSelection,
    @required EditorComponentSelection currentComponentSelection,
  }) {
    if (keyEvent is! RawKeyDownEvent) {
      return;
    }

    final selectableText = displayNode.key.currentState as TextLayout;
    final text = displayNode.paragraph;
    final textSelection = displayNode.selection.componentSelection as TextSelection;

    if (_isCharacterKey(keyEvent.logicalKey)) {
      final newParagraph = _insertStringInString(
        index: (currentComponentSelection.componentSelection as TextSelection).extentOffset,
        existing: text,
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
      final startText = text.substring(0, cursorIndex);
      final endText = cursorIndex < text.length ? text.substring(textSelection.end) : '';
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
          text: text,
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
      if (currentSelection.extentOffset < text.length - 1) {
        final newParagraph = _removeStringSubsection(
          from: currentSelection.extentOffset,
          to: currentSelection.extentOffset + 1,
          text: text,
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
        newSelection = _moveToStartOfLine(
          selectableText: selectableText,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = _moveBackOneWord(
          text: text,
          editorSelection: editorSelection,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = _moveBackOneCharacter(
          text: text,
          editorSelection: editorSelection,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      }

      editorSelection.updateCursorComponentSelection(newSelection);
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      dynamic newSelection;
      if (keyEvent.isMetaPressed) {
        newSelection = _moveToEndOfLine(
          text: text,
          selectableText: selectableText,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = _moveForwardOneWord(
          text: text,
          editorSelection: editorSelection,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = _moveForwardOneCharacter(
          text: text,
          editorSelection: editorSelection,
          currentSelection: editorSelection.nodeWithCursor.selection,
          expandSelection: keyEvent.isShiftPressed,
        );
      }

      editorSelection.updateCursorComponentSelection(newSelection);
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveUpOneLine(
        selectableText: selectableText,
        textSelection: textSelection,
        editorSelection: editorSelection,
        currentSelection: currentComponentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveDownOneLine(
        text: text,
        selectableText: selectableText,
        textSelection: textSelection,
        editorSelection: editorSelection,
        currentSelection: currentComponentSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  }

  void _moveUpOneLine({
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    final oneLineUpPosition = selectableText.getPositionOneLineUp(
      currentPosition: TextPosition(
        offset: textSelection.extentOffset,
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
      final currentSelectionOffset = selectableText.getOffsetForPosition(
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
        baseOffset: expandSelection ? textSelection.baseOffset : oneLineUpPosition.offset,
        extentOffset: oneLineUpPosition.offset,
      ),
    );

    editorSelection.updateCursorComponentSelection(newSelection);
  }

  void _moveDownOneLine({
    @required String text,
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    final oneLineDownPosition = selectableText.getPositionOneLineDown(
      currentPosition: TextPosition(
        offset: textSelection.extentOffset,
      ),
    );

    if (oneLineDownPosition == null) {
      // The last line is selected. There is no line below that.
      if (expandSelection) {
        // Select any remaining text on this line.
        editorSelection.updateCursorComponentSelection(
          ParagraphEditorComponentSelection(
            selection: currentSelection.componentSelection.copyWith(
              extentOffset: text.length,
            ),
          ),
        );
      }

      // Move down to next component in editor.
      final currentSelectionOffset = selectableText.getOffsetForPosition(
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
            baseOffset: expandSelection ? currentSelection.componentSelection.baseOffset : text.length,
            extentOffset: text.length,
          ),
        );

        editorSelection.updateCursorComponentSelection(newSelection);
      }

      return;
    }

    final newSelection = ParagraphEditorComponentSelection(
      selection: currentSelection.componentSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : oneLineDownPosition.offset,
        extentOffset: oneLineDownPosition.offset,
      ),
    );

    editorSelection.updateCursorComponentSelection(newSelection);
  }

  ParagraphEditorComponentSelection _moveBackOneCharacter({
    @required String text,
    @required EditorSelection editorSelection,
    @required ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    if (textSelection.extentOffset > 0) {
      final newExtent = (textSelection.extentOffset - 1).clamp(0.0, text.length).toInt();
      return ParagraphEditorComponentSelection(
        selection: textSelection.copyWith(
          baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      );
    } else {
      // Selection is already at the zero position. Move up to node above.
      // Move up to the previous component in the editor.
      editorSelection.moveCursorToPreviousComponent(
        expandSelection: expandSelection,
      );
    }
  }

  ParagraphEditorComponentSelection _moveBackOneWord({
    @required String text,
    @required EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    if (textSelection.extentOffset > 0) {
      int newExtent = textSelection.extentOffset;
      if (newExtent == 0) {
        return currentSelection;
      }
      newExtent -= 1; // we always want to jump at least 1 character.

      while (newExtent > 0 && _latinCharacters.contains(text[newExtent])) {
        newExtent -= 1;
      }

      return ParagraphEditorComponentSelection(
        selection: textSelection.copyWith(
          baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      );
    } else {
      // Selection is already at the zero position. Move up to node above.
      // Move up to the previous component in the editor.
      editorSelection.moveCursorToPreviousComponent(
        expandSelection: expandSelection,
      );
    }
  }

  ParagraphEditorComponentSelection _moveToStartOfLine({
    @required TextLayout selectableText,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;
    final startOfLinePosition = selectableText.getPositionAtStartOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );

    return ParagraphEditorComponentSelection(
      selection: textSelection.copyWith(
        baseOffset: expandSelection ? textSelection.baseOffset : startOfLinePosition.offset,
        extentOffset: startOfLinePosition.offset,
      ),
    );
  }

  ParagraphEditorComponentSelection _moveForwardOneCharacter({
    @required String text,
    @required EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    if (textSelection.extentOffset < text.length) {
      final newExtent = (textSelection.extentOffset + 1).clamp(0.0, text.length).toInt();
      return ParagraphEditorComponentSelection(
        selection: textSelection.copyWith(
          baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      );
    } else {
      // Selection is already at the zero position. Move up to node above.
      // Move up to the previous component in the editor.
      editorSelection.moveCursorToNextComponent(
        expandSelection: expandSelection,
      );
    }
  }

  ParagraphEditorComponentSelection _moveForwardOneWord({
    @required String text,
    @required EditorSelection editorSelection,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;

    if (textSelection.extentOffset < text.length) {
      int newExtent = currentSelection.componentSelection.extentOffset;
      if (newExtent == text.length) {
        return currentSelection;
      }
      newExtent += 1; // we always want to jump at least 1 character.

      while (newExtent < text.length - 1 && _latinCharacters.contains(text[newExtent])) {
        newExtent += 1;
      }

      return ParagraphEditorComponentSelection(
        selection: textSelection.copyWith(
          baseOffset: expandSelection ? textSelection.baseOffset : newExtent,
          extentOffset: newExtent,
        ),
      );
    } else {
      // Selection is already at the zero position. Move down to node below.
      editorSelection.moveCursorToNextComponent(
        expandSelection: expandSelection,
      );
    }
  }

  ParagraphEditorComponentSelection _moveToEndOfLine({
    @required String text,
    @required TextLayout selectableText,
    ParagraphEditorComponentSelection currentSelection,
    bool expandSelection = false,
  }) {
    print('Moving cursor to end of line');
    if (currentSelection is! ParagraphEditorComponentSelection) {
      print(
          'Received incompatible selection. Wanted TextEditorComponentSelection but was given ${currentSelection?.runtimeType}');
      return null;
    }
    final textSelection = currentSelection.componentSelection;
    print(' - text selection: $textSelection');

    final endOfLineTextPosition = selectableText.getPositionAtEndOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );
    print(' - end of line position: $endOfLineTextPosition');
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

  static const _latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

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
  // ------------------- END EditorParagraph onKeyPressed

  void _onTapDown(TapDownDetails details) {
    print('_onTapDown');
    setState(() {
      _clearSelection();

      bool nodeTapped = false;
      for (final displayNode in _editorSelection.displayNodes) {
        final editorComponent = displayNode.key.currentState as TextLayout;
        final componentBox = displayNode.key.currentContext.findRenderObject() as RenderBox;
        if (_cursorIntersects(componentBox, details.localPosition)) {
          print('Found tapped node: $editorComponent');
          final componentOffset = _localCursorOffset(componentBox, details.localPosition);
          final selection = ParagraphEditorComponentSelection(
            selection: TextSelection.collapsed(
              offset: editorComponent.getPositionAtOffset(componentOffset).offset,
            ),
          );
          displayNode.selection = selection;

          _editorSelection.baseOffsetNode = displayNode;
          _editorSelection.extentOffsetNode = displayNode;
          _editorSelection.nodeWithCursor = displayNode;

          nodeTapped = true;
        }
      }

      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      if (!nodeTapped) {
        _rootFocusNode.requestFocus();
        _editorSelection.nodeWithCursor = null;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    setState(() {
      _clearSelection();
      _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragRect = Rect.fromPoints(_dragStart, details.localPosition);
    _updateCursorStyle(details.localPosition);
    _updateDragSelection();

    setState(() {
      // empty because the drag rect update needs to happen before
      // update selection.
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragRect = null;
    });
  }

  void _onPanCancel() {
    setState(() {
      _dragRect = null;
    });
  }

  void _clearSelection() {
    for (final displayNode in _editorSelection.displayNodes) {
      displayNode.selection = null;
    }
  }

  void _updateDragSelection() {
    DocDisplayNode firstSelectedNode;
    DocDisplayNode lastSelectedNode;

    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    final isDraggingDown = _dragStart.dy < _dragRect.bottom;

    for (final displayNode in _editorSelection.displayNodes) {
      final textLayout = displayNode.key.currentState as SelectableTextState;

      final dragIntersection = _getDragIntersectionWith(textLayout);
      if (dragIntersection != null) {
        print('Drag intersects: ${displayNode.key}');
        print('Intersection: $dragIntersection');
        final textLayout = displayNode.key.currentState as TextLayout;
        final textSelection = textLayout.getSelectionInRect(dragIntersection, isDraggingDown);
        final selection = ParagraphEditorComponentSelection(
          selection: textSelection,
        );
        // final selection = textLayout.getSelectionInRect(dragIntersection, isDraggingDown);
        print('Drag selection: ${selection.componentSelection}');
        print('');
        displayNode.selection = selection;

        if (firstSelectedNode == null) {
          firstSelectedNode = displayNode;
        }
        lastSelectedNode = displayNode;
      }
    }

    // _editorSelection.clear();
    if (firstSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.baseOffsetNode = firstSelectedNode;
      } else {
        _editorSelection.extentOffsetNode = firstSelectedNode;
      }
    }
    if (lastSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.extentOffsetNode = lastSelectedNode;
      } else {
        _editorSelection.baseOffsetNode = lastSelectedNode;
      }
    }
    print('Base node: ${_editorSelection.baseOffsetNode.key}');
    print('Base selection: ${_editorSelection.baseOffsetNode.selection.componentSelection}');
    print('Extent node: ${_editorSelection.extentOffsetNode.key}');
    print('Extent selection: ${_editorSelection.extentOffsetNode.selection.componentSelection}');

    _editorSelection.nodeWithCursor = isDraggingDown ? lastSelectedNode : firstSelectedNode;

    // TODO: is there a more appropriate place to setState()?
    setState(() {});
  }

  Rect _getDragIntersectionWith(TextLayout textLayout) {
    return textLayout.calculateLocalOverlap(
      region: _dragRect,
      ancestorCoordinateSpace: context.findRenderObject(),
    );
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  void _updateCursorStyle(Offset cursorOffset) {
    for (final displayNode in _editorSelection.displayNodes) {
      final componentBox = displayNode.key.currentContext.findRenderObject() as RenderBox;
      final textLayout = displayNode.key.currentState as TextLayout;

      if (_cursorIntersects(componentBox, cursorOffset)) {
        final localCursorOffset = _localCursorOffset(componentBox, cursorOffset);
        final isCursorOverText = textLayout.isTextAtOffset(localCursorOffset);
        final desiredCursor = isCursorOverText ? SystemMouseCursors.text : null;
        if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
          _cursorStyle.value = desiredCursor;
        } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
          _cursorStyle.value = SystemMouseCursors.basic;
        }

        // The cursor can't intersect multiple components, so
        // there is nothing more for us to do. Return.
        return;
      }
    }

    _cursorStyle.value = SystemMouseCursors.basic;
  }

  bool _cursorIntersects(RenderBox contentBox, Offset cursorOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentOffset = contentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & contentBox.size;

    return contentRect.contains(cursorOffset);
  }

  Offset _localCursorOffset(RenderBox contentBox, Offset cursorOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentOffset = contentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & contentBox.size;

    return cursorOffset - contentRect.topLeft;
  }

  @override
  Widget build(BuildContext context) {
    return _buildIgnoreKeyPresses(
      child: _buildCursorStyle(
        child: _buildKeyboardAndMouseInput(
          child: Stack(
            children: [
              _buildDocumentContainer(
                child: _buildDocument(context),
              ),
              _buildDragSelection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Wraps the `child` with a `Shortcuts` widget that ignores arrow keys,
  /// enter, backspace, and delete.
  ///
  /// This doesn't prevent the editor from responding to these keys, it just
  /// prevents Flutter from attempting to do anything with them. I put this
  /// here because I was getting recurring sounds from the Mac window as
  /// I pressed various key combinations. This hack prevents most of them.
  /// TODO: figure out the correct way to deal with this situation.
  Widget _buildIgnoreKeyPresses({
    @required Widget child,
  }) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Up arrow
        LogicalKeySet(LogicalKeyboardKey.arrowUp): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta): DoNothingIntent(),
        // Down arrow
        LogicalKeySet(LogicalKeyboardKey.arrowDown): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        // Left arrow
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        // Right arrow
        LogicalKeySet(LogicalKeyboardKey.arrowRight): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): DoNothingIntent(),
      },
      child: child,
    );
  }

  Widget _buildCursorStyle({
    Widget child,
  }) {
    return AnimatedBuilder(
      animation: _cursorStyle,
      builder: (context, child) {
        return Listener(
          onPointerHover: _onMouseMove,
          child: MouseRegion(
            cursor: _cursorStyle.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildKeyboardAndMouseInput({
    Widget child,
  }) {
    return RawKeyboardListener(
      focusNode: _rootFocusNode,
      onKey: _onKeyPressed,
      autofocus: true,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        behavior: HitTestBehavior.translucent,
        child: child,
      ),
    );
  }

  Widget _buildDocumentContainer({
    Widget child,
  }) {
    return Row(
      children: [
        Spacer(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: _buildDocument(context),
        ),
        Spacer(),
      ],
    );
  }

  Widget _buildDragSelection() {
    return Positioned.fill(
      child: CustomPaint(
        painter: DragRectanglePainter(
          selectionRect: _dragRect,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildDocument(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF312F2C),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );

    return AnimatedBuilder(
        animation: _editorSelection,
        builder: (context, child) {
          print('Building editor components:');
          for (final displayNode in _editorSelection.displayNodes) {
            print(' - ${displayNode.key}: ${displayNode.selection?.componentSelection}');
            if (displayNode == _editorSelection.nodeWithCursor) {
              print('   - ^ has cursor');
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final displayNode in _editorSelection.displayNodes) ...[
                SelectableText(
                  key: displayNode.key,
                  text: displayNode.paragraph,
                  textSelection: (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection,
                  hasCursor: displayNode == _editorSelection.nodeWithCursor,
                  style: textStyle,
                  highlightWhenEmpty: !_editorSelection.isCollapsed &&
                      (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection != null,
                  showDebugPaint: widget.showDebugPaint,
                ),
                // EditorParagraph(
                //   key: displayNode.key,
                //   text: displayNode.paragraph,
                //   textSelection: (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection,
                //   style: textStyle,
                //   hasCursor: displayNode == _editorSelection.nodeWithCursor,
                //   highlightWhenEmpty: !_editorSelection.isCollapsed &&
                //       (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection != null,
                //   showDebugPaint: widget.showDebugPaint,
                // ),
                SizedBox(height: 16),
              ],
            ],
          );
        });
  }
}

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
  });

  final Rect selectionRect;
  final Paint _selectionPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      canvas.drawRect(selectionRect, _selectionPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
