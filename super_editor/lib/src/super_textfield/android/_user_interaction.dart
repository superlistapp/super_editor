import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '_editing_controls.dart';

final _log = androidTextFieldLog;

/// Android text field touch interaction surface.
///
/// This widget is intended to be displayed in the foreground of
/// a [SuperSelectableText] widget.
///
/// This widget recognizes and acts upon various user interactions:
///
///  * Tap: Place a collapsed text selection at the tapped location
///    in text.
///  * Long-Press (over text): select surrounding word.
///  * Long-Press (in empty space with a selection): show the toolbar.
///  * Double-Tap: Select the word surrounding the tapped location
///  * Triple-Tap: Select the paragraph surrounding the tapped location
///  * Drag: Move a collapsed selection wherever the user drags, while
///    displaying a magnifying glass.
///
/// Drag handles, a magnifying glass, and an editing toolbar are displayed
/// based on how the user interacts with this widget. Those UI elements
/// are controller via the given [editingOverlayController].
///
/// Magnifier: based on observed Android behavior, when dragging the collapsed
/// handle, or dragging freely around the text, the magnifier is always positioned
/// relative to the caret position (not the user's exact finger location).
///
/// The text is auto-scrolled when the user drags a collapsed caret in
/// this widget. The auto-scrolling is handled by the given [textScrollController].
///
/// Selection changes are made via the given [textController].
class AndroidTextFieldTouchInteractor extends StatefulWidget {
  const AndroidTextFieldTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.textFieldLayerLink,
    required this.textController,
    required this.editingOverlayController,
    required this.textScrollController,
    required this.textKey,
    required this.getGlobalCaretRect,
    required this.isMultiline,
    required this.handleColor,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  /// [FocusNode] for the text field that contains this [AndroidTextFieldInteractor].
  ///
  /// [AndroidTextFieldInteractor] only shows editing controls, and listens for drag
  /// events when [focusNode] has focus.
  ///
  /// [AndroidTextFieldInteractor] requests focus when the user taps on it.
  final FocusNode focusNode;

  /// [LayerLink] that follows the text field that contains this
  /// [AndroidTextFieldInteractor].
  ///
  /// [textFieldLayerLink] is used to anchor the editing controls.
  final LayerLink textFieldLayerLink;

  /// [TextController] used to read the current selection to display
  /// editing controls, and used to update the selection based on
  /// user interactions.
  final ImeAttributedTextEditingController textController;

  final AndroidEditingOverlayController editingOverlayController;

  final TextScrollController textScrollController;

  /// [GlobalKey] that references the widget that contains the text within
  /// this [AndroidTextFieldTouchInteractor].
  final GlobalKey<ProseTextState> textKey;

  /// A function that returns the current caret global rect, or `null` if no
  /// caret exists.
  final Rect? Function() getGlobalCaretRect;

  /// Whether the text field that owns this [AndroidTextFieldInteractor] is
  /// a multiline text field.
  final bool isMultiline;

  /// The color of expanded selection drag handles.
  final Color handleColor;

  /// Whether to paint debugging guides and regions.
  final bool showDebugPaint;

  /// The child widget.
  final Widget child;

  @override
  AndroidTextFieldTouchInteractorState createState() => AndroidTextFieldTouchInteractorState();
}

class AndroidTextFieldTouchInteractorState extends State<AndroidTextFieldTouchInteractor>
    with TickerProviderStateMixin {
  /// The maximum horizontal distance that a user can press near the caret to enable
  /// a caret drag.
  static const _closeEnoughToDragCaret = 48.0;

  final _textViewportOffsetLink = LayerLink();

  // Whether the user is dragging a collapsed selection.
  bool _isDraggingCaret = false;

  // The latest offset during a user's drag gesture.
  Offset? _globalDragOffset;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();

    widget.textController.addListener(_onTextOrSelectionChange);
    widget.textScrollController.addListener(_onScrollChange);
  }

  @override
  void didUpdateWidget(AndroidTextFieldTouchInteractor oldWidget) {
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
    widget.textController.removeListener(_onTextOrSelectionChange);
    widget.textScrollController.removeListener(_onScrollChange);
    super.dispose();
  }

  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  void _onTextOrSelectionChange() {
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

  void _onTapUp(TapUpDetails details) {
    _log.fine('User released a tap');

    if (widget.focusNode.hasFocus && widget.textController.isAttachedToIme) {
      widget.textController.showKeyboard();
    } else {
      widget.focusNode.requestFocus();
    }

    // If the user tapped on a collapsed caret, or tapped on an
    // expanded selection, toggle the toolbar appearance.
    final tapTextPosition = _getTextPositionAtOffset(details.localPosition);
    if (tapTextPosition == null) {
      // Place the caret based on the tap offset. In this case, the caret will
      // be placed at the end of text because the user tapped in empty space.
      _selectAtOffset(details.localPosition);
      return;
    }

    final previousSelection = widget.textController.selection;
    final didTapOnExistingSelection = previousSelection.isCollapsed
        ? tapTextPosition == previousSelection.extent
        : tapTextPosition.offset >= previousSelection.start && tapTextPosition.offset <= previousSelection.end;

    if (didTapOnExistingSelection && previousSelection.isCollapsed) {
      // Toggle the toolbar display when the user taps on the collapsed caret.
      widget.editingOverlayController.toggleToolbar();
    } else {
      // The user tapped somewhere in the text outside any existing selection.
      // Hide the toolbar.
      widget.editingOverlayController.hideToolbar();

      // Place the caret based on the tap offset.
      _selectAtOffset(details.localPosition);
    }

    // On Android, the collapsed handle should disappear after a few seconds
    // of inactivity.
    widget.editingOverlayController
      ..unHideCollapsedHandle()
      ..startCollapsedHandleAutoHideCountdown();
  }

  /// Places the caret in the field's text based on the given [localOffset],
  /// and displays the drag handle.
  void _selectAtOffset(Offset localOffset) {
    // Ensure that the collapsed handle is not auto-hidden.
    widget.editingOverlayController.unHideCollapsedHandle();

    final tapTextPosition = _getTextPositionAtOffset(localOffset);
    if (tapTextPosition == null) {
      // This situation indicates the user tapped in empty space
      widget.textController.selection = TextSelection.collapsed(offset: widget.textController.text.length);
    } else {
      // Update the text selection to a collapsed selection where the user tapped.
      widget.textController.selection = tapTextPosition.offset >= 0
          ? TextSelection.collapsed(offset: tapTextPosition.offset)
          : const TextSelection.collapsed(offset: 0);
    }
    widget.textController.composingRegion = TextRange.empty;

    widget.editingOverlayController.showHandles();
  }

  void _onLongPress() {
    if (!widget.textController.selection.isValid) {
      // There's no user selection. Don't show the toolbar when there's
      // nothing to apply it to.
      return;
    }

    widget.editingOverlayController.showToolbar();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _log.fine("User double-tapped down");
    widget.focusNode.requestFocus();

    final tapTextPosition = _getTextPositionAtOffset(details.localPosition);
    if (tapTextPosition != null) {
      setState(() {
        final wordSelection = _getWordSelectionAt(tapTextPosition);

        widget.textController.selection = wordSelection;

        if (!wordSelection.isCollapsed) {
          widget.editingOverlayController.showToolbar();
        } else {
          // The selection is collapsed. The collapsed handle should disappear
          // after some inactivity. Start the countdown (or restart an in-progress
          // countdown).
          widget.editingOverlayController
            ..unHideCollapsedHandle()
            ..startCollapsedHandleAutoHideCountdown();
        }
      });
    }
  }

  void _onTripleTapDown(TapDownDetails details) {
    _log.fine("User triple-tapped down");
    final tapTextPosition = _textLayout.getPositionAtOffset(details.localPosition)!;

    widget.textController.selection =
        _textLayout.expandSelection(tapTextPosition, paragraphExpansionFilter, TextAffinity.downstream);

    if (widget.textController.selection.isCollapsed) {
      // The selection is collapsed. The collapsed handle should disappear
      // after some inactivity. Start the countdown (or restart an in-progress
      // countdown).
      widget.editingOverlayController
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _log.fine("User started a pan");

    final globalCaretRect = widget.getGlobalCaretRect();
    if (globalCaretRect == null) {
      // There's no caret, therefore the user shouldn't be able to drag the caret. Fizzle.
      return;
    }
    if ((globalCaretRect.center - details.globalPosition).dx.abs() > _closeEnoughToDragCaret) {
      // There's a caret, but the user's drag offset is far away. Fizzle.
      return;
    }

    setState(() {
      _isDraggingCaret = true;
      _globalDragOffset = details.globalPosition;
      _dragOffset = details.localPosition;

      // Cancel any ongoing handle auto-disappear timer.
      widget.editingOverlayController.cancelCollapsedHandleAutoHideCountdown();

      if (widget.textController.selection.isCollapsed) {
        // The user is dragging the caret. Stop the caret from blinking while dragging.
        widget.editingOverlayController.stopCaretBlinking();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.finer("User panned to new offset");

    if (!_isDraggingCaret) {
      return;
    }

    final newSelection = TextSelection.collapsed(
      offset: _globalOffsetToTextPosition(details.globalPosition).offset,
    );

    if (newSelection != widget.textController.selection) {
      widget.textController.selection = newSelection;
      HapticFeedback.lightImpact();
    }

    setState(() {
      _globalDragOffset = _globalDragOffset! + details.delta;
      _dragOffset = _dragOffset! + details.delta;

      widget.textScrollController.updateAutoScrollingForTouchOffset(
        userInteractionOffsetInViewport: _dragOffset!,
      );

      widget.editingOverlayController.showMagnifier(_globalDragOffset!);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _log.fine("User ended a pan");
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

        // The selection is collapsed. The collapsed handle should disappear
        // after some inactivity. Start the countdown (or restart an in-progress
        // countdown).
        widget.editingOverlayController
          ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
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
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(globalOffset);
  }

  /// Converts a screen-level offset to a [TextPosition] that sits at that
  /// global offset.
  TextPosition _globalOffsetToTextPosition(Offset globalOffset) {
    return _textLayout.getPositionNearestToOffset(
      _globalOffsetToTextOffset(globalOffset),
    );
  }

  /// Returns the [TextPosition] sitting at the given [localOffset] within
  /// this [AndroidTextFieldInteractor].
  TextPosition? _getTextPositionAtOffset(Offset localOffset) {
    // We show placeholder text when there is no text content. We don't want
    // to place the caret in the placeholder text, so when _currentText is
    // empty, explicitly set the text position to an offset of -1.
    if (widget.textController.text.isEmpty) {
      return const TextPosition(offset: -1);
    }

    final globalOffset = (context.findRenderObject() as RenderBox).localToGlobal(localOffset);
    final textOffset = (widget.textKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
    return _textLayout.getPositionNearestToOffset(textOffset);
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
          // up the tree. There must an issue with the custom gesture detector
          // used below that's allowing taps to bubble up even if handled.
          //
          // If this GestureDetector is placed any further down in this tree,
          // it won't block the touch event. But it does from right here.
          //
          // TODO: fix the custom gesture detector in the RawGestureDetector.
        },
        // onDoubleTap: () {
        //   _log.fine('Intercepting double tap');
        //   // no-op
        // },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: widget.showDebugPaint ? Border.all(color: Colors.purple) : const Border(),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (widget.textController.selection.extentOffset >= 0) _buildExtentTrackerForMagnifier(),
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
                ..onTapUp = _onTapUp
                ..onDoubleTapDown = _onDoubleTapDown
                ..onTripleTapDown = _onTripleTapDown
                ..gestureSettings = gestureSettings;
            },
          ),
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(),
            (LongPressGestureRecognizer recognizer) {
              recognizer
                ..onLongPress = _onLongPress
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

  /// Builds a tracking widget at the selection extent offset.
  ///
  /// The extent widget is tracked via [_draggingHandleLink]
  Widget _buildExtentTrackerForMagnifier() {
    if (!_isDraggingCaret) {
      return const SizedBox();
    }

    // Calculate the magnifier offset.
    //
    // On Android, when dragging a collapsed selection, the magnifier should always
    // focus on the vertical midpoint of the current extent position.
    // TODO: can we de-dup this with similar calculations in _editing_controls?
    final extentPosition = widget.textController.selection.extent;
    final extentOffsetInText = _textLayout.getOffsetAtPosition(extentPosition);
    final extentLineHeight =
        _textLayout.getCharacterBox(extentPosition)?.toRect().height ?? _textLayout.estimatedLineHeight;
    final extentGlobalOffset =
        (widget.textKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(extentOffsetInText);
    final extentOffsetInViewport = (context.findRenderObject() as RenderBox).globalToLocal(extentGlobalOffset);

    return Positioned(
      left: extentOffsetInViewport.dx,
      top: extentOffsetInViewport.dy + (extentLineHeight / 2),
      child: CompositedTransformTarget(
        link: widget.editingOverlayController.magnifierFocalPoint,
        child: widget.showDebugPaint
            ? FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Container(
                  width: 20,
                  height: 20,
                  color: Colors.purpleAccent.withValues(alpha: 0.5),
                ),
              )
            : const SizedBox(width: 1, height: 1),
      ),
    );
  }
}
