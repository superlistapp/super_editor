import 'package:example/spikes/editor_input_delegation/document/rich_text_document.dart';
import 'package:example/spikes/editor_input_delegation/layout/document_layout.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'layout/components/paragraph/editor_paragraph_component.dart';
import 'layout/components/paragraph/selectable_text.dart';
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
  final _docLayoutKey = GlobalKey<DocumentLayoutState>();
  RichTextDocument _document;
  ValueNotifier<List<DocumentNodeSelection>> _documentSelection = ValueNotifier([]);

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
    )..addListener(() {
        _documentSelection.value = _buildDocumentSelection(_document);
        print('Updating document selection: $_documentSelection');
      });
    _document = RichTextDocument.fromOldImplementation(_editorSelection);
    _documentSelection.value = _buildDocumentSelection(_document);
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
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = _moveBackOneWord(
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = _moveBackOneCharacter(
          text: text,
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
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        newSelection = _moveForwardOneWord(
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        newSelection = _moveForwardOneCharacter(
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      }

      editorSelection.updateCursorComponentSelection(newSelection);
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveUpOneLine(
        selectableText: selectableText,
        textSelection: textSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveDownOneLine(
        text: text,
        selectableText: selectableText,
        textSelection: textSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  }

  void _moveUpOneLine({
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection as ParagraphEditorComponentSelection;
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
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection as ParagraphEditorComponentSelection;
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
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    bool expandSelection = false,
  }) {
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    bool expandSelection = false,
  }) {
    final editorSelection = _editorSelection;
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    bool expandSelection = false,
  }) {
    print('Moving cursor to end of line');
    final currentSelection = _editorSelection.nodeWithCursor.selection;
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
    _clearSelection();

    final docBox = _docLayoutKey.currentContext.findRenderObject() as RenderBox;
    final docOffset = docBox.globalToLocal(
      details.localPosition,
      ancestor: context.findRenderObject(),
    );
    final docPosition = _docLayoutKey.currentState.getDocumentPositionAtOffset(docOffset);
    print('Tapped doc position: $docPosition');

    if (docPosition != null) {
      final tappedNode =
          _editorSelection.displayNodes.firstWhere((element) => element.key.toString() == docPosition.nodeId);
      print('Tapped display node: $tappedNode');

      final backwardsCompatibleSelection = ParagraphEditorComponentSelection(
        selection: TextSelection.collapsed(
          offset: (docPosition.nodePosition as TextPosition).offset,
        ),
      );
      tappedNode.selection = backwardsCompatibleSelection;

      _editorSelection.baseOffsetNode = tappedNode;
      _editorSelection.extentOffsetNode = tappedNode;
      _editorSelection.nodeWithCursor = tappedNode;
      print('Done with tap');
    } else {
      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      _rootFocusNode.requestFocus();
      _editorSelection.nodeWithCursor = null;
    }
    _editorSelection.notifyListeners();
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;

    _clearSelection();
    _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragRect = Rect.fromPoints(_dragStart, details.localPosition);
    _updateCursorStyle(details.localPosition);
    _updateDragSelection();
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
    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    final isDraggingDown = _dragStart.dy < _dragRect.bottom;

    final docBox = _docLayoutKey.currentContext.findRenderObject() as RenderBox;
    final docStartDrag = docBox.globalToLocal(_dragStart, ancestor: context.findRenderObject());
    final docEndDrag = docBox.globalToLocal(isDraggingDown ? _dragRect.bottomRight : _dragRect.topLeft,
        ancestor: context.findRenderObject());
    final docSelection = _docLayoutKey.currentState.getDocumentSelectionInRegion(docStartDrag, docEndDrag);
    print('Drag doc selection: $docSelection');
    final List<DocumentNodeSelection> selectedNodes = docSelection.computeNodeSelections(document: _document);
    print('Selected nodes: $selectedNodes');
    for (final selectedDocNode in selectedNodes) {
      final selectedDisplayNode =
          _editorSelection.displayNodes.firstWhere((element) => element.key.toString() == selectedDocNode.nodeId);
      print(' - found corresponding display node: $selectedDisplayNode');
      selectedDisplayNode.selection = ParagraphEditorComponentSelection(
        selection: selectedDocNode.nodeSelection,
      );

      if (selectedDocNode.isBase) {
        _editorSelection.baseOffsetNode = selectedDisplayNode;
      }
      if (selectedDocNode.isExtent) {
        _editorSelection.extentOffsetNode = selectedDisplayNode;
      }
    }

    print('Base node: ${_editorSelection.baseOffsetNode.key}');
    print('Base selection: ${_editorSelection.baseOffsetNode.selection.componentSelection}');
    print('Extent node: ${_editorSelection.extentOffsetNode.key}');
    print('Extent selection: ${_editorSelection.extentOffsetNode.selection.componentSelection}');

    _editorSelection.nodeWithCursor = _editorSelection.extentOffsetNode;
    _editorSelection.notifyListeners();
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  void _updateCursorStyle(Offset cursorOffset) {
    final docBox = _docLayoutKey.currentContext.findRenderObject() as RenderBox;
    final docOffset = docBox.globalToLocal(cursorOffset, ancestor: context.findRenderObject());
    final desiredCursor = _docLayoutKey.currentState.getDesiredCursorAtOffset(docOffset);

    if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
      _cursorStyle.value = desiredCursor;
    } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildIgnoreKeyPresses(
      child: _buildCursorStyle(
        child: _buildKeyboardAndMouseInput(
          child: Stack(
            children: [
              _buildDocumentContainer(
                child: AnimatedBuilder(
                    animation: _documentSelection,
                    builder: (context, child) {
                      print('Document selection: $_documentSelection');

                      return DocumentLayout(
                        key: _docLayoutKey,
                        document: _document,
                        documentSelection: _documentSelection.value, //_buildDocumentSelection(_document),
                        showDebugPaint: widget.showDebugPaint,
                      );
                    }),
              ),
              _buildDragSelection(),
            ],
          ),
        ),
      ),
    );
  }

  List<DocumentNodeSelection> _buildDocumentSelection(
    RichTextDocument document,
  ) {
    if (_editorSelection.baseOffsetNode == null || _editorSelection.baseOffsetNode.selection == null) {
      print('No selection to build');
      return const [];
    }

    print('Editor base selection: ${_editorSelection.baseOffsetNode?.selection}');
    print('Editor extent selection: ${_editorSelection.extentOffsetNode?.selection}');

    final base = DocumentPosition(
      nodeId: _editorSelection.baseOffsetNode.key.toString(),
      nodePosition: (_editorSelection.baseOffsetNode.selection.componentSelection as TextSelection).base,
    );
    print('Base doc position: $base');
    final extent = DocumentPosition(
      nodeId: _editorSelection.extentOffsetNode.key.toString(),
      nodePosition: (_editorSelection.extentOffsetNode.selection.componentSelection as TextSelection).extent,
    );
    print('Extent doc position: $extent');

    final docSelection = DocumentSelection(
      base: base,
      extent: extent,
    );

    final selectedNodes = docSelection.computeNodeSelections(
      document: document,
    );
    print('Selected Nodes:');
    for (final node in selectedNodes) {
      print(' - $node');
    }

    return selectedNodes;
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
          child: child,
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
