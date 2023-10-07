import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/composable_text.dart';

/// A strategy for selecting text during a long-press drag gesture, similar to
/// how the Android OS selects text during a long-press drag.
///
/// This strategy is made to operate over a document layout.
///
/// This strategy isn't identical to the Android OS behavior, but it's very similar.
///
/// Differences:
///
///   * Android lets the user collapse the initial word selection when selecting
///     in one direction, and then selecting in the other. This strategy always
///     keeps the initial word selection, regardless of whether the user initially
///     drags in one direction and then reverses back and crosses to the other
///     side of the initial word.
///
///   * Android selects a word when the user selects at least half way into the word.
///     This strategy selects the word as soon as the user selects any part of the
///     word.
///
///   * Android seems to maintain a virtual selection offset, which can be different
///     from the finger position. This is easy to see when the user initially selects
///     by word, and then reverses direction to select by character. The placement of
///     the virtual selection offset, as compared to the finger offset, is different
///     depending on whether the user is pulling back by character, or pushing forward
///     by character.
///
///       * This strategy attempts to match Android's virtual selection offset when the
///         user pulls back from per-word selection and begins per-character selection.
///
///       * When the user starts pushing forward again, after previously pulling back
///         for per-character selection, this strategy waits until the user exceeds
///         the current word boundary and then switches back to per-word selection.
///         This is different from Android, which applies some kind of heuristic to
///         begin pushing the selection forward before the user's finger reaches the
///         edge of the word.
///
class AndroidDocumentLongPressSelectionStrategy {
  AndroidDocumentLongPressSelectionStrategy({
    required Document document,
    required DocumentLayout documentLayout,
    required ScrollPosition scrollPosition,
    required void Function(DocumentSelection) select,
  })  : _document = document,
        _docLayout = documentLayout,
        _scrollPosition = scrollPosition,
        _select = select;

  final Document _document;
  final DocumentLayout _docLayout;
  final ScrollPosition _scrollPosition;
  final void Function(DocumentSelection) _select;

  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;

  /// The word the user initially selects upon long-pressing.
  DocumentSelection? _longPressInitialSelection;

  /// The node where the user's finger was dragging most recently.
  String? _longPressMostRecentBoundaryNodeId;

  /// The direction of the user's current selection in relation to the initial word selection.
  TextAffinity? _longPressSelectionDirection;

  /// The most recent select-by-word boundary in the upstream direction.
  ///
  /// Initially, a long-press drag selects the word under the users finger as the
  /// user drags upstream. The user can drag in the opposite direction (downstream)
  /// to begin selecting by character, instead of by word. However, once the user
  /// switches back to the original upstream drag direction, and the user passes
  /// this boundary, the selection mode returns to per-word selection.
  ///
  /// As the user selects words, this boundary is set to the edge of the selected
  /// word that's furthest from the initial selection. When the user drags in reverse
  /// and selects characters, this boundary moves back to the upstream edge of
  /// whichever word contains the characters that the user is currently selecting.
  ///
  /// Examples of boundary movement:
  ///  - "[" and "]" are selection bounds
  ///  - "|" is the upstream word boundary
  ///  - "*" is a stationary finger
  ///  - "*--" is a finger moving upstream
  ///  - "--*" is a finger moving downstream
  ///
  /// ```
  ///   one two three four five six seven
  ///                [ * ]
  ///
  ///   one two three four five six seven
  ///          |[  *--   ]                <- selection by word
  ///
  ///   one two three four five six seven
  ///      |[ *          ]                <- selection by word
  ///
  ///   one two three four five six seven
  ///      |  [--*       ]                <- selection by character
  ///
  ///   one two three four five six seven
  ///          |  [--*   ]                <- selection by character
  ///
  ///   one two three four five six seven
  ///          |    [  * ]
  ///
  ///   one two three four five six seven
  ///          | [ *--   ]                <- selection by character
  ///
  ///   one two three four five six seven
  ///      |[   *--      ]                <- selection by word
  ///
  ///   one two three four five six seven
  ///      |[ *--        ]                <- selection by word
  ///
  ///   one two three four five six seven
  ///  |[ *              ]
  /// ```
  int? _longPressMostRecentUpstreamWordBoundary;

  /// The most recent select-by-word boundary in the downstream direction.
  ///
  /// See [_longPressMostRecentUpstreamWordBoundary] for move info.
  int? _longPressMostRecentDownstreamWordBoundary;

  /// Whether the user is currently selecting by character, or by word.
  bool _isSelectingByCharacter = false;

  /// The [DocumentPosition] that the user most recently touched with the
  /// long-press finger.
  DocumentPosition? _longPressMostRecentTouchDocumentPosition;

  /// When dragging by word, this value is `0`, when dragging by character,
  /// this is the horizontal offset between the user's finger and the
  /// [_longPressMostRecentUpstreamWordBoundary] or the
  /// [_longPressMostRecentDownstreamWordBoundary] when the user switched to
  /// dragging by character.
  ///
  /// This offset is used, during character selection, to select text that's
  /// some distance away from the user's finger. The closer the user's finger
  /// is to the edge of a word, before going into character selection mode,
  /// the shorter this distance will be. If the user's finger sits directly on
  /// the edge of a word before going into character selection mode, this
  /// value will be near zero, and the visual effect will be unnoticeable.
  double _longPressCharacterSelectionXOffset = 0;

  /// Clients should call this method when a long press gesture is initially
  /// recognized.
  ///
  /// Returns `true` if a long-press selected started, or `false` if the user's
  /// press didn't occur over selectable content.
  bool onLongPressStart({
    required Offset globalTapDownOffset,
  }) {
    editorLongPressSelectionLog.fine("Long press start");
    final docOffset = _getDocOffsetFromGlobalOffset(globalTapDownOffset);
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    if (docPosition == null) {
      editorLongPressSelectionLog.finer("No doc position where the user pressed");
      return false;
    }

    _globalDragOffset = globalTapDownOffset;
    _longPressInitialSelection = getWordSelection(docPosition: docPosition, docLayout: _docLayout);
    _select(_longPressInitialSelection!);

    // Initially, the word vs character selection bound tracking is set equal to
    // the word boundaries of the first selected word.
    editorLongPressSelectionLog
        .finer("Setting initial long-press upstream bound to: ${_longPressInitialSelection!.start}");
    _longPressMostRecentBoundaryNodeId = _longPressInitialSelection!.start.nodeId;
    _longPressMostRecentUpstreamWordBoundary =
        (_longPressInitialSelection!.start.nodePosition as TextNodePosition).offset;
    _longPressMostRecentDownstreamWordBoundary =
        (_longPressInitialSelection!.end.nodePosition as TextNodePosition).offset;

    return true;
  }

  /// Clients should call this method when an existing long-press gesture first
  /// begins to pan.
  ///
  /// Upon long-press pan movements, clients should call [onLongPressDragUpdate].
  void onLongPressDragStart(DragStartDetails details) {
    _globalStartDragOffset = details.globalPosition;
    _dragStartInDoc = _getDocOffsetFromGlobalOffset(details.globalPosition);

    // User is long-press dragging. The start drag offset is wherever the user touched.
    _startDragPositionOffset = _dragStartInDoc!;

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = _scrollPosition.pixels;
  }

  Offset _getDocOffsetFromGlobalOffset(Offset globalOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  /// Clients should call this method whenever a long-press gesture pans, after
  /// initially calling [onLongPressStart].
  void onLongPressDragUpdate(DragUpdateDetails details) {
    editorLongPressSelectionLog.finer("----------------------------------------------");
    editorLongPressSelectionLog.finer("Long press drag update - ${details.globalPosition}");
    _globalDragOffset = details.globalPosition;

    final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final scrollDelta = _dragStartScrollOffset! - _scrollPosition.pixels;
    final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
    final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
      _startDragPositionOffset! + fingerDragDelta - Offset(0, scrollDelta),
    );
    if (fingerDocumentPosition == null) {
      return;
    }

    final isOverNonTextNode = fingerDocumentPosition.nodePosition is! TextNodePosition;
    if (isOverNonTextNode) {
      // The user is dragging over content that isn't text, therefore it doesn't have
      // a concept of "words". Select the whole node.
      editorLongPressSelectionLog.finer("Dragging over non-text node. Selecting the whole node.");
      _select(_longPressInitialSelection!.expandTo(fingerDocumentPosition));
      return;
    }

    final focalPointDocumentOffset = !_isSelectingByCharacter
        ? fingerDocumentOffset
        : fingerDocumentOffset + Offset(_longPressCharacterSelectionXOffset, 0);
    final focalPointDocumentPosition = !_isSelectingByCharacter
        ? fingerDocumentPosition
        : _docLayout.getDocumentPositionNearestToOffset(focalPointDocumentOffset)!;

    final fingerIsInInitialWord =
        _document.doesSelectionContainPosition(_longPressInitialSelection!, focalPointDocumentPosition);
    if (fingerIsInInitialWord) {
      editorLongPressSelectionLog.finer("Dragging in the initial word.");
      _onLongPressFingerIsInInitialWord(details);
      return;
    }

    final componentUnderFinger = _docLayout.getComponentByNodeId(fingerDocumentPosition.nodeId);
    final textComponent = componentUnderFinger is TextComponentState
        ? componentUnderFinger
        : (componentUnderFinger as ProxyTextComposable) as TextComponentState;
    final fingerTextOffset = (fingerDocumentPosition.nodePosition as TextNodePosition).offset;
    final initialSelectionStartOffset = (_longPressInitialSelection!.base.nodePosition as TextNodePosition).offset;
    final initialSelectionEndOffset = (_longPressInitialSelection!.end.nodePosition as TextNodePosition).offset;
    final mostRecentBoundaryTextOffset = _longPressSelectionDirection == TextAffinity.upstream
        ? _longPressMostRecentUpstreamWordBoundary ?? initialSelectionStartOffset
        : _longPressMostRecentDownstreamWordBoundary ?? initialSelectionEndOffset;
    final fingerLine = textComponent.getPositionAtStartOfLine(TextNodePosition(offset: fingerTextOffset));
    final mostRecentBoundaryLine =
        textComponent.getPositionAtStartOfLine(TextNodePosition(offset: mostRecentBoundaryTextOffset));
    final fingerIsOnNewLine = fingerLine != mostRecentBoundaryLine;
    if (fingerIsOnNewLine || fingerDocumentPosition.nodeId != _longPressMostRecentBoundaryNodeId) {
      // The user either dragged from one line of text to another, or the user dragged
      // from one text node to another. For either case, we want to stop any on-going
      // per-character dragging and return to per-word dragging.
      _resetWordVsCharacterTracking();
    }

    final fingerIsUpstream =
        _document.getAffinityBetween(base: fingerDocumentPosition, extent: _longPressInitialSelection!.end) ==
            TextAffinity.downstream;
    if (fingerIsUpstream) {
      _onLongPressDragUpstreamOfInitialWord(
        details,
        docDragOffset: fingerDocumentOffset,
        fingerDocumentPosition: fingerDocumentPosition,
        focalPointDocumentPosition: focalPointDocumentPosition,
        docDragDelta: fingerDragDelta,
        dragScrollDelta: scrollDelta,
      );
      return;
    } else {
      _onLongPressDragDownstreamOfInitialWord(
        details,
        docDragOffset: fingerDocumentOffset,
        fingerDocumentPosition: fingerDocumentPosition,
        focalPointDocumentPosition: focalPointDocumentPosition,
        docDragDelta: fingerDragDelta,
        dragScrollDelta: scrollDelta,
      );
      return;
    }
  }

  void _resetWordVsCharacterTracking() {
    editorLongPressSelectionLog.finest("Resetting word-vs-character tracking");
    _longPressMostRecentBoundaryNodeId = _longPressInitialSelection!.start.nodeId;
    _longPressMostRecentUpstreamWordBoundary =
        (_longPressInitialSelection!.start.nodePosition as TextNodePosition).offset;
    _longPressMostRecentDownstreamWordBoundary =
        (_longPressInitialSelection!.end.nodePosition as TextNodePosition).offset;
    _isSelectingByCharacter = false;
    _longPressCharacterSelectionXOffset = 0;
  }

  void _onLongPressFingerIsInInitialWord(DragUpdateDetails details) {
    // The initial word always remains selected. The entire word is the basis for
    // selection. Whenever the user presses over the initial word, the user isn't
    // selecting in on particular direction or the other.
    _longPressMostRecentUpstreamWordBoundary =
        (_longPressInitialSelection!.start.nodePosition as TextNodePosition).offset;
    _longPressMostRecentDownstreamWordBoundary =
        (_longPressInitialSelection!.end.nodePosition as TextNodePosition).offset;
    _longPressSelectionDirection = null;
    _isSelectingByCharacter = false;
    _longPressCharacterSelectionXOffset = 0;

    final initialWordRect =
        _docLayout.getRectForSelection(_longPressInitialSelection!.base, _longPressInitialSelection!.extent)!;
    final touchOffsetInDocument = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
    final distanceToUpstream = (touchOffsetInDocument.dx - initialWordRect.left).abs();
    final distanceToDownstream = (touchOffsetInDocument.dx - initialWordRect.right).abs();

    if (distanceToDownstream <= distanceToUpstream) {
      // The user's finger is closer to the downstream side than the upstream side.
      // Report the selection with the extent at the downstream edge to indicate the
      // direction the user is likely to move.
      _select(DocumentSelection(
        base: _longPressInitialSelection!.start,
        extent: _longPressInitialSelection!.end,
      ));
    } else {
      // The user's finger is closer to the upstream side than the downstream side.
      // Report the selection with the extent at the upstream edge to indicate the
      // direction the user is likely to move.
      _select(DocumentSelection(
        base: _longPressInitialSelection!.end,
        extent: _longPressInitialSelection!.start,
      ));
    }
  }

  void _onLongPressDragUpstreamOfInitialWord(
    DragUpdateDetails details, {
    required Offset docDragOffset,
    required DocumentPosition fingerDocumentPosition,
    required DocumentPosition focalPointDocumentPosition,
    required Offset docDragDelta,
    required double dragScrollDelta,
  }) {
    editorLongPressSelectionLog.finest("Dragging upstream from initial word.");

    _longPressSelectionDirection = TextAffinity.upstream;

    final focalPointNodeId = focalPointDocumentPosition.nodeId;

    if (focalPointNodeId != _longPressMostRecentBoundaryNodeId) {
      // The user dragged into a different node. The word boundary from the previous
      // node is no longer useful for calculations. Select a new boundary in the
      // newly selected node.
      _longPressMostRecentBoundaryNodeId = focalPointNodeId;

      // When the user initially drags into a new node, we want the user to drag
      // by word, even if the user was previously dragging by character. To help
      // ensure this strategy accomplishes that, place the new upstream boundary
      // at the end of the text so that any user selection position will be seen
      // as passing that boundary and therefore triggering a selection by word
      // instead of a selection by character.
      final textNode = _document.getNodeById(focalPointNodeId) as TextNode;
      _longPressMostRecentUpstreamWordBoundary = textNode.endPosition.offset;
    }

    int focalPointTextOffset = (focalPointDocumentPosition.nodePosition as TextNodePosition).offset;
    final focalPointIsBeyondMostRecentUpstreamWordBoundary = focalPointNodeId == _longPressMostRecentBoundaryNodeId &&
        focalPointTextOffset < _longPressMostRecentUpstreamWordBoundary!;
    editorLongPressSelectionLog.finest(
        "Focal point: $focalPointTextOffset, boundary: $_longPressMostRecentUpstreamWordBoundary, most recent touch position: $_longPressMostRecentTouchDocumentPosition");

    late final bool selectByWord;
    if (focalPointIsBeyondMostRecentUpstreamWordBoundary) {
      editorLongPressSelectionLog.finest("Select by word because finger is beyond most recent boundary.");
      editorLongPressSelectionLog.finest(" - most recent boundary position: $_longPressMostRecentUpstreamWordBoundary");
      editorLongPressSelectionLog.finest(" - focal point position: $focalPointDocumentPosition");
      selectByWord = true;
    } else {
      editorLongPressSelectionLog.finest("Focal point is NOT beyond boundary. Considering per-character selection.");
      final isMovingBackward = _longPressMostRecentTouchDocumentPosition != null &&
          fingerDocumentPosition != _longPressMostRecentTouchDocumentPosition &&
          _document.getAffinityBetween(
                base: _longPressMostRecentTouchDocumentPosition!,
                extent: fingerDocumentPosition,
              ) ==
              TextAffinity.downstream;
      final longPressMostRecentUpstreamWordBoundaryPosition = DocumentPosition(
        nodeId: _longPressMostRecentBoundaryNodeId!,
        nodePosition: TextNodePosition(offset: _longPressMostRecentUpstreamWordBoundary!),
      );
      final upstreamSelectionX = _docLayout
          .getRectForSelection(longPressMostRecentUpstreamWordBoundaryPosition, _longPressInitialSelection!.start)!
          .left;
      final reverseDirectionDistance = docDragOffset.dx - upstreamSelectionX;
      final startedMovingBackward = !_isSelectingByCharacter && isMovingBackward && reverseDirectionDistance > 24;
      editorLongPressSelectionLog.finest(" - current doc drag position: $fingerDocumentPosition");
      editorLongPressSelectionLog.finest(" - most recent drag position: $_longPressMostRecentTouchDocumentPosition");
      editorLongPressSelectionLog.finest(" - is moving backward? $isMovingBackward");
      editorLongPressSelectionLog.finest(" - is already selecting by character? $_isSelectingByCharacter");
      editorLongPressSelectionLog.finest(" - reverse direction distance: $reverseDirectionDistance");

      if (startedMovingBackward || _isSelectingByCharacter) {
        editorLongPressSelectionLog.finest("Selecting by character:");
        editorLongPressSelectionLog.finest(" - just started moving backward: $startedMovingBackward");
        editorLongPressSelectionLog.finest(" - continuing an existing character selection: $_isSelectingByCharacter");
        selectByWord = false;
      } else {
        editorLongPressSelectionLog.finest("User is still dragging away from initial word, selecting by word.");
        selectByWord = true;
      }
    }

    if (!selectByWord && !_isSelectingByCharacter) {
      // This will be the first frame where we start selecting by character.
      // Move the drag reference point from the user's finger to the end of the
      // current selected word.

      if (_longPressSelectionDirection == null) {
        // If we've triggered a "select by character" position, then in theory
        // it shouldn't be possible that we don't know the direction of the user's
        // selection, but that information is null. Log a warning and skip this
        // calculation.
        editorLongPressSelectionLog.warning(
            "The user triggered per-character selection, but we don't know which direction the user started moving the selection. We expected to know that information at this point.");
      } else {
        editorLongPressSelectionLog.finest("Switched to per-character...");
        // The user is selecting upstream. The end of the current selected word
        // is the upstream bound of the current selection.
        final longPressMostRecentUpstreamWordBoundaryPosition = DocumentPosition(
          nodeId: _longPressMostRecentBoundaryNodeId!,
          nodePosition: TextNodePosition(offset: _longPressMostRecentUpstreamWordBoundary!),
        );
        late final DocumentPosition boundary = longPressMostRecentUpstreamWordBoundaryPosition;

        final boundaryOffsetInDocument = _docLayout.getRectForPosition(boundary)!.center;
        final boundaryOffsetGlobal = _docLayout.getAncestorOffsetFromDocumentOffset(boundaryOffsetInDocument);
        _longPressCharacterSelectionXOffset = boundaryOffsetGlobal.dx - details.globalPosition.dx;

        editorLongPressSelectionLog.finest(" - Upstream boundary position: $boundary");
        editorLongPressSelectionLog.finest(" - Upstream boundary offset in document: $boundaryOffsetInDocument");
        editorLongPressSelectionLog.finest(" - Upstream boundary global offset: $boundaryOffsetGlobal");
        editorLongPressSelectionLog.finest(" - Touch global offset: ${details.globalPosition}");
        editorLongPressSelectionLog.finest(" - Per-character selection x-offset: $_longPressCharacterSelectionXOffset");

        // Calculate an updated focal point now that we've started selecting by character.
        final focalPointDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(
            details.globalPosition + Offset(_longPressCharacterSelectionXOffset, 0));
        focalPointDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(focalPointDocumentOffset)!;
        focalPointTextOffset = (focalPointDocumentPosition.nodePosition as TextNodePosition).offset;
        editorLongPressSelectionLog.finest("Updated the focal point because we just started selecting by character");
        editorLongPressSelectionLog.finest(" - new focal point text offset: $focalPointTextOffset");
      }
    }

    _isSelectingByCharacter = !selectByWord;

    late final DocumentSelection newSelection;
    if (selectByWord) {
      editorLongPressSelectionLog.finest("Selecting by word...");
      editorLongPressSelectionLog
          .finest(" - finding word around finger position: ${fingerDocumentPosition.nodePosition}");
      final wordUnderFinger = getWordSelection(docPosition: fingerDocumentPosition, docLayout: _docLayout);
      if (wordUnderFinger == null) {
        // This shouldn't happen. If we've gotten here, the user is selecting over
        // text content but we couldn't find a word selection. The best we can do
        // is fizzle.
        editorLongPressSelectionLog
            .warning("Long-press selecting. Couldn't find word at position: $fingerDocumentPosition");
        return;
      }

      final wordSelection = TextSelection(
        baseOffset: (wordUnderFinger.base.nodePosition as TextNodePosition).offset,
        extentOffset: (wordUnderFinger.extent.nodePosition as TextNodePosition).offset,
      );
      editorLongPressSelectionLog.finest(" - word selection: $wordSelection");
      final textNode = _document.getNodeById(wordUnderFinger.base.nodeId) as TextNode;
      final wordText = textNode.text.substring(wordSelection.start, wordSelection.end);
      editorLongPressSelectionLog.finest("Selected word text: '$wordText'");

      newSelection = DocumentSelection(base: _longPressInitialSelection!.end, extent: wordUnderFinger.start);

      // Update the most recent bounds for word-by-word selection.
      final longPressMostRecentUpstreamTextOffset = _longPressMostRecentUpstreamWordBoundary!;
      editorLongPressSelectionLog.finest(
          "Word upstream offset: ${wordSelection.start}, long press upstream bound: $longPressMostRecentUpstreamTextOffset");
      final newSelectionIsBeyondLastUpstreamWordBoundary = wordSelection.start < longPressMostRecentUpstreamTextOffset;
      if (newSelectionIsBeyondLastUpstreamWordBoundary) {
        _longPressMostRecentUpstreamWordBoundary = wordSelection.start;
        editorLongPressSelectionLog.finest(
            "Updating long-press most recent upstream word boundary: $_longPressMostRecentUpstreamWordBoundary");
      }
    } else {
      // Select by character.
      editorLongPressSelectionLog.finest("Selecting by character...");
      editorLongPressSelectionLog.finest("Calculating the character drag position:");
      editorLongPressSelectionLog.finest(" - character drag position: $focalPointDocumentPosition");
      editorLongPressSelectionLog.finest(" - long-press character x-offset: $_longPressCharacterSelectionXOffset");
      newSelection =
          _document.getAffinityBetween(base: focalPointDocumentPosition, extent: _longPressInitialSelection!.end) ==
                  TextAffinity.downstream
              ? DocumentSelection(base: _longPressInitialSelection!.end, extent: focalPointDocumentPosition)
              : DocumentSelection(base: _longPressInitialSelection!.start, extent: focalPointDocumentPosition);

      // When dragging by character, if the user drags backward far enough to move to
      // an earlier word, we want to re-activate drag-by-word for the word that we just
      // moved away from. To accomplish this, we update our word boundary as the user
      // drags by character.
      final focalPointWord = getWordSelection(docPosition: focalPointDocumentPosition, docLayout: _docLayout);
      if (focalPointWord != null) {
        final upstreamWordBoundary = (focalPointWord.start.nodePosition as TextNodePosition).offset;

        if (upstreamWordBoundary > _longPressMostRecentUpstreamWordBoundary!) {
          editorLongPressSelectionLog.finest(
              "The user moved backward into another word. We're pushing back the upstream boundary from $_longPressMostRecentUpstreamWordBoundary to $upstreamWordBoundary");
          _longPressMostRecentUpstreamWordBoundary = upstreamWordBoundary;
        }
      }
    }

    _longPressMostRecentTouchDocumentPosition = fingerDocumentPosition;

    _select(newSelection);
  }

  void _onLongPressDragDownstreamOfInitialWord(
    DragUpdateDetails details, {
    required Offset docDragOffset,
    required DocumentPosition fingerDocumentPosition,
    required DocumentPosition focalPointDocumentPosition,
    required Offset docDragDelta,
    required double dragScrollDelta,
  }) {
    editorLongPressSelectionLog.finest("Dragging downstream from initial word.");

    _longPressSelectionDirection = TextAffinity.downstream;

    final focalPointNodeId = focalPointDocumentPosition.nodeId;

    if (focalPointNodeId != _longPressMostRecentBoundaryNodeId) {
      // The user dragged into a different node. The word boundary from the previous
      // node is no longer useful for calculations. Select a new boundary in the
      // newly selected node.
      _longPressMostRecentBoundaryNodeId = focalPointNodeId;

      // When the user initially drags into a new node, we want the user to drag
      // by word, even if the user was previously dragging by character. To help
      // ensure this strategy accomplishes that, place the new downstream boundary
      // at the beginning of the text so that any user selection position will
      // be seen as passing that boundary and therefore triggering a selection
      // by word instead of a selection by character.
      final textNode = _document.getNodeById(focalPointNodeId) as TextNode;
      _longPressMostRecentDownstreamWordBoundary = textNode.beginningPosition.offset;
    }

    int focalPointTextOffset = (focalPointDocumentPosition.nodePosition as TextNodePosition).offset;
    final focalPointIsBeyondMostRecentDownstreamWordBoundary = focalPointNodeId == _longPressMostRecentBoundaryNodeId &&
        focalPointTextOffset > _longPressMostRecentDownstreamWordBoundary!;
    editorLongPressSelectionLog.finest(
        "Focal point: $focalPointTextOffset, boundary: $_longPressMostRecentDownstreamWordBoundary, most recent touch position: $_longPressMostRecentTouchDocumentPosition");

    late final bool selectByWord;
    if (focalPointIsBeyondMostRecentDownstreamWordBoundary) {
      editorLongPressSelectionLog.finest("Select by word because finger is beyond most recent boundary.");
      editorLongPressSelectionLog
          .finest(" - most recent boundary position: $_longPressMostRecentDownstreamWordBoundary");
      editorLongPressSelectionLog.finest(" - focal point position: $focalPointDocumentPosition");
      selectByWord = true;
    } else {
      editorLongPressSelectionLog.finest("Focal point is NOT beyond boundary. Considering per-character selection.");
      final isMovingBackward = _longPressMostRecentTouchDocumentPosition != null &&
          fingerDocumentPosition != _longPressMostRecentTouchDocumentPosition &&
          _document.getAffinityBetween(
                base: fingerDocumentPosition,
                extent: _longPressMostRecentTouchDocumentPosition!,
              ) ==
              TextAffinity.downstream;
      final longPressMostRecentDownstreamWordBoundaryPosition = DocumentPosition(
        nodeId: _longPressMostRecentBoundaryNodeId!,
        nodePosition: TextNodePosition(offset: _longPressMostRecentDownstreamWordBoundary!),
      );
      final downstreamSelectionX = _docLayout
          .getRectForSelection(longPressMostRecentDownstreamWordBoundaryPosition, _longPressInitialSelection!.start)!
          .right;
      final reverseDirectionDistance = downstreamSelectionX - docDragOffset.dx;
      final startedMovingBackward = !_isSelectingByCharacter && isMovingBackward && reverseDirectionDistance > 24;
      editorLongPressSelectionLog.finest(" - current doc drag position: $fingerDocumentPosition");
      editorLongPressSelectionLog.finest(" - most recent drag position: $_longPressMostRecentTouchDocumentPosition");
      editorLongPressSelectionLog.finest(" - is moving backward? $isMovingBackward");
      editorLongPressSelectionLog.finest(" - is already selecting by character? $_isSelectingByCharacter");
      editorLongPressSelectionLog.finest(" - reverse direction distance: $reverseDirectionDistance");

      if (startedMovingBackward || _isSelectingByCharacter) {
        editorLongPressSelectionLog.finest("Selecting by character:");
        editorLongPressSelectionLog.finest(" - just started moving backward: $startedMovingBackward");
        editorLongPressSelectionLog.finest(" - continuing an existing character selection: $_isSelectingByCharacter");
        selectByWord = false;
      } else {
        editorLongPressSelectionLog.finest("User is still dragging away from initial word, selecting by word.");
        selectByWord = true;
      }
    }

    if (!selectByWord && !_isSelectingByCharacter) {
      // This will be the first frame where we start selecting by character.
      // Move the drag reference point from the user's finger to the end of the
      // current selected word.

      if (_longPressSelectionDirection == null) {
        // If we've triggered a "select by character" position, then in theory
        // it shouldn't be possible that we don't know the direction of the user's
        // selection, but that information is null. Log a warning and skip this
        // calculation.
        editorLongPressSelectionLog.warning(
            "The user triggered per-character selection, but we don't know which direction the user started moving the selection. We expected to know that information at this point.");
      } else {
        editorLongPressSelectionLog.finest("Switched to per-character...");
        // The user is selecting downstream. The end of the current selected word
        // is the downstream bound of the current selection.
        final longPressMostRecentDownstreamWordBoundaryPosition = DocumentPosition(
          nodeId: _longPressMostRecentBoundaryNodeId!,
          nodePosition: TextNodePosition(offset: _longPressMostRecentDownstreamWordBoundary!),
        );
        late final DocumentPosition boundary = longPressMostRecentDownstreamWordBoundaryPosition;

        final boundaryOffsetInDocument = _docLayout.getRectForPosition(boundary)!.center;
        final boundaryOffsetGlobal = _docLayout.getAncestorOffsetFromDocumentOffset(boundaryOffsetInDocument);
        _longPressCharacterSelectionXOffset = boundaryOffsetGlobal.dx - details.globalPosition.dx;

        editorLongPressSelectionLog.finest(" - Downstream boundary position: $boundary");
        editorLongPressSelectionLog.finest(" - Downstream boundary offset in document: $boundaryOffsetInDocument");
        editorLongPressSelectionLog.finest(" - Downstream boundary global offset: $boundaryOffsetGlobal");
        editorLongPressSelectionLog.finest(" - Touch global offset: ${details.globalPosition}");
        editorLongPressSelectionLog.finest(" - Per-character selection x-offset: $_longPressCharacterSelectionXOffset");

        // Calculate an updated focal point now that we've started selecting by character.
        final focalPointDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(
            details.globalPosition + Offset(_longPressCharacterSelectionXOffset, 0));
        focalPointDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(focalPointDocumentOffset)!;
        focalPointTextOffset = (focalPointDocumentPosition.nodePosition as TextNodePosition).offset;
        editorLongPressSelectionLog.finest("Updated the focal point because we just started selecting by character");
        editorLongPressSelectionLog.finest(" - new focal point text offset: $focalPointTextOffset");
      }
    }

    _isSelectingByCharacter = !selectByWord;

    late final DocumentSelection newSelection;
    if (selectByWord) {
      editorLongPressSelectionLog.finest("Selecting by word...");
      editorLongPressSelectionLog.finest(" - finger document position: $fingerDocumentPosition");
      final wordUnderFinger = getWordSelection(docPosition: fingerDocumentPosition, docLayout: _docLayout);
      if (wordUnderFinger == null) {
        // This shouldn't happen. If we've gotten here, the user is selecting over
        // text content but we couldn't find a word selection. The best we can do
        // is fizzle.
        editorLongPressSelectionLog
            .warning("Long-press selecting. Couldn't find word at position: $fingerDocumentPosition");
        return;
      }

      final wordSelection = TextSelection(
        baseOffset: (wordUnderFinger.base.nodePosition as TextNodePosition).offset,
        extentOffset: (wordUnderFinger.extent.nodePosition as TextNodePosition).offset,
      );
      final textNode = _document.getNodeById(wordUnderFinger.base.nodeId) as TextNode;
      final wordText = textNode.text.substring(wordSelection.start, wordSelection.end);
      editorLongPressSelectionLog.finest("Selected word text: '$wordText'");

      newSelection = DocumentSelection(base: _longPressInitialSelection!.start, extent: wordUnderFinger.end);

      // Update the most recent bounds for word-by-word selection.
      final longPressMostRecentDownstreamTextOffset = _longPressMostRecentDownstreamWordBoundary!;
      editorLongPressSelectionLog.finest(
          "Word downstream offset: ${wordSelection.end}, long press downstream bound: $longPressMostRecentDownstreamTextOffset");
      final newSelectionIsBeyondLastDownstreamWordBoundary =
          wordSelection.end > longPressMostRecentDownstreamTextOffset;
      if (newSelectionIsBeyondLastDownstreamWordBoundary) {
        _longPressMostRecentDownstreamWordBoundary = wordSelection.end;
        editorLongPressSelectionLog.finest(
            "Updating long-press most recent downstream word boundary: $_longPressMostRecentDownstreamWordBoundary");
      }
    } else {
      // Select by character.
      editorLongPressSelectionLog.finest("Selecting by character...");
      editorLongPressSelectionLog.finest("Calculating the character drag position:");
      editorLongPressSelectionLog.finest(" - character drag position: $focalPointDocumentPosition");
      editorLongPressSelectionLog.finest(" - long-press character x-offset: $_longPressCharacterSelectionXOffset");
      newSelection = DocumentSelection(base: _longPressInitialSelection!.start, extent: focalPointDocumentPosition);

      // When dragging by character, if the user drags backward far enough to move to
      // an earlier word, we want to re-activate drag-by-word for the word that we just
      // moved away from. To accomplish this, we update our word boundary as the user
      // drags by character.
      final focalPointWord = getWordSelection(docPosition: focalPointDocumentPosition, docLayout: _docLayout);
      if (focalPointWord != null) {
        final downstreamWordBoundary = (focalPointWord.end.nodePosition as TextNodePosition).offset;

        if (downstreamWordBoundary < _longPressMostRecentDownstreamWordBoundary!) {
          editorLongPressSelectionLog.finest(
              "The user moved backward into another word. We're pushing back the downstream boundary from $_longPressMostRecentDownstreamWordBoundary to $downstreamWordBoundary");
          _longPressMostRecentDownstreamWordBoundary = downstreamWordBoundary;
        }
      }
    }

    _longPressMostRecentTouchDocumentPosition = fingerDocumentPosition;

    _select(newSelection);
  }

  /// Clients should call this method when a long-press drag ends, or is cancelled.
  void onLongPressEnd() {
    // Cancel any on-going long-press.
    // _longPressMagnifierGlobalOffset.value = null;
    _longPressInitialSelection = null;
    _longPressMostRecentUpstreamWordBoundary = null;
    _longPressMostRecentDownstreamWordBoundary = null;
  }
}
