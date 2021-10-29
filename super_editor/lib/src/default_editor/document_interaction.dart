import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';

import 'text_tools.dart';

/// Handles all gesture input that is used to interact with a document.
///
///  - alters document selection on single, double, and triple taps
///  - alters document selection on drag, also account for single,
///    double, or triple taps to drag
///  - sets the cursor style based on hovering over text and other
///    components
///  - automatically scrolls up or down when the user drags near
///    a boundary
class DocumentGestureInteractor extends StatefulWidget {
  const DocumentGestureInteractor({
    Key? key,
    this.focusNode,
    required this.editContext,
    this.scrollController,
    this.selectionExtentAutoScrollBoundary = AxisOffset.zero,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(100),
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  /// Service locator for document editing dependencies.
  final EditContext editContext;

  /// Controls the vertical scrolling of the given [child].
  ///
  /// If no `scrollController` is provided, then one is created
  /// internally.
  final ScrollController? scrollController;

  /// The closest distance between the user's selection extent (caret)
  /// and the boundary of a document before the document auto-scrolls
  /// to make room for the caret.
  ///
  /// The default value is zero for the leading and trailing boundaries.
  /// This means that the top of the caret is permitted to touch the top
  /// of the scrolling region, but if the caret goes above the viewport
  /// boundary then the document scrolls up. If the caret goes below the
  /// bottom of the viewport boundary then the document scrolls down.
  ///
  /// A positive value for each boundary creates a buffer zone at each
  /// edge of the viewport. For example, a value of `100.0` would cause
  /// the document to auto-scroll whenever the caret sits within 100
  /// pixels of the edge of a document.
  ///
  /// A negative value allows the caret to move outside the viewport
  /// before auto-scrolling.
  ///
  /// See also:
  ///
  ///  * [dragAutoScrollBoundary], which defines how close the user's
  ///    drag gesture can get to the document boundary before auto-scrolling.
  final AxisOffset selectionExtentAutoScrollBoundary;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `100.0` pixels for both the leading and trailing
  /// edges.
  ///
  /// See also:
  ///
  ///  * [selectionExtentAutoScrollBoundary], which defines how close the
  ///    selection extent can get to the document boundary before
  ///    auto-scrolling. For example, when the user taps into some text, or
  ///    when the user presses up/down arrows to move the selection extent.
  final AxisOffset dragAutoScrollBoundary;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final bool showDebugPaint;

  /// The document to display within this [DocumentGestureInteractor].
  final Widget child;

  @override
  _DocumentGestureInteractorState createState() => _DocumentGestureInteractorState();
}

class _DocumentGestureInteractorState extends State<DocumentGestureInteractor> with SingleTickerProviderStateMixin {
  final _maxDragSpeed = 20;

  final _documentWrapperKey = GlobalKey();

  late FocusNode _focusNode;

  late ScrollController _scrollController;
  ScrollPosition? _ancestorScrollPosition;

  // Tracks user drag gestures for selection purposes.
  SelectionType _selectionType = SelectionType.position;
  // Offset? _dragStartInViewport;
  Offset? _dragStartInInteractor;
  Offset? _dragStartInDoc;
  double? _dragStartScrollOffset;
  // Offset? _dragEndInViewport;
  Offset? _dragEndInInteractor;
  Offset? _dragEndInDoc;
  // Rect? _dragRectInViewport;

  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;
  late Ticker _ticker;

  // Determines the current mouse cursor style displayed on screen.
  final _cursorStyle = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ticker = createTicker(_onTick);
    _scrollController =
        _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);

    widget.editContext.composer.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(DocumentGestureInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editContext.composer != oldWidget.editContext.composer) {
      oldWidget.editContext.composer.removeListener(_onSelectionChange);
      widget.editContext.composer.addListener(_onSelectionChange);
    }
    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController.removeListener(_updateDragSelection);
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    widget.editContext.composer.removeListener(_onSelectionChange);
    _ticker.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  DocumentLayout get _layout => widget.editContext.documentLayout;

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

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// if the same as the viewport offset.
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

  void _onSelectionChange() {
    if (mounted) {
      // Use a post-frame callback to "ensure selection extent is visible"
      // so that any pending visual document changes can happen before
      // attempting to calculate the visual position of the selection extent.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        editorGesturesLog.finer("Ensuring selection extent is visible because the doc selection changed");
        _ensureSelectionExtentIsVisible();
      });
    }
  }

  void _ensureSelectionExtentIsVisible() {
    editorGesturesLog.finer("Ensuring extent is visible: ${widget.editContext.composer.selection}");
    final selection = widget.editContext.composer.selection;
    if (selection == null) {
      return;
    }

    // The reason that a Rect is used instead of an Offset is
    // because things like Images and Horizontal Rules don't have
    // a clear selection offset. They are either entirely selected,
    // or not selected at all.
    final selectionExtentRectInDoc = _layout.getRectForPosition(
      selection.extent,
    );
    if (selectionExtentRectInDoc == null) {
      editorGesturesLog.warning(
          "Tried to ensure that position ${selection.extent} is visible on screen but no bounding box was returned for that position.");
      return;
    }

    // Viewport might be our box, or an ancestor box if we're inside someone
    // else's Scrollable.
    final viewportBox = _viewport;

    final docBox = _documentWrapperKey.currentContext!.findRenderObject() as RenderBox;

    final docOffsetInViewport = viewportBox.globalToLocal(
      docBox.localToGlobal(Offset.zero),
    );
    final selectionExtentRectInViewport = selectionExtentRectInDoc.translate(0, docOffsetInViewport.dy);

    // TODO: These two lines came from before the viewport coord change. Remove them when done.
    // final selectionTopInViewport = selectionExtentRectInDoc.top - _scrollPosition.pixels;
    // final beyondTopExtent = min(selectionTopInViewport, 0).abs();
    final beyondTopExtent = min(selectionExtentRectInViewport.top, 0).abs();

    // TODO: These two lines came from before the viewport coord change. Remove them when done.
    // final selectionBottomInViewport = selectionExtentRectInDoc.bottom - _scrollPosition.pixels;
    // final beyondBottomExtent = max(selectionBottomInViewport - viewportBox.size.height, 0);
    final beyondBottomExtent = max(selectionExtentRectInViewport.bottom - viewportBox.size.height, 0);

    editorGesturesLog.finest('Ensuring extent is visible.');
    editorGesturesLog.finest(' - viewport size: ${viewportBox.size}');
    editorGesturesLog.finest(' - scroll controller offset: ${_scrollPosition.pixels}');
    editorGesturesLog.finest(' - selection extent rect: $selectionExtentRectInDoc');
    editorGesturesLog.finest(' - beyond top: $beyondTopExtent');
    editorGesturesLog.finest(' - beyond bottom: $beyondBottomExtent');

    if (beyondTopExtent > 0) {
      final newScrollPosition = (_scrollPosition.pixels - beyondTopExtent).clamp(0.0, _scrollPosition.maxScrollExtent);

      _scrollPosition.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondBottomExtent > 0) {
      final newScrollPosition =
          (beyondBottomExtent + _scrollPosition.pixels).clamp(0.0, _scrollPosition.maxScrollExtent);

      _scrollPosition.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTapDown(TapDownDetails details) {
    editorGesturesLog.info("Tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _layout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    _clearSelection();
    _selectionType = SelectionType.position;

    if (docPosition != null) {
      // Place the document selection at the location where the
      // user tapped.
      _selectPosition(docPosition);
    }

    _focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _layout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    _selectionType = SelectionType.word;
    _clearSelection();

    if (docPosition != null) {
      final didSelectWord = _selectWordAt(
        docPosition: docPosition,
        docLayout: _layout,
      );
      if (!didSelectWord) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    }

    _focusNode.requestFocus();
  }

  void _onDoubleTap() {
    editorGesturesLog.info("Double tap up on document");
    _selectionType = SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple down down on document");
    final docOffset = _getDocOffset(details.localPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _layout.getDocumentPositionAtOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    _selectionType = SelectionType.paragraph;
    _clearSelection();

    if (docPosition != null) {
      final didSelectParagraph = _selectParagraphAt(
        docPosition: docPosition,
        docLayout: _layout,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }
    }

    _focusNode.requestFocus();
  }

  void _onTripleTap() {
    editorGesturesLog.info("Triple tap up on document");
    _selectionType = SelectionType.position;
  }

  void _onPanStart(DragStartDetails details) {
    editorGesturesLog.info("Pan start on document");

    _dragStartInInteractor = details.localPosition;
    _dragStartInDoc = _getDocOffset(details.localPosition);

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = _scrollPosition.pixels;

    _clearSelection();

    _focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      editorGesturesLog.info("Pan update on document");

      _dragEndInInteractor = details.localPosition;
      _dragEndInDoc = _getDocOffset(details.localPosition);

      _updateCursorStyle(details.localPosition);
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      editorGesturesLog.info("Pan end on document");
      _dragStartInInteractor = null;
      _dragStartInDoc = null;
      _dragEndInInteractor = null;
      _dragEndInDoc = null;
    });

    _stopScrollingUp();
    _stopScrollingDown();
  }

  void _onPanCancel() {
    setState(() {
      editorGesturesLog.info("Pan cancel on document");
      _dragStartInInteractor = null;
      _dragStartInDoc = null;
      _dragEndInInteractor = null;
      _dragEndInDoc = null;
    });

    _stopScrollingUp();
    _stopScrollingDown();
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
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

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    // We have to re-calculate the drag end in the doc (instead of
    // caching the value during the pan update) because the position
    // in the document is impacted by auto-scrolling behavior.
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final dragEndInDoc = _getDocOffset(_dragEndInInteractor! - Offset(0, scrollDeltaWhileDragging));

    _selectRegion(
      documentLayout: _layout,
      baseOffset: _dragStartInDoc!,
      extentOffset: dragEndInDoc,
      selectionType: _selectionType,
    );
  }

  void _selectRegion({
    required DocumentLayout documentLayout,
    required Offset baseOffset,
    required Offset extentOffset,
    required SelectionType selectionType,
  }) {
    editorGesturesLog.info("Selecting region with selection mode: $selectionType");
    DocumentSelection? selection = documentLayout.getDocumentSelectionInRegion(baseOffset, extentOffset);
    DocumentPosition? basePosition = selection?.base;
    DocumentPosition? extentPosition = selection?.extent;
    editorGesturesLog.fine(" - base: $basePosition, extent: $extentPosition");

    if (basePosition == null || extentPosition == null) {
      widget.editContext.composer.selection = null;
      return;
    }

    if (selectionType == SelectionType.paragraph) {
      final baseParagraphSelection = getParagraphSelection(
        docPosition: basePosition,
        docLayout: documentLayout,
      );
      if (baseParagraphSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      basePosition = baseOffset.dy < extentOffset.dy ? baseParagraphSelection.base : baseParagraphSelection.extent;

      final extentParagraphSelection = getParagraphSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
      );
      if (extentParagraphSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      extentPosition =
          baseOffset.dy < extentOffset.dy ? extentParagraphSelection.extent : extentParagraphSelection.base;
    } else if (selectionType == SelectionType.word) {
      final baseWordSelection = getWordSelection(
        docPosition: basePosition,
        docLayout: documentLayout,
      );
      if (baseWordSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      basePosition = baseWordSelection.base;

      final extentWordSelection = getWordSelection(
        docPosition: extentPosition,
        docLayout: documentLayout,
      );
      if (extentWordSelection == null) {
        widget.editContext.composer.selection = null;
        return;
      }
      extentPosition = extentWordSelection.extent;
    }

    widget.editContext.composer.selection = (DocumentSelection(
      base: basePosition,
      extent: extentPosition,
    ));
    editorGesturesLog.fine("Selected region: ${widget.editContext.composer.selection}");
  }

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.editContext.composer.clearSelection();
  }

  void _updateCursorStyle(Offset cursorOffset) {
    final docOffset = _getDocOffset(cursorOffset);
    final desiredCursor = _layout.getDesiredCursorAtOffset(docOffset);

    if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
      _cursorStyle.value = desiredCursor;
    } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  // Converts the given [offset] from the [DocumentInteractor]'s coordinate
  // space to the [DocumentLayout]'s coordinate space.
  Offset _getDocOffset(Offset offset) {
    return _layout.getDocumentOffsetFromAncestorOffset(offset, context.findRenderObject()!);
  }

  // ------ scrolling -------
  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final newScrollOffset =
          (_scrollPosition.pixels + event.scrollDelta.dy).clamp(0.0, _scrollPosition.maxScrollExtent);
      _scrollPosition.jumpTo(newScrollOffset);

      _updateDragSelection();
    }
  }

  // Preconditions:
  // - _dragEndInViewport must be non-null
  void _scrollIfNearBoundary() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll near boundary but couldn't because _dragEndInViewport is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    final viewport = _viewport;
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - _scrollPosition.pixels;
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) - Offset(0, scrollDeltaWhileDragging);

    print('Drag end in interactor: ${_dragEndInInteractor!.dy}');
    print('Drag end in viewport: ${dragEndInViewport.dy}, viewport size: ${viewport.size}');
    print('Distance to top of viewport: ${dragEndInViewport.dy}');
    print('Distance to bottom of viewport: ${viewport.size.height - dragEndInViewport.dy}');
    print('Auto-scroll distance: ${widget.dragAutoScrollBoundary.trailing}');
    print('Auto-scroll diff: ${viewport.size.height - dragEndInViewport.dy < widget.dragAutoScrollBoundary.trailing}');
    if (dragEndInViewport.dy < widget.dragAutoScrollBoundary.leading) {
      print('Calling _startScrollingUp()');
      _startScrollingUp();
    } else {
      _stopScrollingUp();
    }

    if (viewport.size.height - dragEndInViewport.dy < widget.dragAutoScrollBoundary.trailing) {
      print('Calling _startScrollingDown()');
      _startScrollingDown();
    } else {
      _stopScrollingDown();
    }
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
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) - Offset(0, scrollDeltaWhileDragging);
    editorGesturesLog.finest("Drag end in viewport: $dragEndInViewport");
    final leadingScrollBoundary = widget.dragAutoScrollBoundary.leading;
    final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
    final speedPercent = 1.0 - (gutterAmount / leadingScrollBoundary);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    _scrollPosition.jumpTo(_scrollPosition.pixels - scrollAmount!);

    // By changing the scroll offset, we may have changed the content
    // selected by the user's current finger/mouse position. Update the
    // document selection calculation.
    _updateDragSelection();
  }

  void _startScrollingDown() {
    if (_scrollDownOnTick) {
      print('Already scrolling down. Returning.');
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
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!) - Offset(0, scrollDeltaWhileDragging);
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
    print('onTock, scroll down: $_scrollDownOnTick');
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancestorScrollable = Scrollable.of(context);
    _ancestorScrollPosition = ancestorScrollable?.position;

    return _buildCursorStyle(
      child: _buildGestureInput(
        child: SizedBox.expand(
          child: Stack(
            children: [
              _buildDocumentContainer(
                document: widget.child,
                addScrollView: ancestorScrollable == null,
              ),
              Positioned.fill(
                child: widget.showDebugPaint ? _buildDragSelection() : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCursorStyle({
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _cursorStyle,
      builder: (context, child) {
        return Listener(
          onPointerHover: _onMouseMove,
          child: MouseRegion(
            cursor: _cursorStyle.value,
            child: child,
          ),
        );
      },
      child: child,
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
              ..onTapDown = _onTapDown
              ..onDoubleTapDown = _onDoubleTapDown
              ..onDoubleTap = _onDoubleTap
              ..onTripleTapDown = _onTripleTapDown
              ..onTripleTap = _onTripleTap;
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
        ? Listener(
            onPointerSignal: _onPointerSignal,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: documentWidget,
            ),
          )
        : documentWidget;
  }

  Widget _buildDragSelection() {
    final dragStartInViewport = _interactorOffsetInViewport(_dragStartInInteractor!);
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!);
    final dragRectInViewport = Rect.fromPoints(dragStartInViewport, dragEndInViewport);

    return CustomPaint(
      painter: DragRectanglePainter(
        selectionRect: dragRectInViewport,
      ),
      size: Size.infinite,
    );
  }
}

/// Receives all keyboard input, when focused, and invokes relevant document
/// editing actions on the given [editContext.editor].
///
/// [keyboardActions] determines the mapping from keyboard key presses
/// to document editing behaviors. [keyboardActions] operates as a
/// Chain of Responsibility.
class DocumentKeyboardInteractor extends StatelessWidget {
  const DocumentKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.editContext,
    required this.keyboardActions,
    required this.child,
  }) : super(key: key);

  /// The source of all key events.
  final FocusNode focusNode;

  /// Service locator for document editing dependencies.
  final EditContext editContext;

  /// All the actions that the user can execute with keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> keyboardActions;

  /// The [child] widget, which is expected to include the document UI
  /// somewhere in the sub-tree.
  final Widget child;

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      editorKeyLog.finer("Received key event, but ignoring because it's not a down event: $keyEvent");
      return KeyEventResult.handled;
    }

    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < keyboardActions.length) {
      instruction = keyboardActions[index](
        editContext: editContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    return instruction == ExecutionInstruction.haltExecution ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return _buildSuppressUnhandledKeySound(
      // TODO: try to replace RawKeyboardListener with a regular FocusNode and onKey
      child: RawKeyboardListener(
        focusNode: focusNode,
        onKey: _onKeyPressed,
        autofocus: true,
        child: child,
      ),
    );
  }

  /// Wraps the [child] with a [Focus] node that reports to handle
  /// any and all keys so that no error sound plays on desktop.
  Widget _buildSuppressUnhandledKeySound({
    required Widget child,
  }) {
    return Focus(
      onKey: (node, event) => KeyEventResult.handled,
      child: child,
    );
  }
}

enum SelectionType {
  position,
  word,
  paragraph,
}

/// A distance from the leading and trailing boundaries of an
/// axis-aligned area.
class AxisOffset {
  /// No offset from the leading/trailing edges.
  static const zero = AxisOffset.symmetric(0);

  /// Equal leading/trailing edge spacing equal to `amount`.
  const AxisOffset.symmetric(num amount)
      : leading = amount,
        trailing = amount;

  const AxisOffset({
    required this.leading,
    required this.trailing,
  });

  /// Distance from the leading edge of an axis-oriented area.
  final num leading;

  /// Distance from the trailing edge of an axis-oriented area.
  final num trailing;

  @override
  String toString() => '[AxisOffset] - leading: $leading, trailing: $trailing';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AxisOffset && runtimeType == other.runtimeType && leading == other.leading && trailing == other.trailing;

  @override
  int get hashCode => leading.hashCode ^ trailing.hashCode;
}

/// Executes this action, if the action wants to run, and returns
/// a desired `ExecutionInstruction` to either continue or halt
/// execution of actions.
///
/// It is possible that an action makes changes and then returns
/// `ExecutionInstruction.continueExecution` to continue execution.
///
/// It is possible that an action does nothing and then returns
/// `ExecutionInstruction.haltExecution` to prevent further execution.
typedef DocumentKeyboardAction = ExecutionInstruction Function({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
});

enum ExecutionInstruction {
  continueExecution,
  haltExecution,
}

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final Rect? selectionRect;
  final Paint _selectionPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      canvas.drawRect(selectionRect!, _selectionPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
