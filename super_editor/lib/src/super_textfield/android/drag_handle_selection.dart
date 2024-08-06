import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_text_layout/super_text_layout.dart';

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
class AndroidDocumentDragHandleSelectionStrategy {
  AndroidDocumentDragHandleSelectionStrategy({
    required GlobalKey textContentKey,
    required ProseTextLayout textLayout,
    required void Function(TextSelection) select,
  })  : _textContentKey = textContentKey,
        _textLayout = textLayout,
        _select = select;

  final GlobalKey _textContentKey;
  final ProseTextLayout _textLayout;
  final void Function(TextSelection) _select;

  TextSelection? _lastSelection;

  /// The last position pointed by the drag handle.
  TextPosition? _lastFocalPosition;

  /// Whether the user is dragging upstream or downstream.
  TextAffinity? _currentDragDirection;

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
  void onHandlePanStart(DragStartDetails details, TextSelection initialSelection, HandleType handleType) {
    if (handleType == HandleType.collapsed && !initialSelection.isCollapsed) {
      throw Exception("Tried to drag a collapsed Android handle but the selection is expanded.");
    }
    if (handleType != HandleType.collapsed && initialSelection.isCollapsed) {
      throw Exception("Tried to drag an expanded Android handle but the selection is collapsed.");
    }

    final globalOffsetInMiddleOfLine = _getGlobalOffsetOfMiddleOfLine(initialSelection.base);
    final touchHandleOffsetFromLineOfText = globalOffsetInMiddleOfLine - details.globalPosition;

    final textBox = (_textContentKey.currentContext!.findRenderObject() as RenderBox);
    final textOffset = textBox.globalToLocal(details.globalPosition + touchHandleOffsetFromLineOfText);

    _dragHandleType = handleType;

    _lastFocalPosition = _textLayout.getPositionNearestToOffset(textOffset);
    _lastSelection = initialSelection;
  }

  /// Clients should call this method when a drag handle gesture is updated.
  void onHandlePanUpdate(Offset handleFocalPoint) {
    final nearestPosition = _textLayout.getPositionNearestToOffset(handleFocalPoint);
    if (nearestPosition.offset < 0) {
      return;
    }

    if (_dragHandleType == HandleType.collapsed) {
      // A collapsed handle always produces a collapsed selection.
      _lastSelection = TextSelection.collapsed(offset: nearestPosition.offset);
      _select(_lastSelection!);
      return;
    }

    final nearestPositionTextOffset = nearestPosition.offset;
    final previousNearestPositioTextOffset = _lastFocalPosition!.offset;

    final didFocalPointMoveDownstream = nearestPositionTextOffset > previousNearestPositioTextOffset;
    final didFocalPointMoveUpstream = nearestPositionTextOffset < previousNearestPositioTextOffset;

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
        newDragDirection = didFocalPointMoveDownstream //
            ? TextAffinity.downstream
            : TextAffinity.upstream;
      } else {
        newDragDirection = didFocalPointMoveUpstream //
            ? TextAffinity.upstream
            : TextAffinity.downstream;
      }

      // Invert the drag handle type if the selection has upstream affinity.
      final newEffectiveHandleType = _lastSelection!.baseOffset < _lastSelection!.extentOffset
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
            ? _textLayout.getWordSelectionAt(nearestPosition)
            : _flipSelection(_textLayout.getWordSelectionAt(nearestPosition))
        : TextSelection.collapsed(offset: nearestPosition.offset);

    if (rangeToExpandSelection.isValid) {
      _lastSelection = _lastSelection!.copyWith(
        baseOffset: _dragHandleType == HandleType.upstream //
            ? rangeToExpandSelection.baseOffset
            : _lastSelection!.baseOffset,
        extentOffset: _dragHandleType == HandleType.downstream
            ? rangeToExpandSelection.extentOffset
            : _lastSelection!.extentOffset,
      );
      _select(_lastSelection!);
    }

    if (rangeToExpandSelection.isValid) {
      _lastSelection = _lastSelection!.copyWith(
        baseOffset:
            _dragHandleType == HandleType.upstream ? rangeToExpandSelection.baseOffset : _lastSelection!.baseOffset,
        extentOffset: _dragHandleType == HandleType.downstream
            ? rangeToExpandSelection.extentOffset
            : _lastSelection!.extentOffset,
      );
      _select(_lastSelection!);
    }
  }

  Offset _getGlobalOffsetOfMiddleOfLine(TextPosition position) {
    // TODO: can we de-dup this ?
    final textLayout = _textLayout;
    final extentOffsetInText = textLayout.getOffsetAtPosition(position);
    final extentLineHeight = textLayout.getCharacterBox(position)?.toRect().height ?? textLayout.estimatedLineHeight;
    final extentGlobalOffset =
        (_textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(extentOffsetInText);

    return extentGlobalOffset + Offset(0, extentLineHeight / 2);
  }

  /// Invert the selection so that the base and extent are swapped.
  TextSelection _flipSelection(TextSelection selection) {
    return selection.copyWith(
      baseOffset: selection.extentOffset,
      extentOffset: selection.baseOffset,
    );
  }
}

enum _SelectionModifier {
  character,
  word,
}
