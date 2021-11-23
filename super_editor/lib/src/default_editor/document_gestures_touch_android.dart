import 'dart:async';

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
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

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
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;
  final EditContext editContext;
  final ScrollController? scrollController;
  final GlobalKey documentKey;
  final bool showDebugPaint;
  final Widget child;

  @override
  _AndroidDocumentTouchInteractorState createState() =>
      _AndroidDocumentTouchInteractorState();
}

class _AndroidDocumentTouchInteractorState
    extends State<AndroidDocumentTouchInteractor> with WidgetsBindingObserver {
  final _documentWrapperKey = GlobalKey();
  final _documentLayerLink = LayerLink();

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  late EditingController _editingController;

  // OverlayEntry that displays editing controls, e.g.,
  // drag handles, magnifier, and toolbar.
  OverlayEntry? _controlsOverlayEntry;

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(_onFocusChange);
    if (widget.focusNode.hasFocus) {
      _showEditingControlsOverlay();
    }

    _scrollController =
        _scrollController = (widget.scrollController ?? ScrollController());

    _editingController =
        EditingController(document: widget.editContext.editor.document)
          ..addListener(_onEditingControllerChange);

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

    if (_editingController.hasSelection &&
        _editingController.selection!.isCollapsed) {
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
  ScrollPosition get _scrollPosition =>
      _ancestorScrollPosition ?? _scrollController.position;

  /// Returns the `RenderBox` for the scrolling viewport.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `RenderBox` belongs to that ancestor `Scrollable`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and this `State`'s render object
  /// is the viewport `RenderBox`.
  RenderBox get _viewport =>
      (Scrollable.of(context)?.context.findRenderObject() ??
          context.findRenderObject()) as RenderBox;

  /// Converts the given [offset] from the [DocumentInteractor]'s coordinate
  /// space to the [DocumentLayout]'s coordinate space.
  Offset _getDocOffset(Offset offset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(
        offset, context.findRenderObject()!);
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

  void _onTapUp(TapUpDetails details) {
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

  void _showEditingControlsOverlay() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return DocumentTouchEditingControls(
          editingController: _editingController,
          documentKey: widget.documentKey,
          documentLayerLink: _documentLayerLink,
          documentLayout: _docLayout,
          handleColor: Colors.red,
          style: ControlsStyle.android,
          onDoubleTapOnCaret: _selectWordAtCaret,
          onTripleTapOnCaret: _selectParagraphAtCaret,
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
    final newSelection =
        getWordSelection(docPosition: docPosition, docLayout: docLayout);
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
    final newSelection =
        getParagraphSelection(docPosition: docPosition, docLayout: docLayout);
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
        TapSequenceGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
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
              controller: widget.scrollController,
              child: documentWidget,
            ),
          )
        : documentWidget;
  }
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
  _DocumentTouchEditingControlsState createState() =>
      _DocumentTouchEditingControlsState();
}

class _DocumentTouchEditingControlsState
    extends State<DocumentTouchEditingControls>
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

    if (widget.editingController.hasSelection &&
        widget.editingController.selection!.isCollapsed) {
      widget.editingController.startCollapsedHandleAutoHideCountdown();
    }
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

    widget.editingController
      //   ..hideToolbar()
      ..cancelCollapsedHandleAutoHideCountdown();

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
      _localDragOffset = (context.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition);
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
      _localDragOffset = (context.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition);
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
      _localDragOffset = (context.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    editorGesturesLog.fine('_onPanUpdate');

    // Must set global drag offset before _updateSelectionForNewDragHandleLocation()
    _globalDragOffset = details.globalPosition;
    editorGesturesLog.fine(' - global offset: $_globalDragOffset');
    _updateSelectionForNewDragHandleLocation();
    editorGesturesLog
        .fine(' - done updating selection for new drag handle location');

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    // widget.textScrollController.updateAutoScrollingForTouchOffset(
    //   userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
    //       .globalToLocal(details.globalPosition + _touchHandleOffsetFromLineOfText!),
    // );
    // editorGesturesLog.fine(' - updated auto scrolling for touch offset');

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
      // widget.editingController.showMagnifier(_localDragOffset!);
      editorGesturesLog
          .fine(' - done updating all local state for drag update');
    });
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final docDragPosition = widget.documentLayout
        .getDocumentPositionAtOffset(_startDragPositionOffset! + docDragDelta);

    if (docDragPosition == null) {
      return;
    }

    if (_isDraggingCollapsed) {
      widget.editingController.selection = DocumentSelection.collapsed(
        position: docDragPosition,
      );
    } else if (_isDraggingBase) {
      widget.editingController.selection =
          widget.editingController.selection!.copyWith(
        base: docDragPosition,
      );
    } else if (_isDraggingExtent) {
      widget.editingController.selection =
          widget.editingController.selection!.copyWith(
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
        widget.editingController
          //   ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.disableGestureHandling,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
          animation: widget.editingController,
          builder: (context, child) {
            return Stack(
              children: [
                _buildCaret(),
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
          },
        ),
      ),
    );
  }

  Widget _buildCaret() {
    if (!widget.editingController.hasSelection) {
      editorGesturesLog
          .finer('Not building caret because there is no selection');
      // There is no selection. Draw nothing.
      return const SizedBox();
    }

    if (!widget.editingController.selection!.isCollapsed) {
      editorGesturesLog
          .finer('Not building caret because the selection is expanded');
      // There is no selection. Draw nothing.
      return const SizedBox();
    }

    final extentRect = widget.documentLayout
        .getRectForPosition(widget.editingController.selection!.extent)!;

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
      editorGesturesLog
          .finer('Not building overlay handles because they aren\'t desired');
      return [];
    }

    if (!widget.editingController.hasSelection) {
      editorGesturesLog
          .finer('Not building overlay handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    // Note: we don't build the collapsed handle if we're currently dragging
    //       the base or extent because, if we did, then when the user drags
    //       crosses the base and extent, we'd suddenly jump from an expanded
    //       selection to a collapsed selection.
    if (widget.editingController.selection!.isCollapsed &&
        !_isDraggingBase &&
        !_isDraggingExtent) {
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    final extentRect = widget.documentLayout
        .getRectForPosition(widget.editingController.selection!.extent);

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
      if (base.nodePosition ==
          extentNode.selectUpstreamPosition(
              base.nodePosition, extent.nodePosition)) {
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
        positionRect: selectionDirection == TextAffinity.downstream
            ? baseRect!
            : extentRect!,
        showHandle: true,
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: selectionDirection == TextAffinity.downstream
            ? _onBasePanStart
            : _onExtentPanStart,
      ),
      // right-bounding handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        positionRect: selectionDirection == TextAffinity.downstream
            ? extentRect!
            : baseRect!,
        showHandle: true,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: selectionDirection == TextAffinity.downstream
            ? _onExtentPanStart
            : _onBasePanStart,
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
                    opacity: handleType == HandleType.collapsed &&
                            widget.editingController.isCollapsedHandleAutoHidden
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
}
