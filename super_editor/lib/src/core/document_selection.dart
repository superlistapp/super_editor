import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

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

    return document.getNodeIndexById(baseNode.id) < document.getNodeIndexById(extentNode.id)
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

    return document.getNodeIndexById(baseNode.id) > document.getNodeIndexById(extentNode.id)
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
    final baseIndex = getNodeIndexById(baseNode.id);

    final extentNode = getNode(extent);
    if (extentNode == null) {
      throw Exception('No such position in document: $extent');
    }
    final extentIndex = getNodeIndexById(extentNode.id);

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
    final upstreamIndex = getNodeIndexById(upstreamPosition.nodeId);
    final downstreamPosition = selectDownstreamPosition(selection.base, selection.extent);
    final downstreamIndex = getNodeIndexById(downstreamPosition.nodeId);

    return nodes.sublist(upstreamIndex, downstreamIndex + 1);
  }

  /// Given [docPosition1] and [docPosition2], returns the `DocumentPosition` that
  /// appears first in the document.
  DocumentPosition selectUpstreamPosition(DocumentPosition docPosition1, DocumentPosition docPosition2) {
    final docPosition1Node = getNodeById(docPosition1.nodeId)!;
    final docPosition1NodeIndex = getNodeIndexById(docPosition1Node.id);
    final docPosition2Node = getNodeById(docPosition2.nodeId)!;
    final docPosition2NodeIndex = getNodeIndexById(docPosition2Node.id);

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
    final baseNodeIndex = getNodeIndexById(baseNode.id);
    final extentNode = getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = getNodeIndexById(extentNode.id);

    final upstreamNode = baseNodeIndex < extentNodeIndex ? baseNode : extentNode;
    final upstreamNodeIndex = baseNodeIndex < extentNodeIndex ? baseNodeIndex : extentNodeIndex;
    final downstreamNode = baseNodeIndex < extentNodeIndex ? extentNode : baseNode;
    final downstreamNodeIndex = baseNodeIndex < extentNodeIndex ? extentNodeIndex : baseNodeIndex;

    final positionNodeIndex = getNodeIndexById(position.nodeId);

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

/// A [DocumentChangeEvent] that represents a change to the user's selection within a document.
class SelectionChangeEvent implements DocumentChangeEvent {
  const SelectionChangeEvent(this.newSelection);

  final DocumentSelection? newSelection;

  @override
  String toString() => "[SelectionChangeEvent] - New selection: $newSelection";
}

/// A selection, along with tools to change the selection, and listen for
/// selection changes.
///
/// A [SelectionComponent] provides a drop-in solution for to hold, change,
/// and monitor selection changes. A [SelectionComponent] could be used, for example,
/// within a document composer, which tracks selection along with other transient
/// editor settings. On the other side, a document mouse interactor might take
/// a [SelectionComponent] as a property, so that the document mouse interactor can
/// monitor selection changes, as well as change the current selection.
class SelectionComponent {
  SelectionComponent([DocumentSelection? initialSelection]) {
    _streamController = StreamController<DocumentSelectionChange>.broadcast();
    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);
    selectionNotifier.value = initialSelection;
  }

  void dispose() {
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);
  }

  /// Returns the current [DocumentSelection] for a [Document].
  DocumentSelection? get selection => selectionNotifier.value;

  /// Sets the current [selection] for a [Document] using [SelectionReason.userInteraction] as the reason.
  @Deprecated("Use updateSelectionWithoutNotification instead, and then call notifySelectionListener")
  set selection(DocumentSelection? newSelection) {
    selectionNotifier.value = newSelection;
    _streamController.add(
      DocumentSelectionChange(
        selection: newSelection,
        reason: SelectionReason.userInteraction,
      ),
    );
  }

  /// Sets the current [selection] for a [Document], with the given [reason]
  /// for the change.
  ///
  /// The default [reason] is [SelectionReason.userInteraction].
  void setSelectionWithReason(DocumentSelection? newSelection, [Object reason = SelectionReason.userInteraction]) {
    _latestSelectionChange = DocumentSelectionChange(
      selection: newSelection,
      reason: reason,
    );
    _streamController.sink.add(_latestSelectionChange);

    // Remove the listener, so we don't emit another DocumentSelectionChange.
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);

    // Updates the selection, so both _latestSelectionChange and selectionNotifier are in sync.
    selectionNotifier.value = newSelection;

    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);
  }

  /// Returns the reason for the most recent selection change in the composer.
  ///
  /// For example, a selection might change as a result of user interaction, or as
  /// a result of another user editing content, or some other reason.
  Object? get latestSelectionChangeReason => _latestSelectionChange.reason;

  /// Returns the most recent selection change in the composer.
  ///
  /// The [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  DocumentSelectionChange get latestSelectionChange => _latestSelectionChange;
  late DocumentSelectionChange _latestSelectionChange;

  /// A stream of document selection changes.
  ///
  /// Each new [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  ///
  /// Listen to this [Stream] when the selection reason is needed. Otherwise, use [selectionNotifier].
  Stream<DocumentSelectionChange> get selectionChanges => _streamController.stream;
  late StreamController<DocumentSelectionChange> _streamController;

  /// Notifies whenever the current [DocumentSelection] changes.
  ///
  /// If the selection change reason is needed, use [selectionChanges] instead.
  final selectionNotifier = ValueNotifier<DocumentSelection?>(null);

  void updateSelection(DocumentSelection? newSelection, {bool notifyListeners = false}) {
    _latestSelectionChange = DocumentSelectionChange(
      selection: newSelection,
      reason: SelectionReason.userInteraction,
    );

    if (notifyListeners) {
      notifySelectionListeners();
    }
  }

  void notifySelectionListeners() {
    selectionNotifier.value = _latestSelectionChange.selection;
    _streamController.add(_latestSelectionChange);
  }

  /// Clears the current [selection].
  void clearSelection() {
    updateSelection(null, notifyListeners: true);
  }

  void _onSelectionChangedBySelectionNotifier() {
    _latestSelectionChange = DocumentSelectionChange(
      selection: selectionNotifier.value,
      reason: SelectionReason.userInteraction,
    );
    _streamController.sink.add(_latestSelectionChange);
  }
}

/// Represents a change of a [DocumentSelection].
///
/// The [reason] represents what cause the selection to change.
/// For example, [SelectionReason.userInteraction] represents
/// a selection change caused by the user interacting with the editor.
class DocumentSelectionChange {
  DocumentSelectionChange({
    required this.selection,
    required this.reason,
  });

  final DocumentSelection? selection;
  final Object reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelectionChange && selection == other.selection && reason == other.reason;

  @override
  int get hashCode => (selection?.hashCode ?? 0) ^ reason.hashCode;
}

/// Holds common reasons for selection changes.
/// Developers aren't limited to these selection change reasons. Any object can be passed as
/// a reason for a selection change. However, some Super Editor behavior is based on [userInteraction].
class SelectionReason {
  /// Represents a change caused by an user interaction.
  static const userInteraction = "userInteraction";

  /// Represents a changed caused by an event which was not initiated by the user.
  static const contentChange = "contentChange";
}
