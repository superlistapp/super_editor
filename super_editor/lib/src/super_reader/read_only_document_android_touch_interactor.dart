import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/src/infrastructure/document_gestures.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/build_context.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/overlay_with_groups.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/android/long_press_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/signal_notifier.dart';
import 'package:super_editor/src/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_textfield/metrics.dart';
import 'package:super_text_layout/super_text_layout.dart';

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
    this.tapRegionGroupId,
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

  /// {@macro super_reader_tap_region_group_id}
  final String? tapRegionGroupId;

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

  // Overlay controller that displays editing controls, e.g., drag handles,
  // magnifier, and toolbar.
  final _overlayPortalController =
      GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.editingControls);
  final _overlayPortalRebuildSignal = SignalNotifier();
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

  Timer? _tapDownLongPressTimer;
  Offset? _globalTapDownOffset;
  bool get _isLongPressInProgress => _longPressStrategy != null;
  AndroidDocumentLongPressSelectionStrategy? _longPressStrategy;
  final _longPressMagnifierGlobalOffset = ValueNotifier<Offset?>(null);

  /// Holds the drag gesture that scrolls the document.
  Drag? _scrollingDrag;

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

    _ancestorScrollPosition = context.findAncestorScrollableWithVerticalScroll?.position;

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

    _activeScrollPosition?.removeListener(_onScrollChange);

    // We dispose the EditingController on the next frame because
    // the ListenableBuilder that uses it throws an error if we
    // dispose of it here.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _editingController.dispose();
    });

    widget.document.removeListener(_onDocumentChange);
    widget.selection.removeListener(_onSelectionChange);

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

      // The long-press timer is cancelled if a pan gesture is detected.
      // However, if we have an ancestor scrollable, we won't receive a pan gesture in this widget.
      // Cancel the timer as soon as the user started scrolling.
      _tapDownLongPressTimer?.cancel();
      _tapDownLongPressTimer = null;
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
      (context.findAncestorScrollableWithVerticalScroll?.context.findRenderObject() ?? context.findRenderObject())
          as RenderBox;

  Offset _getDocumentOffsetFromGlobalOffset(Offset globalOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

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

    _globalTapDownOffset = details.globalPosition;
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = Timer(kLongPressTimeout, _onLongPressDown);
  }

  void _onTapCancel() {
    _tapDownLongPressTimer?.cancel();
    _tapDownLongPressTimer = null;
  }

  // Runs when a tap down has lasted long enough to signify a long-press.
  void _onLongPressDown() {
    if (_isScrolling) {
      // When the reader has an ancestor scrollable, dragging won't trigger a pan gesture
      // is this widget. Because of that, the timer still fires after the timeout.
      // Do nothing to let the user scroll.
      return;
    }

    _longPressStrategy = AndroidDocumentLongPressSelectionStrategy(
      document: widget.document,
      documentLayout: _docLayout,
      select: _updateLongPressSelection,
    );

    final didLongPressSelectionStart = _longPressStrategy!.onLongPressStart(
      tapDownDocumentOffset: _getDocumentOffsetFromGlobalOffset(_globalTapDownOffset!),
    );
    if (!didLongPressSelectionStart) {
      _longPressStrategy = null;
      return;
    }

    // A long-press selection is in progress. Initially show the toolbar, but nothing else.
    _editingController
      ..disallowHandles()
      ..hideMagnifier()
      ..showToolbar();
    _positionToolbar();
    _overlayPortalRebuildSignal.notifyListeners();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    // Stop waiting for a long-press to start.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    // Cancel any on-going long-press.
    if (_isLongPressInProgress) {
      _longPressStrategy = null;
      _longPressMagnifierGlobalOffset.value = null;

      // We hide the selection handles when long-press dragging, despite having
      // an expanded selection. Allow the handles to come back.
      _editingController.allowHandles();
      _overlayPortalRebuildSignal.notifyListeners();

      return;
    }

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

  void _onPanStart(DragStartDetails details) {
    // Stop waiting for a long-press to start, if a long press isn't already in-progress.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    if (!_isLongPressInProgress) {
      // We only care about starting a pan if we're long-press dragging.
      _scrollingDrag = scrollPosition.drag(details, () {
        // Allows receiving touches while scrolling due to scroll momentum.
        // This is needed to allow the user to stop scrolling by tapping down.
        scrollPosition.context.setIgnorePointer(false);
      });
      return;
    }

    _globalStartDragOffset = details.globalPosition;
    _dragStartInDoc = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = scrollPosition.pixels;
    _startDragPositionOffset = _dragStartInDoc!;

    _longPressStrategy!.onLongPressDragStart(details);

    // Tell the overlay where to put the magnifier.
    _longPressMagnifierGlobalOffset.value = details.globalPosition;

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    scrollPosition.addListener(_updateDragSelection);

    _editingController
      ..hideToolbar()
      ..showMagnifier();
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLongPressInProgress) {
      _globalDragOffset = details.globalPosition;

      final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final scrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
      final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
      final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
        _startDragPositionOffset! + fingerDragDelta - Offset(0, scrollDelta),
      );
      _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
      return;
    }

    if (_scrollingDrag != null) {
      // The user is trying to scroll the document. Change the scroll offset.
      _scrollingDrag!.update(details);
    }
  }

  void _updateLongPressSelection(DocumentSelection newSelection) {
    if (newSelection != widget.selection.value) {
      widget.selection.value = newSelection;
      HapticFeedback.lightImpact();
    }

    // Note: this needs to happen even when the selection doesn't change, in case
    // some controls, like a magnifier, need to follower the user's finger.
    _updateOverlayControlsOnLongPressDrag();
  }

  void _updateOverlayControlsOnLongPressDrag() {
    final extentDocumentOffset = _docLayout.getRectForPosition(widget.selection.value!.extent)!.center;
    final extentGlobalOffset = _docLayout.getAncestorOffsetFromDocumentOffset(extentDocumentOffset);
    final extentInteractorOffset = (context.findRenderObject() as RenderBox).globalToLocal(extentGlobalOffset);
    final extentViewportOffset = _interactorOffsetInViewport(extentInteractorOffset);
    _handleAutoScrolling.updateAutoScrollHandleMonitoring(dragEndInViewport: extentViewportOffset);

    _longPressMagnifierGlobalOffset.value = extentGlobalOffset;
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }

    if (_scrollingDrag != null) {
      // The user was performing a drag gesture to scroll the document.
      // End the scroll activity and let the document scrolling with momentum.
      _scrollingDrag!.end(details);
    }
  }

  void _onPanCancel() {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }

    if (_scrollingDrag != null) {
      // The user was performing a drag gesture to scroll the document.
      // Cancel the drag gesture.
      _scrollingDrag!.cancel();
    }
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();

    // Cancel any on-going long-press.
    _longPressStrategy = null;
    _longPressMagnifierGlobalOffset.value = null;

    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);

    _editingController
      ..allowHandles()
      ..hideMagnifier();
    if (!widget.selection.value!.isCollapsed) {
      _editingController.showToolbar();
      _positionToolbar();
    }
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _showEditingControlsOverlay() {
    _overlayPortalController.show();
  }

  void _removeEditingOverlayControls() {
    _overlayPortalController.hide();
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    final selectionAffinity = widget.document.getAffinityForSelection(widget.selection.value!);
    switch (handleType) {
      case HandleType.collapsed:
        // no-op for read-only documents
        break;
      case HandleType.upstream:
        _handleType = selectionAffinity == TextAffinity.downstream
            ? SelectionHandleType.upstream
            : SelectionHandleType.downstream;
        break;
      case HandleType.downstream:
        _handleType = selectionAffinity == TextAffinity.downstream
            ? SelectionHandleType.downstream
            : SelectionHandleType.upstream;
        break;
    }

    _globalStartDragOffset = globalOffset;
    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _interactorOffsetToDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _handleType == SelectionHandleType.upstream ? widget.selection.value!.base : widget.selection.value!.extent,
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

    if (_handleType == SelectionHandleType.upstream) {
      widget.selection.value = widget.selection.value!.copyWith(
        base: docDragPosition,
      );
    } else if (_handleType == SelectionHandleType.downstream) {
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
      case SelectionHandleType.upstream:
        basePosition = dragPosition;
        extentPosition = widget.selection.value!.extent;
        break;
      case SelectionHandleType.downstream:
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

    // Calculate the new rectangles for the upstream and downstream handles.
    final baseHandleRect = _docLayout.getRectForPosition(selection.base)!;
    final extentHandleRect = _docLayout.getRectForPosition(selection.extent)!;
    final affinity = widget.document.getAffinityBetween(base: selection.base, extent: selection.extent);
    late Rect upstreamHandleRect = affinity == TextAffinity.downstream ? baseHandleRect : extentHandleRect;
    late Rect downstreamHandleRect = affinity == TextAffinity.downstream ? extentHandleRect : baseHandleRect;

    _editingController
      ..removeCaret()
      ..collapsedHandleOffset = null
      ..upstreamHandleOffset = upstreamHandleRect.bottomLeft
      ..downstreamHandleOffset = downstreamHandleRect.bottomRight
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

    // TODO: The following behavior looks like its calculating a bounding box. Should we use
    //       getRectForSelection instead?
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

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return OverlayPortal(
      controller: _overlayPortalController,
      overlayChildBuilder: _buildControlsOverlay,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
            () => TapSequenceGestureRecognizer(),
            (TapSequenceGestureRecognizer recognizer) {
              recognizer
                ..onTapDown = _onTapDown
                ..onTapCancel = _onTapCancel
                ..onTapUp = _onTapUp
                ..onDoubleTapDown = _onDoubleTapDown
                ..onTripleTapDown = _onTripleTapDown
                ..gestureSettings = gestureSettings;
            },
          ),
          VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(),
            (VerticalDragGestureRecognizer recognizer) {
              recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = _onPanStart
                ..onUpdate = _onPanUpdate
                ..onEnd = _onPanEnd
                ..onCancel = _onPanCancel
                ..gestureSettings = gestureSettings;
            },
          ),
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      child: ListenableBuilder(
        listenable: _overlayPortalRebuildSignal,
        builder: (context, child) {
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
            longPressMagnifierGlobalOffset: _longPressMagnifierGlobalOffset,
            showDebugPaint: false,
          );
        },
      ),
    );
  }
}

// TODO: This was moved here from the SuperEditor side. We've removed the need for this from SuperEditor, remove it from SuperReader, too.
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
    required this.longPressMagnifierGlobalOffset,
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

  /// The color of the Android-style drag handles.
  final Color handleColor;

  final void Function(HandleType handleType, Offset globalOffset)? onHandleDragStart;

  final void Function(Offset globalOffset)? onHandleDragUpdate;

  final void Function()? onHandleDragEnd;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final WidgetBuilder popoverToolbarBuilder;

  final ValueNotifier<Offset?> longPressMagnifierGlobalOffset;

  final bool showDebugPaint;

  @override
  State createState() => _AndroidDocumentTouchEditingControlsState();
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

  late BlinkController _caretBlinkController;
  Offset? _prevCaretOffset;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = BlinkController(tickerProvider: this);
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
        _caretBlinkController.stopBlinking();
      } else {
        _caretBlinkController.jumpToOpaque();
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
      builder: (context, _) {
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
                  // Build the drag handles (if desired).
                  // We don't show handles on web because the browser already displays the native handles.
                  if (!CurrentPlatform.isWeb) //
                    ..._buildHandles(),
                  // Build the focal point for the magnifier
                  if (_isDraggingHandle || widget.longPressMagnifierGlobalOffset.value != null)
                    _buildMagnifierFocalPoint(),
                  // Build the magnifier (this needs to be done before building
                  // the handles so that the magnifier doesn't show the handles.
                  // We don't show magnifier on web because the browser already displays the native magnifier.
                  if (!CurrentPlatform.isWeb && widget.editingController.shouldDisplayMagnifier) _buildMagnifier(),
                  // Build the editing toolbar.
                  // We don't show toolbar on web because the browser already displays the native toolbar.
                  if (!CurrentPlatform.isWeb &&
                      widget.editingController.shouldDisplayToolbar &&
                      widget.editingController.isToolbarPositioned)
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

    return Follower.withOffset(
      link: widget.editingController.selectionLinks.caretLink,
      leaderAnchor: Alignment.topCenter,
      followerAnchor: Alignment.topCenter,
      showWhenUnlinked: false,
      child: IgnorePointer(
        child: BlinkingCaret(
          controller: _caretBlinkController,
          caretOffset: const Offset(0, 0),
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
      handleLink: widget.editingController.selectionLinks.caretLink,
      leaderAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      handleOffset: const Offset(-0.5, 5), // Chosen experimentally
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
        handleLink: widget.editingController.selectionLinks.upstreamLink,
        leaderAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topRight,
        handleOffset: const Offset(0, 2), // Chosen experimentally
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: _onUpstreamHandlePanStart,
      ),
      // downstream-bounding (right side of a RTL line of text) handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        handleLink: widget.editingController.selectionLinks.downstreamLink,
        leaderAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topLeft,
        handleOffset: const Offset(-1, 2), // Chosen experimentally
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: _onDownstreamHandlePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required LeaderLink handleLink,
    required Alignment leaderAnchor,
    required Alignment followerAnchor,
    Offset? handleOffset,
    Offset handleFractionalTranslation = Offset.zero,
    required HandleType handleType,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    return Follower.withOffset(
      key: handleKey,
      link: handleLink,
      leaderAnchor: leaderAnchor,
      followerAnchor: followerAnchor,
      offset: handleOffset ?? Offset.zero,
      showWhenUnlinked: false,
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
    late Offset magnifierOffset;
    if (widget.longPressMagnifierGlobalOffset.value != null) {
      // The user is long-pressing, the magnifier should go at the selection
      // extent.
      magnifierOffset = widget.longPressMagnifierGlobalOffset.value!;
    } else {
      // The user is dragging a handle. The magnifier should go wherever the user
      // places his finger.
      //
      // Also, pull the magnifier up a little bit because the Android drag handles
      // sit below the content they refer to.
      magnifierOffset = _localDragOffset! - const Offset(0, 20);
    }

    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: magnifierOffset.dx,
      // TODO: select focal position based on type of content
      top: magnifierOffset.dy,
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
        screenPadding: widget.editingController.screenPadding,
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
