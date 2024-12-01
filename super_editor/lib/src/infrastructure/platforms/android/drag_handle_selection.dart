import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// A strategy for selecting text while the user is dragging a drag handle,
/// similar to how the Android OS selects text during a handle drag.
///
/// The following behaviors are implemented:
///
/// - When the user drags a downstream handle in downstream direction,
///   the selection expands by word.
///
/// - When the user drags a downstream handle in upstream direction,
///   the selection expands by character.
///
/// - When the user drags an upstream handle in upstream direction,
///   the selection expands by word.
///
/// - When the user drags an upstream handle in downstream direction,
///   the selection expands by character.
///
/// - When the user drags a collapsed handle, the selection is placed
///   at the drag handle focal point.
class AndroidTextFieldDragHandleSelectionStrategy {
  AndroidTextFieldDragHandleSelectionStrategy({
    required Document document,
    required DocumentLayout documentLayout,
    required void Function(DocumentSelection) select,
  })  : _document = document,
        _docLayout = documentLayout,
        _select = select;

  final Document _document;
  final DocumentLayout _docLayout;
  final void Function(DocumentSelection) _select;

  DocumentSelection? _lastSelection;

  /// The last position pointed by the drag handle.
  DocumentPosition? _lastFocalPosition;

  /// Whether the user is dragging upstream or downstream.
  TextAffinity? _currentDragDirection;

  /// The current focal point of the drag handle, in content space.
  ///
  /// This is the center of the [DocumentPosition] that the drag handle points to.
  Offset? _currentFocalPoint;

  /// The drag handle used to start the gesture.
  HandleType? _dragHandleType;

  /// The effective drag handle type based on the selection affinity.
  ///
  /// When the user the starts dragging a handle and causes the selection
  /// to invert the affinity, for example, dragging the extent handle until the
  /// extent position is upstream of the base position, the downstream handle
  /// will behave as if it were the upstream handle, i.e., it will select by word
  /// upstream and by character downstream.
  HandleType? _effectiveDragHandleType;

  /// Whether the user is selecting by character or by word.
  _SelectionModifier? _selectionModifier;

  /// Clients should call this method when a drag handle gesture is initially recognized.
  void onHandlePanStart(DragStartDetails details, DocumentSelection initialSelection, HandleType handleType) {
    _lastSelection = initialSelection;

    if (handleType == HandleType.collapsed && !_lastSelection!.isCollapsed) {
      throw Exception("Tried to drag a collapsed Android handle but the selection is expanded.");
    }
    if (handleType != HandleType.collapsed && _lastSelection!.isCollapsed) {
      throw Exception("Tried to drag an expanded Android handle but the selection is collapsed.");
    }
    _dragHandleType = handleType;

    final isSelectionDownstream = initialSelection.hasDownstreamAffinity(_document);
    late final DocumentPosition selectionBoundPosition;
    if (isSelectionDownstream) {
      selectionBoundPosition = handleType == HandleType.upstream ? initialSelection.base : initialSelection.extent;
    } else {
      selectionBoundPosition = handleType == HandleType.upstream ? initialSelection.extent : initialSelection.base;
    }

    _currentFocalPoint = _docLayout.getAncestorOffsetFromDocumentOffset(
      _docLayout.getRectForPosition(selectionBoundPosition)!.center,
    );

    _dragHandleType = handleType;
    _effectiveDragHandleType = _dragHandleType;
    _lastFocalPosition = selectionBoundPosition;
  }

  /// Clients should call this method when a drag handle gesture is updated.
  void onHandlePanUpdate(DragUpdateDetails details) {
    _currentFocalPoint = _currentFocalPoint! + details.delta;

    final nearestPosition = _docLayout.getDocumentPositionNearestToOffset(
      _docLayout.getDocumentOffsetFromAncestorOffset(_currentFocalPoint!),
    );
    if (nearestPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.collapsed) {
      // A collapsed handle always produces a collapsed selection.
      _lastSelection = DocumentSelection.collapsed(position: nearestPosition);
      _select(_lastSelection!);
      return;
    }

    final isOverNonTextNode = nearestPosition.nodePosition is! TextNodePosition;
    if (isOverNonTextNode) {
      // Don't change selection if the user long-presses over a non-text node and then
      // moves the finger over the same node. This prevents the selection from collapsing
      // when the user moves the finger towards the starting edge of the node.
      if (nearestPosition.nodeId != _lastSelection!.base.nodeId) {
        // The user is dragging over content that isn't text, therefore it doesn't have
        // a concept of "words". Select the whole node.
        _select(_lastSelection!.expandTo(nearestPosition));
      }
      return;
    }

    final nearestPositionTextOffset = (nearestPosition.nodePosition as TextNodePosition).offset;
    final previousNearestPositionTextOffset = (_lastFocalPosition!.nodePosition as TextNodePosition).offset;

    final didFocalPointStayInSameNode = _lastFocalPosition!.nodeId == nearestPosition.nodeId;

    final didFocalPointMoveToDownstreamNode = _document.getAffinityBetween(
              base: _lastFocalPosition!,
              extent: nearestPosition,
            ) ==
            TextAffinity.downstream &&
        !didFocalPointStayInSameNode;

    final didFocalPointMoveToUpstreamNode = _document.getAffinityBetween(
              base: _lastFocalPosition!,
              extent: nearestPosition,
            ) ==
            TextAffinity.upstream &&
        !didFocalPointStayInSameNode;

    final didFocalPointMoveDownstream = didFocalPointMoveToDownstreamNode ||
        (didFocalPointStayInSameNode && nearestPositionTextOffset > previousNearestPositionTextOffset) ||
        (didFocalPointStayInSameNode && details.delta.dx > 0);

    final didFocalPointMoveUpstream = didFocalPointMoveToUpstreamNode ||
        (didFocalPointStayInSameNode && nearestPositionTextOffset < previousNearestPositionTextOffset) ||
        (didFocalPointStayInSameNode && details.delta.dx < 0);

    _lastFocalPosition = nearestPosition;

    if (_currentDragDirection == null) {
      // The user just started dragging the handle.
      _currentDragDirection = didFocalPointMoveDownstream ? TextAffinity.downstream : TextAffinity.upstream;

      if (_dragHandleType == HandleType.upstream && didFocalPointMoveUpstream) {
        _selectionModifier = _SelectionModifier.word;
      } else if (_dragHandleType == HandleType.downstream && didFocalPointMoveDownstream) {
        _selectionModifier = _SelectionModifier.word;
      } else {
        _selectionModifier = _SelectionModifier.character;
      }
    } else {
      // Check if the user started dragging the handle in the opposite direction.
      late TextAffinity newDragDirection;
      if (_currentDragDirection == TextAffinity.upstream) {
        newDragDirection = didFocalPointMoveDownstream ? TextAffinity.downstream : TextAffinity.upstream;
      } else {
        newDragDirection = didFocalPointMoveUpstream ? TextAffinity.upstream : TextAffinity.downstream;
      }

      // Invert the drag handle type if the selection has upstream affinity.
      final newEffectiveHandleType = _lastSelection!.hasDownstreamAffinity(_document) //
          ? _dragHandleType!
          : (_dragHandleType == HandleType.upstream ? HandleType.downstream : HandleType.upstream);

      if (newDragDirection != _currentDragDirection || newEffectiveHandleType != _effectiveDragHandleType) {
        _currentDragDirection = newDragDirection;
        _effectiveDragHandleType = newEffectiveHandleType;

        if (_effectiveDragHandleType == HandleType.downstream && newDragDirection == TextAffinity.downstream) {
          _selectionModifier = _SelectionModifier.word;
        } else if (_effectiveDragHandleType == HandleType.upstream && newDragDirection == TextAffinity.upstream) {
          _selectionModifier = _SelectionModifier.word;
        } else {
          _selectionModifier = _SelectionModifier.character;
        }
      }
    }

    final rangeToExpandSelection = _selectionModifier == _SelectionModifier.word
        ? _dragHandleType == _effectiveDragHandleType
            ? getWordSelection(docPosition: nearestPosition, docLayout: _docLayout)
            : _flipSelection(getWordSelection(docPosition: nearestPosition, docLayout: _docLayout)!)
        : DocumentSelection.collapsed(position: nearestPosition);

    if (rangeToExpandSelection != null) {
      _lastSelection = _lastSelection!.copyWith(
        base: _dragHandleType == HandleType.upstream ? rangeToExpandSelection.base : _lastSelection!.base,
        extent: _dragHandleType == HandleType.downstream ? rangeToExpandSelection.extent : _lastSelection!.extent,
      );
      _select(_lastSelection!);
    }
  }

  /// Invert the selection so that the base and extent are swapped.
  DocumentSelection _flipSelection(DocumentSelection selection) {
    return selection.copyWith(
      base: selection.extent,
      extent: selection.base,
    );
  }
}

enum _SelectionModifier {
  character,
  word,
}
