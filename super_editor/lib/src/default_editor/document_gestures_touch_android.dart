import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/caret.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/android/toolbar.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

import 'document_gestures.dart';
import 'document_gestures_touch.dart';

/// Document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
class AndroidDocumentTouchInteractor extends StatefulWidget {
  const AndroidDocumentTouchInteractor({
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
  _AndroidDocumentTouchInteractorState createState() => _AndroidDocumentTouchInteractorState();
}

class _AndroidDocumentTouchInteractorState extends State<AndroidDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _documentWrapperKey = GlobalKey();
  final _documentLayoutLink = LayerLink();

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  late AndroidDocumentGestureEditingController _editingController;

  // OverlayEntry that displays editing controls, e.g.,
  // drag handles, magnifier, and toolbar.
  OverlayEntry? _controlsOverlayEntry;

  late DragHandleAutoScrolling _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  // TODO: HandleType is the wrong type here, we need collapsed/base/extent,
  //       not collapsed/upstream/downstream. Change the type once it's working.
  HandleType? _dragHandleType;

  final _magnifierFocalPointLink = LayerLink();

  @override
  void initState() {
    super.initState();

    _handleAutoScrolling = DragHandleAutoScrolling(
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

    _editingController = AndroidDocumentGestureEditingController(
      documentLayoutLink: _documentLayoutLink,
      magnifierFocalPointLink: _magnifierFocalPointLink,
    );

    widget.editContext.composer.addListener(_onSelectionChange);

    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // On the next frame, check if our active scroll position changed to a
    // different instance. If it did, move our listener to the new one.
    //
    // This is posted to the next frame because the first time this method
    // runs, we haven't attached to our own ScrollController yet, so
    // this.scrollPosition might be null.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      final newScrollPosition = scrollPosition;
      if (newScrollPosition != _activeScrollPosition) {
        _activeScrollPosition?.removeListener(_onScrollChange);
        newScrollPosition.addListener(_onScrollChange);
      }
    });
  }

  @override
  void didUpdateWidget(AndroidDocumentTouchInteractor oldWidget) {
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

    _activeScrollPosition?.removeListener(_onScrollChange);

    // We dispose the EditingController on the next frame because
    // the ListenableBuilder that uses it throws an error if we
    // dispose of it here.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      _editingController.dispose();
    });

    widget.editContext.composer.removeListener(_onSelectionChange);

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
    final newSelection = widget.editContext.composer.selection;

    if (newSelection == null) {
      _editingController
        ..removeCaret()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null
        ..cancelCollapsedHandleAutoHideCountdown();
    } else if (newSelection.isCollapsed) {
      _positionCaret();

      // Calculate the new (x,y) offset for the collapsed handle.
      final extentRect = _docLayout.getRectForPosition(newSelection.extent);
      late Offset handleOffset = extentRect!.bottomLeft;

      _editingController
        ..collapsedHandleOffset = handleOffset
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
    } else {
      // The selection is expanded

      // Calculate the new (x,y) offsets for the upstream and downstream handles.
      final baseHandleOffset = _docLayout.getRectForPosition(newSelection.base)!.bottomLeft;
      final extentHandleOffset = _docLayout.getRectForPosition(newSelection.extent)!.bottomRight;
      final affinity =
          widget.editContext.editor.document.getAffinityBetween(base: newSelection.base, extent: newSelection.extent);
      late Offset upstreamHandleOffset = affinity == TextAffinity.downstream ? baseHandleOffset : extentHandleOffset;
      late Offset downstreamHandleOffset = affinity == TextAffinity.downstream ? extentHandleOffset : baseHandleOffset;

      _editingController
        ..removeCaret()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = upstreamHandleOffset
        ..downstreamHandleOffset = downstreamHandleOffset
        ..cancelCollapsedHandleAutoHideCountdown();
    }
  }

  void _onScrollChange() {
    if (_editingController.shouldDisplayToolbar) {
      _positionToolbar();
      return;
    }
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
  ScrollPosition get scrollPosition => _ancestorScrollPosition ?? _scrollController.position;
  ScrollPosition? _activeScrollPosition;

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
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null) {
      final selection = widget.editContext.composer.selection;
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
      _clearSelection();

      _editingController.hideToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

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

      if (!widget.editContext.composer.selection!.isCollapsed) {
        _positionToolbar();
        _editingController.showToolbar();
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

  void _onDoubleTap() {
    editorGesturesLog.info("Double tap up on document");
  }

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionAtOffset(docOffset);
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
      }
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTap() {
    editorGesturesLog.info("Triple tap up on document");
  }

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return AndroidDocumentTouchEditingControls(
          editingController: _editingController,
          documentKey: widget.documentKey,
          documentLayout: _docLayout,
          handleColor: Colors.red,
          onHandleDragStart: _onHandleDragStart,
          onHandleDragUpdate: _onHandleDragUpdate,
          onHandleDragEnd: _onHandleDragEnd,
          popoverToolbarBuilder: (_) => AndroidTextEditingFloatingToolbar(
            onCutPressed: () {
              // TODO:
            },
            onCopyPressed: () {
              // TODO:
            },
            onPastePressed: () async {
              // TODO:
            },
            onSelectAllPressed: () {
              // TODO:
            },
          ),
          showDebugPaint: false,
        );
      });

      Overlay.of(context)!.insert(_controlsOverlayEntry!);
    }
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    _dragHandleType = handleType;
    _globalStartDragOffset = globalOffset;

    final interactorBox = context.findRenderObject() as RenderBox;
    final handleOffsetInInteractor = interactorBox.globalToLocal(globalOffset);
    _dragStartInDoc = _getDocOffset(handleOffsetInInteractor);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          handleType == HandleType.upstream
              ? widget.editContext.composer.selection!.base
              : widget.editContext.composer.selection!.extent,
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

    if (handleType == HandleType.collapsed) {
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
      viewportHeight: viewportBox.size.height,
    );

    _editingController.showMagnifier();
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
      widget.editContext.composer.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.upstream) {
      widget.editContext.composer.selection = widget.editContext.composer.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_dragHandleType == HandleType.downstream) {
      widget.editContext.composer.selection = widget.editContext.composer.selection!.copyWith(
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

    if (widget.editContext.composer.selection!.isCollapsed) {
      // The selection is collapsed. The collapsed handle should disappear
      // after some inactivity. Start the countdown (or restart an in-progress
      // countdown).
      _editingController
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
    } else {
      _positionToolbar();
      _editingController.showToolbar();
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

  void _positionCaret() {
    final extentRect = _docLayout.getRectForPosition(widget.editContext.composer.selection!.extent)!;

    _editingController.updateCaret(
      top: extentRect.topLeft,
      height: extentRect.height,
    );
  }

  void _positionToolbar() {
    const toolbarGap = 24.0;
    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    final selection = widget.editContext.composer.selection!;
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
            link: _documentLayoutLink,
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
              ..onTripleTap = _onTripleTap;
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
              controller: _scrollController,
              child: documentWidget,
            ),
          )
        : documentWidget;
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
    this.showDebugPaint = false,
  }) : super(key: key);

  final AndroidDocumentGestureEditingController editingController;

  final GlobalKey documentKey;

  final DocumentLayout documentLayout;

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
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: ListenableBuilder(
        listenable: widget.editingController,
        builder: (context) {
          print(
              "Building controls. Is toolbar visible? ${widget.editingController.shouldDisplayToolbar}, anchors: ${widget.editingController.toolbarTopAnchor}, ${widget.editingController.toolbarBottomAnchor}");
          return Stack(
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
          );
        },
      ),
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
    // // On reassemble we end with a null render object here. I'm not sure how
    // // that's possible - build() shouldn't be called without a RenderObject.
    // // We return nothing when this happens, and we schedule another frame to
    // // try again (otherwise the toolbar will stay hidden).
    // if (context.findRenderObject() == null) {
    //   WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
    //     if (mounted) {
    //       setState(() {});
    //     }
    //   });
    //
    //   return const SizedBox();
    // }
    //
    // const toolbarGap = 24.0;
    // late Rect selectionRect;
    // Offset toolbarTopAnchor;
    // Offset toolbarBottomAnchor;
    //
    // if (widget.editingController.selection!.isCollapsed) {
    //   final extentRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent)!;
    //   selectionRect = Rect.fromPoints(
    //     widget.documentLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.topLeft),
    //     widget.documentLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.bottomRight),
    //   );
    // } else {
    //   final baseRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.base)!;
    //   final extentRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent)!;
    //   final selectionRectInDoc = Rect.fromPoints(
    //     Offset(
    //       min(baseRectInDoc.left, extentRectInDoc.left),
    //       min(baseRectInDoc.top, extentRectInDoc.top),
    //     ),
    //     Offset(
    //       max(baseRectInDoc.right, extentRectInDoc.right),
    //       max(baseRectInDoc.bottom, extentRectInDoc.bottom),
    //     ),
    //   );
    //   selectionRect = Rect.fromPoints(
    //     widget.documentLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.topLeft),
    //     widget.documentLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.bottomRight),
    //   );
    // }
    //
    // // TODO: fix the horizontal placement
    // //       The logic to position the toolbar horizontally is wrong.
    // //       The toolbar should appear horizontally centered between the
    // //       left-most and right-most edge of the selection. However, the
    // //       left-most and right-most edge of the selection may not match
    // //       the handle locations. Consider the situation where multiple
    // //       lines/blocks of content are selected, but both handles sit near
    // //       the left side of the screen. This logic will position the
    // //       toolbar near the left side of the content, when the toolbar should
    // //       instead be centered across the full width of the document.
    // toolbarTopAnchor = selectionRect.topCenter - const Offset(0, toolbarGap);
    // toolbarBottomAnchor = selectionRect.bottomCenter + const Offset(0, toolbarGap);
    //
    // // The selection might start above the visible area on the screen.
    // // In that case, keep the toolbar on-screen.
    // toolbarTopAnchor = Offset(
    //   toolbarTopAnchor.dx,
    //   max(
    //     toolbarTopAnchor.dy,
    //     // TODO: choose a gap spacing that makes sense, e.g., what's the safe area?
    //     24,
    //   ),
    // );
    //
    // // The selection might end below the visible area on the screen.
    // // In that case, keep the toolbar on-screen.
    // final screenHeight = (context.findRenderObject() as RenderBox).size.height;
    // toolbarTopAnchor = Offset(
    //   toolbarTopAnchor.dx,
    //   min(
    //     toolbarTopAnchor.dy,
    //     // TODO: choose a gap spacing that makes sense, e.g., what's the safe area?
    //     screenHeight - 24,
    //   ),
    // );

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
    required this.handleType,
    required this.globalHandleDragStartOffset,
    required this.globalHandleDocPositionRect,
  });

  /// The type of handle that the user started to drag.
  final HandleType handleType;

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
    required this.handleType,
    required this.globalHandleDragOffset,
  });

  /// The type of handle that the user started to drag.
  final HandleType handleType;

  /// The current global offset of the user's pointer during
  /// a handle drag event.
  final Offset globalHandleDragOffset;
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
