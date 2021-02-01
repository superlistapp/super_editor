import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'document_composer_actions.dart';
import '../document/rich_text_document.dart';
import '../document/document_editor.dart';
import '../layout/document_layout.dart';
import '../selection/editor_selection.dart';

// TODO: should nodes be in core?
import '../document/document_nodes.dart';

/// Maintains a `DocumentSelection` within a `RichTextDocument` and
/// uses that selection to edit the document.
class DocumentComposer {
  DocumentComposer({
    @required RichTextDocument document,
    @required DocumentEditor editor,
    @required DocumentLayoutState layout,
    DocumentSelection selection,
  })  : _document = document,
        _editor = editor,
        _documentLayout = layout,
        _selection = ValueNotifier(selection) {
    _selection.addListener(() {
      print('DocumentComposer: selection changed.');
    });
  }

  final RichTextDocument _document;
  final DocumentEditor _editor;
  final DocumentLayoutState _documentLayout;

  final ValueNotifier<DocumentSelection> _selection;
  ValueNotifier<DocumentSelection> get selection => _selection;

  List<DocumentNodeSelection> _nodeSelections = const [];
  List<DocumentNodeSelection> get nodeSelections => List.from(_nodeSelections);

  void clearSelection() {
    _selection.value = null;
  }

  void selectPosition(DocumentPosition position) {
    print('Setting document selection to $position');
    _selection.value = DocumentSelection.collapsed(
      position: position,
    );
  }

  bool selectWordAt({
    @required DocumentPosition docPosition,
    @required DocumentLayoutState docLayout,
  }) {
    final newSelection = _getWordSelection(
      docPosition: docPosition,
      docLayout: docLayout,
    );
    if (newSelection != null) {
      _selection.value = newSelection;
      return true;
    } else {
      return false;
    }
  }

  DocumentSelection _getWordSelection({
    @required DocumentPosition docPosition,
    @required DocumentLayoutState docLayout,
  }) {
    print(' - doc position: $docPosition');
    final docNode = _document.getNodeById(docPosition.nodeId);
    print(' - doc node: ${docNode?.id}');
    if (docNode is TextNode) {
      final textComponent = docLayout.getSelectableTextByNodeId(docNode.id);
      final TextSelection wordSelection = textComponent.getWordSelectionAt(docPosition.nodePosition);

      print(' - word selection: $wordSelection');
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: docPosition.nodeId,
          nodePosition: wordSelection.base,
        ),
        extent: DocumentPosition(
          nodeId: docPosition.nodeId,
          nodePosition: wordSelection.extent,
        ),
      );
    } else {
      return null;
    }
  }

  bool selectParagraphAt({
    @required DocumentPosition docPosition,
    @required DocumentLayoutState docLayout,
  }) {
    final newSelection = _getParagraphSelection(docPosition: docPosition);
    if (newSelection != null) {
      _selection.value = newSelection;
      return true;
    } else {
      return false;
    }
  }

  DocumentSelection _getParagraphSelection({
    @required DocumentPosition docPosition,
  }) {
    final docNode = _document.getNodeById(docPosition.nodeId);
    if (docNode is TextNode) {
      // final textComponent = docLayout.getSelectableTextByNodeId(docNode.id);
      final TextSelection wordSelection = _expandPositionToParagraph(
        text: docNode.text,
        textPosition: docPosition.nodePosition as TextPosition,
      );

      return DocumentSelection(
        base: DocumentPosition(
          nodeId: docPosition.nodeId,
          nodePosition: wordSelection.base,
        ),
        extent: DocumentPosition(
          nodeId: docPosition.nodeId,
          nodePosition: wordSelection.extent,
        ),
      );
    } else {
      return null;
    }
  }

  void selectRegion({
    @required DocumentLayoutState documentLayout,
    @required Offset baseOffset,
    @required Offset extentOffset,
    @required SelectionType selectionType,
  }) {
    print('Composer: selectionRegion(). Mode: $selectionType');
    DocumentPosition basePosition = documentLayout.getDocumentPositionNearestToOffset(baseOffset);
    DocumentPosition extentPosition = documentLayout.getDocumentPositionNearestToOffset(extentOffset);

    if (selectionType == SelectionType.paragraph) {
      final baseParagraphSelection = _getParagraphSelection(
        docPosition: basePosition,
      );
      basePosition = baseOffset.dy < extentOffset.dy ? baseParagraphSelection.base : baseParagraphSelection.extent;
      final extentParagraphSelection = _getParagraphSelection(
        docPosition: extentPosition,
      );
      extentPosition =
          baseOffset.dy < extentOffset.dy ? extentParagraphSelection.extent : extentParagraphSelection.base;
    } else if (selectionType == SelectionType.word) {
      print(' - selecting a word');
      final baseWordSelection = _getWordSelection(
        docPosition: basePosition,
        docLayout: documentLayout,
      );
      basePosition = baseWordSelection.base;

      final extentWordSelection = _getWordSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
      );
      extentPosition = extentWordSelection.extent;
    }

    _selection.value = DocumentSelection(
      base: basePosition ?? _selection.value.base,
      extent: extentPosition ?? _selection.value.extent,
    );
    print('Region selection: $_selection');
  }

  TextSelection _expandPositionToParagraph({
    @required String text,
    @required TextPosition textPosition,
  }) {
    int start = textPosition.offset;
    int end = textPosition.offset;
    while (start > 0 && text[start] != '\n') {
      start -= 1;
    }
    while (end < text.length && text[end] != '\n') {
      end += 1;
    }
    return TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
  }

  KeyEventResult onKeyPressed({
    @required RawKeyEvent keyEvent,
  }) {
    if (keyEvent is! RawKeyDownEvent) {
      return KeyEventResult.handled;
    }

    print('Key pressed');

    // TODO: this is here as a quick fix to ensure we have node selections
    //       for key handlers. Figure out the best place to recompute
    //       node selections.
    if (_selection.value != null) {
      _nodeSelections = _selection.value.computeNodeSelections(document: _document);
    }

    // TODO: move this outside this method.
    final _composerKeyActions = <ComposerKeyboardAction>[
      ComposerKeyboardAction.simple(
        action: preventDeletionOfFirstParagraph,
      ),
      ComposerKeyboardAction.simple(
        action: doNothingWhenThereIsNoSelection,
      ),
      ComposerKeyboardAction.simple(
        action: collapseSelectionWhenDirectionalKeyIsPressed,
      ),
      ComposerKeyboardAction.simple(
        action: deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed,
      ),
      ComposerKeyboardAction.simple(
        action: insertCharacterInParagraph,
      ),
      ComposerKeyboardAction.simple(
        action: insertNewlineInParagraph,
      ),
      ComposerKeyboardAction.simple(
        action: splitParagraphWhenEnterPressed,
      ),
      ComposerKeyboardAction.simple(
        action: deleteCharacterWhenBackspaceIsPressed,
      ),
      ComposerKeyboardAction.simple(
        action: mergeNodeWithPreviousWhenBackspaceIsPressed,
      ),
      ComposerKeyboardAction.simple(
        action: deleteCharacterWhenDeleteIsPressed,
      ),
      ComposerKeyboardAction.simple(
        action: mergeNodeWithNextWhenBackspaceIsPressed,
      ),
      ComposerKeyboardAction.simple(
        action: moveUpDownLeftAndRightWithArrowKeys,
      ),
    ];

    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < _composerKeyActions.length) {
      instruction = _composerKeyActions[index].execute(
        document: _document,
        editor: _editor,
        documentLayout: _documentLayout,
        currentSelection: _selection,
        nodeSelections: nodeSelections,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    return instruction == ExecutionInstruction.haltExecution ? KeyEventResult.handled : KeyEventResult.ignored;
  }
}

enum SelectionType {
  position,
  word,
  paragraph,
}
