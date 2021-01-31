import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rich_text_document.dart';
import '../selection/editor_selection.dart';

class DocumentEditor {
  DocumentSelection addCharacter({
    @required RichTextDocument document,
    @required DocumentPosition position,
    @required String character,
  }) {
    final docNode = document.getNodeById(position.nodeId);
    if (docNode is! ParagraphNode) {
      return DocumentSelection.collapsed(position: position);
    }

    final paragraphNode = docNode as ParagraphNode;
    final textOffset = (position.nodePosition as TextPosition).offset;
    final newParagraph = _insertStringInString(
      index: textOffset,
      existing: paragraphNode.paragraph,
      addition: character,
    );

    // Add the character to the paragraph.
    paragraphNode.paragraph = newParagraph;

    // Update the selection to place the caret after the new character.
    return DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: paragraphNode.id,
        nodePosition: TextPosition(
          offset: textOffset + 1,
        ),
      ),
    );
  }

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

//   DocumentNode insertNewNodeAfter({
//   @required RichTextDocument document,
//     @required DocumentNode nodeBefore,
// }) {
//     //
//   }

  DocumentSelection deleteSelection({
    @required RichTextDocument document,
    @required DocumentSelection selection,
  }) {
    print('DocumentEditor: deleting selection: $selection');
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

      print('Done deleting selection. Returning new document selection.');
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
}
