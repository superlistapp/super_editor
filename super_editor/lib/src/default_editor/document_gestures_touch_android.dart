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
  final _documentLayerLink = LayerLink();

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  late EditingController _editingController;

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

  final _magnifierFocalPoint = LayerLink();

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

    _editingController = EditingController(
      document: widget.editContext.editor.document,
      magnifierFocalPoint: _magnifierFocalPoint,
    )..addListener(_onEditingControllerChange);

    widget.editContext.composer.addListener(_onSelectionChange);

    WidgetsBinding.instance!.addObserver(this);
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

    _editingController.removeListener(_onEditingControllerChange);
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

    if (_editingController.hasSelection && _editingController.selection!.isCollapsed) {
      _editingController
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
    } else if (!_editingController.hasSelection) {
      _editingController.cancelCollapsedHandleAutoHideCountdown();
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
      final didTapOnExistingSelection = _editingController.selection != null &&
          _editingController.selection!.isCollapsed &&
          _editingController.selection!.extent == docPosition;

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
          documentLayerLink: _documentLayerLink,
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
          handleType == HandleType.upstream ? _editingController.selection!.base : _editingController.selection!.extent,
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

  void _onHandleDragEnd() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);

    _editingController.hideMagnifier();

    _dragStartScrollOffset = null;
    _dragStartInDoc = null;
    _dragEndInInteractor = null;

    if (!widget.editContext.composer.selection!.isCollapsed) {
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
    required this.documentLayerLink,
    required this.documentLayout,
    required this.handleColor,
    this.onHandleDragStart,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    required this.popoverToolbarBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  final EditingController editingController;

  final GlobalKey documentKey;

  final LayerLink documentLayerLink;

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

  bool _isDraggingBase = false;
  bool _isDraggingExtent = false;
  bool _isDraggingHandle = false;
  Offset? _localDragOffset;

  late CaretBlinkController _caretBlinkController;
  DocumentSelection? _prevSelection;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = CaretBlinkController(tickerProvider: this);
    _prevSelection = widget.editingController.selection;
    widget.editingController.addListener(_onEditingControllerChange);

    if (widget.editingController.hasSelection && widget.editingController.selection!.isCollapsed) {
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

    widget.editingController
      //   ..hideToolbar()
      ..cancelCollapsedHandleAutoHideCountdown();

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = false;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });

    widget.onHandleDragStart?.call(HandleType.collapsed, details.globalPosition);
  }

  void _onBasePanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onBasePanStart');

    // widget.editingController.hideToolbar();

    setState(() {
      _isDraggingBase = true;
      _isDraggingExtent = false;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });

    widget.onHandleDragStart?.call(HandleType.upstream, details.globalPosition);
  }

  void _onExtentPanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onExtentPanStart');

    // widget.editingController.hideToolbar();

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = true;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });

    widget.onHandleDragStart?.call(HandleType.downstream, details.globalPosition);
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
      _isDraggingBase = false;
      _isDraggingExtent = false;
      _isDraggingHandle = false;
      _localDragOffset = null;

      if (widget.editingController.selection?.isCollapsed == false) {
        // We hid the toolbar while dragging a handle. If the selection is
        // expanded, show it again.
        // widget.editingController.showToolbar();
      } else {
        // The collapsed handle should disappear after some inactivity.
        widget.editingController
          //   ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
      }
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
              if (widget.editingController.isMagnifierVisible) _buildMagnifier(),
              // Build the editing toolbar
              if (widget.editingController.isToolbarVisible) _buildToolbar(context),
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
    if (!widget.editingController.hasSelection) {
      editorGesturesLog.finer('Not building caret because there is no selection');
      // There is no selection. Draw nothing.
      return const SizedBox();
    }

    if (!widget.editingController.selection!.isCollapsed) {
      editorGesturesLog.finer('Not building caret because the selection is expanded');
      // There is no selection. Draw nothing.
      return const SizedBox();
    }

    final extentRect = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent)!;

    late Offset handleOrigin;
    late Offset handleOffset;
    late double caretHeight;
    handleOrigin = extentRect.topLeft;
    handleOffset = const Offset(-1, 0);
    caretHeight = extentRect.height;

    return CompositedTransformFollower(
      link: widget.documentLayerLink,
      offset: handleOrigin,
      child: Transform.translate(
        offset: handleOffset + const Offset(0, 0),
        child: IgnorePointer(
          child: BlinkingCaret(
            controller: _caretBlinkController,
            caretOffset: handleOffset,
            caretHeight: caretHeight,
            width: 2,
            color: widget.showDebugPaint ? Colors.green : widget.handleColor,
            borderRadius: BorderRadius.zero,
            isTextEmpty: false,
            showCaret: true,
          ),
        ),
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
    late Offset fractionalTranslation;
    late Offset handleOrigin;
    switch (handleType) {
      case HandleType.collapsed:
        fractionalTranslation = const Offset(-0.5, 0.0);
        handleOrigin = positionRect.bottomLeft + const Offset(-1, 5);
        break;
      case HandleType.upstream:
        fractionalTranslation = const Offset(-1.0, 0.0);
        handleOrigin = positionRect.bottomLeft + const Offset(0, 2);
        break;
      case HandleType.downstream:
        fractionalTranslation = Offset.zero;
        handleOrigin = positionRect.bottomRight + const Offset(0, 2);
        break;
    }

    return CompositedTransformFollower(
      key: handleKey,
      link: widget.documentLayerLink,
      offset: handleOrigin,
      child: FractionalTranslation(
        translation: fractionalTranslation,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            color: widget.showDebugPaint ? Colors.green : Colors.transparent,
            child: showHandle
                ? AnimatedOpacity(
                    opacity: handleType == HandleType.collapsed && widget.editingController.isCollapsedHandleAutoHidden
                        ? 0.0
                        : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: AndroidSelectionHandle(
                      handleType: handleType,
                      color: widget.handleColor,
                    ),
                  )
                : const SizedBox(),
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
        link: widget.editingController.magnifierFocalPoint,
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
        layerLink: widget.editingController.magnifierFocalPoint,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    // On reassemble we end with a null render object here. I'm not sure how
    // that's possible - build() shouldn't be called without a RenderObject.
    // We return nothing when this happens, and we schedule another frame to
    // try again (otherwise the toolbar will stay hidden).
    if (context.findRenderObject() == null) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {});
        }
      });

      return const SizedBox();
    }

    const toolbarGap = 24.0;
    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    if (widget.editingController.selection!.isCollapsed) {
      final extentRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent)!;
      selectionRect = Rect.fromPoints(
        widget.documentLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.topLeft),
        widget.documentLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.bottomRight),
      );
    } else {
      final baseRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.base)!;
      final extentRectInDoc = widget.documentLayout.getRectForPosition(widget.editingController.selection!.extent)!;
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
        widget.documentLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.topLeft),
        widget.documentLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.bottomRight),
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
        desiredTopAnchorInTextField: toolbarTopAnchor,
        desiredBottomAnchorInTextField: toolbarBottomAnchor,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.isToolbarVisible,
        child: AnimatedOpacity(
          opacity: widget.editingController.isToolbarVisible ? 1.0 : 0.0,
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
