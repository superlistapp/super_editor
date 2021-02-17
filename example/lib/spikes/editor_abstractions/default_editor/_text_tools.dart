import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/document.dart';
import '../core/document_selection.dart';
import 'text.dart';

bool isTextEntryNode({
  @required Document document,
  @required ValueNotifier<DocumentSelection> selection,
}) {
  final extentPosition = selection.value.extent;
  final extentNode = document.getNodeById(extentPosition.nodeId);
  return extentNode is TextNode;
}

const latinCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

bool isCharacterKey(LogicalKeyboardKey key) {
  // keyLabel for a character should be: 'a', 'b',...,'A','B',...
  if (key.keyLabel.length != 1) {
    return false;
  }
  return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()-=_+<>?:"{}|'
      .contains(key.keyLabel);
}

DocumentSelection getWordSelection({
  @required DocumentPosition docPosition,
  @required DocumentLayout docLayout,
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

DocumentSelection getParagraphSelection({
  @required DocumentPosition docPosition,
  @required DocumentLayout docLayout,
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
