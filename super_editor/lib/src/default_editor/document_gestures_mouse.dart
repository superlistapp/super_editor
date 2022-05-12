import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/scrolling_diagnostics/_scrolling_minimap.dart';

import 'document_gestures.dart';

/// Governs mouse gesture interaction with a document, such as scrolling
/// a document with a scroll wheel, tapping to place a caret, and
/// tap-and-dragging to create an expanded selection.
///
/// See also: super_editor's touch gesture support.

/// Document gesture interactor that's designed for mouse input, e.g.,
/// drag to select, and mouse wheel to scroll.
///
///  - alters document selection on single, double, and triple taps
///  - alters document selection on drag, also account for single,
///    double, or triple taps to drag
///  - sets the cursor style based on hovering over text and other
///    components
///  - automatically scrolls up or down when the user drags near
///    a boundary
class DocumentMouseInteractor extends StatefulWidget {
  const DocumentMouseInteractor({
    Key? key,
    this.focusNode,
    required this.editContext,
    this.scrollController,
    this.selectionExtentAutoScrollBoundary = AxisOffset.zero,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(100),
    this.showDebugPaint = false,
    this.scrollingMinimapId,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  /// Service locator for document editing dependencies.
  final EditContext editContext;

  /// Controls the vertical scrolling of the given [child].
  ///
  /// If no `scrollController` is provided, then one is created
  /// internally.
  final ScrollController? scrollController;

  /// The closest distance between the user's selection extent (caret)
  /// and the boundary of a document before the document auto-scrolls
  /// to make room for the caret.
  ///
  /// The default value is zero for the leading and trailing boundaries.
  /// This means that the top of the caret is permitted to touch the top
  /// of the scrolling region, but if the caret goes above the viewport
  /// boundary then the document scrolls up. If the caret goes below the
  /// bottom of the viewport boundary then the document scrolls down.
  ///
  /// A positive value for each boundary creates a buffer zone at each
  /// edge of the viewport. For example, a value of `100.0` would cause
  /// the document to auto-scroll whenever the caret sits within 100
  /// pixels of the edge of a document.
  ///
  /// A negative value allows the caret to move outside the viewport
  /// before auto-scrolling.
  ///
  /// See also:
  ///
  ///  * [dragAutoScrollBoundary], which defines how close the user's
  ///    drag gesture can get to the document boundary before auto-scrolling.
  final AxisOffset selectionExtentAutoScrollBoundary;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `100.0` pixels for both the leading and trailing
  /// edges.
  ///
  /// See also:
  ///
  ///  * [selectionExtentAutoScrollBoundary], which defines how close the
  ///    selection extent can get to the document boundary before
  ///    auto-scrolling. For example, when the user taps into some text, or
  ///    when the user presses up/down arrows to move the selection extent.
  final AxisOffset dragAutoScrollBoundary;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when `true`.
  final bool showDebugPaint;

  /// ID that this widget's scrolling system registers with an ancestor
  /// [ScrollingMinimaps] to report scrolling diagnostics for debugging.
  final String? scrollingMinimapId;

  /// The document to display within this [DocumentMouseInteractor].
  final Widget child;

  @override
  _DocumentMouseInteractorState createState() => _DocumentMouseInteractorState();
}

class _DocumentMouseInteractorState extends State<DocumentMouseInteractor> with SingleTickerProviderStateMixin {
  final _maxDragSpeed = 20.0;

  final _documentWrapperKey = GlobalKey();

  late FocusNode _focusNode;

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  // Tracks user drag gestures for selection purposes.
  SelectionType _selectionType = SelectionType.position;
  bool _hasAncestorScrollable = false;
  Offset? _dragStartInDoc;
  double? _dragStartScrollOffset;
  Offset? _dragEndInInteractor;
  Offset? _dragEndInDoc;
  bool _expandSelectionDuringDrag = false;

  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;
  late Ticker _ticker;

  // Current mouse cursor style displayed on screen.
  final _cursorStyle = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  ScrollableInstrumentation? _debugInstrumentation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ticker = createTicker(_onTick);
    _scrollController =
        _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);

    widget.editContext.composer.addListener(_onSelectionChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // If we were given a scrollingMinimapId, it means our client wants us
    // to report our scrolling behavior for debugging. Register with an
    // ancestor ScrollingMinimaps.
    if (widget.scrollingMinimapId != null) {
      _debugInstrumentation = ScrollableInstrumentation()
        ..viewport.value = Scrollable.of(context)!.context
        ..scrollPosition.value = Scrollable.of(context)!.position;
      ScrollingMinimaps.of(context)?.put(widget.scrollingMinimapId!, _debugInstrumentation);
    }
  }

  @override
  void didUpdateWidget(DocumentMouseInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editContext.composer != oldWidget.editContext.composer) {
      oldWidget.editContext.composer.removeListener(_onSelectionChange);
      widget.editContext.composer.addListener(_onSelectionChange);
    }
    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController.removeListener(_updateDragSelection);
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    // TODO: Flutter says the following de-registration is unsafe. Where are we
    //       supposed to de-register from an ancestor?
    //       I'm commenting this out until we can find the right approach.
    // if (widget.scrollingMinimapId == null) {
    //   ScrollingMinimaps.of(context)?.put(widget.scrollingMinimapId!, null);
    // }

    widget.editContext.composer.removeListener(_onSelectionChange);
    _ticker.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.editContext.documentLayout;

  /// Returns the `ScrollPosition` that controls the scroll offset of
  /// this widget.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `ScrollPosition` belongs to that ancestor `Scrollable`, and this
  /// widget doesn't include a `ScrollView`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and the `ScrollView`'s position
  /// is returned.
  ScrollPosition get _scrollPosition => _ancestorScrollPosition ?? _scrollController.position;

  /// Returns the `RenderBox` for the scrolling viewport.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `RenderBox` belongs to that ancestor `Scrollable`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and this `State`'s render object
  /// is the viewport `RenderBox`.
  RenderBox get _viewport =>
      (Scrollable.of(context)?.context.findRenderObject() ?? context.findRenderObject()) as RenderBox;

  bool get _isShiftPressed =>
      (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
          RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shift)) &&
      widget.editContext.composer.selection != null;

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// if the same as the viewport offset.
  ///
  /// When this interactor defers to an ancestor `Scrollable`, then the
  /// [interactorOffset] is transformed into the ancestor coordinate space.
  Offset _interactorOffsetInViewport(Offset interactorOffset) {
    // Viewport might be our box, or an ancestor box if we're inside someone
    // else's Scrollable.
    final viewportBox = _viewport;
    final interactorBox = context.findRenderObject() as RenderBox;
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  void _onSelectionChange() {
    if (mounted) {
      // Use a post-frame callback to "ensure selection extent is visible"
      // so that any pending visual document changes can happen before
      // attempting to calculate the visual position of the selection extent.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        editorGesturesLog.finer("Ensuring selection extent is visible because the doc selection changed");
        _ensureSelectionExtentIsVisible();
      });
    }
  }

  void _ensureSelectionExtentIsVisible() {
    editorGesturesLog.finer("Ensuring extent is visible: ${widget.editContext.composer.selection}");
    final selection = widget.editContext.composer.selection;
    if (selection == null) {
      return;
    }

    // The reason that a Rect is used instead of an Offset is
    // because things like Images and Horizontal Rules don't have
    // a clear selection offset. They are either entirely selected,
    // or not selected at all.
    final selectionExtentRectInDoc = _docLayout.getRectForPosition(
      selection.extent,
    );
    if (selectionExtentRectInDoc == null) {
      editorGesturesLog.warning(
          "Tried to ensure that position ${selection.extent} is visible on screen but no bounding box was returned for that position.");
      return;
    }

    // Viewport might be our box, or an ancestor box if we're inside someone
    // else's Scrollable.
    final viewportBox = _viewport;

    final docBox = _documentWrapperKey.currentContext!.findRenderObject() as RenderBox;

    final docOffsetInViewport = viewportBox.globalToLocal(
      docBox.localToGlobal(Offset.zero),
    );
    final selectionExtentRectInViewport = selectionExtentRectInDoc.translate(0, docOffsetInViewport.dy);

    final beyondTopExtent = min(selectionExtentRectInViewport.top, 0).abs();

    final beyondBottomExtent = max(selectionExtentRectInViewport.bottom - viewportBox.size.height, 0);

    editorGesturesLog.finest('Ensuring extent is visible.');
    editorGesturesLog.finest(' - viewport size: ${viewportBox.size}');
    editorGesturesLog.finest(' - scroll controller offset: ${_scrollPosition.pixels}');
    editorGesturesLog.finest(' - selection extent rect: $selectionExtentRectInDoc');
    editorGesturesLog.finest(' - beyond top: $beyondTopExtent');
    editorGesturesLog.finest(' - beyond bottom: $beyondBottomExtent');

    if (beyondTopExtent > 0) {
      final newScrollPosition = (_scrollPosition.pixels - beyondTopExtent).clamp(0.0, _scrollPosition.maxScrollExtent);

      _scrollPosition.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondBottomExtent > 0) {
      final newScrollPosition =
          (beyondBottomExtent + _scrollPosition.pixels).clamp(0.0, _scrollPosition.maxScrollExtent);

      _scrollPosition.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTapUp(TapUpDetails details) {
    editorGesturesLog.info("Tap up on document");
    final docOffset = _getDocOffsetFromInteractorOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    _focusNode.requestFocus();

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      if (_isShiftPressed && widget.editContext.composer.selection != null) {
        // The user tapped while pressing shift and there's an existing
        // selection. Move the extent of the selection to where the user tapped.
        widget.editContext.composer.selection = widget.editContext.composer.selection!.copyWith(
          extent: docPosition,
        );
      } else {
        // Place the document selection at the location where the
        // user tapped.
        _selectionType = SelectionType.position;
        _selectPosition(docPosition);
      }
    } else {
      _clearSelection();
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffsetFromInteractorOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }
    }

    _selectionType = SelectionType.word;
    _clearSelection();

    if (docPosition != null) {
      bool didSelectContent = _selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );

      if (!didSelectContent) {
        didSelectContent = _selectBlockAt(docPosition);
      }

      if (!didSelectContent) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    }

    _focusNode.requestFocus();
  }

  bool _selectBlockAt(DocumentPosition position) {
    if (position.nodePosition is! UpstreamDownstreamNodePosition) {
      return false;
    }

    widget.editContext.composer.selection = DocumentSelection(
      base: DocumentPosition(
        nodeId: position.nodeId,
        nodePosition: const UpstreamDownstreamNodePosition.upstream(),
      ),
      extent: DocumentPosition(
        nodeId: position.nodeId,
        nodePosition: const UpstreamDownstreamNodePosition.downstream(),
      ),
    );

    return true;
  }

  void _onDoubleTap() {
    editorGesturesLog.info("Double tap up on document");
    _selectionType = SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffsetFromInteractorOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }
    }

    _selectionType = SelectionType.paragraph;
    _clearSelection();

    if (docPosition != null) {
      final didSelectParagraph = _selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    }

    _focusNode.requestFocus();
  }

  void _onTripleTap() {
    editorGesturesLog.info("Triple tap up on document");
    _selectionType = SelectionType.position;
  }

  void _onPanStart(DragStartDetails details) {
    editorGesturesLog.info("Pan start on document");

    _hasAncestorScrollable = Scrollable.of(context) != null;
    _dragStartInDoc = _getDocOffsetFromInteractorOffset(details.localPosition);

    _debugInstrumentation?.startDragInContent.value = _dragStartInDoc;

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = _scrollPosition.pixels;

    if (_isShiftPressed) {
      _expandSelectionDuringDrag = true;
    }

    if (!_isShiftPressed) {
      // Only clear the selection if the user isn't pressing shift. Shift is
      // used to expand the current selection, not replace it.
      _clearSelection();
    }

    _focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      editorGesturesLog.info("Pan update on document");

      _dragEndInInteractor = details.localPosition;
      _dragEndInDoc = _getDocOffsetFromInteractorOffset(details.localPosition);

      _debugInstrumentation?.startDragInContent.value = _dragEndInDoc;

      _updateCursorStyle(details.localPosition);
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    editorGesturesLog.info("Pan end on document");
    _onDragEnd();
  }

  void _onPanCancel() {
    editorGesturesLog.info("Pan cancel on document");
    _onDragEnd();
  }

  void _onDragEnd() {
    setState(() {
      _dragStartInDoc = null;
      _dragEndInDoc = null;
      _dragEndInInteractor = null;
      _expandSelectionDuringDrag = false;
    });

    _stopScrollingUp();
    _stopScrollingDown();
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  bool _selectWordAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getWordSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editContext.composer.selection = newSelection;
      return true;
    } else {
      return false;
    }
  }

  bool _selectParagraphAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getParagraphSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editContext.composer.selection = newSelection;
      return true;
    } else {
      return false;
    }
  }

  void _selectPosition(DocumentPosition position) {
    editorGesturesLog.fine("Setting document selection to $position");
    widget.editContext.composer.selection = DocumentSelection.collapsed(
      position: position,
    );
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    // We have to re-calculate the drag end in the doc (instead of
    // caching the value during the pan update) because the position
    // in the document is impacted by auto-scrolling behavior.
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final ancestorScrollableDragEndAdjustment =
        _hasAncestorScrollable ? Offset(0, -scrollDeltaWhileDragging) : Offset.zero;
    _dragEndInDoc = _getDocOffsetFromInteractorOffset(_dragEndInInteractor! + ancestorScrollableDragEndAdjustment);

    _selectRegion(
      documentLayout: _docLayout,
      baseOffset: _dragStartInDoc!,
      extentOffset: _dragEndInDoc!,
      selectionType: _selectionType,
      expandSelection: _expandSelectionDuringDrag,
    );
  }

  void _selectRegion({
    required DocumentLayout documentLayout,
    required Offset baseOffset,
    required Offset extentOffset,
    required SelectionType selectionType,
    bool expandSelection = false,
  }) {
    editorGesturesLog.info("Selecting region with selection mode: $selectionType");
    DocumentSelection? selection = documentLayout.getDocumentSelectionInRegion(baseOffset, extentOffset);
    DocumentPosition? basePosition = selection?.base;
    DocumentPosition? extentPosition = selection?.extent;
    editorGesturesLog.fine(" - base: $basePosition, extent: $extentPosition");

    if (basePosition == null || extentPosition == null) {
      widget.editContext.composer.selection = null;
      return;
    }

    if (selectionType == SelectionType.paragraph) {
      final baseParagraphSelection = getParagraphSelection(
        docPosition: basePosition,
        docLayout: documentLayout,
      );
      if (baseParagraphSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      basePosition = baseOffset.dy < extentOffset.dy ? baseParagraphSelection.base : baseParagraphSelection.extent;

      final extentParagraphSelection = getParagraphSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
      );
      if (extentParagraphSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      extentPosition =
          baseOffset.dy < extentOffset.dy ? extentParagraphSelection.extent : extentParagraphSelection.base;
    } else if (selectionType == SelectionType.word) {
      final baseWordSelection = getWordSelection(
        docPosition: basePosition,
        docLayout: documentLayout,
      );
      if (baseWordSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      basePosition = baseWordSelection.base;

      final extentWordSelection = getWordSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
      );
      if (extentWordSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      extentPosition = extentWordSelection.extent;
    }

    widget.editContext.composer.selection = (DocumentSelection(
      // If desired, expand the selection instead of replacing it.
      base: expandSelection ? widget.editContext.composer.selection?.base ?? basePosition : basePosition,
      extent: extentPosition,
    ));
    editorGesturesLog.fine("Selected region: ${widget.editContext.composer.selection}");
  }

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.editContext.composer.clearSelection();
  }

  void _updateCursorStyle(Offset cursorOffset) {
    final docOffset = _getDocOffsetFromInteractorOffset(cursorOffset);
    final desiredCursor = _docLayout.getDesiredCursorAtOffset(docOffset);

    if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
      _cursorStyle.value = desiredCursor;
    } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  // Converts the given [offset] from the [DocumentInteractor]'s coordinate
  // space to the [DocumentLayout]'s coordinate space.
  Offset _getDocOffsetFromInteractorOffset(Offset offset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(offset, context.findRenderObject()!);
  }

  // ------ scrolling -------
  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final newScrollOffset =
          (_scrollPosition.pixels + event.scrollDelta.dy).clamp(0.0, _scrollPosition.maxScrollExtent);
      _scrollPosition.jumpTo(newScrollOffset);

      _updateDragSelection();
    }
  }

  // Preconditions:
  // - _dragEndInViewport must be non-null
  void _scrollIfNearBoundary() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll near boundary but couldn't because _dragEndInViewport is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    final viewport = _viewport;

    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final ancestorScrollableDragEndAdjustment =
        _hasAncestorScrollable ? Offset(0, -scrollDeltaWhileDragging) : Offset.zero;

    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) + ancestorScrollableDragEndAdjustment;

    editorGesturesLog.finest("Scrolling, if near boundary:");
    editorGesturesLog.finest(' - Drag end in interactor: ${_dragEndInInteractor!.dy}');
    editorGesturesLog.finest(' - Drag end in viewport: ${dragEndInViewport.dy}, viewport size: ${viewport.size}');
    editorGesturesLog.finest(' - Distance to top of viewport: ${dragEndInViewport.dy}');
    editorGesturesLog.finest(' - Distance to bottom of viewport: ${viewport.size.height - dragEndInViewport.dy}');
    editorGesturesLog.finest(' - Auto-scroll distance: ${widget.dragAutoScrollBoundary.trailing}');
    editorGesturesLog.finest(
        ' - Auto-scroll diff: ${viewport.size.height - dragEndInViewport.dy < widget.dragAutoScrollBoundary.trailing}');
    if (dragEndInViewport.dy < widget.dragAutoScrollBoundary.leading) {
      editorGesturesLog.finest('Metrics say we should try to scroll up');
      _startScrollingUp();
    } else {
      _stopScrollingUp();
    }

    if (viewport.size.height - dragEndInViewport.dy < widget.dragAutoScrollBoundary.trailing) {
      editorGesturesLog.finest('Metrics say we should try to scroll down');
      _startScrollingDown();
    } else {
      _stopScrollingDown();
    }
  }

  void _startScrollingUp() {
    if (_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll up');
    _scrollUpOnTick = true;
    _debugInstrumentation?.autoScrollEdge.value = ViewportEdge.leading;
    _ticker.start();
  }

  void _stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll up');
    _scrollUpOnTick = false;
    _debugInstrumentation?.autoScrollEdge.value = null;
    _ticker.stop();
  }

  void _scrollUp() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll up but couldn't because _dragEndInViewport is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    if (_scrollPosition.pixels <= 0) {
      editorGesturesLog.finest("Tried to scroll up but the scroll position is already at the top");
      return;
    }

    editorGesturesLog.finest("Scrolling up on tick");

    // If this widget sits inside an ancestor Scrollable, adjust the drag-end
    // offset to account for the scroll offset of the ancestor Scrollable.
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final ancestorScrollableDragEndAdjustment =
        _hasAncestorScrollable ? Offset(0, -scrollDeltaWhileDragging) : Offset.zero;

    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) + ancestorScrollableDragEndAdjustment;
    final leadingScrollBoundary = widget.dragAutoScrollBoundary.leading;
    final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
    final speedPercent = 1.0 - (gutterAmount / leadingScrollBoundary);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _scrollPosition.jumpTo(_scrollPosition.pixels - scrollAmount);

    // By changing the scroll offset, we may have changed the content
    // selected by the user's current finger/mouse position. Update the
    // document selection calculation.
    _updateDragSelection();
  }

  void _startScrollingDown() {
    if (_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll down');
    _scrollDownOnTick = true;
    _debugInstrumentation?.autoScrollEdge.value = ViewportEdge.trailing;
    _ticker.start();
  }

  void _stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll down');
    _scrollDownOnTick = false;
    _debugInstrumentation?.autoScrollEdge.value = null;
    _ticker.stop();
  }

  void _scrollDown() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll down but couldn't because _dragEndInViewport is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    if (_scrollPosition.pixels >= _scrollPosition.maxScrollExtent) {
      editorGesturesLog.finest("Tried to scroll down but the scroll position is already beyond the max");
      return;
    }

    editorGesturesLog.finest("Scrolling down on tick");

    // If this widget sits inside an ancestor Scrollable, adjust the drag-end
    // offset to account for the scroll offset of the ancestor Scrollable.
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final ancestorScrollableDragEndAdjustment =
        _hasAncestorScrollable ? Offset(0, -scrollDeltaWhileDragging) : Offset.zero;

    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) + ancestorScrollableDragEndAdjustment;
    final trailingScrollBoundary = widget.dragAutoScrollBoundary.trailing;
    final viewportBox = _viewport;
    final gutterAmount = (viewportBox.size.height - dragEndInViewport.dy).clamp(0.0, trailingScrollBoundary);
    final speedPercent = 1.0 - (gutterAmount / trailingScrollBoundary);
    editorGesturesLog.finest("Speed percent: $speedPercent");
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent)!;

    editorGesturesLog.finest("Jumping from ${_scrollPosition.pixels} to ${_scrollPosition.pixels + scrollAmount}");
    _scrollPosition.jumpTo(_scrollPosition.pixels + scrollAmount);

    // By changing the scroll offset, we may have changed the content
    // selected by the user's current finger/mouse position. Update the
    // document selection calculation.
    _updateDragSelection();
  }

  void _onTick(elapsedTime) {
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancestorScrollable = Scrollable.of(context);
    _ancestorScrollPosition = ancestorScrollable?.position;

    return _buildCursorStyle(
      child: _buildGestureInput(
        child: SizedBox(
          width: double.infinity,
          // If there is no ancestor scrollable then we want the gesture area
          // to fill all available height. If there is a scrollable ancestor,
          // then expanding vertically would cause an infinite height, so in that
          // case we let the gesture area take up whatever it can, naturally.
          height: ancestorScrollable == null ? double.infinity : null,
          child: Stack(
            children: [
              _buildDocumentContainer(
                document: widget.child,
                addScrollView: ancestorScrollable == null,
              ),
              if (widget.showDebugPaint) ..._buildScrollingDebugPaint(includesScrollView: ancestorScrollable == null),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScrollingDebugPaint({
    required bool includesScrollView,
  }) {
    return [
      if (includesScrollView) ...[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: widget.dragAutoScrollBoundary.leading.toDouble(),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x440088FF),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: widget.dragAutoScrollBoundary.trailing.toDouble(),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x440088FF),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildCursorStyle({
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _cursorStyle,
      builder: (context, child) {
        return Listener(
          onPointerHover: _onMouseMove,
          child: MouseRegion(
            cursor: _cursorStyle.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildGestureInput({
    required Widget child,
  }) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
          () => TapSequenceGestureRecognizer(),
          (TapSequenceGestureRecognizer recognizer) {
            recognizer
              ..onTapUp = _onTapUp
              ..onDoubleTapDown = _onDoubleTapDown
              ..onDoubleTap = _onDoubleTap
              ..onTripleTapDown = _onTripleTapDown
              ..onTripleTap = _onTripleTap;
          },
        ),
        PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(),
          (PanGestureRecognizer recognizer) {
            recognizer
              ..onStart = _onPanStart
              ..onUpdate = _onPanUpdate
              ..onEnd = _onPanEnd
              ..onCancel = _onPanCancel;
          },
        ),
      },
      child: child,
    );
  }

  Widget _buildDocumentContainer({
    required Widget document,
    required bool addScrollView,
  }) {
    final documentWidget = Center(
      child: Stack(
        children: [
          SizedBox(
            key: _documentWrapperKey,
            child: document,
          ),
          if (widget.showDebugPaint) ..._buildDebugPaintInDocSpace(),
        ],
      ),
    );

    return addScrollView
        ? Listener(
            onPointerSignal: _onPointerSignal,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: documentWidget,
            ),
          )
        : documentWidget;
  }

  List<Widget> _buildDebugPaintInDocSpace() {
    return [
      if (_dragStartInDoc != null)
        Positioned(
          left: _dragStartInDoc!.dx,
          top: _dragStartInDoc!.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0088FF),
              ),
            ),
          ),
        ),
      if (_dragEndInDoc != null)
        Positioned(
          left: _dragEndInDoc!.dx,
          top: _dragEndInDoc!.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0088FF),
              ),
            ),
          ),
        ),
      if (_dragStartInDoc != null && _dragEndInDoc != null)
        Positioned(
          left: min(_dragStartInDoc!.dx, _dragEndInDoc!.dx),
          top: min(_dragStartInDoc!.dy, _dragEndInDoc!.dy),
          width: (_dragEndInDoc!.dx - _dragStartInDoc!.dx).abs(),
          height: (_dragEndInDoc!.dy - _dragStartInDoc!.dy).abs(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0088FF), width: 3),
            ),
          ),
        ),
    ];
  }
}

enum SelectionType {
  position,
  word,
  paragraph,
}

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final Rect? selectionRect;
  final Paint _selectionPaint = Paint()
    ..color = const Color(0xFFFF0000)
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      canvas.drawRect(selectionRect!, _selectionPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
