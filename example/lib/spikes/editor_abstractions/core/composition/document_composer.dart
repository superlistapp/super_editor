import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../document/rich_text_document.dart';
import '../document/document_editor.dart';
import '../layout/document_layout.dart';
import '../selection/editor_selection.dart';

// TODO: get rid of this import
import '../../default_editor/text.dart';

/// Maintains a `DocumentSelection` within a `RichTextDocument` and
/// uses that selection to edit the document.
class DocumentComposer {
  DocumentComposer({
    @required RichTextDocument document,
    @required DocumentEditor editor,
    @required DocumentLayoutState layout,
    @required List<ComposerKeyboardAction> keyboardActions,
    DocumentSelection initialSelection,
  })  : _document = document,
        _editor = editor,
        _documentLayout = layout,
        _keyboardActions = keyboardActions,
        _selection = ValueNotifier(initialSelection) {
    _selection.addListener(() {
      print('DocumentComposer: selection changed.');
      _updateComposerPreferencesAtSelection();
    });
  }

  final RichTextDocument _document;
  final DocumentEditor _editor;
  final DocumentLayoutState _documentLayout;
  final List<ComposerKeyboardAction> _keyboardActions;

  final ValueNotifier<DocumentSelection> _selection;
  // TODO: only the selection should be visible. Showing the ValueNotifier
  //       allows clients to change the value
  ValueNotifier<DocumentSelection> get selection => _selection;

  final ComposerPreferences _composerPreferences = ComposerPreferences();

  void _setSelection(DocumentSelection newSelection) {
    _selection.value = newSelection;
  }

  // TODO: this text selection logic probably belongs in some place
  //       that is specific to text content
  void _updateComposerPreferencesAtSelection() {
    _composerPreferences.clearStyles();

    if (_selection.value == null || !_selection.value.isCollapsed) {
      return;
    }

    final node = _document.getNodeById(_selection.value.extent.nodeId);
    if (node is! TextNode) {
      return;
    }

    final textPosition = _selection.value.extent.nodePosition as TextPosition;
    if (textPosition.offset == 0) {
      return;
    }

    print('Looking up styles. Caret at: ${textPosition.offset}, looking back one place at: ${textPosition.offset - 1}');
    final allStyles = (node as TextNode).text.getAllAttributionsAt(textPosition.offset - 1);
    print(' - styles: $allStyles');
    _composerPreferences.addStyles(allStyles);
  }

  void clearSelection() {
    _setSelection(null);
  }

  // TODO: have each component report a DocumentPosition with optional
  //       selectionModifiers like 'word' and 'paragraph', then
  //       run those calculations in the EditableDocument, expose only
  //       this capability in the composer.
  void selectPosition(DocumentPosition position) {
    print('Setting document selection to $position');
    _setSelection(DocumentSelection.collapsed(
      position: position,
    ));
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
      _setSelection(newSelection);
      return true;
    } else {
      return false;
    }
  }

  DocumentSelection _getWordSelection({
    @required DocumentPosition docPosition,
    @required DocumentLayoutState docLayout,
  }) {
    print('_getWordSelection()');
    print(' - doc position: $docPosition');

    final component = docLayout.getComponentByNodeId(docPosition.nodeId);
    if (component is TextComposable) {
      final TextSelection wordSelection = (component as TextComposable).getWordSelectionAt(docPosition.nodePosition);

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
    final newSelection = _getParagraphSelection(
      docPosition: docPosition,
      docLayout: docLayout,
    );

    if (newSelection != null) {
      _setSelection(newSelection);
      return true;
    } else {
      return false;
    }
  }

  DocumentSelection _getParagraphSelection({
    @required DocumentPosition docPosition,
    @required DocumentLayoutState docLayout,
  }) {
    print('_getWordSelection()');
    print(' - doc position: $docPosition');

    final component = docLayout.getComponentByNodeId(docPosition.nodeId);
    if (component is TextComposable) {
      final TextSelection wordSelection = _expandPositionToParagraph(
        text: (component as TextComposable).getContiguousTextAt(docPosition.nodePosition),
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
        docLayout: documentLayout,
      );
      basePosition = baseOffset.dy < extentOffset.dy ? baseParagraphSelection.base : baseParagraphSelection.extent;
      final extentParagraphSelection = _getParagraphSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
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

    _setSelection(DocumentSelection(
      base: basePosition ?? _selection.value.base,
      extent: extentPosition ?? _selection.value.extent,
    ));
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

    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < _keyboardActions.length) {
      instruction = _keyboardActions[index].execute(
        composerContext: ComposerContext(
          document: _document,
          editor: _editor,
          documentLayout: _documentLayout,
          currentSelection: _selection,
          composerPreferences: _composerPreferences,
        ),
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

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<String> _currentStyles = {};
  Set<String> get currentStyles => _currentStyles;

  void addStyle(String name) {
    _currentStyles.add(name);
    notifyListeners();
  }

  void addStyles(Set<String> names) {
    _currentStyles.addAll(names);
    notifyListeners();
  }

  void removeStyle(String name) {
    _currentStyles.remove(name);
    notifyListeners();
  }

  void removeStyles(Set<String> names) {
    _currentStyles.removeAll(names);
    notifyListeners();
  }

  void toggleStyle(String name) {
    if (_currentStyles.contains(name)) {
      _currentStyles.remove(name);
    } else {
      _currentStyles.add(name);
    }
    notifyListeners();
  }

  void clearStyles() {
    _currentStyles.clear();
    notifyListeners();
  }
}

/// Collection of core artifacts related to composition
/// behavior.
///
/// A `ComposerContext` is made available to each key
/// press action.
class ComposerContext {
  ComposerContext({
    @required this.document,
    @required this.editor,
    @required this.documentLayout,
    @required this.currentSelection,
    @required this.composerPreferences,
  });

  final RichTextDocument document;
  final DocumentEditor editor;
  final DocumentLayoutState documentLayout;
  final ValueNotifier<DocumentSelection> currentSelection;
  final ComposerPreferences composerPreferences;
}

class ComposerKeyboardAction {
  const ComposerKeyboardAction.simple({
    @required SimpleComposerKeyboardAction action,
  }) : _action = action;

  final SimpleComposerKeyboardAction _action;

  /// Executes this action, if the action wants to run, and returns
  /// a desired `ExecutionInstruction` to either continue or halt
  /// execution of actions.
  ///
  /// It is possible that an action makes changes and then returns
  /// `ExecutionInstruction.continueExecution` to continue execution.
  ///
  /// It is possible that an action does nothing and then returns
  /// `ExecutionInstruction.haltExecution` to prevent further execution.
  ExecutionInstruction execute({
    @required ComposerContext composerContext,
    @required RawKeyEvent keyEvent,
  }) {
    return _action(
      composerContext: composerContext,
      keyEvent: keyEvent,
    );
  }
}

/// Executes an action, if the action wants to run, and returns
/// `true` if further execution should stop, or `false` if further
/// execution should continue.
///
/// It is possible that an action makes changes and then returns
/// `false` to continue execution.
///
/// It is possible that an action does nothing and then returns
/// `true` to prevent further execution.
typedef SimpleComposerKeyboardAction = ExecutionInstruction Function({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
});

enum ExecutionInstruction {
  continueExecution,
  haltExecution,
}
