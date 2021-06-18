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

  /// Creates a selection from the [base] position to the [extent] position
  /// within the document.
  DocumentSelection({
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

  /// The ID of the node that is selected.
  final String nodeId;

  /// The selection within the given node.
  final SelectionType? nodeSelection;

  /// `true` if this [DocumentNodeSelection] forms the base position of a larger
  /// document selection, `false` otherwise.
  ///
  /// If the node that [DocumentSelection.base] points to is equal to the node
  /// that [nodeId] points to, [isBase] is `true`. Otherwise, it is `false`.
  final bool isBase;

  /// `true` if this [DocumentNodeSelection] forms the extent position of a
  /// larger document selection, `false` otherwise.
  ///
  /// If the node that [DocumentSelection.extent] points to is equal to the node
  /// that [nodeId] points to, [isExtent] is `true`. Otherwise, it is `false`.
  final bool isExtent;

  /// [true] if the component rendering this [DocumentNodeSelection] should
  /// paint a highlight even when the given node has no content, [false]
  /// otherwise.
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
