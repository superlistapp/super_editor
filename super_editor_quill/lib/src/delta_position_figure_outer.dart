import 'dart:ui';

import 'package:super_editor/super_editor.dart';

const _converter = DocumentPositionToDeltaPositionConverter();

class DeltaPositionFigureOuter {
  const DeltaPositionFigureOuter();

  bool isAtTheEndOfABlock(Document document, int position) {
    final convertedPosition =
        _converter.deltaPositionToDocumentPosition(document, position);
    final node = document.getNode(convertedPosition)!;
    return convertedPosition.nodePosition == node.endPosition;
  }
}

/// A class that knows how to convert a [DocumentPosition] from SuperEditor to
/// an absolute QuillJS delta position and back.
///
/// Exists solely for [DocumentSelectionTransformer] to use - commonly this class
/// should not be used by itself.
class DocumentPositionToDeltaPositionConverter {
  const DocumentPositionToDeltaPositionConverter();

  /// Converts the [position] in the given [document] into an integer that
  /// represents the absolute position in QuillJS delta terms.
  ///
  /// On the first node in the document, a [TextNodePosition] with any given
  /// offset will be exactly the same as the returned absolute position.
  ///
  /// On the subsequent nodes, the returned absolute offset will be shifted by
  /// the following equation:
  ///
  /// "dl + n"
  ///
  /// where "dl" is "document length" (=sum of the length of all of the document
  /// nodes) and "n" is "node index". This is because the Delta format always
  /// assumes a newline character after every block in any given Delta document.
  ///
  /// For example, given the following document:
  ///
  /// ```
  /// final document = MutableDocument(
  ///   nodes: [
  ///     ParagraphNode(id: 'node-1', text: AttributedText('abc')),
  ///     ParagraphNode(id: 'node-2', text: AttributedText('def')),
  ///     ParagraphNode(id: 'node-3', text: AttributedText('ghi')),
  ///   ]
  /// );
  /// ```
  ///
  /// the following expectations would be correct:
  ///
  /// ```
  /// final first = documentPositionToDeltaPosition(
  ///   document: document,
  ///   position: DocumentPosition(
  ///     nodeId: 'node-1',
  ///     nodePosition: TextNodePosition(offset: 0),
  ///   ),
  /// );
  ///
  /// final second = documentPositionToDeltaPosition(
  ///   document: document,
  ///   position: DocumentPosition(
  ///     nodeId: 'node-2',
  ///     nodePosition: TextNodePosition(offset: 0),
  ///   ),
  /// );
  ///
  /// final third = documentPositionToDeltaPosition(
  ///   document: document,
  ///   position: DocumentPosition(
  ///     nodeId: 'node-3',
  ///     nodePosition: TextNodePosition(offset: 0),
  ///   ),
  /// );
  ///
  /// expect(first, 0);
  /// expect(second, 4);
  /// expect(third, 8);
  /// ```
  int documentPositionToDeltaPosition({
    required Document document,
    required DocumentPosition position,
  }) {
    var absolutePosition = 0;

    for (final node in document.nodes) {
      if (node.id == position.nodeId) {
        final nodePosition = position.nodePosition;

        if (nodePosition is TextNodePosition) {
          _ensureTextPositionIsWithinBounds(document, node, nodePosition);
          absolutePosition += nodePosition.offset;
        }

        // We found the absolute delta position, so no need to loop anymore.
        break;
      }

      if (node is TextNode) {
        absolutePosition += node.text.text.length;
      }

      // This is accounting for the newline character that every block in a
      // Delta document has.
      absolutePosition++;
    }

    return absolutePosition;
  }

  /// Converts the [absolutePosition] in the given [document] to a SuperEditor
  /// [DocumentPosition].
  ///
  /// The [absolutePosition] is commonly obtained from [documentPositionToDeltaPosition],
  /// and this method works "backwards" in relation to that method.
  ///
  /// If the given [absolutePosition] contains a [TextNode], meaning that the
  /// node position will resolve to be a [TextNodePosition], the given [textAffinity]
  /// will be passed to it. Otherwise, the [textAffinity] has no effect.
  ///
  /// For example, given the following document:
  ///
  /// ```
  /// final document = MutableDocument(
  ///   nodes: [
  ///     ParagraphNode(id: 'node-1', text: AttributedText('abc')),
  ///     ParagraphNode(id: 'node-2', text: AttributedText('def')),
  ///     ParagraphNode(id: 'node-3', text: AttributedText('ghi')),
  ///   ]
  /// );
  /// ```
  ///
  /// the following expectations would be correct:
  ///
  /// ```
  /// final first = deltaPositionToDocumentPosition(
  ///   document: document,
  ///   absolutePosition: 0,
  ///   textAffinity: TextAffinity.downstream,
  /// );
  ///
  /// final second = deltaPositionToDocumentPosition(
  ///   document: document,
  ///   absolutePosition: 4,
  ///   textAffinity: TextAffinity.downstream,
  /// );
  ///
  /// final third = deltaPositionToDocumentPosition(
  ///   document: document,
  ///   absolutePosition: 8,
  ///   textAffinity: TextAffinity.downstream,
  /// );
  ///
  /// expect(
  ///   first,
  ///   DocumentPosition(
  ///     nodeId: 'node-1',
  ///     nodePosition: TextNodePosition(
  ///       offset: 0,
  ///       affinity: TextAffinity.downstream,
  ///     ),
  ///   ),
  /// );
  ///
  /// expect(
  ///   second,
  ///   DocumentPosition(
  ///     nodeId: 'node-2',
  ///     nodePosition: TextNodePosition(
  ///       offset: 0,
  ///       affinity: TextAffinity.downstream,
  ///     ),
  ///   ),
  /// );
  ///
  /// expect(
  ///   third,
  ///   DocumentPosition(
  ///     nodeId: 'node-3',
  ///     nodePosition: TextNodePosition(
  ///       offset: 0,
  ///       affinity: TextAffinity.downstream,
  ///     ),
  ///   ),
  /// );
  /// ```
  DocumentPosition deltaPositionToDocumentPosition(
    Document document,
    int absolutePosition,
  ) {
    String? nodeId;
    NodePosition? nodePosition;

    var currentAbsolutePosition = 0;
    var contentLength = 0;
    var nodeIndex = 0;

    for (final node in document.nodes) {
      // If the current node is a TextNode, then the length of it is the length
      // of its characters. Otherwise, it's likely a divider, or another
      // block, and the length of that is zero. It still takes 1 position
      // due to the newline that comes after it.
      final currentNodeLength = node is TextNode ? node.text.text.length : 0;

      if (currentAbsolutePosition + currentNodeLength >= absolutePosition) {
        nodeId = node.id;

        if (node is TextNode) {
          nodePosition = TextNodePosition(
            offset: absolutePosition - contentLength - nodeIndex,
          );
        } else {
          // Since the node is not a TextNode, it's most likely a block, where
          // the selection exists either before or after it.
          nodePosition =
              const UpstreamDownstreamNodePosition(TextAffinity.downstream);
        }

        // We found the node position, so no need to loop anymore.
        break;
      }

      currentAbsolutePosition += currentNodeLength;
      contentLength += currentNodeLength;
      nodeIndex++;

      // Accounts for the newline character that comes after every block in a
      // Delta document.
      currentAbsolutePosition++;
    }

    if (nodeId == null && nodePosition == null) {
      // If a node was not found, we put the selection to the end of the last
      // node in the document.
      final lastNode = document.nodes.last;
      nodeId = lastNode.id;
      nodePosition = lastNode.endPosition;
    }

    return DocumentPosition(nodeId: nodeId!, nodePosition: nodePosition!);
  }

  void _ensureTextPositionIsWithinBounds(
    Document document,
    DocumentNode node,
    TextNodePosition nodePosition,
  ) {
    if (node is TextNode &&
        (nodePosition.offset < 0 ||
            nodePosition.offset > node.text.text.length)) {
      throw OutOfBoundsError(
        nodeIndex: document.getNodeIndexById(node.id),
        offset: nodePosition.offset,
        maxOffset: node.text.text.length,
      );
    }
  }
}

class OutOfBoundsError extends Error {
  OutOfBoundsError({
    required this.nodeIndex,
    required this.offset,
    required this.maxOffset,
  });

  final int nodeIndex;
  final int offset;
  final int maxOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutOfBoundsError &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          maxOffset == other.maxOffset;

  @override
  int get hashCode => offset.hashCode ^ maxOffset.hashCode;

  @override
  String toString() {
    return 'The TextNode at index $nodeIndex has an offset that is out of bounds. '
        'Offset: $offset, valid range: 0-$maxOffset.';
  }
}
