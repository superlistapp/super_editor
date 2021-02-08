import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/document.dart';
import '../core/document_selection.dart';
import 'text.dart';

bool isTextEntryNode({
  @required RichTextDocument document,
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
