import 'dart:math';

import 'package:flutter/material.dart';

import 'layout/components/paragraph/editor_paragraph_component.dart';
import 'selection/editor_selection.dart';

class DocDisplayNode {
  DocDisplayNode({
    @required this.key,
    @required this.paragraph,
  });

  final GlobalKey key;
  String paragraph;
  // TODO: remove the concept of selection from the layout model
  EditorComponentSelection selection;

  void deleteSelection() {
    assert(selection is ParagraphEditorComponentSelection);
    print('Deleting selection for $key: ${selection.componentSelection}');

    final textSelection = selection.componentSelection as TextSelection;
    final from = min(textSelection.baseOffset, textSelection.extentOffset);
    final to = max(textSelection.baseOffset, textSelection.extentOffset);
    print(' - from: $from, to: $to, text: $paragraph');

    paragraph = _removeStringSubsection(
      from: from,
      to: to,
      text: paragraph,
    );
    print(' - remaining text: $paragraph');
    selection.componentSelection = TextSelection.collapsed(
      offset: from,
    );
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
    if (to <= text.length) {
      right = text.substring(to, text.length);
    }
    return left + right;
  }

  bool tryToCombineWithNextNode(DocDisplayNode nextNode) {
    // TODO: make sure next node is compatible. This requires different
    //       types of doc display nodes.

    print('Combing nodes: "$paragraph" + "${nextNode.paragraph}"');
    paragraph += nextNode.paragraph;

    return true;
  }
}
