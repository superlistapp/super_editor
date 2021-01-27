import 'dart:math';

import 'package:example/spikes/editor_input_delegation/document/rich_text_document.dart';
import 'package:example/spikes/editor_input_delegation/layout/components/paragraph/selectable_text.dart';
import 'package:example/spikes/editor_input_delegation/layout/document_layout.dart';
import 'package:example/spikes/editor_input_delegation/selection/editor_selection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Maintains a `DocumentSelection` within a `RichTextDocument` and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  RichTextDocument _document;
  RichTextDocument get document => _document;
  set document(RichTextDocument newValue) {
    if (newValue != _document) {
      _document = newValue;

      _nodeSelections = _selection != null && _document != null
          ? _selection.computeNodeSelections(
              document: _document,
            )
          : [];

      notifyListeners();
    }
  }

  DocumentSelection _selection;
  DocumentSelection get selection => _selection;
  set selection(DocumentSelection newValue) {
    if (newValue != _selection) {
      _selection = newValue;

      _nodeSelections = _selection != null && _document != null
          ? _selection.computeNodeSelections(
              document: _document,
            )
          : [];

      notifyListeners();
    }
  }

  List<DocumentNodeSelection> _nodeSelections = const [];
  List<DocumentNodeSelection> get nodeSelections => List.from(_nodeSelections);

  KeyEventResult onKeyPressed({
    @required RawKeyEvent keyEvent,
    @required DocumentLayoutState documentLayout,
  }) {
    if (keyEvent is! RawKeyDownEvent) {
      return KeyEventResult.handled;
    }

    print('Key pressed');

    if (selection == null) {
      print(' - no selection. Returning.');
      return KeyEventResult.handled;
    }

    final isDirectionalKey = keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowUp ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowDown;
    print(' - is directional key? $isDirectionalKey');
    print(' - is editor selection collapsed? ${selection.isCollapsed}');
    print(' - is shift pressed? ${keyEvent.isShiftPressed}');
    if (isDirectionalKey && !selection.isCollapsed && !keyEvent.isShiftPressed && !keyEvent.isMetaPressed) {
      print('Collapsing editor selection, then returning.');
      selection = selection.collapse();
      notifyListeners();
      return KeyEventResult.handled;
    }

    // Handle delete and backspace for a selection.
    // TODO: add all characters to this condition.
    final isDestructiveKey =
        keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
    final shouldDeleteSelection = isDestructiveKey || _isCharacterKey(keyEvent.logicalKey);
    if (!selection.isCollapsed && shouldDeleteSelection) {
      selection = deleteDocumentSelection();

      if (isDestructiveKey) {
        // Destructive keys only want deletion. The deletion is done.
        // Return.
        notifyListeners();
        return KeyEventResult.handled;
      }
    }

    print('DocumentComposer: onKeyPressed()');
    final extentPosition = selection.extent;
    final extentNode = document.getNodeById(extentPosition.nodeId);
    if (extentNode is! ParagraphNode) {
      print('Cannot handle key press on unrecognized node: $extentNode');
      return KeyEventResult.ignored;
    }

    final nodeSelections = selection.computeNodeSelections(document: document);
    final extentSelection = nodeSelections.first.isExtent ? nodeSelections.first : nodeSelections.last;

    final selectableText = documentLayout.getSelectableTextByNodeId(extentPosition.nodeId);

    _onParagraphKeyPressed(
      keyEvent: keyEvent,
      documentLayout: documentLayout,
      paragraphNode: extentNode as ParagraphNode,
      nodeSelection: extentSelection,
      selectableText: selectableText,
    );

    print('Notifying listeners of composer change.');
    notifyListeners();
    return KeyEventResult.handled;
  }

  DocumentSelection deleteDocumentSelection() {
    print('DocumentComposer: deleteDocumentSelection');
    print(' - selection: $selection');

    final nodeSelections = selection.computeNodeSelections(document: document);

    if (nodeSelections.length == 1) {
      // This is a selection within a single node.
      final nodeSelection = nodeSelections.first;
      assert(nodeSelection.nodeSelection is TextSelection);
      final textSelection = nodeSelection.nodeSelection as TextSelection;
      final paragraphNode = document.getNodeById(nodeSelection.nodeId) as ParagraphNode;
      paragraphNode.paragraph = _removeStringSubsection(
        from: textSelection.start,
        to: textSelection.end,
        text: paragraphNode.paragraph,
      );

      return DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: paragraphNode.id,
          nodePosition: TextPosition(offset: textSelection.start),
        ),
      );
    }

    final range = document.getRangeBetween(selection.base, selection.extent);

    // Delete all nodes between the first node and the last node.
    final startPosition = range.start;
    final startNode = document.getNodeById(startPosition.nodeId);
    final startIndex = document.getNodeIndex(startNode);

    final endPosition = range.end;
    final endNode = document.getNodeById(endPosition.nodeId);
    final endIndex = document.getNodeIndex(endNode);

    print(' - start node index: $startIndex');
    print(' - start position: $startPosition');
    print(' - end node index: $endIndex');
    print(' - end position: $endPosition');
    print(' - initially ${document.nodes.length} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    for (int i = endIndex - 1; i > startIndex; --i) {
      print(' - deleting node $i: ${document.getNodeAt(i).id}');
      document.deleteNodeAt(i);
    }

    print(' - deleting partial selection within the starting node.');
    _deleteSelectionWithinNodeAt(
      document: document,
      docNode: startNode,
      nodeSelection: nodeSelections.first.nodeSelection,
    );

    print(' - deleting partial selection within ending node.');
    _deleteSelectionWithinNodeAt(
      document: document,
      docNode: endNode,
      nodeSelection: nodeSelections.last.nodeSelection,
    );

    final shouldTryToCombineNodes = nodeSelections.length > 1;
    if (shouldTryToCombineNodes) {
      print(' - trying to combine nodes');
      final didCombine = startNode.tryToCombineWithOtherNode(endNode);
      if (didCombine) {
        print(' - nodes were successfully combined');
        print(' - deleting end node $endIndex');
        final didRemoveLast = document.deleteNode(endNode);
        print(' - did remove ending node? $didRemoveLast');
        print(' - finally ${document.nodes.length} nodes');
      }
    }

    final newSelection = DocumentSelection.collapsed(
      position: startPosition,
    );
    print(' - returning new selection: $newSelection');

    return newSelection;
  }

  void _deleteSelectionWithinNodeAt({
    @required RichTextDocument document,
    @required DocumentNode docNode,
    @required dynamic nodeSelection,
  }) {
    // TODO: support other nodes
    if (docNode is! ParagraphNode) {
      print(' - unknown node type: $docNode');
      return;
    }

    final index = document.getNodeIndex(docNode);
    assert(index >= 0 && index < document.nodes.length);

    print('Deleting selection within node $index');
    final paragraphNode = docNode as ParagraphNode;
    if (nodeSelection is TextSelection) {
      print(' - deleting TextSelection within ParagraphNode');
      final from = min(nodeSelection.baseOffset, nodeSelection.extentOffset);
      final to = max(nodeSelection.baseOffset, nodeSelection.extentOffset);
      print(' - from: $from, to: $to, text: ${paragraphNode.paragraph}');

      paragraphNode.paragraph = _removeStringSubsection(
        from: from,
        to: to,
        text: paragraphNode.paragraph,
      );
      print(' - remaining text: ${paragraphNode.paragraph}');
    } else {
      print('ParagraphNode cannot delete unknown selection type: $nodeSelection');
    }
  }

  // ------------------- START EditorParagraph onKeyPressed
  void _onParagraphKeyPressed({
    @required RawKeyEvent keyEvent,
    @required DocumentLayoutState documentLayout,
    @required ParagraphNode paragraphNode,
    @required DocumentNodeSelection nodeSelection,
    @required SelectableTextState selectableText,
  }) {
    if (keyEvent is! RawKeyDownEvent) {
      return;
    }

    final textSelection = nodeSelection.nodeSelection as TextSelection;
    assert(textSelection is TextSelection);
    final text = paragraphNode.paragraph;

    if (_isCharacterKey(keyEvent.logicalKey)) {
      print(' - handling a character key');
      final newParagraph = _insertStringInString(
        index: textSelection.extentOffset,
        existing: text,
        addition: keyEvent.character,
      );

      // Add the character to the paragraph.
      paragraphNode.paragraph = newParagraph;

      // Update the selection to place the caret after the new character.
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeSelection.nodeId,
          nodePosition: TextPosition(
            offset: textSelection.extentOffset + 1,
          ),
        ),
      );

      // editorSelection.updateCursorComponentSelection(
      //   ParagraphEditorComponentSelection(
      //     selection: TextSelection(
      //       baseOffset: currentSelection.extentOffset + 1,
      //       extentOffset: currentSelection.extentOffset + 1,
      //     ),
      //   ),
      // );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
      print(' - handling enter key');
      final cursorIndex = textSelection.start;
      final startText = text.substring(0, cursorIndex);
      final endText = cursorIndex < text.length ? text.substring(textSelection.end) : '';
      print('Splitting paragraph:');
      print(' - start text: "$startText"');
      print(' - end text: "$endText"');

      paragraphNode.paragraph = startText;
      final newNode = ParagraphNode(
        id: RichTextDocument.createNodeId(),
        paragraph: endText,
      );
      document.insertNodeAfter(
        previousNode: paragraphNode,
        newNode: newNode,
      );

      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newNode.id,
          nodePosition: TextPosition(offset: 0),
        ),
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      print(' - handling backspace key');
      if (textSelection.extentOffset > 0) {
        final newParagraph = _removeStringSubsection(
          from: textSelection.extentOffset - 1,
          to: textSelection.extentOffset,
          text: text,
        );

        paragraphNode.paragraph = newParagraph;

        // Update the selection to place the caret before the deleted character.
        selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeSelection.nodeId,
            nodePosition: TextPosition(
              offset: textSelection.extentOffset - 1,
            ),
          ),
        );

        // editorSelection.updateCursorComponentSelection(
        //   ParagraphEditorComponentSelection(
        //     selection: TextSelection(
        //       baseOffset: currentSelection.extentOffset - 1,
        //       extentOffset: currentSelection.extentOffset - 1,
        //     ),
        //   ),
        // );
      } else {
        print('Combining node with previous.');

        final nodeAbove = document.getNodeBefore(paragraphNode);
        if (nodeAbove != null) {
          if (nodeAbove is ParagraphNode) {
            final aboveParagraphLength = nodeAbove.paragraph.length;

            // Combine the text and delete the currently selected node.
            nodeAbove.paragraph += paragraphNode.paragraph;
            bool didRemove = document.deleteNode(paragraphNode);
            if (!didRemove) {
              print('ERROR: Failed to delete the currently selected node from the document.');
            }

            // Place the cursor at the point where the text came together.
            selection = DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: nodeAbove.id,
                nodePosition: TextPosition(offset: aboveParagraphLength),
              ),
            );
          } else {
            print(' - unknown node type above: $nodeAbove');
          }
        } else {
          print(' - you are at the top of the doc. Cannot backspace.');
        }
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.delete) {
      print(' - handling delete key');
      if (textSelection.extentOffset < text.length - 1) {
        final newParagraph = _removeStringSubsection(
          from: textSelection.extentOffset,
          to: textSelection.extentOffset + 1,
          text: text,
        );

        paragraphNode.paragraph = newParagraph;
        // Note: no change to selection is required because deleting
        //       a character does not move the caret.
      } else {
        print('Combining node with next.');
        final nodeBelow = document.getNodeAfter(paragraphNode);
        if (nodeBelow != null) {
          if (nodeBelow is ParagraphNode) {
            final currentParagraphLength = paragraphNode.paragraph.length;

            // Combine the text and delete the currently selected node.
            paragraphNode.paragraph += nodeBelow.paragraph;
            final didRemove = document.deleteNode(nodeBelow);
            if (!didRemove) {
              print('ERROR: failed to remove next node from document.');
            }

            // Place the cursor at the point where the text came together.
            selection = DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: TextPosition(offset: currentParagraphLength),
              ),
            );
          } else {
            print(' - unknown node type above: $nodeBelow');
          }
        } else {
          print(' - you are at the bottom of the doc. Cannot backspace.');
        }
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
      print(' - handling left arrow key');
      if (keyEvent.isMetaPressed) {
        _moveToStartOfLine(
          selectedNode: paragraphNode,
          selectableText: selectableText,
          textSelection: textSelection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        _moveBackOneWord(
          documentLayout: documentLayout,
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        _moveBackOneCharacter(
          documentLayout: documentLayout,
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
      print(' - handling right arrow key');
      if (keyEvent.isMetaPressed) {
        _moveToEndOfLine(
          selectedNode: paragraphNode,
          selectableText: selectableText,
          textSelection: textSelection,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else if (keyEvent.isAltPressed) {
        _moveForwardOneWord(
          documentLayout: documentLayout,
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      } else {
        _moveForwardOneCharacter(
          documentLayout: documentLayout,
          text: text,
          expandSelection: keyEvent.isShiftPressed,
        );
      }
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
      print(' - handling up arrow key');
      _moveUpOneLine(
        documentLayout: documentLayout,
        selectedNode: paragraphNode,
        selectableText: selectableText,
        textSelection: textSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
      print(' - handling down arrow key');
      _moveDownOneLine(
        documentLayout: documentLayout,
        selectedNode: paragraphNode,
        selectableText: selectableText,
        textSelection: textSelection,
        expandSelection: keyEvent.isShiftPressed,
      );
    }
  }

  void _moveUpOneLine({
    @required DocumentLayoutState documentLayout,
    @required DocumentNode selectedNode,
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    bool expandSelection = false,
  }) {
    DocumentNode oneLineUpNode = selectedNode;

    // Determine the TextPosition one line up.
    TextPosition oneLineUpPosition = selectableText.getPositionOneLineUp(
      currentPosition: TextPosition(
        offset: textSelection.extentOffset,
      ),
    );
    if (oneLineUpPosition == null) {
      // The first line is selected. Move up to the component above.
      final nodeAbove = document.getNodeBefore(selectedNode) as ParagraphNode;

      if (nodeAbove != null) {
        final offsetToMatch = selectableText.getOffsetForPosition(
          TextPosition(
            offset: textSelection.extentOffset,
          ),
        );

        if (offsetToMatch == null) {
          // TODO: this situation doesn't look like it's possible. It was copied
          //       from different logic. See if we still need it. Maybe the
          //       situation where you get to the beginning of a paragraph and
          //       press left.
          // No (x,y) offset was provided. Place the selection at the
          // end of the node.
          oneLineUpPosition = TextPosition(offset: nodeAbove.paragraph.length);
        } else {
          // An (x,y) offset was provided. Place the selection as close
          // to the given x-value as possible within the node.
          final selectableText = documentLayout.getSelectableTextByNodeId(nodeAbove.id);
          oneLineUpPosition = selectableText.getPositionInLastLineAtX(offsetToMatch.dx);
        }
        oneLineUpNode = nodeAbove;
      } else {
        // We're at the top of the document. Move the cursor to the beginning
        // of the paragraph.
        oneLineUpPosition = TextPosition(offset: 0);
      }
    }

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: oneLineUpNode.id,
          nodePosition: oneLineUpPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: oneLineUpNode.id,
          nodePosition: oneLineUpPosition,
        ),
      );
    }
  }

  // previousCursorOffset: if non-null, the cursor is positioned in
  //      the previous component at the same horizontal location. If
  //      null then cursor is placed at end of previous component.
  void moveCursorToPreviousComponent({
    @required DocumentLayoutState documentLayout,
    @required DocumentNode moveFromNode,
    @required bool expandSelection,
    Offset previousCursorOffset,
  }) {
    print('Moving to previous node');
    print(' - move from node: $moveFromNode');
    final nodeAbove = document.getNodeBefore(moveFromNode) as ParagraphNode;
    if (nodeAbove == null) {
      print(' - at top of document. Can\'t move up to node above.');
    }
    print(' - node above: ${nodeAbove.id}');

    // final existingSelectionForNodeAbove = _getNodeSelectionByNodeId(nodeAbove.id).nodeSelection;
    // assert(existingSelectionForNodeAbove is TextSelection);
    // print(' - existing selection for node above: $existingSelectionForNodeAbove');

    if (nodeAbove == null) {
      return;
    }

    TextPosition newTextPosition;
    if (previousCursorOffset == null) {
      // No (x,y) offset was provided. Place the selection at the
      // end of the node.
      newTextPosition = TextPosition(offset: nodeAbove.paragraph.length);
      // nodeAboveSelection = moveSelectionToEnd(
      //   text: nodeAbove.paragraph,
      //   previousSelection: existingSelectionForNodeAbove,
      //   expandSelection: expandSelection,
      // );
    } else {
      // An (x,y) offset was provided. Place the selection as close
      // to the given x-value as possible within the node.
      final selectableText = documentLayout.getSelectableTextByNodeId(nodeAbove.id);

      newTextPosition = selectableText.getPositionInLastLineAtX(previousCursorOffset.dx);
      // nodeAboveSelection = moveSelectionFromEndToOffset(
      //   selectableText: selectableText,
      //   text: nodeAbove.paragraph,
      //   currentSelection: existingSelectionForNodeAbove,
      //   expandSelection: expandSelection,
      //   localOffset: previousCursorOffset,
      // );
    }

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: nodeAbove.id,
          nodePosition: newTextPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeAbove.id,
          nodePosition: newTextPosition,
        ),
      );
    }

    // final isCurrentNodeTheExtent = nodeWithCursor == extentOffsetNode;
    // final isSelectionGoingDownward = displayNodes.indexOf(baseOffsetNode) < displayNodes.indexOf(extentOffsetNode);
    //
    // previousNode.selection = nodeAboveSelection;
    //
    // extentOffsetNode = previousNode;
    // if (!expandSelection) {
    //   baseOffsetNode = extentOffsetNode;
    //   nodeWithCursor.selection = null;
    // } else if (isCurrentNodeTheExtent && isSelectionGoingDownward) {
    //   nodeWithCursor.selection = null;
    // }
    // return true;
  }

  DocumentNodeSelection _getNodeSelectionByNodeId(String nodeId) {
    return _nodeSelections.firstWhere(
      (element) => element.nodeId == nodeId,
      orElse: () => null,
    );
  }

  TextSelection moveSelectionToEnd({
    @required String text,
    TextSelection previousSelection,
    bool expandSelection = false,
  }) {
    if (previousSelection != null && expandSelection) {
      return TextSelection(
        baseOffset: expandSelection ? previousSelection.baseOffset : text.length,
        extentOffset: text.length,
      );
    } else {
      return TextSelection.collapsed(
        offset: text.length,
      );
    }
  }

  TextSelection moveSelectionFromEndToOffset({
    @required TextLayout selectableText,
    @required String text,
    TextSelection currentSelection,
    @required bool expandSelection,
    @required Offset localOffset,
  }) {
    final extentOffset = selectableText.getPositionInLastLineAtX(localOffset.dx).offset;

    if (currentSelection != null) {
      return TextSelection(
        baseOffset: expandSelection ? currentSelection.baseOffset : extentOffset,
        extentOffset: extentOffset,
      );
    } else {
      return TextSelection(
        baseOffset: expandSelection ? text.length : extentOffset,
        extentOffset: extentOffset,
      );
    }
  }

  void _moveDownOneLine({
    @required DocumentLayoutState documentLayout,
    @required ParagraphNode selectedNode,
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    bool expandSelection = false,
  }) {
    DocumentNode oneLineDownNode = selectedNode;

    // Determine the TextPosition one line up.
    TextPosition oneLineDownPosition = selectableText.getPositionOneLineDown(
      currentPosition: TextPosition(
        offset: textSelection.extentOffset,
      ),
    );
    if (oneLineDownPosition == null) {
      // The last line is selected. Move down to the component below.
      final nodeBelow = document.getNodeAfter(selectedNode) as ParagraphNode;

      if (nodeBelow != null) {
        final offsetToMatch = selectableText.getOffsetForPosition(
          TextPosition(
            offset: textSelection.extentOffset,
          ),
        );

        if (offsetToMatch == null) {
          // TODO: this situation doesn't look like it's possible. It was copied
          //       from different logic. See if we still need it. Maybe the
          //       situation where you get to the end of a paragraph and
          //       press right.
          // No (x,y) offset was provided. Place the selection at the
          // beginning of the node.
          oneLineDownPosition = TextPosition(offset: 0);
        } else {
          // An (x,y) offset was provided. Place the selection as close
          // to the given x-value as possible within the node.
          final selectableText = documentLayout.getSelectableTextByNodeId(nodeBelow.id);
          oneLineDownPosition = selectableText.getPositionInFirstLineAtX(offsetToMatch.dx);
        }
        oneLineDownNode = nodeBelow;
      } else {
        // We're at the bottom of the document. Move the cursor to the end
        // of the paragraph.
        oneLineDownPosition = TextPosition(offset: selectedNode.paragraph.length);
      }
    }

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: oneLineDownNode.id,
          nodePosition: oneLineDownPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: oneLineDownNode.id,
          nodePosition: oneLineDownPosition,
        ),
      );
    }
  }

  void _moveBackOneCharacter({
    @required DocumentLayoutState documentLayout,
    @required String text,
    bool expandSelection = false,
  }) {
    final extentDocPosition = selection.extent;
    final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
    assert(extentTextPosition is TextPosition);

    if (extentTextPosition.offset > 0) {
      final newPosition = TextPosition(offset: extentTextPosition.offset - 1);

      if (expandSelection) {
        selection = DocumentSelection(
          base: selection.base,
          extent: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      } else {
        selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      }
    } else {
      print(' - at start of paragraph. Trying to move to end of paragraph above.');
      final moveFromNode = document.getNodeById(selection.extent.nodeId);
      moveCursorToPreviousComponent(
        documentLayout: documentLayout,
        moveFromNode: moveFromNode,
        expandSelection: expandSelection,
      );
    }
  }

  void _moveBackOneWord({
    @required DocumentLayoutState documentLayout,
    @required String text,
    bool expandSelection = false,
  }) {
    final extentDocPosition = selection.extent;
    final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
    assert(extentTextPosition is TextPosition);

    if (extentTextPosition.offset > 0) {
      int newOffset = extentTextPosition.offset;
      newOffset -= 1; // we always want to jump at least 1 character.
      while (newOffset > 0 && _latinCharacters.contains(text[newOffset])) {
        newOffset -= 1;
      }
      final newPosition = TextPosition(offset: newOffset);

      if (expandSelection) {
        selection = DocumentSelection(
          base: selection.base,
          extent: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      } else {
        selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      }
    } else {
      final moveFromNode = document.getNodeById(selection.extent.nodeId);
      moveCursorToPreviousComponent(
        documentLayout: documentLayout,
        moveFromNode: moveFromNode,
        expandSelection: expandSelection,
      );
    }
  }

  void _moveToStartOfLine({
    @required DocumentNode selectedNode,
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    bool expandSelection = false,
  }) {
    final newPosition = selectableText.getPositionAtStartOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: newPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: newPosition,
        ),
      );
    }
  }

  void _moveForwardOneCharacter({
    @required DocumentLayoutState documentLayout,
    @required String text,
    bool expandSelection = false,
  }) {
    final extentDocPosition = selection.extent;
    final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
    assert(extentTextPosition is TextPosition);

    if (extentTextPosition.offset < text.length) {
      final newPosition = TextPosition(offset: extentTextPosition.offset + 1);

      if (expandSelection) {
        selection = DocumentSelection(
          base: selection.base,
          extent: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      } else {
        selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      }
    } else {
      final moveFromNode = document.getNodeById(selection.extent.nodeId);
      moveCursorToNextComponent(
        documentLayout: documentLayout,
        moveFromNode: moveFromNode,
        expandSelection: expandSelection,
      );
    }
  }

  // previousCursorOffset: if non-null, the cursor is positioned in
  //      the next component at the same horizontal location. If
  //      null then cursor is placed at beginning of next component.
  void moveCursorToNextComponent({
    @required DocumentLayoutState documentLayout,
    @required DocumentNode moveFromNode,
    @required bool expandSelection,
    Offset previousCursorOffset,
  }) {
    print('Moving to next node');
    final nodeBelow = document.getNodeAfter(moveFromNode) as ParagraphNode;
    print(' - node above: $nodeBelow');

    // final existingSelectionForNodeBelow = _getNodeSelectionByNodeId(nodeBelow.id).nodeSelection;
    // assert(existingSelectionForNodeBelow is TextSelection);
    // print(' - existing selection for node above: $existingSelectionForNodeBelow');

    if (nodeBelow == null) {
      return;
    }

    TextPosition newTextPosition;
    if (previousCursorOffset == null) {
      // No (x,y) offset was provided. Place the selection at the
      // beginning of the node.
      newTextPosition = TextPosition(offset: 0);
    } else {
      // An (x,y) offset was provided. Place the selection as close
      // to the given x-value as possible within the node.
      final selectableText = documentLayout.getSelectableTextByNodeId(nodeBelow.id);

      newTextPosition = selectableText.getPositionInFirstLineAtX(previousCursorOffset.dx);
    }

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: nodeBelow.id,
          nodePosition: newTextPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeBelow.id,
          nodePosition: newTextPosition,
        ),
      );
    }
  }

  // TODO: collapse this implementation with the "back" version.
  void _moveForwardOneWord({
    @required DocumentLayoutState documentLayout,
    @required String text,
    bool expandSelection = false,
  }) {
    final extentDocPosition = selection.extent;
    final extentTextPosition = extentDocPosition.nodePosition as TextPosition;
    assert(extentTextPosition is TextPosition);

    if (extentTextPosition.offset < text.length) {
      int newOffset = extentTextPosition.offset;
      newOffset += 1; // we always want to jump at least 1 character.
      while (newOffset < text.length && _latinCharacters.contains(text[newOffset])) {
        newOffset += 1;
      }
      final newPosition = TextPosition(offset: newOffset);

      if (expandSelection) {
        selection = DocumentSelection(
          base: selection.base,
          extent: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      } else {
        selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: extentDocPosition.nodeId,
            nodePosition: newPosition,
          ),
        );
      }
    } else {
      final moveFromNode = document.getNodeById(selection.extent.nodeId);
      moveCursorToNextComponent(
        documentLayout: documentLayout,
        moveFromNode: moveFromNode,
        expandSelection: expandSelection,
      );
    }
  }

  void _moveToEndOfLine({
    @required ParagraphNode selectedNode,
    @required TextLayout selectableText,
    @required TextSelection textSelection,
    bool expandSelection = false,
  }) {
    TextPosition newPosition = selectableText.getPositionAtEndOfLine(
      currentPosition: TextPosition(offset: textSelection.extentOffset),
    );
    final isAutoWrapLine = newPosition.offset < selectedNode.paragraph.length &&
        (selectedNode.paragraph.isNotEmpty && selectedNode.paragraph[newPosition.offset] != '\n');

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
    newPosition = isAutoWrapLine ? TextPosition(offset: newPosition.offset - 1) : newPosition;

    if (expandSelection) {
      selection = DocumentSelection(
        base: selection.base,
        extent: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: newPosition,
        ),
      );
    } else {
      selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: newPosition,
        ),
      );
    }
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
    @required int from,
    @required int to,
    @required String text,
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
}
