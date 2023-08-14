import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/document_gestures.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_pipeline.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_textfield/metrics.dart';

/// Read-only document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
///
/// The primary difference between a read-only touch interactor, and an
/// editing touch interactor, is that read-only documents don't support
/// collapsed selections, i.e., caret display. When the user taps on
/// a read-only document, nothing happens. The user must drag an expanded
/// selection, or double/triple tap to select content.
class ReadOnlyAndroidDocumentTouchInteractor extends StatefulWidget {
  const ReadOnlyAndroidDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.document,
    required this.documentKey,
    required this.getDocumentLayout,
    required this.selection,
    required this.selectionLinks,
    required this.scrollController,
    this.contentTapHandler,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    required this.handleColor,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
    this.overlayController,
    this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final Document document;
  final GlobalKey documentKey;
  final DocumentLayout Function() getDocumentLayout;
  final ValueNotifier<DocumentSelection?> selection;

  final SelectionLayerLinks selectionLinks;

  /// Optional handler that responds to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  final ContentTapDelegate? contentTapHandler;

  final ScrollController scrollController;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  /// The color of the Android-style drag handles.
  final Color handleColor;

  final WidgetBuilder popoverToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  final bool showDebugPaint;

  final Widget? child;

  @override
  State createState() => _ReadOnlyAndroidDocumentTouchInteractorState();
}

class _ReadOnlyAndroidDocumentTouchInteractorState extends State<ReadOnlyAndroidDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isScrolling = false;

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
  final _magnifierFocalPointLink = LayerLink();

  late DragHandleAutoScroller _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  SelectionHandleType? _handleType;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  late MagnifierAndToolbarController _overlayController;

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

    _configureScrollController();

    _overlayController = widget.overlayController ?? MagnifierAndToolbarController();

    _editingController = AndroidDocumentGestureEditingController(
      selectionLinks: widget.selectionLinks,
      magnifierFocalPointLink: _magnifierFocalPointLink,
      overlayController: _overlayController,
    );

    widget.document.addListener(_onDocumentChange);
    widget.selection.addListener(_onSelectionChange);

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
    onNextFrame((_) => _updateScrollPositionListener());
  }

  @override
  void didUpdateWidget(ReadOnlyAndroidDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }

    if (widget.scrollController != oldWidget.scrollController) {
      _teardownScrollController();
      _configureScrollController();
    }

    if (widget.overlayController != oldWidget.overlayController) {
      _overlayController = widget.overlayController ?? MagnifierAndToolbarController();
      _editingController.overlayController = _overlayController;
    }

    // Selection has changed, we need to update the caret.
    if (widget.selection.value != oldWidget.selection.value) {
      _onSelectionChange();
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

      onNextFrame((_) => _showEditingControlsOverlay());
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
    widget.selection.removeListener(_onSelectionChange);

    _removeEditingOverlayControls();

    _teardownScrollController();

    widget.focusNode.removeListener(_onFocusChange);

    _handleAutoScrolling.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    onNextFrame((_) {
      _ensureSelectionExtentIsVisible();
      _updateHandlesAfterSelectionOrLayoutChange();

      setState(() {
        // reflow document layout
      });
    });
  }

  void _configureScrollController() {
    // I added this listener directly to our ScrollController because the listener we added
    // to the ScrollPosition wasn't triggering once the user makes an initial selection. I'm
    // not sure why that happened. It's as if the ScrollPosition was replaced, but I don't
    // know why the ScrollPosition would be replaced. In the meantime, adding this listener
    // keeps the toolbar positioning logic working.
    // TODO: rely solely on a ScrollPosition listener, not a ScrollController listener.
    widget.scrollController.addListener(_onScrollChange);

    onNextFrame((_) => scrollPosition.isScrollingNotifier.addListener(_onScrollActivityChange));
  }

  void _teardownScrollController() {
    widget.scrollController.removeListener(_onScrollChange);

    if (widget.scrollController.hasClients) {
      scrollPosition.isScrollingNotifier.removeListener(_onScrollActivityChange);
    }
  }

  void _onScrollActivityChange() {
    final isScrolling = scrollPosition.isScrollingNotifier.value;

    if (isScrolling) {
      _isScrolling = true;
    } else {
      onNextFrame((_) {
        // Set our scrolling flag to false on the next frame, so that our tap handlers
        // have an opportunity to see that the scrollable was scrolling when the user
        // tapped down.
        //
        // See the "on tap down" handler for more info about why this flag is important.
        _isScrolling = false;
      });
    }
  }

  void _ensureSelectionExtentIsVisible() {
    readerGesturesLog.fine("Ensuring selection extent is visible");
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
      readerGesturesLog.fine("The selection is collapsed");
      handleInViewportOffset = collapsedHandleOffset - editorInViewportOffset;
    } else {
      readerGesturesLog.fine("The selection is expanded");
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

  void _onDocumentChange(_) {
    _editingController.hideToolbar();

    onNextFrame((_) {
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
    onNextFrame((_) => _updateHandlesAfterSelectionOrLayoutChange());
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
        ..collapsedHandleOffset = null
        ..cancelCollapsedHandleAutoHideCountdown();
    } else if (!newSelection.isCollapsed) {
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
  ScrollPosition get scrollPosition => _ancestorScrollPosition ?? widget.scrollController.position;

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

  /// Converts the given [interactorOffset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _interactorOffsetToDocOffset(Offset interactorOffset) {
    final globalOffset = (context.findRenderObject() as RenderBox).localToGlobal(interactorOffset);
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
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

  bool _wasScrollingOnTapDown = false;
  void _onTapDown(TapDownDetails details) {
    // When the user scrolls and releases, the scrolling continues with momentum.
    // If the user then taps down again, the momentum stops. When this happens, we
    // still receive tap callbacks. But we don't want to take any further action,
    // like moving the caret, when the user taps to stop scroll momentum. We have
    // to carefully watch the scrolling activity to recognize when this happens.
    // We can't check whether we're scrolling in "on tap up" because by then the
    // scrolling has already stopped. So we log whether we're scrolling "on tap down"
    // and then check this flag in "on tap up".
    _wasScrollingOnTapDown = _isScrolling;

    final position = scrollPosition;
    if (position is ScrollPositionWithSingleContext) {
      position.goIdle();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_wasScrollingOnTapDown) {
      // The scrollable was scrolling when the user touched down. We expect that the
      // touch down stopped the scrolling momentum. We don't want to take any further
      // action on this touch event. The user will tap again to change the selection.
      return;
    }

    readerGesturesLog.info("Tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");

    if (widget.contentTapHandler != null && docPosition != null) {
      final result = widget.contentTapHandler!.onTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    if (docPosition == null) {
      widget.selection.value = null;
      _editingController.hideToolbar();
      widget.focusNode.requestFocus();

      return;
    }

    final selection = widget.selection.value;
    final didTapOnExistingSelection =
        selection != null && widget.document.doesSelectionContainPosition(selection, docPosition);
    if (didTapOnExistingSelection) {
      // Toggle the toolbar display when the user taps on the collapsed caret,
      // or on top of an existing selection.
      _editingController.toggleToolbar();
    } else {
      // The user tapped somewhere else in the document. Hide the toolbar.
      _editingController.hideToolbar();
      widget.selection.value = null;
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    readerGesturesLog.info("Double tap down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null && widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onDoubleTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    widget.selection.value = null;

    if (docPosition != null) {
      // The user tapped a non-selectable component, so we can't select a word.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      bool didSelectContent = selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayout,
        selection: widget.selection,
      );

      if (!didSelectContent) {
        didSelectContent = selectBlockAt(docPosition, widget.selection);
      }

      if (widget.selection.value != null) {
        if (!widget.selection.value!.isCollapsed) {
          _editingController.showToolbar();
          _positionToolbar();
        }
      }
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTapDown(TapDownDetails details) {
    readerGesturesLog.info("Triple down down on document");
    final docOffset = _interactorOffsetToDocOffset(details.localPosition);
    readerGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    readerGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null && widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onTripleTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    widget.selection.value = null;

    if (docPosition != null) {
      // The user tapped a non-selectable component, so we can't select a paragraph.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayout,
        selection: widget.selection,
      );
    }

    widget.focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    scrollPosition.jumpTo(scrollPosition.pixels - details.delta.dy);
  }

  void _onPanEnd(DragEndDetails details) {
    final pos = scrollPosition;
    if (pos is ScrollPositionWithSingleContext) {
      pos.goBallistic(-details.velocity.pixelsPerSecond.dy);
      pos.context.setIgnorePointer(false);
    }
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return AndroidDocumentTouchEditingControls(
          editingController: _editingController,
          documentKey: widget.documentKey,
          documentLayout: _docLayout,
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          handleColor: widget.handleColor,
          onHandleDragStart: _onHandleDragStart,
          onHandleDragUpdate: _onHandleDragUpdate,
          onHandleDragEnd: _onHandleDragEnd,
          popoverToolbarBuilder: widget.popoverToolbarBuilder,
          showDebugPaint: false,
        );
      });

      Overlay.of(context).insert(_controlsOverlayEntry!);
    }
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    final selectionAffinity = widget.document.getAffinityForSelection(widget.selection.value!);
    switch (handleType) {
      case HandleType.collapsed:
        // no-op for read-only documents
        break;
      case HandleType.upstream:
        _handleType =
            selectionAffinity == TextAffinity.downstream ? SelectionHandleType.base : SelectionHandleType.extent;
        break;
      case HandleType.downstream:
        _handleType =
            selectionAffinity == TextAffinity.downstream ? SelectionHandleType.extent : SelectionHandleType.base;
        break;
    }

    _globalStartDragOffset = globalOffset;
    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _interactorOffsetToDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _handleType == SelectionHandleType.base ? widget.selection.value!.base : widget.selection.value!.extent,
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

    if (_handleType == SelectionHandleType.base) {
      widget.selection.value = widget.selection.value!.copyWith(
        base: docDragPosition,
      );
    } else if (_handleType == SelectionHandleType.extent) {
      widget.selection.value = widget.selection.value!.copyWith(
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

    if (widget.selection.value!.isCollapsed) {
      // The selection is collapsed. Read-only documents don't display
      // collapsed selections. Clear the selection.
      widget.selection.value = null;
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
    final dragEndInDoc = _interactorOffsetToDocOffset(_dragEndInInteractor!);

    final dragPosition = _docLayout.getDocumentPositionNearestToOffset(dragEndInDoc);
    readerGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
      return;
    }

    late DocumentPosition basePosition;
    late DocumentPosition extentPosition;
    switch (_handleType!) {
      case SelectionHandleType.collapsed:
        // no-op for read-only documents
        return;
      case SelectionHandleType.base:
        basePosition = dragPosition;
        extentPosition = widget.selection.value!.extent;
        break;
      case SelectionHandleType.extent:
        basePosition = widget.selection.value!.base;
        extentPosition = dragPosition;
        break;
    }

    widget.selection.value = DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    );
    readerGesturesLog.fine("Selected region: ${widget.selection.value}");
  }

  void _positionExpandedHandles() {
    final selection = widget.selection.value;
    if (selection == null) {
      readerGesturesLog.shout("Tried to update expanded handle offsets but there is no document selection");
      return;
    }
    if (selection.isCollapsed) {
      readerGesturesLog.shout("Tried to update expanded handle offsets but the selection is collapsed");
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

  void _positionToolbar() {
    if (!_editingController.shouldDisplayToolbar) {
      return;
    }

    final selection = widget.selection.value!;
    if (selection.isCollapsed) {
      readerGesturesLog.warning(
          "Tried to position toolbar for a collapsed selection in a read-only interactor. Collapsed selections shouldn't exist.");
      return;
    }

    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

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
    toolbarTopAnchor = selectionRect.topCenter - const Offset(0, gapBetweenToolbarAndContent);
    toolbarBottomAnchor = selectionRect.bottomCenter + const Offset(0, gapBetweenToolbarAndContent);

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
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
          () => TapSequenceGestureRecognizer(),
          (TapSequenceGestureRecognizer recognizer) {
            recognizer
              ..onTapDown = _onTapDown
              ..onTapUp = _onTapUp
              ..onDoubleTapDown = _onDoubleTapDown
              ..onTripleTapDown = _onTripleTapDown
              ..gestureSettings = gestureSettings;
          },
        ),
        PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(),
          (PanGestureRecognizer recognizer) {
            recognizer
              ..onUpdate = _onPanUpdate
              ..onEnd = _onPanEnd
              ..gestureSettings = gestureSettings;
          },
        ),
      },
      child: widget.child,
    );
  }
}
