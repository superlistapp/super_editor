import 'package:super_editor_quill/super_editor_quill.dart';

typedef _DeltaAttributor = Attribution Function(
  Attribution? attribution,
  Object? value,
);

typedef Attributors = Map<String, _DeltaAttributor>;

final _defaultBlockAttributors = <String, _DeltaAttributor>{
  'header': (_, value) {
    if (value == null || value == false) return paragraphAttribution;

    if (value == 1) return header1Attribution;
    if (value == 2) return header2Attribution;
    if (value == 3) return header3Attribution;
    if (value == 4) return header4Attribution;
    if (value == 5) return header5Attribution;
    if (value == 6) return header6Attribution;

    throw UnimplementedError('Unknown header value: $value');
  },
};

final _defaultTextAttributors = <String, _DeltaAttributor>{
  'bold': (_, __) => boldAttribution,
  'italic': (_, __) => italicsAttribution,
  'underline': (_, __) => underlineAttribution,
  'link': (attribution, url) {
    // TODO: This is not the clearest API by any means
    return attribution ?? LinkAttribution(url: Uri.parse(url as String));
  },
};

/// Translated QuillJS Deltas to SuperEditor EditRequests and executes them as
/// one batch of requests.
class DeltaApplier {
  DeltaApplier({
    Attributors? blockAttributors,
    Attributors? textAttributors,
    String Function() idGenerator = Editor.createNodeId,
  })  : _blockAttributors = blockAttributors ?? _defaultBlockAttributors,
        _textAttributors = textAttributors ?? _defaultTextAttributors,
        _idGenerator = idGenerator;

  final Attributors _blockAttributors;
  final Attributors _textAttributors;
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
            final hasBlockAttribution =
                _blockAttributors.containsKey(attribute.key);

            if (hasBlockAttribution) {
              assert(!_textAttributors.containsKey(attribute.key));
              assert(range.start.nodeId == range.end.nodeId);
              final blockAttribution = _blockAttributors[attribute.key]!;

              if (attribute.value == false || attribute.value == null) {
                requests.add(
                  ChangeParagraphBlockTypeRequest(
                    nodeId: range.end.nodeId,
                    blockType: blockAttribution(null, attribute.value),
                  ),
                );
              } else {
                requests.add(
                  ChangeParagraphBlockTypeRequest(
                    nodeId: range.end.nodeId,
                    blockType: blockAttribution(null, attribute.value),
                  ),
                );
              }

              continue;
            }

            if (!_textAttributors.containsKey(attribute.key)) {
              throw StateError(
                'No attribution handler implemented for ${attribute.key}: ${attribute.value}',
              );
            }

            final textAttribution = _textAttributors[attribute.key]!;
            final node = (document.getNodesInside(range.start, range.end).single
                    as TextNode)
                .text
                .spans
                .getAllAttributionsAt(
                  (range.start.nodePosition as TextNodePosition).offset,
                )
                .singleOrNull;
            if (attribute.value == false || attribute.value == null) {
              requests.add(
                RemoveTextAttributionsRequest(
                  documentRange: range,
                  attributions: {
                    textAttribution(node!, attribute.value),
                  },
                ),
              );
            } else {
              requests.add(
                AddTextAttributionsRequest(
                  documentRange: range,
                  attributions: {
                    textAttribution(node, attribute.value),
                  },
                ),
              );
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

    // TODO: Handle other types than TextNodes
    // ignore: unnecessary_type_check
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
