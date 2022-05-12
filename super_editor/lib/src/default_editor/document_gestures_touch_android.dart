import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_text/super_selectable_text.dart';

import 'document_gestures.dart';
import 'document_gestures_touch.dart';
import 'selection_upstream_downstream.dart';

/// Document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
class AndroidDocumentTouchInteractor extends StatefulWidget {
  const AndroidDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.composer,
    required this.document,
    required this.documentKey,
    required this.getDocumentLayout,
    this.scrollController,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
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

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  final bool showDebugPaint;

  final Widget child;

  @override
  _AndroidDocumentTouchInteractorState createState() => _AndroidDocumentTouchInteractorState();
}

class _AndroidDocumentTouchInteractorState extends State<AndroidDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ScrollController used when this interactor installs its own Scrollable.
  // The alternative case is the one in which this interactor defers to an
  // ancestor scrollable.
  late ScrollController _scrollController;
  // The ScrollPosition attached to the _ancestorScrollable, if there's an ancestor
  // Scrollable.
  ScrollPosition? _ancestorScrollPosition;
  // The actual ScrollPosition that's used for the document layout, either
  // the Scrollable installed by this interactor, or an ancestor Scrollable.
  ScrollPosition? _activeScrollPosition;

  // OverlayEntry that displays editing controls, e.g.,
  // drag handles, magnifier, and toolbar.
  OverlayEntry? _controlsOverlayEntry;
  late AndroidDocumentGestureEditingController _editingController;
  final _documentLayoutLink = LayerLink();
  final _magnifierFocalPointLink = LayerLink();

  late DragHandleAutoScroller _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  SelectionType? _selectionType;

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
    // On the next frame, after our ScrollController is attached to the Scrollable,
    // add a listener for scroll changes.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateScrollPositionListener();
    });
    // I added this listener directly to our ScrollController because the listener we added
    // to the ScrollPosition wasn't triggering once the user makes an initial selection. I'm
    // not sure why that happened. It's as if the ScrollPosition was replaced, but I don't
    // know why the ScrollPosition would be replaced. In the meantime, adding this listener
    // keeps the toolbar positioning logic working.
    // TODO: rely solely on a ScrollPosition listener, not a ScrollController listener.
    _scrollController.addListener(_onScrollChange);

    _editingController = AndroidDocumentGestureEditingController(
      documentLayoutLink: _documentLayoutLink,
      magnifierFocalPointLink: _magnifierFocalPointLink,
    );

    widget.document.addListener(_onDocumentChange);

    widget.composer.addListener(_onSelectionChange);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _ancestorScrollPosition = Scrollable.of(context)?.position;

    // On the next frame, check if our active scroll position changed to a
    // different instance. If it did, move our listener to the new one.
    //
    // This is posted to the next frame because the first time this method
    // runs, we haven't attached to our own ScrollController yet, so
    // this.scrollPosition might be null.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateScrollPositionListener();
    });
  }

  @override
  void didUpdateWidget(AndroidDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
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

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _showEditingControlsOverlay();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // TODO: I commented this out because the scroll position is already
    //       disposed by the time this runs and it causes an error.
    // _activeScrollPosition?.removeListener(_onScrollChange);

    // We dispose the EditingController on the next frame because
    // the ListenableBuilder that uses it throws an error if we
    // dispose of it here.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _editingController.dispose();
    });

    widget.document.removeListener(_onDocumentChange);

    widget.composer.removeListener(_onSelectionChange);

    _removeEditingOverlayControls();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    widget.focusNode.removeListener(_onFocusChange);

    _handleAutoScrolling.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _ensureSelectionExtentIsVisible();

        setState(() {
          // reflow document layout
        });
      }
    });
  }

  void _ensureSelectionExtentIsVisible() {
    editorGesturesLog.fine("Ensuring selection extent is visible");
    final collapsedHandleOffset = _editingController.collapsedHandleOffset;
    final extentHandleOffset = _editingController.downstreamHandleOffset;
    if (collapsedHandleOffset == null && extentHandleOffset == null) {
      // There's no selection. We don't need to take any action.
      return;
    }

    // Determines the offset of the editor in the viewport coordinate
    final editorBox = widget.documentKey.currentContext!.findRenderObject() as RenderBox;
    final editorInViewportOffset = viewportBox.localToGlobal(Offset.zero) - editorBox.localToGlobal(Offset.zero);

    // Determines the offset of the handle in the viewport coordinate
    late Offset handleInViewportOffset;

    if (collapsedHandleOffset != null) {
      editorGesturesLog.fine("The selection is collapsed");
      handleInViewportOffset = collapsedHandleOffset - editorInViewportOffset;
    } else {
      editorGesturesLog.fine("The selection is expanded");
      handleInViewportOffset = extentHandleOffset! - editorInViewportOffset;
    }
    _handleAutoScrolling.ensureOffsetIsVisible(handleInViewportOffset);
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

  void _onDocumentChange() {
    _editingController.hideToolbar();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
      _updateHandlesAfterSelectionOrLayoutChange();

      _ensureSelectionExtentIsVisible();
    });
  }

  void _onSelectionChange() {
    // The selection change might correspond to new content that's not
    // laid out yet. Wait until the next frame to update visuals.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateHandlesAfterSelectionOrLayoutChange();
    });
  }

  void _updateHandlesAfterSelectionOrLayoutChange() {
    final newSelection = widget.composer.selection;

    if (newSelection == null) {
      _editingController
        ..removeCaret()
        ..hideToolbar()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null
        ..cancelCollapsedHandleAutoHideCountdown();
    } else if (newSelection.isCollapsed) {
      _positionCaret();
      _positionCollapsedHandle();
    } else {
      // The selection is expanded
      _positionExpandedHandles();
    }
  }

  void _updateScrollPositionListener() {
    final newScrollPosition = scrollPosition;
    if (newScrollPosition != _activeScrollPosition) {
      _activeScrollPosition?.removeListener(_onScrollChange);
      newScrollPosition.addListener(_onScrollChange);
      _activeScrollPosition = newScrollPosition;
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
    final interactorBox = context.findRenderObject() as RenderBox;
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  void _onTapUp(TapUpDetails details) {
    editorGesturesLog.info("Tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final selection = widget.composer.selection;
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

      _positionToolbar();
    } else {
      _clearSelection();

      _editingController.hideToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

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

      if (!widget.composer.selection!.isCollapsed) {
        _editingController.showToolbar();
        _positionToolbar();
      } else {
        // The selection is collapsed. The collapsed handle should disappear
        // after some inactivity. Start the countdown (or restart an in-progress
        // countdown).
        _editingController
          ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
      }
    }

    widget.focusNode.requestFocus();
  }

  bool _selectBlockAt(DocumentPosition position) {
    if (position.nodePosition is! UpstreamDownstreamNodePosition) {
      return false;
    }

    widget.composer.selection = DocumentSelection(
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

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

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
        _positionToolbar();
      }
    }

    widget.focusNode.requestFocus();
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return AndroidDocumentTouchEditingControls(
          editingController: _editingController,
          documentKey: widget.documentKey,
          documentLayout: _docLayout,
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          handleColor: Colors.red,
          onHandleDragStart: _onHandleDragStart,
          onHandleDragUpdate: _onHandleDragUpdate,
          onHandleDragEnd: _onHandleDragEnd,
          popoverToolbarBuilder: widget.popoverToolbarBuilder,
          showDebugPaint: false,
        );
      });

      Overlay.of(context)!.insert(_controlsOverlayEntry!);
    }
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    final selectionAffinity = widget.document.getAffinityForSelection(widget.composer.selection!);
    switch (handleType) {
      case HandleType.collapsed:
        _selectionType = SelectionType.collapsed;
        break;
      case HandleType.upstream:
        _selectionType = selectionAffinity == TextAffinity.downstream ? SelectionType.base : SelectionType.extent;
        break;
      case HandleType.downstream:
        _selectionType = selectionAffinity == TextAffinity.downstream ? SelectionType.extent : SelectionType.base;
        break;
    }

    _globalStartDragOffset = globalOffset;
    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _getDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _selectionType == SelectionType.base ? widget.composer.selection!.base : widget.composer.selection!.extent,
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

    if (_selectionType == SelectionType.collapsed) {
      // Don't let the handle fade out while dragging it.
      _editingController.cancelCollapsedHandleAutoHideCountdown();
    }

    scrollPosition.addListener(_updateDragSelection);
  }

  void _onHandleDragUpdate(Offset globalOffset) {
    _globalDragOffset = globalOffset;
    final interactorBox = context.findRenderObject() as RenderBox;
    _dragEndInInteractor = interactorBox.globalToLocal(globalOffset);
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!);

    _updateSelectionForNewDragHandleLocation();

    _handleAutoScrolling.updateAutoScrollHandleMonitoring(
      dragEndInViewport: dragEndInViewport,
    );

    _editingController.showMagnifier();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final dragScrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
    final docDragPosition = _docLayout
        .getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_selectionType == SelectionType.collapsed) {
      widget.composer.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_selectionType == SelectionType.base) {
      widget.composer.selection = widget.composer.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_selectionType == SelectionType.extent) {
      widget.composer.selection = widget.composer.selection!.copyWith(
        extent: docDragPosition,
      );
    }
  }

  void _onHandleDragEnd() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);

    _editingController.hideMagnifier();

    _dragStartScrollOffset = null;
    _dragStartInDoc = null;
    _dragEndInInteractor = null;

    if (widget.composer.selection!.isCollapsed) {
      // The selection is collapsed. The collapsed handle should disappear
      // after some inactivity. Start the countdown (or restart an in-progress
      // countdown).
      _editingController
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
    } else {
      _editingController.showToolbar();
      _positionToolbar();
    }
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    // We have to re-calculate the drag end in the doc (instead of
    // caching the value during the pan update) because the position
    // in the document is impacted by auto-scrolling behavior.
    // final scrollDeltaWhileDragging = _dragStartScrollOffset! - scrollPosition.pixels;
    final dragEndInDoc = _getDocOffset(_dragEndInInteractor! /* - Offset(0, scrollDeltaWhileDragging)*/);

    final dragPosition = _docLayout.getDocumentPositionNearestToOffset(dragEndInDoc);
    editorGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
      return;
    }

    late DocumentPosition basePosition;
    late DocumentPosition extentPosition;
    switch (_selectionType!) {
      case SelectionType.collapsed:
        basePosition = dragPosition;
        extentPosition = dragPosition;
        break;
      case SelectionType.base:
        basePosition = dragPosition;
        extentPosition = widget.composer.selection!.extent;
        break;
      case SelectionType.extent:
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

  void _positionCollapsedHandle() {
    final selection = widget.composer.selection;
    if (selection == null) {
      editorGesturesLog.shout("Tried to update collapsed handle offset but there is no document selection");
      return;
    }
    if (!selection.isCollapsed) {
      editorGesturesLog.shout("Tried to update collapsed handle offset but the selection is expanded");
      return;
    }

    // Calculate the new (x,y) offset for the collapsed handle.
    final extentRect = _docLayout.getRectForPosition(selection.extent);
    late Offset handleOffset = extentRect!.bottomLeft;

    _editingController
      ..collapsedHandleOffset = handleOffset
      ..unHideCollapsedHandle()
      ..startCollapsedHandleAutoHideCountdown();
  }

  void _positionExpandedHandles() {
    final selection = widget.composer.selection;
    if (selection == null) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but there is no document selection");
      return;
    }
    if (selection.isCollapsed) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but the selection is collapsed");
      return;
    }

    // Calculate the new (x,y) offsets for the upstream and downstream handles.
    final baseHandleOffset = _docLayout.getRectForPosition(selection.base)!.bottomLeft;
    final extentHandleOffset = _docLayout.getRectForPosition(selection.extent)!.bottomRight;
    final affinity = widget.document.getAffinityBetween(base: selection.base, extent: selection.extent);
    late Offset upstreamHandleOffset = affinity == TextAffinity.downstream ? baseHandleOffset : extentHandleOffset;
    late Offset downstreamHandleOffset = affinity == TextAffinity.downstream ? extentHandleOffset : baseHandleOffset;

    _editingController
      ..removeCaret()
      ..collapsedHandleOffset = null
      ..upstreamHandleOffset = upstreamHandleOffset
      ..downstreamHandleOffset = downstreamHandleOffset
      ..cancelCollapsedHandleAutoHideCountdown();
  }

  void _positionCaret() {
    final extentRect = _docLayout.getRectForPosition(widget.composer.selection!.extent)!;

    _editingController.updateCaret(
      top: extentRect.topLeft,
      height: extentRect.height,
    );
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

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.composer.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGestureInput(
      child: ScrollableDocument(
        scrollController: _scrollController,
        documentLayerLink: _documentLayoutLink,
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
              ..onTripleTapDown = _onTripleTapDown;
          },
        ),
      },
      child: child,
    );
  }
}

class AndroidDocumentTouchEditingControls extends StatefulWidget {
  const AndroidDocumentTouchEditingControls({
    Key? key,
    required this.editingController,
    required this.documentKey,
    required this.documentLayout,
    required this.handleColor,
    this.onHandleDragStart,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AndroidDocumentGestureEditingController editingController;

  final GlobalKey documentKey;

  final DocumentLayout documentLayout;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  final Color handleColor;

  final void Function(HandleType handleType, Offset globalOffset)? onHandleDragStart;

  final void Function(Offset globalOffset)? onHandleDragUpdate;

  final void Function()? onHandleDragEnd;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final Widget Function(BuildContext) popoverToolbarBuilder;

  final bool showDebugPaint;

  @override
  _AndroidDocumentTouchEditingControlsState createState() => _AndroidDocumentTouchEditingControlsState();
}

class _AndroidDocumentTouchEditingControlsState extends State<AndroidDocumentTouchEditingControls>
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

  bool _isDraggingExpandedHandle = false;
  bool _isDraggingHandle = false;
  Offset? _localDragOffset;

  late CaretBlinkController _caretBlinkController;
  Offset? _prevCaretOffset;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = CaretBlinkController(tickerProvider: this);
    _prevCaretOffset = widget.editingController.caretTop;
    widget.editingController.addListener(_onEditingControllerChange);

    if (widget.editingController.shouldDisplayCollapsedHandle) {
      widget.editingController.startCollapsedHandleAutoHideCountdown();
    }
  }

  @override
  void didUpdateWidget(AndroidDocumentTouchEditingControls oldWidget) {
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

  void _onCollapsedPanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onCollapsedPanStart');

    setState(() {
      _isDraggingExpandedHandle = false;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });

    widget.onHandleDragStart?.call(HandleType.collapsed, details.globalPosition);
  }

  void _onUpstreamHandlePanStart(DragStartDetails details) {
    _onExpandedHandleDragStart(details);
    widget.onHandleDragStart?.call(HandleType.upstream, details.globalPosition);
  }

  void _onDownstreamHandlePanStart(DragStartDetails details) {
    _onExpandedHandleDragStart(details);
    widget.onHandleDragStart?.call(HandleType.downstream, details.globalPosition);
  }

  void _onExpandedHandleDragStart(DragStartDetails details) {
    setState(() {
      _isDraggingExpandedHandle = true;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    editorGesturesLog.fine('_onPanUpdate');

    widget.onHandleDragUpdate?.call(details.globalPosition);

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
    });
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

    // TODO: ensure that extent is visible

    setState(() {
      _isDraggingExpandedHandle = false;
      _isDraggingHandle = false;
      _localDragOffset = null;
    });

    widget.onHandleDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editingController,
      builder: (context) {
        return Padding(
          // Remove the keyboard from the space that we occupy so that
          // clipping calculations apply to the expected visual borders,
          // instead of applying underneath the keyboard.
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRect(
            clipper: widget.createOverlayControlsClipper?.call(context),
            child: SizedBox(
              // ^ SizedBox tries to be as large as possible, because
              // a Stack will collapse into nothing unless something
              // expands it.
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Build the caret
                  _buildCaret(),
                  // Build the drag handles (if desired)
                  ..._buildHandles(),
                  // Build the focal point for the magnifier
                  if (_isDraggingHandle) _buildMagnifierFocalPoint(),
                  // Build the magnifier (this needs to be done before building
                  // the handles so that the magnifier doesn't show the handles
                  if (widget.editingController.shouldDisplayMagnifier) _buildMagnifier(),
                  // Build the editing toolbar
                  if (widget.editingController.shouldDisplayToolbar && widget.editingController.isToolbarPositioned)
                    _buildToolbar(context),
                  // Build a UI that's useful for debugging, if desired.
                  if (widget.showDebugPaint)
                    IgnorePointer(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.yellow.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaret() {
    if (!widget.editingController.hasCaret) {
      return const SizedBox();
    }

    return CompositedTransformFollower(
      link: widget.editingController.documentLayoutLink,
      offset: widget.editingController.caretTop!,
      child: IgnorePointer(
        child: BlinkingCaret(
          controller: _caretBlinkController,
          caretOffset: const Offset(-1, 0),
          caretHeight: widget.editingController.caretHeight!,
          width: 2,
          color: widget.showDebugPaint ? Colors.green : widget.handleColor,
          borderRadius: BorderRadius.zero,
          isTextEmpty: false,
          showCaret: true,
        ),
      ),
    );
  }

  List<Widget> _buildHandles() {
    if (!widget.editingController.shouldDisplayCollapsedHandle &&
        !widget.editingController.shouldDisplayExpandedHandles) {
      editorGesturesLog.finer('Not building overlay handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    if (widget.editingController.shouldDisplayCollapsedHandle && !_isDraggingExpandedHandle) {
      // Note: we don't build the collapsed handle if we're currently dragging
      //       the base or extent because, if we did, then when the user drags
      //       crosses the base and extent, we'd suddenly jump from an expanded
      //       selection to a collapsed selection.
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    return _buildHandle(
      handleKey: _collapsedHandleKey,
      handleOffset: widget.editingController.collapsedHandleOffset! + const Offset(0, 5),
      handleFractionalTranslation: const Offset(-0.5, 0.0),
      handleType: HandleType.collapsed,
      debugColor: Colors.green,
      onPanStart: _onCollapsedPanStart,
    );
  }

  List<Widget> _buildExpandedHandles() {
    return [
      // upstream-bounding (left side of a RTL line of text) handle touch target
      _buildHandle(
        handleKey: _upstreamHandleKey,
        handleOffset: widget.editingController.upstreamHandleOffset! + const Offset(0, 2),
        handleFractionalTranslation: const Offset(-1.0, 0.0),
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: _onUpstreamHandlePanStart,
      ),
      // downstream-bounding (right side of a RTL line of text) handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        handleOffset: widget.editingController.downstreamHandleOffset! + const Offset(0, 2),
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: _onDownstreamHandlePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset handleOffset,
    Offset handleFractionalTranslation = Offset.zero,
    required HandleType handleType,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    return CompositedTransformFollower(
      key: handleKey,
      link: widget.editingController.documentLayoutLink,
      offset: handleOffset,
      child: FractionalTranslation(
        translation: handleFractionalTranslation,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            color: widget.showDebugPaint ? Colors.green : Colors.transparent,
            child: AnimatedOpacity(
              opacity: handleType == HandleType.collapsed && widget.editingController.isCollapsedHandleAutoHidden
                  ? 0.0
                  : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AndroidSelectionHandle(
                handleType: handleType,
                color: widget.handleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: _localDragOffset!.dx,
      // TODO: select focal position based on type of content
      top: _localDragOffset!.dy - 20,
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
      child: AndroidFollowingMagnifier(
        layerLink: widget.editingController.magnifierFocalPointLink,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    // TODO: figure out why this approach works. Why isn't the text field's
    //       RenderBox offset stale when the keyboard opens or closes? Shouldn't
    //       we end up with the previous offset because no rebuild happens?
    //
    //       Disproven theory: CompositedTransformFollower's link causes a rebuild of its
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
        desiredTopAnchorInTextField: widget.editingController.toolbarTopAnchor!, //toolbarTopAnchor,
        desiredBottomAnchorInTextField: widget.editingController.toolbarBottomAnchor!, //toolbarBottomAnchor,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.shouldDisplayToolbar,
        child: AnimatedOpacity(
          opacity: widget.editingController.shouldDisplayToolbar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Builder(builder: widget.popoverToolbarBuilder),
        ),
      ),
    );
  }
}

class HandleStartDragEvent {
  const HandleStartDragEvent({
    required this.selectionType,
    required this.globalHandleDragStartOffset,
    required this.globalHandleDocPositionRect,
  });

  /// The type of selection that the user started to drag, e.g., collapsed, base, extent.
  final SelectionType selectionType;

  /// The global offset where the user started dragging.
  ///
  /// This offset sits somewhere within the handle that the
  /// user is dragging.
  final Offset globalHandleDragStartOffset;

  /// The global rectangle that contains the content next to
  /// the caret where the handle sits.
  ///
  /// This rectangle encapsulate a character, or an image, etc.
  final Rect globalHandleDocPositionRect;
}

class HandleUpdateDragEvent {
  const HandleUpdateDragEvent({
    required this.selectionType,
    required this.globalHandleDragOffset,
  });

  /// The type of selection that the user started to drag, e.g., collapsed, base, extent.
  final SelectionType selectionType;

  /// The current global offset of the user's pointer during
  /// a handle drag event.
  final Offset globalHandleDragOffset;
}

enum SelectionType {
  collapsed,
  base,
  extent,
}

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming Android-style behavior for the
/// handles.
class AndroidDocumentGestureEditingController extends MagnifierAndToolbarController {
  AndroidDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required LayerLink magnifierFocalPointLink,
  })  : _documentLayoutLink = documentLayoutLink,
        super(magnifierFocalPointLink: magnifierFocalPointLink);

  @override
  void dispose() {
    _collapsedHandleAutoHideTimer?.cancel();
    super.dispose();
  }

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

  final Duration _collapsedHandleAutoHideDuration = const Duration(seconds: 4);
  Timer? _collapsedHandleAutoHideTimer;

  /// Whether the collapsed handle should be faded out for the purpose of
  /// auto-hiding while the user is inactive.
  bool get isCollapsedHandleAutoHidden => _isCollapsedHandleAutoHidden;
  bool _isCollapsedHandleAutoHidden = false;

  /// Starts a countdown that, if reached, fades out the collapsed drag handle.
  void startCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
    _collapsedHandleAutoHideTimer = Timer(_collapsedHandleAutoHideDuration, _hideCollapsedHandle);
  }

  /// Cancels a countdown that started with [startCollapsedHandleAutoHideCountdown].
  void cancelCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
  }

  void _hideCollapsedHandle() {
    if (!_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = true;
      notifyListeners();
    }
  }

  /// Brings back a faded-out collapsed drag handle.
  void unHideCollapsedHandle() {
    if (_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = false;
      notifyListeners();
    }
  }
}
