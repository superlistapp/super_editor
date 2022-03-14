import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// A read-only document with styled text and multimedia elements.
///
/// A [Document] is comprised of a list of [DocumentNode]s,
/// which describe the type and substance of a piece of content
/// within the document. For example, a [ParagraphNode] holds a
/// single paragraph of text within the document.
///
/// New types of content can be added by subclassing [DocumentNode].
///
/// To represent a specific location within a [Document],
/// see [DocumentPosition].
///
/// A [Document] has no opinion on the visual presentation of its
/// content.
///
/// To edit the content of a document, see [DocumentEditor].
abstract class Document with ChangeNotifier {
  /// Returns all of the content within the document as a list
  /// of [DocumentNode]s.
  List<DocumentNode> get nodes;

  /// Returns the [DocumentNode] with the given [nodeId], or [null]
  /// if no such node exists.
  DocumentNode? getNodeById(String nodeId);

  /// Returns the [DocumentNode] at the given [index], or [null]
  /// if no such node exists.
  DocumentNode? getNodeAt(int index);

  /// Returns the index of the given [node], or [-1] if the [node]
  /// does not exist within this [Document].
  int getNodeIndex(DocumentNode node);

  /// Returns the index of the `DocumentNode` in this `Document` that
  /// has the given [nodeId], or `-1` if the node does not exist.
  int getNodeIndexById(String nodeId);

  /// Returns the [DocumentNode] that appears immediately before the
  /// given [node] in this [Document], or null if the given [node]
  /// is the first node, or the given [node] does not exist in this
  /// [Document].
  DocumentNode? getNodeBefore(DocumentNode node);

  /// Returns the [DocumentNode] that appears immediately after the
  /// given [node] in this [Document], or null if the given [node]
  /// is the last node, or the given [node] does not exist in this
  /// [Document].
  DocumentNode? getNodeAfter(DocumentNode node);

  /// Returns the [DocumentNode] at the given [position], or [null] if
  /// no such node exists in this [Document].
  DocumentNode? getNode(DocumentPosition position);

  /// Returns a [DocumentRange] that ranges from [position1] to
  /// [position2], including [position1] and [position2].
  // TODO: this method is misleading (#48) because if `position1` and
  //       `position2` are in the same node, they may be returned
  //       in the wrong order because the document doesn't know
  //       how to interpret positions within a node.
  DocumentRange getRangeBetween(DocumentPosition position1, DocumentPosition position2);

  /// Returns all [DocumentNode]s from [position1] to [position2], including
  /// the nodes at [position1] and [position2].
  List<DocumentNode> getNodesInside(DocumentPosition position1, DocumentPosition position2);

  /// Returns [true] if the content in the [other] document is equivalent to
  /// the content in this document, ignoring any details that are unrelated
  /// to content, such as individual node IDs.
  ///
  /// To compare [Document] equality, use the standard [==] operator.
  bool hasEquivalentContent(Document other);
}

/// A span within a [Document] that begins at [start] and
/// ends at [end].
///
/// The [start] position must come before the [end] position in
/// the document.
class DocumentRange {
  /// Creates a document range from its start and end positions.
  ///
  /// The [start] position must come before the [end] position in
  /// the document.
  DocumentRange({
    required this.start,
    required this.end,
  });

  /// The start position of the range represented by its position within the
  /// document.
  ///
  /// The [start] position comes before the [end] position, or is equivalent to
  /// the [end] position.
  final DocumentPosition start;

  /// The end position of the range represented by its position within the
  /// document.
  ///
  /// The [end] position comes after the [start] position, or is equivalent to
  /// the [start] position.
  final DocumentPosition end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentRange && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() {
    return '[DocumentRange] - from: ($start), to: ($end)';
  }
}

/// A logical position within a [Document].
///
/// A [DocumentPosition] points to a specific node by way of a [nodeId],
/// and points to a specific position within the node by way of a
/// [nodePosition].
///
/// The type of the [nodePosition] depends upon the type of [DocumentNode]
/// that this position points to. For example, a [ParagraphNode]
/// uses a [TextPosition] to represent a [nodePosition].
class DocumentPosition {
  /// Creates a document position from its node ID and node-specific
  /// representation of the position.
  ///
  /// The [nodeId] references a [DocumentNode] within the document and the
  /// [nodePosition] adds node-specific context.
  ///
  /// For example, the following code creates a [DocumentPosition] that points
  /// to a [TextNode] and a text offset of `1` within that text node:
  ///
  /// ```dart
  /// final documentPosition = DocumentPosition(
  ///   nodeId: documentEditor.document.nodes.first.id,
  ///   nodePosition: TextNodePosition(offset: 1),
  /// );
  /// ```
  const DocumentPosition({
    required this.nodeId,
    required this.nodePosition,
  });

  /// ID of a [DocumentNode] within a [Document].
  final String nodeId;

  /// Node-specific representation of a position.
  ///
  /// For example: a paragraph node might use a [TextNodePosition].
  final NodePosition nodePosition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPosition && nodeId == other.nodeId && nodePosition == other.nodePosition;

  @override
  int get hashCode => nodeId.hashCode ^ nodePosition.hashCode;

  /// Creates a new [DocumentPosition] based on the current position, with the
  /// provided parameters overridden.
  DocumentPosition copyWith({
    String? nodeId,
    NodePosition? nodePosition,
  }) {
    return DocumentPosition(
      nodeId: nodeId ?? this.nodeId,
      nodePosition: nodePosition ?? this.nodePosition,
    );
  }

  @override
  String toString() {
    return '[DocumentPosition] - node: "$nodeId", position: ($nodePosition)';
  }
}

/// A single content node within a [Document].
abstract class DocumentNode implements ChangeNotifier {
  /// ID that is unique within a [Document].
  String get id;

  /// Returns the [NodePosition] that corresponds to the beginning
  /// of content in this node.
  ///
  /// For example, a [ParagraphNode] would return [TextNodePosition(offset: 0)].
  NodePosition get beginningPosition;

  /// Returns the [NodePosition] that corresponds to the end of the
  /// content in this node.
  ///
  /// For example, a [ParagraphNode] would return [TextNodePosition(offset: text.length)].
  NodePosition get endPosition;

  /// Inspects [position1] and [position2] and returns the one that's
  /// positioned further upstream in this [DocumentNode].
  ///
  /// For example, in a [TextNode], this returns the [TextPosition]
  /// for the character that appears earlier in the block of text.
  NodePosition selectUpstreamPosition(
    NodePosition position1,
    NodePosition position2,
  );

  /// Inspects [position1] and [position2] and returns the one that's
  /// positioned further downstream in this [DocumentNode].
  ///
  /// For example, in a [TextNode], this returns the [TextPosition]
  /// for the character that appears later in the block of text.
  NodePosition selectDownstreamPosition(
    NodePosition position1,
    NodePosition position2,
  );

  /// Returns a node-specific representation of a selection from
  /// [base] to [extent].
  ///
  /// For example, a [ParagraphNode] would return a [TextNodeSelection].
  NodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  });

  /// Returns a plain-text version of the content in this node
  /// within [selection], or null if the given selection does
  /// not make sense as plain-text.
  String? copyContent(NodeSelection selection);

  /// Returns true if the [other] node is the same type as this
  /// node, and contains the same content.
  ///
  /// Content equivalency ignores the node ID.
  ///
  /// Content equivalency is used to determine if two documents are
  /// equivalent. Corresponding nodes in each document are compared
  /// with this method.
  bool hasEquivalentContent(DocumentNode other) {
    return const DeepCollectionEquality().equals(_metadata, other._metadata);
  }

  /// Returns all metadata attached to this [DocumentNode].
  Map<String, dynamic> get metadata => _metadata;

  final Map<String, dynamic> _metadata = {};

  /// Sets all metadata for this [DocumentNode], removing all
  /// existing values.
  set metadata(Map<String, dynamic>? newMetadata) {
    if (const DeepCollectionEquality().equals(_metadata, newMetadata)) {
      return;
    }

    _metadata.clear();
    if (newMetadata != null) {
      _metadata.addAll(newMetadata);
    }
    notifyListeners();
  }

  /// Returns `true` if this node has a non-null metadata value for
  /// the given metadata [key], and returns `false`, otherwise.
  bool hasMetadataValue(String key) => _metadata[key] != null;

  /// Returns this node's metadata value for the given [key].
  dynamic getMetadataValue(String key) => _metadata[key];

  /// Sets this node's metadata value for the given [key] to the given
  /// [value], and notifies node listeners that a change has occurred.
  void putMetadataValue(String key, dynamic value) {
    if (_metadata[key] == value) {
      return;
    }

    _metadata[key] = value;
    notifyListeners();
  }

  /// Returns a copy of this node's metadata.
  Map<String, dynamic> copyMetadata() => Map.from(_metadata);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNode &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(_metadata, other._metadata);

  // We return an arbitrary number for the hashCode because the only
  // data we have is metadata, and different instances of metadata can
  // be equivalent. If we returned `_metadata.hashCode`, then two
  // `DocumentNode`s with equivalent metadata would say that they're
  // unequal, because the hashCodes would be different.
  @override
  int get hashCode => 1;
}

extension InspectNodeAffinity on DocumentNode {
  /// Returns the affinity direction implied by the given [base] and [extent].
  TextAffinity getAffinityBetween({
    required NodePosition base,
    required NodePosition extent,
  }) {
    return base == selectUpstreamPosition(base, extent) ? TextAffinity.downstream : TextAffinity.upstream;
  }
}

/// Marker interface for a selection within a [DocumentNode].
abstract class NodeSelection {
  // marker interface
}

/// Marker interface for all node positions.
///
/// A node position is a logical position within a [DocumentNode],
/// e.g., a [TextNodePosition] within a [ParagraphNode], or a [BinaryNodePosition]
/// within an [ImageNode].
abstract class NodePosition {
  // marker interface
}
