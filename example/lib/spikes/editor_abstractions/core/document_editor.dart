import 'package:flutter/foundation.dart';

import 'document.dart';

class DocumentEditor {
  DocumentEditor({
    @required RichTextDocument document,
  }) : _document = document;

  final RichTextDocument _document;

  void executeCommand(EditorCommand command) {
    command.execute(_document, this);
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void insertNodeAt(int index, DocumentNode node) {
    if (index <= _document.nodes.length) {
      _document.mutateDocument((onNodeChange) {
        _document.nodes.insert(index, node);
        node.addListener(onNodeChange);
      });
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void insertNodeAfter({
    @required DocumentNode previousNode,
    @required DocumentNode newNode,
  }) {
    final nodeIndex = _document.nodes.indexOf(previousNode);
    if (nodeIndex >= 0 && nodeIndex < _document.nodes.length) {
      _document.mutateDocument((onNodeChange) {
        _document.nodes.insert(nodeIndex + 1, newNode);
        newNode.addListener(onNodeChange);
      });
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  void deleteNodeAt(int index) {
    if (index >= 0 && index < _document.nodes.length) {
      _document.mutateDocument((onNodeChange) {
        final removedNode = _document.nodes.removeAt(index);
        removedNode.removeListener(onNodeChange);
      });
    } else {
      print('Could not delete node. Index out of range: $index');
    }
  }

  // TODO: convert this to a command, or move command execution out of the editor
  bool deleteNode(DocumentNode node) {
    bool isRemoved;

    _document.mutateDocument((onNodeChange) {
      node.removeListener(onNodeChange);
      isRemoved = _document.nodes.remove(node);
    });

    return isRemoved;
  }
}

abstract class EditorCommand {
  void execute(RichTextDocument document, DocumentEditor editor);
}
