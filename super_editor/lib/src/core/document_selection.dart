import 'dart:ui';

import 'package:super_editor/src/default_editor/text.dart';

import 'document.dart';

/// A selection within a [Document].
///
/// A [DocumentSelection] spans from a [base] position to an
/// [extent] position, and includes all content in between.
///
/// [base] and [extent] are instances of [DocumentPosition],
/// which represents a single position within a [Document].
///
/// A [DocumentSelection] does not hold a reference to a
/// [Document], it only represents a directional selection
/// within a [Document]. The [base] and [extent] positions must
/// be interpreted within the context of a specific [Document]
/// to locate nodes between [base] and [extent], and to identify
/// partial content that is selected within the [base] and [extent]
/// nodes within the document.
class DocumentSelection {
  /// Creates a collapsed selection at the given [position] within the document.
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  const DocumentSelection.collapsed({
    required DocumentPosition position,
  })  : base = position,
        extent = position;

  /// Creates a selection from the [base] position to the [extent] position
  /// within the document.
  const DocumentSelection({
    required this.base,
    required this.extent,
  });

  /// The base position of the selection within the document.
  ///
  /// If [base] equals [extent], the selection is collapsed.
  ///
  /// If [base] comes before [extent], the selection is expanded in the
  /// downstream direction.
  ///
  /// If [base] comes after [extent], the selection is expanded in the upstream
  /// direction.
  final DocumentPosition base;

  /// The extent position of the selection within the document.
  ///
  /// If [extent] equals [base], the selection is collapsed.
  ///
  /// If [extent] comes after [base], the selection is expanded in the
  /// downstream direction.
  ///
  /// If [extent] comes before [base], the selection is expanded in the upstream
  /// direction.
  final DocumentPosition extent;

  /// Returns `true` if this selection is collapsed, or `false` if this
  /// selection is expanded.
  ///
  /// A [DocumentSelection] is "collapsed" when its [base] and [extent] are
  /// equal ([DocumentPosition.==]). Otherwise, the [DocumentSelection] is
  /// "expanded".
  bool get isCollapsed => base == extent;

  @override
  String toString() {
    return '[DocumentSelection] - \n  base: ($base),\n  extent: ($extent)';
  }

  /// Returns a version of this that is collapsed at the [extent] position.
  ///
  /// Note, the returned [DocumentSelection] is collapsed at this selection's
  /// [extent], regardless of whether this selection's [extent] comes before or
  /// after its [base].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseUpstream], which collapses the selection in the upstream
  ///    direction relative to the document.
  ///  * [collapseDownstream], which collapses the selection in the downstream
  ///    direction relative to the document.
  DocumentSelection collapse() {
    if (isCollapsed) {
      return this;
    } else {
      return DocumentSelection(
        base: extent,
        extent: extent,
      );
    }
  }

  /// Returns a version of this [DocumentSelection] that is collapsed
  /// in the upstream (start) direction.
  ///
  /// The source [Document] is required so that the upstream [DocumentPosition]
  /// can be selected from [base] and [extent].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseDownstream], which collapses the selection in the downstream
  ///    direction relative to the document.
  ///  * [collapse], which collapses the selection to the extent position.
  DocumentSelection collapseUpstream(Document document) {
    if (isCollapsed) {
      // The selection is already collapsed. Therefore, the collapsed
      // version of this selection is the same as this selection.
      return this;
    }

    final baseNode = document.getNodeById(base.nodeId)!;
    final extentNode = document.getNodeById(extent.nodeId)!;

    if (baseNode == extentNode) {
      // The selection is expanded, but it sits within a single node.
      final upstreamNodePosition = extentNode.selectUpstreamPosition(
        base.nodePosition,
        extent.nodePosition,
      );
      return DocumentSelection.collapsed(
        position: extent.copyWith(nodePosition: upstreamNodePosition),
      );
    }

    return document.getNodeIndex(baseNode) < document.getNodeIndex(extentNode)
        ? DocumentSelection.collapsed(position: base)
        : DocumentSelection.collapsed(position: extent);
  }

  /// Returns a version of this [DocumentSelection] that is collapsed
  /// in the downstream (end) direction.
  ///
  /// The source [Document] is required so that the downstream [DocumentPosition]
  /// can be selected from [base] and [extent].
  ///
  /// See also:
  ///
  ///  * [isCollapsed], which determines whether a selection is collapsed or
  ///    not.
  ///  * [collapseUpstream], which collapses the selection in the upstream
  ///    direction relative to the document.
  ///  * [collapse], which collapses the selection to the extent position.
  DocumentSelection collapseDownstream(Document document) {
    if (isCollapsed) {
      // The selection is already collapsed. Therefore, the collapsed
      // version of this selection is the same as this selection.
      return this;
    }

    final baseNode = document.getNodeById(base.nodeId)!;
    final extentNode = document.getNodeById(extent.nodeId)!;

    if (baseNode == extentNode) {
      // The selection is expanded, but it sits within a single node.
      final downstreamNodePosition = extentNode.selectDownstreamPosition(
        base.nodePosition,
        extent.nodePosition,
      );
      return DocumentSelection.collapsed(
        position: extent.copyWith(nodePosition: downstreamNodePosition),
      );
    }

    return document.getNodeIndex(baseNode) > document.getNodeIndex(extentNode)
        ? DocumentSelection.collapsed(position: base)
        : DocumentSelection.collapsed(position: extent);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelection && runtimeType == other.runtimeType && base == other.base && extent == other.extent;

  @override
  int get hashCode => base.hashCode ^ extent.hashCode;

  /// Creates a new [DocumentSelection] based on the current selection, with the
  /// provided parameters overridden.
  DocumentSelection copyWith({
    DocumentPosition? base,
    DocumentPosition? extent,
  }) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.extent,
    );
  }

  /// Creates a copy of this selection but with the [extent] expanded to the
  /// given new extent.
  ///
  /// This is like calling [copyWith] with the [newExtent] as the new value for
  /// the extent.
  DocumentSelection expandTo(DocumentPosition newExtent) {
    return copyWith(
      extent: newExtent,
    );
  }
}

extension InspectDocumentAffinity on Document {
  TextAffinity getAffinityForSelection(DocumentSelection selection) {
    return getAffinityBetween(base: selection.base, extent: selection.extent);
  }

  /// Returns the affinity direction implied by the given [base] and [extent].
  // TODO: Replace TextAffinity with a DocumentAffinity to avoid confusion.
  TextAffinity getAffinityBetween({
    required DocumentPosition base,
    required DocumentPosition extent,
  }) {
    final baseNode = getNode(base);
    if (baseNode == null) {
      throw Exception('No such position in document: $base');
    }
    final baseIndex = getNodeIndex(getNode(base)!);

    final extentNode = getNode(extent);
    if (extentNode == null) {
      throw Exception('No such position in document: $extent');
    }
    final extentIndex = getNodeIndex(extentNode);

    late TextAffinity affinity;
    if (extentIndex > baseIndex) {
      affinity = TextAffinity.downstream;
    } else if (extentIndex < baseIndex) {
      affinity = TextAffinity.upstream;
    } else {
      // The selection is within the same node. Ask the node which position
      // comes first.
      affinity = extentNode.getAffinityBetween(base: base.nodePosition, extent: extent.nodePosition);
    }

    return affinity;
  }
}

extension InspectDocumentSelection on Document {
  /// Returns a list of all the `DocumentNodes` within the given [selection], ordered
  /// from upstream to downstream.
  List<DocumentNode> getNodesInContentOrder(DocumentSelection selection) {
    final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
    final upstreamIndex = getNodeIndex(getNode(upstreamPosition)!);
    final downstreamPosition = selectDownstreamPosition(selection.base, selection.extent);
    final downstreamIndex = getNodeIndex(getNode(downstreamPosition)!);

    return nodes.sublist(upstreamIndex, downstreamIndex + 1);
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears first in the document.
  DocumentPosition selectUpstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final docPosition1Node = getNodeById(docPosition1.nodeId)!;
    final docPosition1NodeIndex = getNodeIndex(docPosition1Node);
    final docPosition2Node = getNodeById(docPosition2.nodeId)!;
    final docPosition2NodeIndex = getNodeIndex(docPosition2Node);

    if (docPosition1NodeIndex < docPosition2NodeIndex) {
      return docPosition1;
    } else if (docPosition2NodeIndex < docPosition1NodeIndex) {
      return docPosition2;
    }

    // Both document positions are in the same node. Figure out which
    // node position comes first.
    final theNode = docPosition1Node;
    return theNode.selectUpstreamPosition(docPosition1.nodePosition, docPosition2.nodePosition) ==
            docPosition1.nodePosition
        ? docPosition1
        : docPosition2;
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears last in the document.
  DocumentPosition selectDownstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final upstreamPosition = selectUpstreamPosition(docPosition1, docPosition2);
    return upstreamPosition == docPosition1 ? docPosition2 : docPosition1;
  }

  /// Returns `true` if, and only if, the given [position] sits within the
  /// given [selection] in this `Document`.
  bool doesSelectionContainPosition(DocumentSelection selection, DocumentPosition position) {
    if (selection.isCollapsed) {
      return false;
    }

    final baseNode = getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = getNodeIndex(baseNode);
    final extentNode = getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = getNodeIndex(extentNode);

    final upstreamNode = baseNodeIndex < extentNodeIndex ? baseNode : extentNode;
    final upstreamNodeIndex = baseNodeIndex < extentNodeIndex ? baseNodeIndex : extentNodeIndex;
    final downstreamNode = baseNodeIndex < extentNodeIndex ? extentNode : baseNode;
    final downstreamNodeIndex = baseNodeIndex < extentNodeIndex ? extentNodeIndex : baseNodeIndex;

    final positionNodeIndex = getNodeIndex(getNodeById(position.nodeId)!);

    if (upstreamNodeIndex < positionNodeIndex && positionNodeIndex < downstreamNodeIndex) {
      // The given position is sandwiched between two other nodes that form
      // the bounds of the selection. Therefore, the position is definitely within
      // the selection.
      return true;
    }

    if (positionNodeIndex == upstreamNodeIndex) {
      final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
      final downstreamPosition = upstreamPosition == selection.base ? selection.extent : selection.base;

      // This is the furthest a position could sit in the upstream node
      // and still contain the given position. Keep in mind that the
      // upstream position, downstream position, and given position may
      // all reside in the same node (in fact, they probably do).
      final downstreamCap =
          upstreamNodeIndex == downstreamNodeIndex ? downstreamPosition.nodePosition : upstreamNode.endPosition;

      // If and only if the given position comes after the upstream position,
      // and before the downstream cap, then the position is within the selection.
      return upstreamNode.selectDownstreamPosition(upstreamPosition.nodePosition, position.nodePosition) ==
          upstreamNode.selectUpstreamPosition(position.nodePosition, downstreamCap);
    }

    if (positionNodeIndex == downstreamNodeIndex) {
      final upstreamPosition = selectUpstreamPosition(selection.base, selection.extent);
      final downstreamPosition = upstreamPosition == selection.base ? selection.extent : selection.base;

      // This is the furthest upstream that a position could sit in the
      // downstream node and still contain the given position. Keep in
      // mind that the upstream position, downstream position, and given
      // position may all reside in the same node (in fact, they probably do).
      final upstreamCap =
          downstreamNodeIndex == upstreamNodeIndex ? upstreamPosition.nodePosition : downstreamNode.beginningPosition;

      // If and only if the given position comes before the downstream position,
      // and after the upstream cap, then the position is within the selection.
      return downstreamNode.selectDownstreamPosition(upstreamCap, position.nodePosition) ==
          downstreamNode.selectUpstreamPosition(position.nodePosition, downstreamPosition.nodePosition);
    }

    // If we got here, then the position is either before the upstream
    // selection boundary, or after the downstream selection boundary.
    // Either way, the position is not in the selection.
    return false;
  }
}
