import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_selection_on_focus_mixin.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

import '../infrastructure/document_gestures.dart';
import 'document_gestures_touch.dart';
import 'selection_upstream_downstream.dart';

/// Document gesture interactor that's designed for iOS touch input, e.g.,
/// drag to scroll, and handles to control selection.
class IOSDocumentTouchInteractor extends StatefulWidget {
  const IOSDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.document,
    required this.documentKey,
    required this.getDocumentLayout,
    required this.selection,
    this.scrollController,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    required this.handleColor,
    required this.popoverToolbarBuilder,
    required this.floatingCursorController,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final Document document;
  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;
  final ValueNotifier<DocumentSelection?> selection;

  final ScrollController? scrollController;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  /// Color the iOS-style text selection drag handles.
  final Color handleColor;

  final WidgetBuilder popoverToolbarBuilder;

  /// Controller that reports the current offset of the iOS floating
  /// cursor.
  final FloatingCursorController floatingCursorController;

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
  State createState() => _IOSDocumentTouchInteractorState();
}

class _IOSDocumentTouchInteractorState extends State<IOSDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin, DocumentSelectionOnFocusMixin {
  // ScrollController used when this interactor installs its own Scrollable.
  // The alternative case is the one in which this interactor defers to an
  // ancestor scrollable.
  late ScrollController _scrollController;
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
  DragMode? _dragMode;
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
      // During Hot Reload, the gesture mode could be changed.
      // If that's the case, initState is called while the Overlay is being
      // built. This could crash the app. Because of that, we show the editing
      // controls overlay in the next frame.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _showEditingControlsOverlay();
      });
    }

    _scrollController = _scrollController = (widget.scrollController ?? ScrollController());
    // I added this listener directly to our ScrollController because the listener we added
    // to the ScrollPosition wasn't triggering once the user makes an initial selection. I'm
    // not sure why that happened. It's as if the ScrollPosition was replaced, but I don't
    // know why the ScrollPosition would be replaced. In the meantime, adding this listener
    // keeps the toolbar positioning logic working.
    // TODO: rely solely on a ScrollPosition listener, not a ScrollController listener.
    _scrollController.addListener(_onScrollChange);

    _editingController = IosDocumentGestureEditingController(
      documentLayoutLink: _documentLayerLink,
      magnifierFocalPointLink: _magnifierFocalPointLink,
    );

    widget.document.addListener(_onDocumentChange);
    widget.selection.addListener(_onSelectionChange);

    startSyncingSelectionWithFocus(
      focusNode: widget.focusNode,
      getDocumentLayout: widget.getDocumentLayout,
      selection: widget.selection,
    );

    // If we already have a selection, we need to display the caret.
    if (widget.selection.value != null) {
      _onSelectionChange();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _ancestorScrollPosition = _findAncestorScrollable(context)?.position;

    // On the next frame, check if our active scroll position changed to a
    // different instance. If it did, move our listener to the new one.
    //
    // This is posted to the next frame because the first time this method
    // runs, we haven't attached to our own ScrollController yet, so
    // this.scrollPosition might be null.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
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
      onFocusNodeReplaced(widget.focusNode);
    }

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
      onDocumentSelectionNotifierReplaced(widget.selection);

      // Selection has changed, we need to update the caret.
      if (widget.selection.value != oldWidget.selection.value) {
        _onSelectionChange();
      }
    }

    if (widget.getDocumentLayout != oldWidget.getDocumentLayout) {
      onDocumentLayoutResolverReplaced(widget.getDocumentLayout);
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
        // During Hot Reload, the gesture mode could be changed,
        // so it's possible that we are no longer mounted after
        // the post frame callback.
        if (mounted) {
          _showEditingControlsOverlay();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    widget.document.removeListener(_onDocumentChange);
    widget.selection.removeListener(_onSelectionChange);

    _removeEditingOverlayControls();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    _handleAutoScrolling.dispose();

    widget.focusNode.removeListener(_onFocusChange);

    stopSyncingSelectionWithFocus();

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
        _updateHandlesAfterSelectionOrLayoutChange();

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

    // Determines the offset of the bottom of the handle in the viewport coordinate
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

  void _onDocumentChange(DocumentChangeLog changeLog) {
    _editingController.hideToolbar();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
      // TODO: find a way to only do this when something relevant changes
      _updateHandlesAfterSelectionOrLayoutChange();

      _ensureSelectionExtentIsVisible();
    });
  }

  void _onSelectionChange() {
    // The selection change might correspond to new content that's not
    // laid out yet. Wait until the next frame to update visuals.
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateHandlesAfterSelectionOrLayoutChange();
    });
  }

  void _updateHandlesAfterSelectionOrLayoutChange() {
    final newSelection = widget.selection.value;

    if (newSelection == null) {
      _editingController
        ..removeCaret()
        ..hideToolbar()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null;
    } else if (newSelection.isCollapsed) {
      _positionCaret();
      _positionCollapsedHandle();
    } else {
      // The selection is expanded
      _positionExpandedSelectionHandles();
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
      (_findAncestorScrollable(context)?.context.findRenderObject() ?? context.findRenderObject()) as RenderBox;

  RenderBox get interactorBox => context.findRenderObject() as RenderBox;

  /// Converts the given [interactorOffset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _interactorOffsetToDocOffset(Offset interactorOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
  }

  /// Converts the given [documentOffset] to an `Offset` in the interactor's
  /// coordinate space.
  Offset _docOffsetToInteractorOffset(Offset documentOffset) {
    return _docLayout.getAncestorOffsetFromDocumentOffset(documentOffset, context.findRenderObject()!);
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
    final selection = widget.selection.value;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      _editingController.toggleToolbar();
      _positionToolbar();
      return;
    }

    editorGesturesLog.info("Tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null &&
        selection != null &&
        !selection.isCollapsed &&
        widget.document.doesSelectionContainPosition(selection, docPosition)) {
      // The user tapped on an expanded selection. Toggle the toolbar.
      _editingController.toggleToolbar();
      _positionToolbar();
      return;
    }

    setState(() {
      _waitingForMoreTaps = true;
      _controlsOverlayEntry?.markNeedsBuild();
    });

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

      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        // The user tapped a non-selectable component.
        // Place the document selection at the nearest selectable node
        // to the tapped component.
        moveSelectionToNearestSelectableNode(
          document: widget.document,
          documentLayoutResolver: widget.getDocumentLayout,
          selection: widget.selection,
          startingNode: widget.document.getNodeById(docPosition.nodeId)!,
        );
        return;
      } else {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    } else {
      widget.selection.value = null;
      _editingController.hideToolbar();
    }

    _positionToolbar();

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapUp(TapUpDetails details) {
    final selection = widget.selection.value;
    if (selection != null &&
        !selection.isCollapsed &&
        (_isOverBaseHandle(details.localPosition) || _isOverExtentHandle(details.localPosition))) {
      return;
    }

    editorGesturesLog.info("Double tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      widget.selection.value = null;

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
    } else {
      widget.selection.value = null;
    }

    final newSelection = widget.selection.value;
    if (newSelection == null || newSelection.isCollapsed) {
      _editingController.hideToolbar();
    } else {
      _editingController.showToolbar();
      _positionToolbar();
    }

    widget.focusNode.requestFocus();
  }

  bool _selectBlockAt(DocumentPosition position) {
    if (position.nodePosition is! UpstreamDownstreamNodePosition) {
      return false;
    }

    widget.selection.value = DocumentSelection(
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

  void _onTripleTapUp(TapUpDetails details) {
    editorGesturesLog.info("Triple down down on document");

    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      widget.selection.value = null;

      final didSelectParagraph = _selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    } else {
      widget.selection.value = null;
    }

    final selection = widget.selection.value;
    if (selection == null || selection.isCollapsed) {
      _editingController.hideToolbar();
    } else {
      _editingController.showToolbar();
      _positionToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onPanDown(DragDownDetails details) {
    // No-op: this method is only here to beat out any ancestor
    // Scrollable that's also trying to drag.
  }

  void _onPanStart(DragStartDetails details) {
    // TODO: to help the user drag handles instead of scrolling, try checking touch
    //       placement during onTapDown, and then pick that up here. I think the little
    //       bit of slop might be the problem.
    final selection = widget.selection.value;
    if (selection == null) {
      return;
    }

    if (selection.isCollapsed && _isOverCollapsedHandle(details.localPosition)) {
      _dragMode = DragMode.collapsed;
      _dragHandleType = HandleType.collapsed;
    } else if (_isOverBaseHandle(details.localPosition)) {
      _dragMode = DragMode.base;
      _dragHandleType = HandleType.upstream;
    } else if (_isOverExtentHandle(details.localPosition)) {
      _dragMode = DragMode.extent;
      _dragHandleType = HandleType.downstream;
    } else {
      return;
    }

    _editingController.hideToolbar();

    _globalStartDragOffset = details.globalPosition;
    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(details.globalPosition);
    _dragStartInDoc = _interactorOffsetToDocOffset(handleOffsetInInteractor);

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
    final collapsedPosition = widget.selection.value?.extent;
    if (collapsedPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(collapsedPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = widget.selection.value?.base;
    if (basePosition == null) {
      return false;
    }

    final baseRect = _docLayout.getRectForPosition(basePosition)!;
    // The following caretRect offset and size were chosen empirically, based
    // on trying to drag the handle from various locations near the handle.
    final caretRect = Rect.fromLTWH(baseRect.left - 24, baseRect.top - 24, 48, baseRect.height + 48);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverExtentHandle(Offset interactorOffset) {
    final extentPosition = widget.selection.value?.extent;
    if (extentPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(extentPosition)!;
    // The following caretRect offset and size were chosen empirically, based
    // on trying to drag the handle from various locations near the handle.
    final caretRect = Rect.fromLTWH(extentRect.left - 24, extentRect.top, 48, extentRect.height + 32);

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
    final docDragPosition = _docLayout
        .getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_dragHandleType == HandleType.collapsed) {
      widget.selection.value = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.upstream) {
      widget.selection.value = widget.selection.value!.copyWith(
        base: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.downstream) {
      widget.selection.value = widget.selection.value!.copyWith(
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
    if (!widget.selection.value!.isCollapsed) {
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

    final dragEndInDoc = _interactorOffsetToDocOffset(_dragEndInInteractor!);
    final dragPosition = _docLayout.getDocumentPositionNearestToOffset(dragEndInDoc);
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
        extentPosition = widget.selection.value!.extent;
        break;
      case HandleType.downstream:
        basePosition = widget.selection.value!.base;
        extentPosition = dragPosition;
        break;
    }

    widget.selection.value = DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    );
    editorGesturesLog.fine("Selected region: ${widget.selection.value}");
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry != null) {
      return;
    }

    _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
      return IosDocumentTouchEditingControls(
        editingController: _editingController,
        floatingCursorController: widget.floatingCursorController,
        documentLayout: _docLayout,
        document: widget.document,
        selection: widget.selection,
        handleColor: widget.handleColor,
        onDoubleTapOnCaret: _selectWordAtCaret,
        onTripleTapOnCaret: _selectParagraphAtCaret,
        onFloatingCursorStart: _onFloatingCursorStart,
        onFloatingCursorMoved: _moveSelectionToFloatingCursor,
        onFloatingCursorStop: _onFloatingCursorStop,
        magnifierFocalPointOffset: _globalDragOffset,
        popoverToolbarBuilder: widget.popoverToolbarBuilder,
        createOverlayControlsClipper: widget.createOverlayControlsClipper,
        disableGestureHandling: _waitingForMoreTaps,
        showDebugPaint: false,
      );
    });

    Overlay.of(context).insert(_controlsOverlayEntry!);
  }

  void _positionCaret() {
    final extentRect = _docLayout.getRectForPosition(widget.selection.value!.extent)!;

    _editingController.updateCaret(
      top: extentRect.topLeft,
      height: extentRect.height,
    );
  }

  void _positionCollapsedHandle() {
    final selection = widget.selection.value;
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

    _editingController.collapsedHandleOffset = handleOffset;
  }

  void _positionExpandedSelectionHandles() {
    final selection = widget.selection.value;
    if (selection == null) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but there is no document selection");
      return;
    }
    if (selection.isCollapsed) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but the selection is collapsed");
      return;
    }

    // Calculate the new (x,y) offsets for the upstream and downstream handles.
    final baseRect = _docLayout.getRectForPosition(selection.base)!;
    final baseHandleOffset = baseRect.bottomLeft;

    final extentRect = _docLayout.getRectForPosition(selection.extent)!;
    final extentHandleOffset = extentRect.bottomRight;

    final affinity = widget.document.getAffinityForSelection(selection);

    final upstreamHandleOffset = affinity == TextAffinity.downstream ? baseHandleOffset : extentHandleOffset;
    final upstreamHandleHeight = affinity == TextAffinity.downstream ? baseRect.height : extentRect.height;

    final downstreamHandleOffset = affinity == TextAffinity.downstream ? extentHandleOffset : baseHandleOffset;
    final downstreamHandleHeight = affinity == TextAffinity.downstream ? extentRect.height : baseRect.height;

    _editingController
      ..removeCaret()
      ..collapsedHandleOffset = null
      ..upstreamHandleOffset = upstreamHandleOffset
      ..upstreamCaretHeight = upstreamHandleHeight
      ..downstreamHandleOffset = downstreamHandleOffset
      ..downstreamCaretHeight = downstreamHandleHeight;
  }

  void _positionToolbar() {
    if (!_editingController.shouldDisplayToolbar) {
      return;
    }

    const toolbarGap = 24.0;
    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    final selection = widget.selection.value!;
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

  void _selectWordAtCaret() {
    final docSelection = widget.selection.value;
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
      widget.selection.value = newSelection;
      return true;
    } else {
      return false;
    }
  }

  void _selectParagraphAtCaret() {
    final docSelection = widget.selection.value;
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
      widget.selection.value = newSelection;
      return true;
    } else {
      return false;
    }
  }

  void _onFloatingCursorStart() {
    _handleAutoScrolling.startAutoScrollHandleMonitoring();
  }

  void _moveSelectionToFloatingCursor(Offset documentOffset) {
    final nearestDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(documentOffset)!;
    _selectPosition(nearestDocumentPosition);
    _handleAutoScrolling.updateAutoScrollHandleMonitoring(
      dragEndInViewport: _docOffsetToInteractorOffset(documentOffset),
    );
  }

  void _onFloatingCursorStop() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
  }

  void _selectPosition(DocumentPosition position) {
    editorGesturesLog.fine("Setting document selection to $position");
    widget.selection.value = DocumentSelection.collapsed(
      position: position,
    );
  }

  ScrollableState? _findAncestorScrollable(BuildContext context) {
    final ancestorScrollable = Scrollable.maybeOf(context);
    if (ancestorScrollable == null) {
      return null;
    }

    final direction = ancestorScrollable.axisDirection;
    // If the direction is horizontal, then we are inside a widget like a TabBar
    // or a horizontal ListView, so we can't use the ancestor scrollable
    if (direction == AxisDirection.left || direction == AxisDirection.right) {
      return null;
    }

    return ancestorScrollable;
  }

  @override
  Widget build(BuildContext context) {
    if (_scrollController.hasClients) {
      if (_scrollController.positions.length > 1) {
        // During Hot Reload, if the gesture mode was changed,
        // the widget might be built while the old gesture interactor
        // scroller is still attached to the _scrollController.
        //
        // Defer adding the listener to the next frame.
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          setState(() {});
        });
      } else {
        if (scrollPosition != _activeScrollPosition) {
          _activeScrollPosition = scrollPosition;
          _activeScrollPosition?.addListener(_onScrollChange);
        }
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
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
          () => TapSequenceGestureRecognizer(),
          (TapSequenceGestureRecognizer recognizer) {
            recognizer
              ..onTapUp = _onTapUp
              ..onDoubleTapUp = _onDoubleTapUp
              ..onTripleTapUp = _onTripleTapUp
              ..onTimeout = _onTapTimeout;
          },
        ),
        // We use a VerticalDragGestureRecognizer instead of a PanGestureRecognizer
        // because `Scrollable` also uses a VerticalDragGestureRecognizer and we
        // need to beat out any ancestor `Scrollable` in the gesture arena.
        VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
          (VerticalDragGestureRecognizer instance) {
            instance
              ..dragStartBehavior = DragStartBehavior.down
              ..onDown = _onPanDown
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

enum DragMode {
  // Dragging the collapsed handle
  collapsed,
  // Dragging the base handle
  base,
  // Dragging the extent handle
  extent,
}
