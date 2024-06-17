import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/text_selection.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_heuristics.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_editor/src/test/test_globals.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '_editing_controls.dart';

final _log = iosTextFieldLog;

/// iOS text field touch interaction surface.
///
/// This widget is intended to be displayed in the foreground of a [SuperText] widget.
///
/// This widget recognizes and acts upon various user interactions:
///
///  * Tap: Place a collapsed text selection at the text location that's
///    nearest to the tap offset.
///  * Tap (in a location that doesn't move the caret): Toggle the toolbar.
///  * Double-Tap: Select the word surrounding the tapped location.
///  * Triple-Tap: Select the paragraph surrounding the tapped location
///  * Drag: Move a collapsed selection wherever the user drags, while
///    displaying a magnifying glass.
///
/// Drag handles, a magnifying glass, and an editing toolbar are displayed
/// based on how the user interacts with this widget. Those UI elements
/// are controller via the given [editingOverlayController].
///
/// The text is auto-scrolled when the user drags a collapsed caret in
/// this widget. The auto-scrolling is handled by the given [textScrollController].
///
/// Selection changes are made via the given [textController].
class IOSTextFieldTouchInteractor extends StatefulWidget {
  const IOSTextFieldTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.textFieldLayerLink,
    required this.textController,
    required this.editingOverlayController,
    required this.textScrollController,
    required this.selectableTextKey,
    required this.getGlobalCaretRect,
    required this.isMultiline,
    required this.handleColor,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for the text field that contains this [IOSTextFieldInteractor].
  ///
  /// [IOSTextFieldInteractor] only shows editing controls, and listens for drag
  /// events when [focusNode] has focus.
  ///
  /// [IOSTextFieldInteractor] requests focus when the user taps on it.
  final FocusNode focusNode;

  /// [LayerLink] that follows the text field that contains this
  /// [IOSExtFieldInteractor].
  ///
  /// [textFieldLayerLink] is used to anchor the editing controls.
  final LayerLink textFieldLayerLink;

  /// [TextController] used to read the current selection to display
  /// editing controls, and used to update the selection based on
  /// user interactions.
  final ImeAttributedTextEditingController textController;

  final IOSEditingOverlayController editingOverlayController;

  final TextScrollController textScrollController;

  /// [GlobalKey] that references the widget that contains the field's
  /// text.
  final GlobalKey<ProseTextState> selectableTextKey;

  /// A function that returns the current caret global rect, or `null` if no
  /// caret exists.
  final Rect? Function() getGlobalCaretRect;

  /// Whether the text field that owns this [IOSTextFieldInteractor] is
  /// a multiline text field.
  final bool isMultiline;

  /// The color of expanded selection drag handles.
  final Color handleColor;

  /// Whether to paint debugging guides and regions.
  final bool showDebugPaint;

  /// The child widget.
  final Widget child;

  @override
  IOSTextFieldTouchInteractorState createState() => IOSTextFieldTouchInteractorState();
}

class IOSTextFieldTouchInteractorState extends State<IOSTextFieldTouchInteractor> with TickerProviderStateMixin {
  /// The maximum horizontal distance that a user can press near the caret to enable
  /// a caret drag.
  static const _closeEnoughToDragCaret = 48.0;

  final _textViewportOffsetLink = LayerLink();

  // Whether the user is dragging a collapsed selection.
  bool _isDraggingCaret = false;

  // The latest offset during a user's drag gesture.
  Offset? _globalDragOffset;
  Offset? _dragOffset;

  TextSelection? _selectionBeforeTap;

  TextSelection? _previousToolbarFocusSelection;
  final _toolbarFocusSelectionRect = ValueNotifier<Rect?>(null);

  @override
  void initState() {
    super.initState();

    widget.textController.addListener(_onTextOrSelectionChange);
    widget.textScrollController.addListener(_onScrollChange);
  }

  @override
  void didUpdateWidget(IOSTextFieldTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onTextOrSelectionChange);
      widget.textController.addListener(_onTextOrSelectionChange);
    }
    if (widget.textScrollController != oldWidget.textScrollController) {
      oldWidget.textScrollController.removeListener(_onScrollChange);
      widget.textScrollController.addListener(_onScrollChange);
    }
  }

  @override
  void dispose() {
    _toolbarFocusSelectionRect.dispose();
    widget.textController.removeListener(_onTextOrSelectionChange);
    widget.textScrollController.removeListener(_onScrollChange);
    super.dispose();
  }

  ProseTextLayout get _textLayout => widget.selectableTextKey.currentState!.textLayout;

  void _onTextOrSelectionChange() {
    if (widget.textController.selection != _previousToolbarFocusSelection) {
      // Update the selection bounds focal point
      WidgetsBinding.instance.runAsSoonAsPossible(_computeSelectionRect);
    }

    if (!_isDraggingCaret) {
      // The user isn't dragging the caret. Ensure the current selection is visible. The
      // user may have typed beyond the viewport, or something may have changed the controller's
      // selection to sit beyond the viewport.
      //
      // We don't do this when the user is dragging the caret because the user's finger position
      // and the auto-scrolling system should control the scroll offset in that case.
      onNextFrame((timeStamp) {
        // We adjust for the extent offset in the next frame because we need the
        // underlying RenderParagraph to update first, so that we can inspect the
        // text layout for the most recent text and selection.
        widget.textScrollController.ensureExtentIsVisible();
      });
    }
  }

  void _onTapDown(TapDownDetails details) {
    _log.fine("User tapped down");
    if (!widget.focusNode.hasFocus) {
      _log.finer("Field isn't focused. Ignoring press.");
      return;
    }
  }

  void _onTapUp(TapUpDetails details) {
    _log.fine('User released a tap');

    _selectionBeforeTap = widget.textController.selection;

    if (widget.focusNode.hasFocus && widget.textController.isAttachedToIme) {
      widget.textController.showKeyboard();
    } else if (widget.focusNode.hasFocus) {
      // This situation can happen on iOS web when the user taps outside the field
      // or clicks on the OK button of the software keyboard.
      // In this situation, the IME connection is closed but the field remains focused.
      // We need to attach to IME so the keyboard is displayed again.
      widget.textController.attachToIme();
    } else {
      widget.focusNode.requestFocus();
    }

    final exactTapTextPosition = _getTextPositionNearestToOffset(details.localPosition);
    final adjustedTapTextPosition =
        exactTapTextPosition != null ? _moveTapPositionToWordBoundary(exactTapTextPosition) : null;
    final didTapOnExistingSelection = adjustedTapTextPosition != null &&
        _selectionBeforeTap != null &&
        (_selectionBeforeTap!.isCollapsed
            ? adjustedTapTextPosition.offset == _selectionBeforeTap!.extent.offset
            : adjustedTapTextPosition.offset >= _selectionBeforeTap!.start &&
                adjustedTapTextPosition.offset <= _selectionBeforeTap!.end);

    // Select the text that's nearest to where the user tapped.
    _selectPosition(adjustedTapTextPosition);

    final didCaretStayInSamePlace = _selectionBeforeTap != null &&
        _selectionBeforeTap?.hasSameBoundsAs(widget.textController.selection) == true &&
        _selectionBeforeTap!.isCollapsed;
    if ((didCaretStayInSamePlace || didTapOnExistingSelection) && widget.focusNode.hasFocus) {
      // The user either tapped directly on the caret, or on an expanded selection,
      // or the user tapped in empty space but didn't move the caret, for example
      // the user tapped in empty space after the text and the caret was already
      // at the end of the text.
      //
      // Toggle the toolbar.
      widget.editingOverlayController.toggleToolbar();
    } else if (!didCaretStayInSamePlace && !didTapOnExistingSelection) {
      // The user tapped somewhere in the text outside any existing selection.
      // Hide the toolbar.
      widget.editingOverlayController.hideToolbar();
    }

    _selectionBeforeTap = null;
  }

  TextPosition _moveTapPositionToWordBoundary(TextPosition textPosition) {
    if (Testing.isInTest) {
      // Don't adjust the tap location in tests because we want tests to be
      // able to precisely position the caret at a given offset.
      // TODO: Make this decision configurable, similar to SuperEditor, so that
      //       we can add tests for this behavior.
      return textPosition;
    }

    if (textPosition.offset < 0) {
      return textPosition;
    }

    final text = widget.textController.text.text;
    final tapOffset = textPosition.offset;
    if (tapOffset == text.length) {
      return textPosition;
    }
    final adjustedSelectionOffset = IosHeuristics.adjustTapOffset(text, tapOffset);

    return TextPosition(offset: adjustedSelectionOffset);
  }

  void _selectPosition(TextPosition? textPosition) {
    if (textPosition == null || textPosition.offset < 0) {
      // This situation indicates the user tapped in empty space
      widget.textController.selection = TextSelection.collapsed(offset: widget.textController.text.length);
      return;
    }

    // Update the text selection to a collapsed selection where the user tapped.
    widget.textController.selection = TextSelection.collapsed(offset: textPosition.offset);
    widget.textController.composingRegion = TextRange.empty;
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _log.fine('Double tap');
    widget.focusNode.requestFocus();

    // When the user released the first tap, the toolbar was set
    // to visible. At the beginning of a double-tap, make it invisible
    // again.
    widget.editingOverlayController.hideToolbar();

    final tapTextPosition = _getTextPositionNearestToOffset(details.localPosition);
    if (tapTextPosition != null) {
      setState(() {
        final wordSelection = _getWordSelectionAt(tapTextPosition);

        widget.textController.selection = wordSelection;

        if (!wordSelection.isCollapsed) {
          widget.editingOverlayController.showToolbar();
        }
      });
    }
  }

  void _onTripleTapDown(TapDownDetails details) {
    final textLayout = _textLayout;
    final tapTextPosition = textLayout.getPositionAtOffset(details.localPosition)!;

    widget.textController.selection =
        textLayout.expandSelection(tapTextPosition, paragraphExpansionFilter, TextAffinity.downstream);
  }

  void _onPanStart(DragStartDetails details) {
    _log.fine('_onPanStart()');

    final globalCaretRect = widget.getGlobalCaretRect();
    if (globalCaretRect == null) {
      // There's no caret, therefore the user shouldn't be able to drag the caret. Fizzle.
      return;
    }
    if ((globalCaretRect.center - details.globalPosition).dx.abs() > _closeEnoughToDragCaret) {
      // There's a caret, but the user's drag offset is far away. Fizzle.
      return;
    }

    // Let the user drag the caret around.
    setState(() {
      _isDraggingCaret = true;
      _globalDragOffset = details.globalPosition;
      _dragOffset = details.localPosition;

      // When the user drags, the toolbar should not be visible.
      widget.editingOverlayController.hideToolbar();

      if (widget.textController.selection.isCollapsed) {
        // The user is dragging the caret. Stop the caret from blinking while dragging.
        widget.editingOverlayController.stopCaretBlinking();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.fine('_onPanUpdate handle mode');
    if (!_isDraggingCaret) {
      return;
    }

    setState(() {
      widget.textController.selection = TextSelection.collapsed(
        offset: _globalOffsetToTextPosition(details.globalPosition).offset,
      );

      _globalDragOffset = _globalDragOffset! + details.delta;
      _dragOffset = _dragOffset! + details.delta;

      widget.textScrollController.updateAutoScrollingForTouchOffset(
        userInteractionOffsetInViewport: _dragOffset!,
      );

      widget.editingOverlayController.showMagnifier(_globalDragOffset!);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _log.fine('_onPanEnd()');
    _onHandleDragEnd();
  }

  void _onPanCancel() {
    _log.fine('_onPanCancel()');
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    _log.fine('_onHandleDragEnd()');
    widget.textScrollController.stopScrolling();

    if (_isDraggingCaret) {
      widget.textScrollController.ensureExtentIsVisible();
    }

    setState(() {
      _isDraggingCaret = false;
      widget.editingOverlayController.hideMagnifier();

      if (!widget.textController.selection.isCollapsed) {
        widget.editingOverlayController.showToolbar();
      } else {
        // The user stopped dragging the caret and the selection is collapsed.
        // Start the caret blinking again.
        widget.editingOverlayController.startCaretBlinking();
      }
    });
  }

  void _onScrollChange() {
    if (_isDraggingCaret) {
      // This callback is invoked as soon as the logical scroll offset
      // changes, but that scroll value won't be reflected in the text
      // layout until the end of this frame. Therefore, we schedule a
      // a post frame callback to lookup the new text selection location
      // after the current layout pass.
      onNextFrame((_) {
        widget.textController.selection = TextSelection.collapsed(
          offset: _globalOffsetToTextPosition(_globalDragOffset!).offset,
        );
      });
    }
  }

  /// Converts a screen-level offset to an offset relative to the top-left
  /// corner of the text within this text field.
  Offset _globalOffsetToTextOffset(Offset globalOffset) {
    final textBox = widget.selectableTextKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(globalOffset);
  }

  /// Converts a screen-level offset to a [TextPosition] that sits at that
  /// global offset.
  TextPosition _globalOffsetToTextPosition(Offset globalOffset) {
    return _textLayout.getPositionNearestToOffset(
      _globalOffsetToTextOffset(globalOffset),
    );
  }

  /// Returns the [TextPosition] that's nearest to the given [localOffset] within
  /// this [IOSTextFieldInteractor].
  TextPosition? _getTextPositionNearestToOffset(Offset localOffset) {
    // We show placeholder text when there is no text content. We don't want
    // to place the caret in the placeholder text, so when _currentText is
    // empty, explicitly set the text position to an offset of -1.
    if (widget.textController.text.text.isEmpty) {
      return const TextPosition(offset: -1);
    }

    final globalOffset = (context.findRenderObject() as RenderBox).localToGlobal(localOffset);
    final textOffset =
        (widget.selectableTextKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
    return _textLayout.getPositionNearestToOffset(textOffset);
  }

  /// Returns the [TextPosition] that's at the given [localOffset] within
  /// this [IOSTextFieldInteractor], or `null` if no text exists at the given
  /// offset.
  TextPosition? _getTextPositionAtOffset(Offset localOffset) {
    // We show placeholder text when there is no text content. We don't want
    // to place the caret in the placeholder text, so when _currentText is
    // empty, explicitly set the text position to an offset of -1.
    if (widget.textController.text.text.isEmpty) {
      return const TextPosition(offset: -1);
    }

    final globalOffset = (context.findRenderObject() as RenderBox).localToGlobal(localOffset);
    final textOffset =
        (widget.selectableTextKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
    return _textLayout.getPositionAtOffset(textOffset);
  }

  /// Returns a [TextSelection] that selects the word surrounding the given
  /// [position].
  TextSelection _getWordSelectionAt(TextPosition position) {
    return _textLayout.getWordSelectionAt(position);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _textViewportOffsetLink,
      child: GestureDetector(
        onTap: () {
          _log.fine('Intercepting single tap');
          // This GestureDetector is here to prevent taps from going further
          // up the tree. There must be an issue with the custom gesture detector
          // used below that's allowing taps to bubble up even if handled.
          //
          // If this GestureDetector is placed any further down in this tree,
          // it won't block the touch event. But it does from right here.
          //
          // TODO: fix the custom gesture detector in the RawGestureDetector.
        },
        onDoubleTap: () {
          _log.fine('Intercepting double tap');
          // no-op
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: widget.showDebugPaint ? Border.all(color: Colors.purple) : const Border(),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              _buildExtentTrackerForMagnifier(),
              _buildTrackerForToolbarFocus(),
              _buildTapAndDragDetector(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapAndDragDetector() {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: RawGestureDetector(
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
                ..onStart = widget.focusNode.hasFocus ? _onPanStart : null
                ..onUpdate = widget.focusNode.hasFocus ? _onPanUpdate : null
                ..onEnd = widget.focusNode.hasFocus || _isDraggingCaret ? _onPanEnd : null
                ..onCancel = widget.focusNode.hasFocus || _isDraggingCaret ? _onPanCancel : null
                ..gestureSettings = gestureSettings;
            },
          ),
        },
      ),
    );
  }

  Widget _buildTrackerForToolbarFocus() {
    return ValueListenableBuilder(
      valueListenable: _toolbarFocusSelectionRect,
      builder: (context, selectionRect, child) {
        if (selectionRect == null) {
          return const SizedBox();
        }

        return Positioned.fromRect(
          rect: selectionRect,
          child: Leader(
            link: widget.editingOverlayController.toolbarFocalPoint,
            child: widget.showDebugPaint ? ColoredBox(color: Colors.green.withOpacity(0.2)) : const SizedBox(),
          ),
        );
      },
    );
  }

  void _computeSelectionRect() {
    _previousToolbarFocusSelection = widget.textController.selection;

    if (!widget.textController.selection.isValid) {
      _toolbarFocusSelectionRect.value = null;
      return;
    }

    if (widget.textController.selection.isCollapsed) {
      // The selection is collapsed.
      // Place the selection rect at the caret position.
      final selectionExtent = widget.textController.selection.extent;
      final caretOffset = _textLayout.getOffsetForCaret(selectionExtent);
      final caretHeight =
          _textLayout.getHeightForCaret(selectionExtent) ?? _textLayout.getLineHeightAtPosition(selectionExtent);
      _toolbarFocusSelectionRect.value = Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 0, caretHeight);

      return;
    }

    // The selection is expanded.
    // Make the selection rect include all selected characters.
    final textBoxes = _textLayout.getBoxesForSelection(widget.textController.selection);

    Rect boundingBox = textBoxes.first.toRect();
    for (int i = 1; i < textBoxes.length; i += 1) {
      boundingBox = boundingBox.expandToInclude(textBoxes[i].toRect());
    }
    _toolbarFocusSelectionRect.value = boundingBox;
  }

  /// Builds a tracking widget at the selection extent offset.
  ///
  /// The extent widget is tracked via [_draggingHandleLink]
  Widget _buildExtentTrackerForMagnifier() {
    if (!widget.textController.selection.isValid || _dragOffset == null) {
      return const SizedBox();
    }

    return Positioned(
      left: _dragOffset!.dx,
      top: _dragOffset!.dy,
      child: Leader(
        link: widget.editingOverlayController.magnifierFocalPoint,
        child: widget.showDebugPaint
            ? FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Container(
                  width: 20,
                  height: 20,
                  color: Colors.purpleAccent.withOpacity(0.5),
                ),
              )
            : const SizedBox(width: 1, height: 1),
      ),
    );
  }
}
