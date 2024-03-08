import 'package:quill_delta/quill_delta.dart';
import 'package:super_editor/super_editor.dart';

// TODO(roughike): this is a bit weird API - revisit it.
class DeltaDocumentChangeListener {
  DeltaDocumentChangeListener({
    required this.peekAtDocument,
    required this.onDeltaChangeDetected,
  }) {
    _currentDocument = _copy(peekAtDocument());
  }

  final Document Function() peekAtDocument;
  final void Function(Delta) onDeltaChangeDetected;

  late Document _currentDocument;

  /// Converts the [changeLog] to a [Delta] change and calls [onDeltaChangeDetected]
  /// when the change delta is not empty - i.e. when something actually changed.
  void call(DocumentChangeLog changeLog) {
    final appliedChanges = <DocumentChange>[];
    Delta? changeDelta;

    for (final change in changeLog.changes) {
      if (change is TextInsertionEvent) {
        changeDelta = (changeDelta ?? Delta()).compose(
          Delta()
            ..retain(
              _findInsertionOffset(appliedChanges, change.nodeId, 1) +
                  change.offset,
            )
            ..insert(change.text.text),
        );
      } else if (change is TextDeletedEvent) {
        changeDelta = (changeDelta ?? Delta()).compose(
          Delta()
            ..retain(_findInsertionOffset(appliedChanges, change.nodeId, 1) +
                change.offset)
            ..delete(change.deletedText.length),
        );
      } else if (change is NodeChangeEvent) {
        print('Need more information on what changed.');
        // throw UnsupportedError('Need more information on what changed.');
      } else if (change is NodeInsertedEvent) {
        changeDelta = (changeDelta ?? Delta()).compose(
          Delta()
            ..retain(_previousNodeLengths(change.insertionIndex))
            ..insert('\n'),
        );
      } else if (change is NodeRemovedEvent) {
        final willDocumentBeEmptyAfterChange =
            _willDocumentBeEmpty([...appliedChanges, change]);
        changeDelta = (changeDelta ?? Delta()).compose(
          Delta()
            ..retain(_findInsertionOffset(appliedChanges, change.nodeId, 0))
            ..delete(
              _nodeLength(change.removedNode) +
                  (willDocumentBeEmptyAfterChange ? 0 : 1),
            ),
        );
      } else {
        throw StateError('Unhandled change: $change');
      }

      appliedChanges.add(change);
    }

    if (changeDelta != null && changeDelta.isNotEmpty) {
      onDeltaChangeDetected(changeDelta);
      _currentDocument = _copy(peekAtDocument());
    }
  }

  // TODO: figure out if we actually need to add `\n` at this level, or if it's
  // more of a quill editor thing for full documents
  bool _willDocumentBeEmpty(List<DocumentChange> changes) {
    final nodesInDocument = _copy(_currentDocument) as MutableDocument;
    for (final change in changes) {
      if (change is NodeRemovedEvent) {
        nodesInDocument
            .deleteNodeAt(nodesInDocument.getNodeIndexById(change.nodeId));
      } else {
        throw StateError('Unhandled: $change');
      }
    }

    return nodesInDocument.nodes.isEmpty;
  }

  int _previousNodeLengths(int nodeIndex) {
    final doc = _currentDocument;
    var offset = 0;

    for (var i = 0; i < nodeIndex; i++) {
      final node = doc.nodes[i];
      offset += _nodeLength(node);
    }

    return offset + (nodeIndex > 0 ? nodeIndex - 1 : 0);
  }

  int _findInsertionOffset(
    List<DocumentChange> changes,
    String nodeId,
    int extra,
  ) {
    final doc = _currentDocument;
    var nodeIndex = 0;
    var offset = _shiftInsertionOffset(changes);

    for (final node in doc.nodes) {
      if (node.id == nodeId) break;
      offset += _nodeLength(node) + nodeIndex;
      nodeIndex++;
    }

    return offset > 0 ? offset + extra : offset;
  }

  int _shiftInsertionOffset(List<DocumentChange> changes) {
    var result = 0;

    for (final change in changes) {
      if (change is NodeRemovedEvent) {
        result -= _nodeLength(change.removedNode);
      } else if (change is NodeInsertedEvent) {
        // TODO
      } else if (change is TextInsertionEvent ||
          change is TextDeletedEvent ||
          change is NodeChangeEvent) {
        // no-op
      } else {
        throw StateError('Cannot handle $change');
      }
    }

    return result;
  }

  int _nodeLength(DocumentNode node) {
    if (node is TextNode) {
      return node.text.length;
    } else {
      return 1;
    }
  }
}

// TODO: figure out how to either a) not have to "peek" at the document or
// b) a nicer way to make sure the document does not change in the middle of
// being peeked at
Document _copy(Document document) {
  return MutableDocument(
    nodes: document.nodes.map((node) {
      if (node is ParagraphNode) {
        return ParagraphNode(
          id: node.id,
          text: AttributedText(
            node.text.text,
            node.text.spans,
          ),
          metadata: node.metadata,
        );
      }

      throw StateError('Unhandled node: $node');
    }).toList(),
  );
}
