import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/caret.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

import 'document_gestures.dart';
import 'document_gestures_touch.dart';

/// Document gesture interactor that's designed for iOS touch input, e.g.,
/// drag to scroll, and handles to control selection.
class IOSDocumentTouchInteractor extends StatefulWidget {
  const IOSDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.editContext,
    this.scrollController,
    required this.documentKey,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final EditContext editContext;

  final ScrollController? scrollController;

  final GlobalKey documentKey;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  final bool showDebugPaint;

  final Widget child;

  @override
  _IOSDocumentTouchInteractorState createState() => _IOSDocumentTouchInteractorState();
}

class _IOSDocumentTouchInteractorState extends State<IOSDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _documentWrapperKey = GlobalKey();
  final _documentLayerLink = LayerLink();

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  late EditingController _editingController;

  // OverlayEntry that displays editing controls, e.g.,
  // drag handles, magnifier, and toolbar.
  OverlayEntry? _controlsOverlayEntry;

  // Whether we're currently waiting to see if the user taps
  // again on the document.
  //
  // We track this for the following reason: on iOS, there is
  // no collapsed handle. Instead, the caret is the handle. This
  // means that the caret must be draggable. But this creates an
  // issue. If the user tries to double tap, first the user taps
  // and places the caret and then the user taps again. But the
  // 2nd tap gets consumed by the tappable caret, when instead the
  // 2nd tap should hit the document again. To allow for double and
  // triple taps on iOS, we explicitly tell the overlay controls to
  // avoid handling gestures while we are `_waitingForMoreTaps`.
  bool _waitingForMoreTaps = false;

  _DragMode? _dragMode;

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(_onFocusChange);
    if (widget.focusNode.hasFocus) {
      _showEditingControlsOverlay();
    }

    _scrollController = _scrollController = (widget.scrollController ?? ScrollController());

    _editingController = EditingController(document: widget.editContext.editor.document)
      ..addListener(_onEditingControllerChange);

    widget.editContext.composer.addListener(_onSelectionChange);

    _ticker = createTicker(_onTick);

    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didUpdateWidget(IOSDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.editContext.composer != oldWidget.editContext.composer) {
      oldWidget.editContext.composer.removeListener(_onSelectionChange);
      widget.editContext.composer.addListener(_onSelectionChange);
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    if (widget.focusNode.hasFocus) {
      // On Hot Reload we need to remove any visible overlay controls and then
      // bring them back a frame later to avoid having the controls attempt
      // to access the layout of the text. The text layout is not immediately
      // available upon Hot Reload. Accessing it results in an exception.
      // TODO: this was copied from Super Textfield, see if the timing
      //       problem exists for documents, too.
      _removeEditingOverlayControls();

      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        _showEditingControlsOverlay();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);

    _ticker.dispose();

    _editingController.removeListener(_onEditingControllerChange);

    widget.editContext.composer.removeListener(_onSelectionChange);

    _removeEditingOverlayControls();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    widget.focusNode.removeListener(_onFocusChange);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {
          // no-op
        });
      }
    });
  }

  void _onEditingControllerChange() {
    widget.editContext.composer.selection = _editingController.selection;
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // TODO: the text field only showed the editing controls if the text input
      //       client wasn't attached yet. Do we need a similar check here?
      _showEditingControlsOverlay();
    } else {
      _removeEditingOverlayControls();
    }
  }

  void _onSelectionChange() {
    _editingController.selection = widget.editContext.composer.selection;
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

  /// Converts the given [offset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _getDocOffset(Offset offset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(offset, context.findRenderObject()!);
  }

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// is the same as the viewport offset.
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

  final _maxDragSpeed = 2;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  // TODO: HandleType is the wrong type here, we need collapsed/base/extent,
  //       not collapsed/upstream/downstream. Change the type once it's working.
  HandleType? _dragHandleType;
  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;
  late Ticker _ticker;

  void _onTapUp(TapUpDetails details) {
    if (_editingController.selection != null &&
        !_editingController.selection!.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    setState(() {
      _waitingForMoreTaps = true;
      _controlsOverlayEntry?.markNeedsBuild();
    });

    editorGesturesLog.info("Tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    _clearSelection();
    // _selectionType = SelectionType.position;

    if (docPosition != null) {
      // Place the document selection at the location where the
      // user tapped.
      _selectPosition(docPosition);
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_editingController.selection != null &&
        !_editingController.selection!.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    // _selectionType = SelectionType.word;
    _clearSelection();

    if (docPosition != null) {
      final didSelectWord = _selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (!didSelectWord) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTap() {
    editorGesturesLog.info("Double tap up on document");
    // _selectionType = SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    if (_editingController.selection != null &&
        !_editingController.selection!.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    // _selectionType = SelectionType.paragraph;
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

    widget.focusNode.requestFocus();
  }

  void _onTripleTap() {
    editorGesturesLog.info("Triple tap up on document");
    // _selectionType = SelectionType.position;
  }

  void _onPanStart(DragStartDetails details) {
    print('onPanStart');
    if (_editingController.selection == null) {
      return;
    }

    if (_editingController.selection!.isCollapsed && _isOverCollapsedHandle(details.localPosition)) {
      print("IS OVER COLLAPSED HANDLE");
      _dragMode = _DragMode.collapsed;
    } else if (_isOverBaseHandle(details.localPosition)) {
      print("IS OVER BASE");
      _dragMode = _DragMode.base;
    } else if (_isOverExtentHandle(details.localPosition)) {
      print("IS OVER CARET");
      _dragMode = _DragMode.extent;
    }

    if (_dragMode == null) {
      return;
    }

    // The user is dragging a handle. Capture the details needed for auto-scrolling.
    switch (_dragMode!) {
      case _DragMode.collapsed:
        _dragHandleType = HandleType.collapsed;
        break;
      case _DragMode.base:
        _dragHandleType = HandleType.upstream;
        break;
      case _DragMode.extent:
        _dragHandleType = HandleType.downstream;
        break;
    }
    _globalStartDragOffset = details.globalPosition;

    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(details.globalPosition);
    _dragStartInDoc = _getDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _dragHandleType! == HandleType.upstream
              ? _editingController.selection!.base
              : _editingController.selection!.extent,
        )!
        .center;

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = _scrollPosition.pixels;
  }

  bool _isOverCollapsedHandle(Offset interactorOffset) {
    final collapsedPosition = _editingController.selection?.extent;
    if (collapsedPosition == null) {
      return false;
    }

    print('Is over collapsed handle?');
    print(' - position: $collapsedPosition');
    final extentRect = _docLayout.getRectForPosition(collapsedPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);
    print(" - caret rect: $caretRect");

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    print(" - touch offset: $docOffset");
    print(" - offset in caret? ${caretRect.contains(docOffset)}");
    return caretRect.contains(docOffset);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = _editingController.selection?.base;
    if (basePosition == null) {
      return false;
    }

    print('Is over base handle?');
    print(' - position: $basePosition');
    final baseRect = _docLayout.getRectForPosition(basePosition)!;
    final caretRect = Rect.fromLTWH(baseRect.left - 1, baseRect.center.dy, 1, 1).inflate(24);
    print(" - caret rect: $caretRect");

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    print(" - touch offset: $docOffset");
    print(" - offset in caret? ${caretRect.contains(docOffset)}");
    return caretRect.contains(docOffset);
  }

  bool _isOverExtentHandle(Offset interactorOffset) {
    final extentPosition = _editingController.selection?.extent;
    if (extentPosition == null) {
      return false;
    }

    print('Is over extent handle?');
    print(' - position: $extentPosition');
    final extentRect = _docLayout.getRectForPosition(extentPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);
    print(" - caret rect: $caretRect");

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    print(" - touch offset: $docOffset");
    print(" - offset in caret? ${caretRect.contains(docOffset)}");
    return caretRect.contains(docOffset);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // If the user isn't dragging a handle, then the user is trying to
    // scroll the document. Scroll it, accordingly.
    if (_dragMode == null) {
      _scrollPosition.jumpTo(_scrollPosition.pixels - details.delta.dy);
      return;
    }

    // The user is dragging a handle. Update the document selection, and
    // auto-scroll, if needed.

    // From implementation before auto-scrolling:
    // print("_onPanUpdate - selecting position at drag position");
    // _selectDragPositionAt(details.localPosition);

    _globalDragOffset = details.globalPosition;
    final interactorBox = context.findRenderObject() as RenderBox;
    _dragEndInInteractor = interactorBox.globalToLocal(details.globalPosition);

    final viewport = _viewport;
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final dragEndInViewport =
        _interactorOffsetInViewport(_dragEndInInteractor!); // - Offset(0, scrollDeltaWhileDragging);

    _updateSelectionForNewDragHandleLocation();

    editorGesturesLog.finest("Scrolling, if near boundary:");
    editorGesturesLog.finest(' - Scroll delta while dragging: $scrollDeltaWhileDragging');
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

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final dragScrollDelta = _dragStartScrollOffset! - _scrollPosition.pixels;
    final docDragPosition =
        _docLayout.getDocumentPositionAtOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.collapsed) {
      _editingController.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.upstream) {
      _editingController.selection = _editingController.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.downstream) {
      _editingController.selection = _editingController.selection!.copyWith(
        extent: docDragPosition,
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragMode == null) {
      // User was dragging the scroll area. Go ballistic.
      if (_scrollPosition is ScrollPositionWithSingleContext) {
        (_scrollPosition as ScrollPositionWithSingleContext).goBallistic(-details.velocity.pixelsPerSecond.dy);
      }
    } else {
      // The user was dragging a handle. Stop any auto-scrolling that may have started.
      _stopScrollingUp();
      _stopScrollingDown();
    }

    _dragMode = null;
  }

  void _onPanCancel() {
    _dragMode = null;
  }

  void _onTapTimeout() {
    setState(() {
      _waitingForMoreTaps = false;
      _controlsOverlayEntry?.markNeedsBuild();
    });
  }

  void _startScrollingUp() {
    if (_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll up');
    _scrollUpOnTick = true;
    _ticker.start();
  }

  void _stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll up');
    _scrollUpOnTick = false;
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
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    editorGesturesLog.finest("Scroll delta: $scrollDeltaWhileDragging");
    final dragEndInViewport =
        _interactorOffsetInViewport(_dragEndInInteractor!); // - Offset(0, scrollDeltaWhileDragging);
    editorGesturesLog.finest("Drag end in viewport: $dragEndInViewport");
    final leadingScrollBoundary = widget.dragAutoScrollBoundary.leading;
    final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
    final speedPercent = (1.0 - (gutterAmount / leadingScrollBoundary)).clamp(0.0, 1.0);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    _scrollPosition.jumpTo(_scrollPosition.pixels - scrollAmount!);

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
    _ticker.start();
  }

  void _stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll down');
    _scrollDownOnTick = false;
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
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final dragEndInViewport =
        _interactorOffsetInViewport(_dragEndInInteractor!); // - Offset(0, scrollDeltaWhileDragging);
    final trailingScrollBoundary = widget.dragAutoScrollBoundary.trailing;
    final viewportBox = _viewport;
    final gutterAmount = (viewportBox.size.height - dragEndInViewport.dy).clamp(0.0, trailingScrollBoundary);
    final speedPercent = 1.0 - (gutterAmount / trailingScrollBoundary);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    _scrollPosition.jumpTo(_scrollPosition.pixels + scrollAmount!);

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

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    // We have to re-calculate the drag end in the doc (instead of
    // caching the value during the pan update) because the position
    // in the document is impacted by auto-scrolling behavior.
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final dragEndInDoc = _getDocOffset(_dragEndInInteractor! /* - Offset(0, scrollDeltaWhileDragging)*/);

    // TODO: I changed this behavior to get a collapsed handle working - update it
    //       to support base/extent selection
    final dragPosition = _docLayout.getDocumentPositionAtOffset(dragEndInDoc);
    editorGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
      // widget.editContext.composer.selection = null;
      return;
    }

    late DocumentPosition basePosition;
    late DocumentPosition extentPosition;
    switch (_dragHandleType!) {
      case HandleType.collapsed:
        basePosition = dragPosition;
        extentPosition = dragPosition;
        break;
      case HandleType.upstream:
        basePosition = dragPosition;
        extentPosition = widget.editContext.composer.selection!.extent;
        break;
      case HandleType.downstream:
        basePosition = widget.editContext.composer.selection!.base;
        extentPosition = dragPosition;
        break;
    }

    widget.editContext.composer.selection = DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    );
    editorGesturesLog.fine("Selected region: ${widget.editContext.composer.selection}");
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return DocumentTouchEditingControls(
          editingController: _editingController,
          documentKey: widget.documentKey,
          documentLayerLink: _documentLayerLink,
          documentLayout: _docLayout,
          handleColor: Colors.red,
          style: ControlsStyle.iOS,
          onDoubleTapOnCaret: _selectWordAtCaret,
          onTripleTapOnCaret: _selectParagraphAtCaret,
          disableGestureHandling: _waitingForMoreTaps,
          showDebugPaint: false,
        );
      });

      Overlay.of(context)!.insert(_controlsOverlayEntry!);
    }
  }

  void _removeEditingOverlayControls() {
    if (_controlsOverlayEntry != null) {
      _controlsOverlayEntry!.remove();
      _controlsOverlayEntry = null;
    }
  }

  void _selectDragPositionAt(Offset interactorOffset) {
    if (_dragMode == null) {
      return;
    }

    final layoutOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    final position = _docLayout.getDocumentPositionAtOffset(layoutOffset);

    if (position != null) {
      switch (_dragMode!) {
        case _DragMode.collapsed:
          _editingController.selection = DocumentSelection.collapsed(
            position: position,
          );
          return;
        case _DragMode.base:
          _editingController.selection = _editingController.selection!.copyWith(
            base: position,
          );
          return;
        case _DragMode.extent:
          _editingController.selection = _editingController.selection!.copyWith(
            extent: position,
          );
          return;
      }
    }
  }

  void _selectWordAtCaret() {
    final docSelection = widget.editContext.composer.selection;
    if (docSelection == null) {
      return;
    }

    _selectWordAt(
      docPosition: docSelection.extent,
      docLayout: _docLayout,
    );
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

  void _selectParagraphAtCaret() {
    final docSelection = widget.editContext.composer.selection;
    if (docSelection == null) {
      return;
    }

    _selectParagraphAt(
      docPosition: docSelection.extent,
      docLayout: _docLayout,
    );
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

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.editContext.composer.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final ancestorScrollable = Scrollable.of(context);
    _ancestorScrollPosition = ancestorScrollable?.position;

    return _buildGestureInput(
      child: SizedBox(
        width: double.infinity,
        // If there is no ancestor scrollable then we want the gesture area
        // to fill all available height. If there is a scrollable ancestor,
        // then expanding vertically would cause an infinite height, so in that
        // case we let the gesture area take up whatever it can, naturally.
        height: ancestorScrollable == null ? double.infinity : null,
        child: _buildDocumentContainer(
          document: CompositedTransformTarget(
            link: _documentLayerLink,
            child: widget.child,
          ),
          addScrollView: ancestorScrollable == null,
        ),
      ),
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
              ..onTripleTap = _onTripleTap
              ..onTimeout = _onTapTimeout;
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
      child: SizedBox(
        key: _documentWrapperKey,
        child: document,
      ),
    );

    return addScrollView
        ? ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            }),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _scrollController,
              child: documentWidget,
            ),
          )
        : documentWidget;
  }
}

enum _DragMode {
  // Dragging the collapsed handle
  collapsed,
  // Dragging the base handle
  base,
  // Dragging the extent handle
  extent,
}

class DocumentTouchEditingControls extends StatefulWidget {
  const DocumentTouchEditingControls({
    Key? key,
    required this.editingController,
    required this.documentKey,
    required this.documentLayerLink,
    required this.documentLayout,
    required this.handleColor,
    required this.style,
    this.onDoubleTapOnCaret,
    this.onTripleTapOnCaret,
    this.disableGestureHandling = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final EditingController editingController;
  final GlobalKey documentKey;
  final LayerLink documentLayerLink;
  final DocumentLayout documentLayout;
  final Color handleColor;
  final ControlsStyle style;

  /// Callback invoked on iOS when the user double taps on the caret.
  final VoidCallback? onDoubleTapOnCaret;

  /// Callback invoked on iOS when the user triple taps on the caret.
  final VoidCallback? onTripleTapOnCaret;

  /// Disables all gesture interaction for these editing controls,
  /// allowing gestures to pass through these controls to whatever
  /// content currently sits beneath them.
  ///
  /// While this is `true`, the user can't tap or drag on selection
  /// handles or other controls.
  final bool disableGestureHandling;
  final bool showDebugPaint;

  @override
  _DocumentTouchEditingControlsState createState() => _DocumentTouchEditingControlsState();
}

class _DocumentTouchEditingControlsState extends State<DocumentTouchEditingControls>
    with SingleTickerProviderStateMixin {
  // These global keys are assigned to each draggable handle to
  // prevent a strange dragging issue.
  //
  // Without these keys, if the user drags into the auto-scroll area
  // of the text field for a period of time, we never receive a
  // "pan end" or "pan cancel" callback. I have no idea why this is
  // the case. These handles sit in an Overlay, so it's not as if they
  // suffered some conflict within a ScrollView. I tried many adjustments
  // to recover the end/cancel callbacks. Finally, I tried adding these
  // global keys based on a hunch that perhaps the gesture detector was
  // somehow getting switched out, or assigned to a different widget, and
  // that was somehow disrupting the callback series. For now, these keys
  // seem to solve the problem.
  final _collapsedHandleKey = GlobalKey();
  final _upstreamHandleKey = GlobalKey();
  final _downstreamHandleKey = GlobalKey();

  bool _isDraggingCollapsed = false;
  bool _isDraggingBase = false;
  bool _isDraggingExtent = false;
  Offset? _globalStartDragOffset;
  Offset? _globalDragOffset;
  Offset? _localDragOffset;
  // The (x,y) at the center of the content that was selected
  // when the drag began, e.g., the center of a character, or the
  // center of an image.
  Offset? _startDragPositionOffset;

  late CaretBlinkController _caretBlinkController;
  DocumentSelection? _prevSelection;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = CaretBlinkController(tickerProvider: this);
    _prevSelection = widget.editingController.selection;
    widget.editingController.addListener(_onEditingControllerChange);
  }

  @override
  void didUpdateWidget(DocumentTouchEditingControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editingController != oldWidget.editingController) {
      oldWidget.editingController.removeListener(_onEditingControllerChange);
      widget.editingController.addListener(_onEditingControllerChange);
    }
  }

  @override
  void dispose() {
    widget.editingController.removeListener(_onEditingControllerChange);
    _caretBlinkController.dispose();
    super.dispose();
  }

  void _onEditingControllerChange() {
    if (_prevSelection != widget.editingController.selection) {
      if (widget.editingController.selection == null) {
        _caretBlinkController.onCaretRemoved();
      } else if (_prevSelection == null) {
        _caretBlinkController.onCaretPlaced();
      } else {
        _caretBlinkController.onCaretMoved();
      }

      _prevSelection = widget.editingController.selection;
    }
  }

  void _onCollapsedPanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onCollapsedPanStart');

    // widget.editingController
    //   ..hideToolbar()
    //   ..cancelCollapsedHandleAutoHideCountdown();

    _startDragPositionOffset = widget.documentLayout
        .getRectForPosition(
          widget.editingController.selection!.extent,
        )!
        .center;

    // // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    // widget.textScrollController.updateAutoScrollingForTouchOffset(
    //   userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
    //       .globalToLocal(globalOffsetInMiddleOfLine),
    // );
    // widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    setState(() {
      _isDraggingCollapsed = true;
      _isDraggingBase = false;
      _isDraggingExtent = false;
      _globalStartDragOffset = details.globalPosition;
      _globalDragOffset = details.globalPosition;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onBasePanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onBasePanStart');

    // widget.editingController.hideToolbar();

    _startDragPositionOffset = widget.documentLayout
        .getRectForPosition(
          widget.editingController.selection!.base,
        )!
        .center;

    // widget.textScrollController.updateAutoScrollingForTouchOffset(
    //   userInteractionOffsetInViewport:
    //   (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(details.globalPosition),
    // );
    // widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    setState(() {
      _isDraggingBase = true;
      _isDraggingExtent = false;
      _globalStartDragOffset = details.globalPosition;
      _globalDragOffset = details.globalPosition;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onExtentPanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onExtentPanStart');

    // widget.editingController.hideToolbar();

    _startDragPositionOffset = widget.documentLayout
        .getRectForPosition(
          widget.editingController.selection!.extent,
        )!
        .center;

    // widget.textScrollController.updateAutoScrollingForTouchOffset(
    //   userInteractionOffsetInViewport:
    //   (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(details.globalPosition),
    // );
    // widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = true;
      _globalStartDragOffset = details.globalPosition;
      _globalDragOffset = details.globalPosition;
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    editorGesturesLog.fine('_onPanUpdate');

    // Must set global drag offset before _updateSelectionForNewDragHandleLocation()
    _globalDragOffset = details.globalPosition;
    editorGesturesLog.fine(' - global offset: $_globalDragOffset');
    _updateSelectionForNewDragHandleLocation();
    editorGesturesLog.fine(' - done updating selection for new drag handle location');

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    // widget.textScrollController.updateAutoScrollingForTouchOffset(
    //   userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
    //       .globalToLocal(details.globalPosition + _touchHandleOffsetFromLineOfText!),
    // );
    // editorGesturesLog.fine(' - updated auto scrolling for touch offset');

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
      // widget.editingController.showMagnifier(_localDragOffset!);
      editorGesturesLog.fine(' - done updating all local state for drag update');
    });
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final docDragPosition = widget.documentLayout.getDocumentPositionAtOffset(_startDragPositionOffset! + docDragDelta);

    if (docDragPosition == null) {
      return;
    }

    if (_isDraggingCollapsed) {
      widget.editingController.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_isDraggingBase) {
      widget.editingController.selection = widget.editingController.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_isDraggingExtent) {
      widget.editingController.selection = widget.editingController.selection!.copyWith(
        extent: docDragPosition,
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    editorGesturesLog.fine('_onPanEnd');
    _onHandleDragEnd();
  }

  void _onPanCancel() {
    editorGesturesLog.fine('_onPanCancel');
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    editorGesturesLog.fine('_onHandleDragEnd()');
    // widget.textScrollController.stopScrolling();
    // widget.textScrollController.removeListener(_updateSelectionForNewDragHandleLocation);

    // TODO: ensure that extent is visible

    setState(() {
      _isDraggingCollapsed = false;
      _isDraggingBase = false;
      _isDraggingExtent = false;
      // widget.editingController.hideMagnifier();

      if (widget.editingController.selection?.isCollapsed == false) {
        // We hid the toolbar while dragging a handle. If the selection is
        // expanded, show it again.
        // widget.editingController.showToolbar();
      } else {
        // The collapsed handle should disappear after some inactivity.
        // widget.editingController
        //   ..unHideCollapsedHandle()
        //   ..startCollapsedHandleAutoHideCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // On iOS, we treat the handles like a painting without gestures so
      // that the document interactor beneath us can handle all taps/drags.
      ignoring: true,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
            animation: widget.editingController,
            builder: (context, child) {
              return Stack(
                children: [
                  ..._buildHandles(),
                  if (widget.showDebugPaint)
                    IgnorePointer(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.yellow.withOpacity(0.2),
                      ),
                    ),
                ],
              );
            }),
      ),
    );
  }

  List<Widget> _buildHandles() {
    if (!widget.editingController.areHandlesDesired) {
      editorGesturesLog.finer('Not building overlay handles because they aren\'t desired');
      return [];
    }

    if (!widget.editingController.hasSelection) {
      editorGesturesLog.finer('Not building overlay handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    // Note: we don't build the collapsed handle if we're currently dragging
    //       the base or extent because, if we did, then when the user drags
    //       crosses the base and extent, we'd suddenly jump from an expanded
    //       selection to a collapsed selection.
    if (widget.editingController.selection!.isCollapsed && !_isDraggingBase && !_isDraggingExtent) {
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    final extentRect = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent);

    editorGesturesLog.fine("Selection extent rect: $extentRect");

    // if (extentHandleOffsetInText == const Offset(0, 0) && extentTextPosition.offset != 0) {
    //   // The caret offset is (0, 0), but the caret text position isn't at the
    //   // beginning of the text. This means that there's a layout timing
    //   // issue and we should reschedule this calculation for the next frame.
    //   _scheduleRebuildBecauseTextIsNotLaidOutYet();
    //   return const SizedBox();
    // }

    // if (extentLineHeight == 0) {
    //   editorGesturesLog.finer('Not building collapsed handle because the text layout reported a zero line-height');
    //   // A line height of zero indicates that the text isn't laid out yet.
    //   // Schedule a rebuild to give the text a frame to layout.
    //   _scheduleRebuildBecauseTextIsNotLaidOutYet();
    //   return const SizedBox();
    // }

    return _buildHandle(
      handleKey: _collapsedHandleKey,
      positionRect: extentRect!,
      handleType: HandleType.collapsed,
      showHandle: true,
      debugColor: Colors.blue,
      onPanStart: _onCollapsedPanStart,
    );
  }

  List<Widget> _buildExpandedHandles() {
    final base = widget.editingController.selection!.base;
    final baseIndex = widget.editingController.document.getNodeIndex(
      widget.editingController.document.getNode(base)!,
    );
    final extent = widget.editingController.selection!.extent;
    final extentNode = widget.editingController.document.getNode(extent)!;
    final extentIndex = widget.editingController.document.getNodeIndex(
      extentNode,
    );

    // // The selection is expanded. Draw 2 drag handles.
    // // TODO: handle the case with no text affinity and then query widget.selection!.affinity
    // // TODO: handle RTL text orientation
    late TextAffinity selectionDirection;
    if (extentIndex > baseIndex) {
      selectionDirection = TextAffinity.downstream;
    } else if (extentIndex < baseIndex) {
      selectionDirection = TextAffinity.upstream;
    } else {
      // The selection is within the same node. Ask the node which position
      // comes first.
      if (base.nodePosition == extentNode.selectUpstreamPosition(base.nodePosition, extent.nodePosition)) {
        selectionDirection = TextAffinity.downstream;
      } else {
        selectionDirection = TextAffinity.upstream;
      }
    }

    final baseRect = widget.documentLayout.getRectForPosition(base);
    editorGesturesLog.fine("Selection base rect: $baseRect");

    final extentRect = widget.documentLayout.getRectForPosition(extent);
    editorGesturesLog.fine("Selection extent rect: $extentRect");

    return [
      // Left-bounding handle touch target
      _buildHandle(
        handleKey: _upstreamHandleKey,
        positionRect: selectionDirection == TextAffinity.downstream ? baseRect! : extentRect!,
        showHandle: true,
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onBasePanStart : _onExtentPanStart,
      ),
      // right-bounding handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        positionRect: selectionDirection == TextAffinity.downstream ? extentRect! : baseRect!,
        showHandle: true,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onExtentPanStart : _onBasePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Rect positionRect,
    required bool showHandle,
    required HandleType handleType,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    const ballDiameter = 8.0;

    late Widget handle;
    late Offset handleOrigin;
    late Offset handleOffset;
    late double caretHeight;
    switch (handleType) {
      case HandleType.collapsed:
        handleOrigin = positionRect.topLeft;
        handleOffset = const Offset(-1, 0);
        caretHeight = positionRect.height;
        handle = IOSCollapsedHandle(
          controller: _caretBlinkController,
          color: widget.handleColor,
          caretHeight: caretHeight,
        );
        break;
      case HandleType.upstream:
        handleOrigin = positionRect.topLeft;
        handleOffset = const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: max(positionRect.height, 0),
          ballRadius: ballDiameter / 2,
        );
        break;
      case HandleType.downstream:
        handleOrigin = positionRect.topRight;
        handleOffset = const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: max(positionRect.height, 0),
          ballRadius: ballDiameter / 2,
        );
        break;
    }

    return CompositedTransformFollower(
      key: handleKey,
      link: widget.documentLayerLink,
      offset: handleOrigin,
      child: Transform.translate(
        offset: handleOffset + const Offset(-5, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          color: widget.showDebugPaint ? Colors.green : Colors.transparent,
          child: showHandle ? handle : const SizedBox(),
        ),
      ),
    );
  }
}
