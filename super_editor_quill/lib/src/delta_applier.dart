import 'package:quill_delta/quill_delta.dart';
import 'package:super_editor/super_editor.dart';

/// Translated QuillJS Deltas to SuperEditor EditRequests and executes them as
/// one batch of requests.
class DeltaApplier {
  const DeltaApplier({
    String Function() idGenerator = Editor.createNodeId,
  }) : _idGenerator = idGenerator;

  final String Function() _idGenerator;

  /// Converts the [delta] to appropriate [EditRequest]s and executes them on
  /// the given [editor].
  void apply(Editor editor, Delta delta) {
    final requests = <EditRequest>[];
    var offset = 0;

    for (final operation in delta.toList()) {
      if (operation.isInsert) {
        final document =
            editor.context.find<MutableDocument>(Editor.documentKey);

        if (operation.length == 1 && operation.data == '\n') {
          final targetIndex = _deltaPositionToDocumentNodeIndex(
            document: document,
            pendingRequests: requests,
            deltaPosition: offset,
          );

          requests.add(
            InsertNodeAtIndexRequest(
              nodeIndex: targetIndex != null ? targetIndex + 1 : 0,
              newNode: ParagraphNode(
                id: _idGenerator(),
                text: AttributedText(),
              ),
            ),
          );
        } else {
          final position = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: offset,
          );

          requests.add(
            InsertTextRequest(
              documentPosition: position!,
              textToInsert: operation.data as String,
              attributions: {},
            ),
          );
        }
      } else if (operation.isRetain) {
        offset = offset + operation.length;

        final attributes = operation.attributes ?? {};

        if (attributes.isNotEmpty) {
          final normalizedOffset = offset - 1;
          final document =
              editor.context.find<MutableDocument>(Editor.documentKey);
          final start = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: normalizedOffset,
          )!;
          final end = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: normalizedOffset + operation.length,
          )!;
          final range = DocumentRange(start: start, end: end);

          for (final attribute in attributes.entries) {
            if (attribute.key == 'bold') {
              if (attribute.value == true) {
                requests.add(
                  AddTextAttributionsRequest(
                    documentRange: range,
                    attributions: {boldAttribution},
                  ),
                );
              }
            }
          }
        }
      } else if (operation.isDelete) {
        final document =
            editor.context.find<MutableDocument>(Editor.documentKey);
        final start = _deltaPositionToDocumentPosition(
          document: document,
          pendingRequests: requests,
          deltaPosition: offset,
        )!;
        final end = _deltaPositionToDocumentPosition(
          document: document,
          pendingRequests: requests,
          deltaPosition: offset + operation.length,
        )!;

        requests.add(
          DeleteContentRequest(
            documentRange: DocumentRange(start: start, end: end),
          ),
        );

        offset = 0;
      } else {
        throw StateError('Unknown operation type: $operation');
      }
    }

    if (requests.isNotEmpty) {
      editor.execute(requests);
    }
  }
}

int? _deltaPositionToDocumentNodeIndex({
  required Document document,
  required List<EditRequest> pendingRequests,
  required int deltaPosition,
}) {
  final position = _deltaPositionToDocumentPosition(
    document: document,
    pendingRequests: pendingRequests,
    deltaPosition: deltaPosition,
  );

  return position == null ? null : document.getNodeIndexById(position.nodeId);
}

DocumentPosition? _deltaPositionToDocumentPosition({
  required Document document,
  required List<EditRequest> pendingRequests,
  required int deltaPosition,
}) {
  if (document.nodes.isEmpty) return null;

  var currentAbsolutePosition =
      _shiftDeltaPositionBasedOnPendingRequests(pendingRequests);
  var contentLength = 0;
  var nodeIndex = 0;

  for (final node in document.nodes) {
    if (node is! TextNode) {
      throw UnimplementedError('Not handling other nodes than TextNodes yet.');
    }

    final currentNodeLength = node is TextNode ? node.text.text.length : 0;
    if (currentAbsolutePosition + currentNodeLength >= deltaPosition) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition:
            TextNodePosition(offset: deltaPosition - contentLength - nodeIndex),
      );
    }

    currentAbsolutePosition += currentNodeLength;
    contentLength += currentNodeLength;
    nodeIndex++;

    // Accounts for the newline character that comes after every block in a
    // Delta document.
    currentAbsolutePosition++;
  }

  final lastNode = document.nodes.last;
  final lastNodeEndPosition = lastNode.endPosition;
  if (lastNodeEndPosition is! TextNodePosition) {
    throw UnimplementedError();
  }

  return DocumentPosition(
    nodeId: lastNode.id,
    nodePosition: TextNodePosition(
      offset: lastNodeEndPosition.offset +
          _shiftDeltaPositionBasedOnPendingRequests(pendingRequests),
      affinity: lastNodeEndPosition.affinity,
    ),
  );
}

int _shiftDeltaPositionBasedOnPendingRequests(
  List<EditRequest> pendingRequests,
) {
  var result = 0;

  for (final request in pendingRequests) {
    if (request is InsertTextRequest) {
      result += request.textToInsert.length;
    } else {
      throw StateError('Cannot handle $request');
    }
  }

  return result;
}
