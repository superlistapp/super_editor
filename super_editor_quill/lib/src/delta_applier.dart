import 'package:quill_delta/quill_delta.dart';
import 'package:super_editor/super_editor.dart';

abstract interface class DeltaAttribution {
  const DeltaAttribution();

  String get deltaAttributeKey;
  bool typeMatchesSuperEditorAttribution(Attribution attribution);
  Attribution toSuperEditorAttribution(Object value);
}

class DeltaHeaderAttribution implements DeltaAttribution {
  const DeltaHeaderAttribution();

  @override
  String get deltaAttributeKey => 'header';

  @override
  bool typeMatchesSuperEditorAttribution(Attribution attribution) {
    return {
      header1Attribution,
      header2Attribution,
      header3Attribution,
      header4Attribution,
      header5Attribution,
      header6Attribution
    }.contains(attribution);
  }

  @override
  Attribution toSuperEditorAttribution(Object value) {
    if (value == 1) return header1Attribution;
    if (value == 2) return header2Attribution;
    if (value == 3) return header3Attribution;
    if (value == 4) return header4Attribution;
    if (value == 5) return header5Attribution;
    if (value == 6) return header6Attribution;

    throw UnimplementedError('Unknown header value: $value');
  }
}

class DeltaBoldAttribution implements DeltaAttribution {
  const DeltaBoldAttribution();

  @override
  String get deltaAttributeKey => 'bold';

  @override
  bool typeMatchesSuperEditorAttribution(Attribution attribution) {
    return attribution == boldAttribution;
  }

  @override
  Attribution toSuperEditorAttribution(Object value) {
    return boldAttribution;
  }
}

class DeltaItalicsAttribution implements DeltaAttribution {
  const DeltaItalicsAttribution();

  @override
  String get deltaAttributeKey => 'italic';

  @override
  bool typeMatchesSuperEditorAttribution(Attribution attribution) {
    return attribution == italicsAttribution;
  }

  @override
  Attribution toSuperEditorAttribution(Object value) {
    return italicsAttribution;
  }
}

class DeltaUnderlineAttribution implements DeltaAttribution {
  const DeltaUnderlineAttribution();

  @override
  String get deltaAttributeKey => 'underline';

  @override
  bool typeMatchesSuperEditorAttribution(Attribution attribution) {
    return attribution == underlineAttribution;
  }

  @override
  Attribution toSuperEditorAttribution(Object value) {
    return underlineAttribution;
  }
}

class DeltaLinkAttribution implements DeltaAttribution {
  const DeltaLinkAttribution();

  @override
  String get deltaAttributeKey => 'link';

  @override
  bool typeMatchesSuperEditorAttribution(Attribution attribution) {
    return attribution.id ==
        LinkAttribution(url: Uri.parse('https://doesnotmatter.com')).id;
  }

  @override
  Attribution toSuperEditorAttribution(Object value) {
    return LinkAttribution(url: Uri.parse(value as String));
  }
}

const _defaultBlockAttributions = <DeltaAttribution>[
  DeltaHeaderAttribution(),
];

const _defaultTextAttributions = <DeltaAttribution>[
  DeltaBoldAttribution(),
  DeltaItalicsAttribution(),
  DeltaUnderlineAttribution(),
  DeltaLinkAttribution(),
];

/// Translated QuillJS Deltas to SuperEditor EditRequests and executes them as
/// one batch of requests.
class DeltaApplier {
  const DeltaApplier({
    List<DeltaAttribution> blockAttributions = _defaultBlockAttributions,
    List<DeltaAttribution> textAttributions = _defaultTextAttributions,
    String Function() idGenerator = Editor.createNodeId,
  })  : _blockAttributions = blockAttributions,
        _textAttributions = textAttributions,
        _idGenerator = idGenerator;

  final List<DeltaAttribution> _blockAttributions;
  final List<DeltaAttribution> _textAttributions;
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
          final data = operation.data;
          final position = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: offset,
          )!;

          if (data is String) {
            requests.add(
              InsertTextRequest(
                documentPosition: position,
                textToInsert: data,
                attributions: {},
              ),
            );
          } else {
            assert(data is Map);
            requests.addAll([
              InsertNodeBeforeNodeRequest(
                existingNodeId: position.nodeId,
                newNode: HorizontalRuleNode(id: _idGenerator()),
              ),
            ]);
          }
        }
      } else if (operation.isRetain) {
        final startOffset = offset;
        final endOffset = offset + operation.length;
        offset = endOffset;

        final attributes = operation.attributes ?? {};

        if (attributes.isNotEmpty) {
          final document =
              editor.context.find<MutableDocument>(Editor.documentKey);
          final start = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: startOffset,
          )!;
          final end = _deltaPositionToDocumentPosition(
            document: document,
            pendingRequests: requests,
            deltaPosition: endOffset,
          )!;
          final range = DocumentRange(start: start, end: end);

          for (final attribute in attributes.entries) {
            final hasBlockAttribution = _blockAttributions.any(
              (attribution) => attribution.deltaAttributeKey == attribute.key,
            );

            if (hasBlockAttribution) {
              assert(
                !_textAttributions.any(
                  (attribution) =>
                      attribution.deltaAttributeKey == attribute.key,
                ),
              );

              final nodesInRange =
                  document.getNodesInside(range.start, range.end);

              for (final node in nodesInRange) {
                final blockAttribution = _blockAttributions.singleWhere(
                  (attribution) =>
                      attribution.deltaAttributeKey == attribute.key,
                );

                if (attribute.value == null) {
                  // Removing the block type attribution makes the block type into
                  // just a plain paragraph.
                  requests.add(
                    ChangeParagraphBlockTypeRequest(
                      nodeId: node.id,
                      blockType: paragraphAttribution,
                    ),
                  );
                } else {
                  requests.add(
                    ChangeParagraphBlockTypeRequest(
                      nodeId: node.id,
                      blockType: blockAttribution
                          .toSuperEditorAttribution(attribute.value),
                    ),
                  );
                }
              }

              continue;
            }

            if (!_textAttributions.any(
              (attribution) => attribution.deltaAttributeKey == attribute.key,
            )) {
              throw StateError(
                'No attribution handler implemented for ${attribute.key}: ${attribute.value}',
              );
            }

            final textAttribution = _textAttributions.singleWhere(
              (attribution) => attribution.deltaAttributeKey == attribute.key,
            );
            if (attribute.value == null) {
              final existingAttribution = _findExistingAttribution(
                document: document,
                range: range,
                testAgainstSuperEditorAttribution:
                    textAttribution.typeMatchesSuperEditorAttribution,
              );
              requests.add(
                RemoveTextAttributionsRequest(
                  documentRange: range,
                  attributions: {existingAttribution},
                ),
              );
            } else {
              requests.add(
                AddTextAttributionsRequest(
                  documentRange: range,
                  attributions: {
                    textAttribution.toSuperEditorAttribution(attribute.value),
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

        final deletionWithinSingleBlock =
            document.getNodesInside(start, end).length == 1;
        final deletedNode = document.getNodeById(start.nodeId) as ParagraphNode;

        if (_upcomingDocumentNodeCount(document, requests) > 1 &&
            deletionWithinSingleBlock &&
            start.nodePosition == deletedNode.beginningPosition &&
            end.nodePosition == deletedNode.endPosition) {
          assert(start.nodeId == end.nodeId);
          requests.add(DeleteNodeRequest(nodeId: start.nodeId));
        } else {
          requests.add(
            DeleteContentRequest(
              documentRange: DocumentRange(start: start, end: end),
            ),
          );
        }

        offset = 0;
      } else {
        throw StateError('Unknown operation type: $operation');
      }
    }

    if (requests.isNotEmpty) {
      editor.execute(requests);
    }
  }

  Attribution _findExistingAttribution({
    required Document document,
    required DocumentRange range,
    required bool Function(Attribution) testAgainstSuperEditorAttribution,
  }) {
    final node = (document.getNodesInside(range.start, range.end).single)
        as ParagraphNode;
    final shiftedRange = node.computeSelection(
      base: range.start.nodePosition,
      extent: range.end.nodePosition,
    );

    return node.text.spans
        .getAttributionSpansInRange(
          attributionFilter: testAgainstSuperEditorAttribution,
          start: shiftedRange.start,
          end: shiftedRange.end,
        )
        .single
        .attribution;
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
    } else if (request is AddTextAttributionsRequest ||
        request is RemoveTextAttributionsRequest ||
        request is ChangeParagraphBlockTypeRequest ||

        // TODO: These affect positioning so they need to be shifted most likely
        request is InsertNodeBeforeNodeRequest ||
        request is DeleteNodeRequest) {
      // No-op
    } else {
      throw StateError('Cannot handle $request');
    }
  }

  return result;
}

int _upcomingDocumentNodeCount(
    Document document, List<EditRequest> pendingRequests) {
  var count = document.nodes.length;
  for (final request in pendingRequests) {
    if (_isInsertNodeRequest(request)) {
      count++;
    } else if (_isDeleteNodeRequest(request)) {
      count--;
    }
  }

  return count;
}

bool _isInsertNodeRequest(EditRequest request) {
  return request is InsertNodeAtIndexRequest ||
      request is InsertNodeBeforeNodeRequest ||
      request is InsertNodeAfterNodeRequest ||
      request is InsertNodeAtCaretRequest;
}

bool _isDeleteNodeRequest(EditRequest request) {
  return request is DeleteNodeRequest;
}
