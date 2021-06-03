import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/super_selectable_text.dart';

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

  /// Creates a selection from the [base] position and [extent] position within
  /// the document.
  DocumentSelection({
    required this.base,
    required this.extent,
  });

  /// The base position of the selection within the document.
  ///
  /// If the [base] position comes before the [extent] position within the
  /// document and the specific node that the position points to, the selection
  /// is in the downstream direction.
  /// If the [base] position and [extent] position are equal, the selection is
  /// collapsed (see [isCollapsed] for details).
  /// Otherwise, the selection is in the upstream direction.
  final DocumentPosition base;

  /// The extent position of the selection within the document.
  ///
  /// If the [extent] position comes before the [base] position within the
  /// document and the specific node that the position points to, the selection
  /// is in the upstream direction.
  /// If the [extent] position and [base] position are equal, the selection is
  /// collapsed (see [isCollapsed] for details).
  /// Otherwise, the selection is in the downstream direction.
  final DocumentPosition extent;

  /// Whether this selection is collapsed or not.
  ///
  /// A collapsed document selection is one where the [base] position and
  /// [extent] position are identical ([DocumentPosition.==] to be precise).
  /// Semantically, a collapsed selection represents a single position and can
  /// be understood as *nothing being selected*, i.e. the cursor not having
  /// highlighted any node or character.
  ///
  /// A selection is **not collapsed** when the [base] and [extent] point to the
  /// same node but only when they point to the same node **and** also point
  /// to the same node-specific [DocumentPosition.nodePosition]. This means that
  /// in a [ParagraphNode] e.g., the offset of the text position must also be
  /// the same for the selection to be collapsed.
  bool get isCollapsed => base == extent;

  @override
  String toString() {
    return '[DocumentSelection] - \n  base: ($base),\n  extent: ($extent)';
  }

  /// Returns a version of this that is collapsed at the [extent] position.
  ///
  /// If this selection is already collapsed, returns this instance (i.e. the
  /// [identical] object).
  ///
  /// Note that the relative position within the document does not play a role
  /// in this case, i.e. the selection is always collapsed to the [extent]
  /// position, regardless of whether it comes before or after the [base]
  /// position.
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
  /// If this selection is already collapsed, returns this instance (i.e. the
  /// [identical] object).
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
  /// If this selection is already collapsed, returns this instance (i.e. the
  /// [identical] object).
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

  /// Creates a copy of this selection but with the given fields replaced with
  /// the new values.
  DocumentSelection copyWith({
    DocumentPosition? base,
    DocumentPosition? extent,
  }) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.base,
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

/// Description of a selection within a specific node in a document.
///
/// The [nodeSelection] only describes the selection in the particular node
/// that [nodeId] points to. The document might have a selection that spans
/// multiple nodes but this only regards the part of that total selection that
/// affects the single node.
///
/// The [SelectionType] is a generic subtype of [NodeSelection], i.e. for
/// example a [TextNodeSelection] that describes which characters of text are
/// selected within the text node.
class DocumentNodeSelection<SelectionType extends NodeSelection> {
  /// Creates a node selection for a particular node in the document.
  DocumentNodeSelection({
    required this.nodeId,
    required this.nodeSelection,
    this.isBase = false,
    this.isExtent = false,
    // TODO: either remove highlightWhenEmpty from this class, or move
    //       this class to a different place. Visual preferences don't
    //       belong here. (#52)
    this.highlightWhenEmpty = false,
  });

  /// ID that points to the single node that the selection describes about.
  final String nodeId;

  /// The actual node-specific selection data.
  final SelectionType? nodeSelection;

  /// Whether this node selection is base in the context of the surrounding
  /// [DocumentSelection].
  ///
  /// If the node that [DocumentSelection.base] points to is equal to the node
  /// that [nodeId] points to, [isBase] is `true`. Otherwise, it is `false`.
  final bool isBase;

  /// Whether this node selection is extent in the context of the surrounding
  /// [DocumentSelection].
  ///
  /// If the node that [DocumentSelection.extent] points to is equal to the node
  /// that [nodeId] points to, [isExtent] is `true`. Otherwise, it is `false`.
  final bool isExtent;

  /// Whether a thin selection highlight should be shown when the text is empty,
  /// or false to avoid showing a selection highlight.
  ///
  /// TODO: this is out-of-place here and should be removed.
  ///
  /// See also:
  ///
  ///  * [SuperSelectableText.highlightWhenEmpty], which the value of this field
  ///    is indirectly passed to.
  final bool highlightWhenEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNodeSelection &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          nodeSelection == other.nodeSelection;

  @override
  int get hashCode => nodeId.hashCode ^ nodeSelection.hashCode;

  @override
  String toString() {
    return '[DocumentNodeSelection] - node: "$nodeId", selection: ($nodeSelection)';
  }
}
