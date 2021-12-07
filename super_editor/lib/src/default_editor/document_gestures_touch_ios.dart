import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/caret.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

import 'document_gestures.dart';
import 'document_gestures_touch.dart';

/// Document gesture interactor that's designed for iOS touch input, e.g.,
/// drag to scroll, and handles to control selection.
class IOSDocumentTouchInteractor extends StatefulWidget {
  const IOSDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.composer,
    required this.document,
    required this.documentKey,
    required this.getDocumentLayout,
    this.scrollController,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    required this.popoverToolbarBuilder,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final DocumentComposer composer;
  final Document document;
  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;

  final ScrollController? scrollController;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  final WidgetBuilder popoverToolbarBuilder;

  final bool showDebugPaint;

  final Widget child;

  @override
  _IOSDocumentTouchInteractorState createState() => _IOSDocumentTouchInteractorState();
}

class _IOSDocumentTouchInteractorState extends State<IOSDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ScrollController used when this interactor installs its own Scrollable.
  // The alternative case is the one in which this interactor defers to an
  // ancestor scrollable.
  late ScrollController _scrollController;
  // The nearest ancestor scrollable, if one exists. This interactor defers
  // to the ancestor scrollable when it exists.
  ScrollableState? _ancestorScrollable;
  // The ScrollPosition attached to the _ancestorScrollable.
  ScrollPosition? _ancestorScrollPosition;
  // The actual ScrollPosition that's used for the document layout, either
  // the Scrollable installed by this interactor, or an ancestor Scrollable.
  ScrollPosition? _activeScrollPosition;

  // OverlayEntry that displays editing controls, e.g.,
  // drag handles, magnifier, and toolbar.
  OverlayEntry? _controlsOverlayEntry;
  late IosDocumentGestureEditingController _editingController;
  final _documentLayerLink = LayerLink();
  final _magnifierFocalPointLink = LayerLink();

  late DragHandleAutoScroller _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  _DragMode? _dragMode;
  // TODO: HandleType is the wrong type here, we need collapsed/base/extent,
  //       not collapsed/upstream/downstream. Change the type once it's working.
  HandleType? _dragHandleType;

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

  @override
  void initState() {
    super.initState();

    _handleAutoScrolling = DragHandleAutoScroller(
      vsync: this,
      dragAutoScrollBoundary: widget.dragAutoScrollBoundary,
      getScrollPosition: () => scrollPosition,
      getViewportBox: () => viewportBox,
    );

    widget.focusNode.addListener(_onFocusChange);
    if (widget.focusNode.hasFocus) {
      _showEditingControlsOverlay();
    }

    _scrollController = _scrollController = (widget.scrollController ?? ScrollController());

    _editingController = IosDocumentGestureEditingController(
      documentLayoutLink: _documentLayerLink,
      magnifierFocalPointLink: _magnifierFocalPointLink,
    );

    widget.composer.addListener(_onSelectionChange);

    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _ancestorScrollable = Scrollable.of(context);
    _ancestorScrollPosition = _ancestorScrollable?.position;

    // On the next frame, check if our active scroll position changed to a
    // different instance. If it did, move our listener to the new one.
    //
    // This is posted to the next frame because the first time this method
    // runs, we haven't attached to our own ScrollController yet, so
    // this.scrollPosition might be null.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      final newScrollPosition = scrollPosition;
      if (newScrollPosition != _activeScrollPosition) {
        setState(() {
          _activeScrollPosition?.removeListener(_onScrollChange);
          newScrollPosition.addListener(_onScrollChange);
          _activeScrollPosition = newScrollPosition;
        });
      }
    });
  }

  @override
  void didUpdateWidget(IOSDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.removeListener(_onSelectionChange);
      widget.composer.addListener(_onSelectionChange);
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

    widget.composer.removeListener(_onSelectionChange);

    _removeEditingOverlayControls();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    _handleAutoScrolling.dispose();

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
    final newSelection = widget.composer.selection;

    if (newSelection == null) {
      _editingController
        ..removeCaret()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null;
    } else if (newSelection.isCollapsed) {
      _positionCaret();

      // Calculate the new (x,y) offset for the collapsed handle.
      final extentRect = _docLayout.getRectForPosition(newSelection.extent);
      late Offset handleOffset = extentRect!.bottomLeft;

      _editingController.collapsedHandleOffset = handleOffset;
    } else {
      // The selection is expanded
      _positionExpandedCarets();

      // Calculate the new (x,y) offsets for the upstream and downstream handles.
      final baseHandleOffset = _docLayout.getRectForPosition(newSelection.base)!.bottomLeft;
      final extentHandleOffset = _docLayout.getRectForPosition(newSelection.extent)!.bottomRight;
      final affinity = widget.document.getAffinityBetween(base: newSelection.base, extent: newSelection.extent);
      late Offset upstreamHandleOffset = affinity == TextAffinity.downstream ? baseHandleOffset : extentHandleOffset;
      late Offset downstreamHandleOffset = affinity == TextAffinity.downstream ? extentHandleOffset : baseHandleOffset;

      _editingController
        ..removeCaret()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = upstreamHandleOffset
        ..downstreamHandleOffset = downstreamHandleOffset;
    }
  }

  void _onScrollChange() {
    _positionToolbar();
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

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
  ScrollPosition get scrollPosition => _ancestorScrollPosition ?? _scrollController.position;

  /// Returns the `RenderBox` for the scrolling viewport.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `RenderBox` belongs to that ancestor `Scrollable`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and this `State`'s render object
  /// is the viewport `RenderBox`.
  RenderBox get viewportBox =>
      (Scrollable.of(context)?.context.findRenderObject() ?? context.findRenderObject()) as RenderBox;

  RenderBox get interactorBox => context.findRenderObject() as RenderBox;

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
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  void _onTapUp(TapUpDetails details) {
    final selection = widget.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
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

    if (docPosition != null) {
      final didTapOnExistingSelection = selection != null && selection.isCollapsed && selection.extent == docPosition;

      if (didTapOnExistingSelection) {
        // Toggle the toolbar display when the user taps on the collapsed caret,
        // or on top of an existing selection.
        _editingController.toggleToolbar();
      } else {
        // The user tapped somewhere else in the document. Hide the toolbar.
        _editingController.hideToolbar();
      }

      // Place the document selection at the location where the
      // user tapped.
      _selectPosition(docPosition);
    } else {
      widget.composer.clearSelection();
      _editingController.hideToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final selection = widget.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    widget.composer.clearSelection();

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

    final newSelection = widget.composer.selection;
    if (newSelection == null || newSelection.isCollapsed) {
      _editingController.hideToolbar();
    } else {
      _editingController.showToolbar();
      _positionToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTapDown(TapDownDetails details) {
    final selection = widget.composer.selection;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    widget.composer.clearSelection();

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

    if (selection == null || selection.isCollapsed) {
      _editingController.hideToolbar();
    } else {
      _editingController.showToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onPanStart(DragStartDetails details) {
    final selection = widget.composer.selection;
    if (selection == null) {
      return;
    }

    if (selection.isCollapsed && _isOverCollapsedHandle(details.localPosition)) {
      _dragMode = _DragMode.collapsed;
      _dragHandleType = HandleType.collapsed;
    } else if (_isOverBaseHandle(details.localPosition)) {
      _dragMode = _DragMode.base;
      _dragHandleType = HandleType.upstream;
    } else if (_isOverExtentHandle(details.localPosition)) {
      _dragMode = _DragMode.extent;
      _dragHandleType = HandleType.downstream;
    } else {
      return;
    }

    _editingController.hideToolbar();

    _globalStartDragOffset = details.globalPosition;
    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(details.globalPosition);
    _dragStartInDoc = _getDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _dragHandleType! == HandleType.upstream ? selection.base : selection.extent,
        )!
        .center;

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = scrollPosition.pixels;

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    scrollPosition.addListener(_updateDragSelection);

    _controlsOverlayEntry!.markNeedsBuild();
  }

  bool _isOverCollapsedHandle(Offset interactorOffset) {
    final collapsedPosition = widget.composer.selection?.extent;
    if (collapsedPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(collapsedPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = widget.composer.selection?.base;
    if (basePosition == null) {
      return false;
    }

    final baseRect = _docLayout.getRectForPosition(basePosition)!;
    final caretRect = Rect.fromLTWH(baseRect.left - 1, baseRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverExtentHandle(Offset interactorOffset) {
    final extentPosition = widget.composer.selection?.extent;
    if (extentPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(extentPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // If the user isn't dragging a handle, then the user is trying to
    // scroll the document. Scroll it, accordingly.
    if (_dragMode == null) {
      scrollPosition.jumpTo(scrollPosition.pixels - details.delta.dy);
      _positionToolbar();
      return;
    }

    // The user is dragging a handle. Update the document selection, and
    // auto-scroll, if needed.
    _globalDragOffset = details.globalPosition;
    final interactorBox = context.findRenderObject() as RenderBox;
    _dragEndInInteractor = interactorBox.globalToLocal(details.globalPosition);
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!);

    _updateSelectionForNewDragHandleLocation();

    _handleAutoScrolling.updateAutoScrollHandleMonitoring(
      dragEndInViewport: dragEndInViewport,
    );

    _editingController.showMagnifier();

    _controlsOverlayEntry!.markNeedsBuild();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final dragScrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
    final docDragPosition =
        _docLayout.getDocumentPositionAtOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.collapsed) {
      widget.composer.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.upstream) {
      widget.composer.selection = widget.composer.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.downstream) {
      widget.composer.selection = widget.composer.selection!.copyWith(
        extent: docDragPosition,
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragMode == null) {
      // User was dragging the scroll area. Go ballistic.
      if (scrollPosition is ScrollPositionWithSingleContext) {
        (scrollPosition as ScrollPositionWithSingleContext).goBallistic(-details.velocity.pixelsPerSecond.dy);

        // We add the scroll change listener again, because going ballistic
        // seems to switch out the scroll position.
        scrollPosition.addListener(_onScrollChange);
      }
    } else {
      // The user was dragging a handle. Stop any auto-scrolling that may have started.
      _onHandleDragEnd();
    }
  }

  void _onPanCancel() {
    if (_dragMode != null) {
      _onHandleDragEnd();
    }
  }

  void _onHandleDragEnd() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);
    _dragMode = null;

    _editingController.hideMagnifier();
    if (!widget.composer.selection!.isCollapsed) {
      _editingController.showToolbar();
      _positionToolbar();
    }

    _controlsOverlayEntry!.markNeedsBuild();
  }

  void _onTapTimeout() {
    setState(() {
      _waitingForMoreTaps = false;
      _controlsOverlayEntry?.markNeedsBuild();
    });
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    final dragEndInDoc = _getDocOffset(_dragEndInInteractor!);
    final dragPosition = _docLayout.getDocumentPositionAtOffset(dragEndInDoc);
    editorGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
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
        extentPosition = widget.composer.selection!.extent;
        break;
      case HandleType.downstream:
        basePosition = widget.composer.selection!.base;
        extentPosition = dragPosition;
        break;
    }

    widget.composer.selection = DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    );
    editorGesturesLog.fine("Selected region: ${widget.composer.selection}");
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry != null) {
      return;
    }

    _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
      return IosDocumentTouchEditingControls(
        editingController: _editingController,
        documentLayout: _docLayout,
        handleColor: Colors.red,
        onDoubleTapOnCaret: _selectWordAtCaret,
        onTripleTapOnCaret: _selectParagraphAtCaret,
        magnifierFocalPointOffset: _globalDragOffset,
        popoverToolbarBuilder: widget.popoverToolbarBuilder,
        disableGestureHandling: _waitingForMoreTaps,
        showDebugPaint: false,
      );
    });

    Overlay.of(context)!.insert(_controlsOverlayEntry!);
  }

  void _positionCaret() {
    final extentRect = _docLayout.getRectForPosition(widget.composer.selection!.extent)!;

    _editingController.updateCaret(
      top: extentRect.topLeft,
      height: extentRect.height,
    );
  }

  void _positionExpandedCarets() {
    final baseRect = _docLayout.getRectForPosition(widget.composer.selection!.base)!;
    final extentRect = _docLayout.getRectForPosition(widget.composer.selection!.extent)!;

    final selectionAffinity = widget.document.getAffinityBetween(
      base: widget.composer.selection!.base,
      extent: widget.composer.selection!.extent,
    );

    _editingController
      ..upstreamCaretHeight = selectionAffinity == TextAffinity.downstream ? baseRect.height : extentRect.height
      ..downstreamCaretHeight = selectionAffinity == TextAffinity.downstream ? extentRect.height : baseRect.height;
  }

  void _positionToolbar() {
    if (!_editingController.shouldDisplayToolbar) {
      return;
    }

    const toolbarGap = 24.0;
    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    final selection = widget.composer.selection!;
    if (selection.isCollapsed) {
      final extentRectInDoc = _docLayout.getRectForPosition(selection.extent)!;
      selectionRect = Rect.fromPoints(
        _docLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.topLeft),
        _docLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.bottomRight),
      );
    } else {
      final baseRectInDoc = _docLayout.getRectForPosition(selection.base)!;
      final extentRectInDoc = _docLayout.getRectForPosition(selection.extent)!;
      final selectionRectInDoc = Rect.fromPoints(
        Offset(
          min(baseRectInDoc.left, extentRectInDoc.left),
          min(baseRectInDoc.top, extentRectInDoc.top),
        ),
        Offset(
          max(baseRectInDoc.right, extentRectInDoc.right),
          max(baseRectInDoc.bottom, extentRectInDoc.bottom),
        ),
      );
      selectionRect = Rect.fromPoints(
        _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.topLeft),
        _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.bottomRight),
      );
    }

    // TODO: fix the horizontal placement
    //       The logic to position the toolbar horizontally is wrong.
    //       The toolbar should appear horizontally centered between the
    //       left-most and right-most edge of the selection. However, the
    //       left-most and right-most edge of the selection may not match
    //       the handle locations. Consider the situation where multiple
    //       lines/blocks of content are selected, but both handles sit near
    //       the left side of the screen. This logic will position the
    //       toolbar near the left side of the content, when the toolbar should
    //       instead be centered across the full width of the document.
    toolbarTopAnchor = selectionRect.topCenter - const Offset(0, toolbarGap);
    toolbarBottomAnchor = selectionRect.bottomCenter + const Offset(0, toolbarGap);

    // The selection might start above the visible area on the screen.
    // In that case, keep the toolbar on-screen.
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      max(
        toolbarTopAnchor.dy,
        // TODO: choose a gap spacing that makes sense, e.g., what's the safe area?
        24,
      ),
    );

    // The selection might end below the visible area on the screen.
    // In that case, keep the toolbar on-screen.
    final screenHeight = (context.findRenderObject() as RenderBox).size.height;
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      min(
        toolbarTopAnchor.dy,
        // TODO: choose a gap spacing that makes sense, e.g., what's the safe area?
        screenHeight - 24,
      ),
    );

    _editingController.positionToolbar(
      topAnchor: toolbarTopAnchor,
      bottomAnchor: toolbarBottomAnchor,
    );
  }

  void _removeEditingOverlayControls() {
    if (_controlsOverlayEntry != null) {
      _controlsOverlayEntry!.remove();
      _controlsOverlayEntry = null;
    }
  }

  void _selectWordAtCaret() {
    final docSelection = widget.composer.selection;
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
      widget.composer.selection = newSelection;
      return true;
    } else {
      return false;
    }
  }

  void _selectParagraphAtCaret() {
    final docSelection = widget.composer.selection;
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
      widget.composer.selection = newSelection;
      return true;
    } else {
      return false;
    }
  }

  void _selectPosition(DocumentPosition position) {
    editorGesturesLog.fine("Setting document selection to $position");
    widget.composer.selection = DocumentSelection.collapsed(
      position: position,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scrollController.hasClients) {
      if (scrollPosition != _activeScrollPosition) {
        _activeScrollPosition = scrollPosition;
        _activeScrollPosition?.addListener(_onScrollChange);
      }
    }

    return _buildGestureInput(
      child: ScrollableDocument(
        scrollController: _scrollController,
        disableDragScrolling: true,
        documentLayerLink: _documentLayerLink,
        child: widget.child,
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
              ..onTripleTapDown = _onTripleTapDown
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
}

enum _DragMode {
  // Dragging the collapsed handle
  collapsed,
  // Dragging the base handle
  base,
  // Dragging the extent handle
  extent,
}

class IosDocumentTouchEditingControls extends StatefulWidget {
  const IosDocumentTouchEditingControls({
    Key? key,
    required this.editingController,
    required this.documentLayout,
    required this.handleColor,
    this.onDoubleTapOnCaret,
    this.onTripleTapOnCaret,
    this.magnifierFocalPointOffset,
    required this.popoverToolbarBuilder,
    this.disableGestureHandling = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final IosDocumentGestureEditingController editingController;

  final DocumentLayout documentLayout;

  final Color handleColor;

  /// Callback invoked on iOS when the user double taps on the caret.
  final VoidCallback? onDoubleTapOnCaret;

  /// Callback invoked on iOS when the user triple taps on the caret.
  final VoidCallback? onTripleTapOnCaret;

  /// Offset where the magnifier should focus.
  ///
  /// The magnifier is displayed whenever this offset is non-null, otherwise
  /// the magnifier is not shown.
  final Offset? magnifierFocalPointOffset;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final Widget Function(BuildContext) popoverToolbarBuilder;

  /// Disables all gesture interaction for these editing controls,
  /// allowing gestures to pass through these controls to whatever
  /// content currently sits beneath them.
  ///
  /// While this is `true`, the user can't tap or drag on selection
  /// handles or other controls.
  final bool disableGestureHandling;

  final bool showDebugPaint;

  @override
  _IosDocumentTouchEditingControlsState createState() => _IosDocumentTouchEditingControlsState();
}

class _IosDocumentTouchEditingControlsState extends State<IosDocumentTouchEditingControls>
    with SingleTickerProviderStateMixin {
  // These global keys are assigned to each draggable handle to
  // prevent a strange dragging issue.
  //
  // Without these keys, if the user drags into the auto-scroll area
  // for a period of time, we never receive a
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

  late CaretBlinkController _caretBlinkController;
  Offset? _prevCaretOffset;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = CaretBlinkController(tickerProvider: this);
    _prevCaretOffset = widget.editingController.caretTop;
    widget.editingController.addListener(_onEditingControllerChange);
  }

  @override
  void didUpdateWidget(IosDocumentTouchEditingControls oldWidget) {
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
    if (_prevCaretOffset != widget.editingController.caretTop) {
      if (widget.editingController.caretTop == null) {
        _caretBlinkController.onCaretRemoved();
      } else if (_prevCaretOffset == null) {
        _caretBlinkController.onCaretPlaced();
      } else {
        _caretBlinkController.onCaretMoved();
      }

      _prevCaretOffset = widget.editingController.caretTop;
    }
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
                  // Build the editing toolbar
                  if (widget.editingController.shouldDisplayToolbar && widget.editingController.isToolbarPositioned)
                    _buildToolbar(),
                  // Build the focal point for the magnifier
                  if (widget.magnifierFocalPointOffset != null) _buildMagnifierFocalPoint(),
                  // Build the magnifier
                  if (widget.editingController.shouldDisplayMagnifier) _buildMagnifier(),
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
    if (!widget.editingController.shouldDisplayCollapsedHandle &&
        !widget.editingController.shouldDisplayExpandedHandles) {
      editorGesturesLog.finer('Not building overlay handles because they aren\'t desired');
      return [];
    }

    if (widget.editingController.shouldDisplayCollapsedHandle) {
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    return _buildHandleOld(
      handleKey: _collapsedHandleKey,
      handleType: HandleType.collapsed,
      debugColor: Colors.blue,
    );
  }

  List<Widget> _buildExpandedHandles() {
    return [
      // Left-bounding handle touch target
      _buildHandleOld(
        handleKey: _upstreamHandleKey,
        handleType: HandleType.upstream,
        debugColor: Colors.green,
      ),
      // right-bounding handle touch target
      _buildHandleOld(
        handleKey: _downstreamHandleKey,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
      ),
    ];
  }

  Widget _buildHandleOld({
    required Key handleKey,
    required HandleType handleType,
    required Color debugColor,
  }) {
    const ballDiameter = 8.0;

    late Widget handle;
    late Offset handleOffset;
    switch (handleType) {
      case HandleType.collapsed:
        handleOffset = widget.editingController.caretTop! + const Offset(-1, 0);
        handle = IOSCollapsedHandle(
          controller: _caretBlinkController,
          color: widget.handleColor,
          caretHeight: widget.editingController.caretHeight!,
        );
        break;
      case HandleType.upstream:
        handleOffset = widget.editingController.upstreamHandleOffset! -
            Offset(0, widget.editingController.downstreamCaretHeight!) +
            const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: widget.editingController.upstreamCaretHeight!,
          ballRadius: ballDiameter / 2,
        );
        break;
      case HandleType.downstream:
        handleOffset = widget.editingController.downstreamHandleOffset! -
            Offset(0, widget.editingController.downstreamCaretHeight!) +
            const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: widget.editingController.downstreamCaretHeight!,
          ballRadius: ballDiameter / 2,
        );
        break;
    }

    return _buildHandle(
      handleKey: handleKey,
      handleOffset: handleOffset,
      handle: handle,
      debugColor: debugColor,
    );
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset handleOffset,
    required Widget handle,
    required Color debugColor,
  }) {
    return CompositedTransformFollower(
      key: handleKey,
      link: widget.editingController.documentLayoutLink,
      offset: handleOffset + const Offset(-5, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        color: widget.showDebugPaint ? Colors.green : Colors.transparent,
        child: handle,
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: widget.magnifierFocalPointOffset!.dx,
      top: widget.magnifierFocalPointOffset!.dy,
      child: CompositedTransformTarget(
        link: widget.editingController.magnifierFocalPointLink,
        child: const SizedBox(width: 1, height: 1),
      ),
    );
  }

  Widget _buildMagnifier() {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, we place a LayerLink
    // target. This magnifier follows that target.
    return Center(
      child: IOSFollowingMagnifier.roundedRectangle(
        layerLink: widget.editingController.magnifierFocalPointLink,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  Widget _buildToolbar() {
    // TODO: figure out why this approach works. Why isn't the text field's
    //       RenderBox offset stale when the keyboard opens or closes? Shouldn't
    //       we end up with the previous offset because no rebuild happens?
    //
    //       Dis-proven theory: CompositedTransformFollower's link causes a rebuild of its
    //       subtree whenever the linked transform changes.
    //
    //       Theory:
    //         - Keyboard only effects vertical offsets, so global x offset
    //           was never at risk
    //         - The global y offset isn't used in the calculation at all
    //         - If this same approach were used in a situation where the
    //           distance between the left edge of the available space and the
    //           text field changed, I think it would fail.
    return CustomSingleChildLayout(
      delegate: ToolbarPositionDelegate(
        // TODO: handle situation where document isn't full screen
        textFieldGlobalOffset: Offset.zero,
        desiredTopAnchorInTextField: widget.editingController.toolbarTopAnchor!,
        desiredBottomAnchorInTextField: widget.editingController.toolbarBottomAnchor!,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.shouldDisplayToolbar,
        child: AnimatedOpacity(
          opacity: widget.editingController.shouldDisplayToolbar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Builder(builder: (context) {
            return widget.popoverToolbarBuilder(context);
          }),
        ),
      ),
    );
  }
}

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming iOS-style behavior for the
/// handles.
class IosDocumentGestureEditingController extends MagnifierAndToolbarController {
  IosDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required LayerLink magnifierFocalPointLink,
  })  : _documentLayoutLink = documentLayoutLink,
        super(magnifierFocalPointLink: magnifierFocalPointLink);

  /// Layer link that's aligned to the top-left corner of the document layout.
  ///
  /// Some of the offsets reported by this controller are based on the
  /// document layout coordinate space. Therefore, to honor those offsets on
  /// the screen, this `LayerLink` should be used to align the controls with
  /// the document layout before applying the offset that sits within the
  /// document layout.
  LayerLink get documentLayoutLink => _documentLayoutLink;
  final LayerLink _documentLayoutLink;

  /// Whether or not a caret should be displayed.
  bool get hasCaret => caretTop != null;

  /// The offset of the top of the caret, or `null` if no caret should
  /// be displayed.
  ///
  /// When the caret is drawn, the caret will have a thickness. That width
  /// should be placed either on the left or right of this offset, based on
  /// whether the [caretAffinity] is upstream or downstream, respectively.
  Offset? get caretTop => _caretTop;
  Offset? _caretTop;

  /// The height of the caret, or `null` if no caret should be displayed.
  double? get caretHeight => _caretHeight;
  double? _caretHeight;

  /// Updates the caret's size and position.
  ///
  /// The [top] offset is in the document layout's coordinate space.
  void updateCaret({
    Offset? top,
    double? height,
  }) {
    bool changed = false;
    if (top != null) {
      _caretTop = top;
      changed = true;
    }
    if (height != null) {
      _caretHeight = height;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Removes the caret from the display.
  void removeCaret() {
    if (!hasCaret) {
      return;
    }

    _caretTop = null;
    _caretHeight = null;
    notifyListeners();
  }

  /// Whether a collapsed handle should be displayed.
  bool get shouldDisplayCollapsedHandle => _collapsedHandleOffset != null;

  /// The offset of the collapsed handle focal point, within the coordinate space
  /// of the document layout, or `null` if no collapsed handle should be displayed.
  Offset? get collapsedHandleOffset => _collapsedHandleOffset;
  Offset? _collapsedHandleOffset;
  set collapsedHandleOffset(Offset? offset) {
    if (offset != _collapsedHandleOffset) {
      _collapsedHandleOffset = offset;
      notifyListeners();
    }
  }

  /// Whether the expanded handles (base + extent) should be displayed.
  bool get shouldDisplayExpandedHandles => _upstreamHandleOffset != null && _downstreamHandleOffset != null;

  double? get upstreamCaretHeight => _upstreamCaretHeight;
  double? _upstreamCaretHeight;
  set upstreamCaretHeight(double? height) {
    if (height != _upstreamCaretHeight) {
      _upstreamCaretHeight = height;
      notifyListeners();
    }
  }

  /// The offset of the upstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no upstream handle should be displayed.
  Offset? get upstreamHandleOffset => _upstreamHandleOffset;
  Offset? _upstreamHandleOffset;
  set upstreamHandleOffset(Offset? offset) {
    if (offset != _upstreamHandleOffset) {
      _upstreamHandleOffset = offset;
      notifyListeners();
    }
  }

  double? get downstreamCaretHeight => _downstreamCaretHeight;
  double? _downstreamCaretHeight;
  set downstreamCaretHeight(double? height) {
    if (height != _downstreamCaretHeight) {
      _downstreamCaretHeight = height;
      notifyListeners();
    }
  }

  /// The offset of the downstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no downstream handle should be displayed.
  Offset? get downstreamHandleOffset => _downstreamHandleOffset;
  Offset? _downstreamHandleOffset;
  set downstreamHandleOffset(Offset? offset) {
    if (offset != _downstreamHandleOffset) {
      _downstreamHandleOffset = offset;
      notifyListeners();
    }
  }
}
