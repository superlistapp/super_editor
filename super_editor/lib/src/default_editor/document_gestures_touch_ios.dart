import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/caret.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
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

  late DragHandleAutoScrolling _handleAutoScrolling;
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

    _editingController.removeListener(_onEditingControllerChange);

    widget.editContext.composer.removeListener(_onSelectionChange);

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
  }

  void _onPanStart(DragStartDetails details) {
    if (_editingController.selection == null) {
      return;
    }

    if (_editingController.selection!.isCollapsed && _isOverCollapsedHandle(details.localPosition)) {
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

    // widget.editingController.hideToolbar();

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
    _dragStartScrollOffset = scrollPosition.pixels;

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    scrollPosition.addListener(_updateDragSelection);

    _controlsOverlayEntry!.markNeedsBuild();
  }

  bool _isOverCollapsedHandle(Offset interactorOffset) {
    final collapsedPosition = _editingController.selection?.extent;
    if (collapsedPosition == null) {
      return false;
    }

    final extentRect = _docLayout.getRectForPosition(collapsedPosition)!;
    final caretRect = Rect.fromLTWH(extentRect.left - 1, extentRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverBaseHandle(Offset interactorOffset) {
    final basePosition = _editingController.selection?.base;
    if (basePosition == null) {
      return false;
    }

    final baseRect = _docLayout.getRectForPosition(basePosition)!;
    final caretRect = Rect.fromLTWH(baseRect.left - 1, baseRect.center.dy, 1, 1).inflate(24);

    final docOffset = _docLayout.getDocumentOffsetFromAncestorOffset(interactorOffset, context.findRenderObject()!);
    return caretRect.contains(docOffset);
  }

  bool _isOverExtentHandle(Offset interactorOffset) {
    final extentPosition = _editingController.selection?.extent;
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
      viewportHeight: viewportBox.size.height,
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
      if (scrollPosition is ScrollPositionWithSingleContext) {
        (scrollPosition as ScrollPositionWithSingleContext).goBallistic(-details.velocity.pixelsPerSecond.dy);
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

    _controlsOverlayEntry!.markNeedsBuild();

    // if (widget.editingController.selection?.isCollapsed == false) {
    //   // We hid the toolbar while dragging a handle. If the selection is
    //   // expanded, show it again.
    //   widget.editingController.showToolbar();
    // } else {
    //   // The collapsed handle should disappear after some inactivity.
    //   widget.editingController
    //     ..unHideCollapsedHandle()
    //     ..startCollapsedHandleAutoHideCountdown();
    // }
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
    if (_controlsOverlayEntry != null) {
      return;
    }

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
        magnifierFocalPointOffset: _globalDragOffset,
        disableGestureHandling: _waitingForMoreTaps,
        showDebugPaint: false,
      );
    });

    Overlay.of(context)!.insert(_controlsOverlayEntry!);
  }

  void _removeEditingOverlayControls() {
    if (_controlsOverlayEntry != null) {
      _controlsOverlayEntry!.remove();
      _controlsOverlayEntry = null;
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
    this.magnifierFocalPointOffset,
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

  /// Offset where the magnifier should focus.
  ///
  /// The magnifier is displayed whenever this offset is non-null, otherwise
  /// the magnifier is not shown.
  final Offset? magnifierFocalPointOffset;

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
                  // Build the focal point for the magnifier
                  if (widget.magnifierFocalPointOffset != null) _buildMagnifierFocalPoint(),
                  // Build the magnifier
                  if (widget.editingController.isMagnifierVisible) _buildMagnifier(),
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

    if (widget.editingController.selection!.isCollapsed) {
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
      ),
      // right-bounding handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        positionRect: selectionDirection == TextAffinity.downstream ? extentRect! : baseRect!,
        showHandle: true,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Rect positionRect,
    required bool showHandle,
    required HandleType handleType,
    required Color debugColor,
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

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: widget.magnifierFocalPointOffset!.dx,
      top: widget.magnifierFocalPointOffset!.dy,
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
      child: IOSFollowingMagnifier.roundedRectangle(
        layerLink: widget.editingController.magnifierFocalPoint,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }
}
