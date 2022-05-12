import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text/super_selectable_text.dart';

import '_editing_controls.dart';

final _log = iosTextFieldLog;

/// iOS text field touch interaction surface.
///
/// This widget is intended to be displayed in the foreground of
/// a [SuperSelectableText] widget.
///
/// This widget recognizes and acts upon various user interactions:
///
///  * Tap: Place a collapsed text selection at the tapped location
///    in text.
///  * Double-Tap: Select the word surrounding the tapped location
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
  final AttributedTextEditingController textController;

  final IOSEditingOverlayController editingOverlayController;

  final TextScrollController textScrollController;

  /// [GlobalKey] that references the [SuperSelectableText] that lays out
  /// and renders the text within the text field that owns this
  /// [IOSTextFieldInteractor].
  final GlobalKey<SuperSelectableTextState> selectableTextKey;

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
  final _textViewportOffsetLink = LayerLink();

  TextSelection? _selectionBeforeSingleTapDown;

  // Whether the user is dragging a collapsed selection.
  bool _isDraggingCaret = false;

  // The latest offset during a user's drag gesture.
  Offset? _globalDragOffset;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();

    widget.textScrollController.addListener(_onScrollChange);
  }

  @override
  void didUpdateWidget(IOSTextFieldTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textScrollController != oldWidget.textScrollController) {
      oldWidget.textScrollController.removeListener(_onScrollChange);
      widget.textScrollController.addListener(_onScrollChange);
    }
  }

  @override
  void dispose() {
    widget.textScrollController.removeListener(_onScrollChange);
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _log.fine('_onTapDown');

    widget.focusNode.requestFocus();

    // When the user drags, the toolbar should not be visible.
    // A drag can begin with a tap down, so we hide the toolbar
    // preemptively.
    widget.editingOverlayController.hideToolbar();

    _selectionBeforeSingleTapDown = widget.textController.selection;

    final tapTextPosition = _getTextPositionAtOffset(details.localPosition);
    if (tapTextPosition == null) {
      // This shouldn't be possible, but we'll ignore the tap if we can't
      // map it to a position within the text.
      _log.warning('received a tap-down event on IOSTextFieldInteractor that is not on top of any text');
      return;
    }

    // Update the text selection to a collapsed selection where the user tapped.
    widget.textController.selection = TextSelection.collapsed(offset: tapTextPosition.offset);
  }

  void _onTapUp(TapUpDetails details) {
    _log.fine('_onTapUp()');
    // If the user tapped on a collapsed caret, or tapped on an
    // expanded selection, toggle the toolbar appearance.

    final tapTextPosition = _getTextPositionAtOffset(details.localPosition);
    if (tapTextPosition == null) {
      // This shouldn't be possible, but we'll ignore the tap if we can't
      // map it to a position within the text.
      _log.warning('received a tap-up event on IOSTextFieldInteractor that is not on top of any text');
      return;
    }

    final didTapOnExistingSelection = widget.textController.selection.isCollapsed
        ? tapTextPosition == _selectionBeforeSingleTapDown!.extent
        : tapTextPosition.offset >= _selectionBeforeSingleTapDown!.start &&
            tapTextPosition.offset <= _selectionBeforeSingleTapDown!.end;

    if (didTapOnExistingSelection) {
      // Toggle the toolbar display when the user taps on the collapsed caret,
      // or on top of an existing selection.
      widget.editingOverlayController.toggleToolbar();
    } else {
      // The user tapped somewhere in the text outside any existing selection.
      // Hide the toolbar.
      widget.editingOverlayController.hideToolbar();
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _log.fine('Double tap');
    widget.focusNode.requestFocus();

    // When the user released the first tap, the toolbar was set
    // to visible. At the beginning of a double-tap, make it invisible
    // again.
    widget.editingOverlayController.hideToolbar();

    final tapTextPosition = _getTextPositionAtOffset(details.localPosition);
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
    final tapTextPosition = widget.selectableTextKey.currentState!.getPositionAtOffset(details.localPosition);

    widget.textController.selection = widget.selectableTextKey.currentState!
        .expandSelection(tapTextPosition, paragraphExpansionFilter, TextAffinity.downstream);
  }

  void _onTextPanStart(DragStartDetails details) {
    _log.fine('_onTextPanStart()');
    setState(() {
      _isDraggingCaret = true;
      _globalDragOffset = details.globalPosition;
      _dragOffset = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.fine('_onPanUpdate handle mode');

    if (_isDraggingCaret) {
      widget.textController.selection = TextSelection.collapsed(
        offset: _globalOffsetToTextPosition(details.globalPosition).offset,
      );
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
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
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
    return widget.selectableTextKey.currentState!.getPositionNearestToOffset(
      _globalOffsetToTextOffset(globalOffset),
    );
  }

  /// Returns the [TextPosition] sitting at the given [localOffset] within
  /// this [IOSTextFieldInteractor].
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
    return widget.selectableTextKey.currentState!.getPositionAtOffset(textOffset);
  }

  /// Returns a [TextSelection] that selects the word surrounding the given
  /// [position].
  TextSelection _getWordSelectionAt(TextPosition position) {
    return widget.selectableTextKey.currentState!.getWordSelectionAt(position);
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
              if (widget.textController.selection.extentOffset >= 0) _buildExtentTrackerForMagnifier(),
              _buildTapAndDragDetector(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapAndDragDetector() {
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
                ..onTripleTapDown = _onTripleTapDown;
            },
          ),
          PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(),
            (PanGestureRecognizer recognizer) {
              recognizer
                ..onStart = widget.focusNode.hasFocus ? _onTextPanStart : null
                ..onUpdate = widget.focusNode.hasFocus ? _onPanUpdate : null
                ..onEnd = widget.focusNode.hasFocus || _isDraggingCaret ? _onPanEnd : null
                ..onCancel = widget.focusNode.hasFocus || _isDraggingCaret ? _onPanCancel : null;
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

    return Positioned(
      left: _dragOffset!.dx,
      top: _dragOffset!.dy,
      child: CompositedTransformTarget(
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
