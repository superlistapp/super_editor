import 'dart:math';

import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Collection of generic text inspection behavior that does not belong
/// to any particular `DocumentNode` or `Component`.

final _log = Logger(scope: 'text_tools.dart');

/// Returns the word of text that contains the given `docPosition`, or `null` if
/// no text exists at the given `docPosition`.
///
/// A word is defined by `TextComposable#getWordSelectionAt()`.
DocumentSelection? getWordSelection({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
}) {
  _log.log('getWordSelection', '_getWordSelection()');
  _log.log('getWordSelection', ' - doc position: $docPosition');

  final component = docLayout.getComponentByNodeId(docPosition.nodeId);
  if (component is! TextComposable) {
    return null;
  }

  final TextSelection wordSelection = (component as TextComposable).getWordSelectionAt(docPosition.nodePosition);

  _log.log('getWordSelection', ' - word selection: $wordSelection');
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
}

/// Returns the paragraph of text that contains the given `docPosition`, or `null`
/// if there is no text at the given `docPosition`.
///
/// A paragraph is defined as all text within the given document node, bounded by
/// newlines or the beginning/end of the node's text.
DocumentSelection? getParagraphSelection({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
}) {
  _log.log('getParagraphSelection', '_getWordSelection()');
  _log.log('getParagraphSelection', ' - doc position: $docPosition');

  final component = docLayout.getComponentByNodeId(docPosition.nodeId);
  if (component is! TextComposable) {
    return null;
  }

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
}

TextSelection _expandPositionToParagraph({
  required String text,
  required TextPosition textPosition,
}) {
  if (text.isEmpty) {
    return TextSelection.collapsed(offset: -1);
  }

  int start = min(textPosition.offset, text.length - 1);
  int end = min(textPosition.offset, text.length - 1);
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
