import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/default_editor/editor.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/selectable_text.dart';
import 'package:super_editor/src/infrastructure/text_layout.dart';

import 'attributed_text.dart';
import 'multi_tap_gesture.dart';

final _log = Logger(scope: 'super_textfield.dart');

class SuperTextField extends StatefulWidget {
  const SuperTextField({
    Key? key,
    this.focusNode,
    this.textController,
    this.textStyleBuilder = defaultStyleBuilder,
    this.textAlign = TextAlign.left,
    this.textSelectionDecoration = const TextSelectionDecoration(
      selectionColor: Color(0xFFACCEF7),
    ),
    this.textCaretFactory = const TextCaretFactory(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
    this.padding = EdgeInsets.zero,
    this.minLines,
    this.maxLines = 1,
    this.decorationBuilder,
    this.hintBuilder,
    this.hintBehavior = HintBehavior.displayHintUntilFocus,
    this.onRightClick,
    this.keyboardActions = defaultTextfieldKeyboardActions,
  }) : super(key: key);

  final FocusNode? focusNode;

  final AttributedTextEditingController? textController;

  final AttributionStyleBuilder textStyleBuilder;

  /// The alignment to use for `richText` display.
  final TextAlign textAlign;

  /// The visual decoration to apply to the `textSelection`.
  final TextSelectionDecoration textSelectionDecoration;

  /// Builds the visual representation of the caret in this
  /// `SelectableText` widget.
  final TextCaretFactory textCaretFactory;

  final EdgeInsetsGeometry padding;

  final int? minLines;
  final int? maxLines;

  final DecorationBuilder? decorationBuilder;

  final WidgetBuilder? hintBuilder;
  final HintBehavior hintBehavior;

  final RightClickListener? onRightClick;

  final List<TextfieldKeyboardAction> keyboardActions;

  @override
  SuperTextFieldState createState() => SuperTextFieldState();
}

class SuperTextFieldState extends State<SuperTextField> {
  final _selectableTextKey = GlobalKey<SelectableTextState>();
  final _textScrollKey = GlobalKey<SuperTextFieldScrollviewState>();
  late FocusNode _focusNode;

  late AttributedTextEditingController _controller;
  late ScrollController _scrollController;

  double? _viewportHeight;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();
    _controller = (widget.textController ?? AttributedTextEditingController())
      ..addListener(_onSelectionOrContentChange);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(SuperTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }

    if (widget.textController != oldWidget.textController) {
      _controller.removeListener(_onSelectionOrContentChange);
      if (oldWidget.textController == null) {
        _controller.dispose();
      }
      _controller = (widget.textController ?? AttributedTextEditingController())
        ..addListener(_onSelectionOrContentChange);
    }

    if (widget.padding != oldWidget.padding ||
        widget.minLines != oldWidget.minLines ||
        widget.maxLines != oldWidget.maxLines) {
      _onSelectionOrContentChange();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.removeListener(_onSelectionOrContentChange);
    if (widget.textController == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _updateViewportHeight();
      }
    });
  }

  /// Returns true if the viewport height changed, false otherwise.
  bool _updateViewportHeight() {
    final estimatedLineHeight = _getEstimatedLineHeight();
    final estimatedLinesOfText = _getEstimatedLinesOfText();
    final estimatedContentHeight = estimatedLinesOfText * estimatedLineHeight;
    final minHeight = widget.minLines != null ? widget.minLines! * estimatedLineHeight + widget.padding.vertical : null;
    final maxHeight = widget.maxLines != null ? widget.maxLines! * estimatedLineHeight + widget.padding.vertical : null;
    double? viewportHeight;
    if (maxHeight != null && estimatedContentHeight > maxHeight) {
      viewportHeight = maxHeight;
    } else if (minHeight != null && estimatedContentHeight < minHeight) {
      viewportHeight = minHeight;
    }

    if (viewportHeight == _viewportHeight) {
      // The height of the viewport hasn't changed. Return.
      return false;
    }

    setState(() {
      _viewportHeight = viewportHeight;
    });

    return true;
  }

  int _getEstimatedLinesOfText() {
    if (_controller.text.text.isEmpty) {
      return 0;
    }

    if (_selectableTextKey.currentState == null) {
      return 0;
    }

    final offsetAtEndOfText =
        _selectableTextKey.currentState!.getOffsetAtPosition(TextPosition(offset: _controller.text.text.length));
    int lineCount = (offsetAtEndOfText.dy / _getEstimatedLineHeight()).ceil();

    if (_controller.text.text.endsWith('\n')) {
      lineCount += 1;
    }

    return lineCount;
  }

  double _getEstimatedLineHeight() {
    final defaultStyle = widget.textStyleBuilder({});
    return (defaultStyle.height ?? 1.0) * defaultStyle.fontSize!;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectableTextKey.currentContext == null) {
      // The text hasn't been laid out yet, which means our calculations
      // for text height is probably wrong. Schedule a post frame callback
      // to re-calculate the height after initial layout.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {
            _updateViewportHeight();
          });
        }
      });
    }

    final isMultiline = widget.minLines != 1 || widget.maxLines != 1;

    return Focus(
      // Prevents error sound when pressing keyboard keys.
      onKey: (_, __) => true,
      child: SuperTextFieldKeyboardInteractor(
        focusNode: _focusNode,
        controller: _controller,
        textKey: _selectableTextKey,
        keyboardActions: widget.keyboardActions,
        child: SuperTextFieldGestureInteractor(
          focusNode: _focusNode,
          controller: _controller,
          textKey: _selectableTextKey,
          textScrollKey: _textScrollKey,
          isMultiline: isMultiline,
          onRightClick: widget.onRightClick,
          child: MultiListenableBuilder(
            listenables: {
              _focusNode,
              _controller,
            },
            builder: (context) {
              final isTextEmpty = _controller.text.text.isEmpty;
              final showHint = widget.hintBuilder != null &&
                  ((isTextEmpty && widget.hintBehavior == HintBehavior.displayHintUntilTextEntered) ||
                      (isTextEmpty &&
                          !_focusNode.hasFocus &&
                          widget.hintBehavior == HintBehavior.displayHintUntilFocus));

              return _buildDecoration(
                child: SuperTextFieldScrollview(
                  key: _textScrollKey,
                  textKey: _selectableTextKey,
                  textController: _controller,
                  scrollController: _scrollController,
                  viewportHeight: _viewportHeight,
                  estimatedLineHeight: _getEstimatedLineHeight(),
                  padding: widget.padding,
                  isMultiline: isMultiline,
                  child: Stack(
                    children: [
                      if (showHint) widget.hintBuilder!(context),
                      _buildSelectableText(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDecoration({
    required Widget child,
  }) {
    return widget.decorationBuilder != null ? widget.decorationBuilder!(context, child) : child;
  }

  Widget _buildSelectableText() {
    return SelectableText(
      key: _selectableTextKey,
      textSpan: _controller.text.computeTextSpan(widget.textStyleBuilder),
      textAlign: widget.textAlign,
      textSelection: _controller.selection,
      textSelectionDecoration: widget.textSelectionDecoration,
      showCaret: _focusNode.hasFocus,
      textCaretFactory: widget.textCaretFactory,
    );
  }
}

typedef DecorationBuilder = Widget Function(BuildContext, Widget child);

enum HintBehavior {
  /// Display a hint when the text field is empty until
  /// the text field receives focus, then hide the hint.
  displayHintUntilFocus,

  /// Display a hint when the text field is empty until
  /// at least 1 character is entered into the text field.
  displayHintUntilTextEntered,

  /// Do not display a hint.
  noHint,
}

class SuperTextFieldGestureInteractor extends StatefulWidget {
  const SuperTextFieldGestureInteractor({
    Key? key,
    required this.focusNode,
    required this.controller,
    required this.textKey,
    required this.textScrollKey,
    required this.isMultiline,
    this.onRightClick,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;
  final AttributedTextEditingController controller;
  final GlobalKey<SelectableTextState> textKey;
  final GlobalKey<SuperTextFieldScrollviewState> textScrollKey;
  final bool isMultiline;
  final RightClickListener? onRightClick;
  final Widget child;

  @override
  _SuperTextFieldGestureInteractorState createState() => _SuperTextFieldGestureInteractorState();
}

class _SuperTextFieldGestureInteractorState extends State<SuperTextFieldGestureInteractor> {
  final _cursorStyle = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  _SelectionType _selectionType = _SelectionType.position;
  Offset? _dragStartInViewport;
  Offset? _dragStartInText;
  Offset? _dragEndInViewport;
  Offset? _dragEndInText;
  Rect? _dragRectInViewport;

  final _dragGutterExtent = 24;
  final _maxDragSpeed = 20;

  SelectableTextState get _text => widget.textKey.currentState!;

  SuperTextFieldScrollviewState get _textScroll => widget.textScrollKey.currentState!;

  //-------- START GESTURES ---------
  void _onTapDown(TapDownDetails details) {
    _log.log('_onTapDown', 'EditableDocument: onTapDown()');
    _clearSelection();
    _selectionType = _SelectionType.position;

    final textOffset = _getTextOffset(details.localPosition);
    final tapTextPosition = _getPositionNearestToTextOffset(textOffset);

    setState(() {
      widget.controller.selection = TextSelection.collapsed(offset: tapTextPosition.offset);
    });

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.word;

    _log.log('_onDoubleTapDown', 'EditableDocument: onDoubleTap()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.controller.selection = _text.getWordSelectionAt(tapTextPosition);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    _selectionType = _SelectionType.paragraph;

    _log.log('_onTripleTapDown', 'EditableDocument: onTripleTapDown()');

    final tapTextPosition = _getPositionAtOffset(details.localPosition);

    if (tapTextPosition != null) {
      setState(() {
        widget.controller.selection = _getParagraphSelectionAt(tapTextPosition, TextAffinity.downstream);
      });
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onTripleTap() {
    _selectionType = _SelectionType.position;
  }

  void _onRightClick(TapUpDetails details) {
    widget.onRightClick?.call(context, widget.controller, details.localPosition);
  }

  void _onPanStart(DragStartDetails details) {
    _log.log('_onPanStart', '_onPanStart()');
    _dragStartInViewport = details.localPosition;
    _dragStartInText = _getTextOffset(_dragStartInViewport!);

    _dragRectInViewport = Rect.fromLTWH(_dragStartInViewport!.dx, _dragStartInViewport!.dy, 1, 1);

    widget.focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.log('_onPanUpdate', '_onPanUpdate()');
    setState(() {
      _dragEndInViewport = details.localPosition;
      _dragEndInText = _getTextOffset(_dragEndInViewport!);
      _dragRectInViewport = Rect.fromPoints(_dragStartInViewport!, _dragEndInViewport!);
      _log.log('_onPanUpdate', ' - drag rect: $_dragRectInViewport');
      _updateCursorStyle(details.localPosition);
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll._stopScrollingToStart();
    _textScroll._stopScrollingToEnd();
  }

  void _onPanCancel() {
    setState(() {
      _dragStartInText = null;
      _dragEndInText = null;
      _dragRectInViewport = null;
    });

    _textScroll._stopScrollingToStart();
    _textScroll._stopScrollingToEnd();
  }

  void _updateDragSelection() {
    if (_dragStartInText == null || _dragEndInText == null) {
      return;
    }

    setState(() {
      final startDragOffset = _getPositionNearestToTextOffset(_dragStartInText!).offset;
      final endDragOffset = _getPositionNearestToTextOffset(_dragEndInText!).offset;
      final affinity = startDragOffset <= endDragOffset ? TextAffinity.downstream : TextAffinity.upstream;

      if (_selectionType == _SelectionType.paragraph) {
        final baseParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: startDragOffset), affinity);
        final extentParagraphSelection = _getParagraphSelectionAt(TextPosition(offset: endDragOffset), affinity);

        widget.controller.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else if (_selectionType == _SelectionType.word) {
        final baseParagraphSelection = _text.getWordSelectionAt(TextPosition(offset: startDragOffset));
        final extentParagraphSelection = _text.getWordSelectionAt(TextPosition(offset: endDragOffset));

        widget.controller.selection = _combineSelections(
          baseParagraphSelection,
          extentParagraphSelection,
          affinity,
        );
      } else {
        widget.controller.selection = TextSelection(
          baseOffset: startDragOffset,
          extentOffset: endDragOffset,
        );
      }
    });
  }

  TextSelection _combineSelections(
    TextSelection selection1,
    TextSelection selection2,
    TextAffinity affinity,
  ) {
    return affinity == TextAffinity.downstream
        ? TextSelection(
            baseOffset: min(selection1.start, selection2.start),
            extentOffset: max(selection1.end, selection2.end),
          )
        : TextSelection(
            baseOffset: max(selection1.end, selection2.end),
            extentOffset: min(selection1.start, selection2.start),
          );
  }

  void _clearSelection() {
    setState(() {
      widget.controller.selection = TextSelection.collapsed(offset: -1);
    });
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // TODO: remove access to _textScroll.widget
      final newScrollOffset = (_textScroll.widget.scrollController.offset + event.scrollDelta.dy)
          .clamp(0.0, _textScroll.widget.scrollController.position.maxScrollExtent);
      _textScroll.widget.scrollController.jumpTo(newScrollOffset);

      _updateDragSelection();
    }
  }

  void _scrollIfNearBoundary() {
    if (_dragEndInViewport == null) {
      _log.log('_scrollIfNearBoundary', "Can't scroll near boundary because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    if (!widget.isMultiline) {
      _scrollIfNearHorizontalBoundary();
    } else {
      _scrollIfNearVerticalBoundary();
    }
  }

  void _scrollIfNearHorizontalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToStart();
    } else {
      _stopScrollingToStart();
    }
    if (editorBox.size.width - _dragEndInViewport!.dx < _dragGutterExtent) {
      _startScrollingToEnd();
    } else {
      _stopScrollingToEnd();
    }
  }

  void _scrollIfNearVerticalBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToStart();
    } else {
      _stopScrollingToStart();
    }
    if (editorBox.size.height - _dragEndInViewport!.dy < _dragGutterExtent) {
      _startScrollingToEnd();
    } else {
      _stopScrollingToEnd();
    }
  }

  void _startScrollingToStart() {
    if (_dragEndInViewport == null) {
      _log.log('_scrollUp', "Can't scroll up because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final gutterAmount = _dragEndInViewport!.dy.clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll._startScrollingToStart(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToStart() {
    _textScroll._stopScrollingToStart();
  }

  void _startScrollingToEnd() {
    if (_dragEndInViewport == null) {
      _log.log('_scrollDown', "Can't scroll down because _dragEndInViewport is null");
      assert(_dragEndInViewport != null);
      return;
    }

    final editorBox = context.findRenderObject() as RenderBox;
    final gutterAmount = (editorBox.size.height - _dragEndInViewport!.dy).clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent)!;

    _textScroll._startScrollingToEnd(amountPerFrame: scrollAmount);
  }

  void _stopScrollingToEnd() {
    _textScroll._stopScrollingToEnd();
  }

  void _updateCursorStyle(Offset cursorOffset) {
    if (_isTextAtOffset(cursorOffset)) {
      _cursorStyle.value = SystemMouseCursors.text;
    } else {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  TextPosition? _getPositionAtOffset(Offset textFieldOffset) {
    final textOffset = _getTextOffset(textFieldOffset);
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;

    return textBox.size.contains(textOffset) ? widget.textKey.currentState!.getPositionAtOffset(textOffset) : null;
  }

  TextSelection _getParagraphSelectionAt(TextPosition textPosition, TextAffinity affinity) {
    return _text.expandSelection(textPosition, paragraphExpansionFilter, affinity);
  }

  TextPosition _getPositionNearestToTextOffset(Offset textOffset) {
    return widget.textKey.currentState!.getPositionAtOffset(textOffset);
  }

  bool _isTextAtOffset(Offset textFieldOffset) {
    final textOffset = _getTextOffset(textFieldOffset);
    return widget.textKey.currentState!.isTextAtOffset(textOffset);
  }

  Offset _getTextOffset(Offset textFieldOffset) {
    final textFieldBox = context.findRenderObject() as RenderBox;
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    return textBox.globalToLocal(textFieldOffset, ancestor: textFieldBox);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerHover: _onMouseMove,
      child: GestureDetector(
        onSecondaryTapUp: _onRightClick,
        child: RawGestureDetector(
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
          child: ListenableBuilder(
            listenable: _cursorStyle,
            builder: (context) {
              return MouseRegion(
                cursor: _cursorStyle.value,
                child: widget.child,
              );
            },
          ),
        ),
      ),
    );
  }
}

class SuperTextFieldKeyboardInteractor extends StatefulWidget {
  const SuperTextFieldKeyboardInteractor({
    Key? key,
    required this.focusNode,
    required this.controller,
    required this.textKey,
    required this.keyboardActions,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;
  final AttributedTextEditingController controller;
  final GlobalKey<SelectableTextState> textKey;
  final List<TextfieldKeyboardAction> keyboardActions;
  final Widget child;

  @override
  _SuperTextFieldKeyboardInteractorState createState() => _SuperTextFieldKeyboardInteractorState();
}

class _SuperTextFieldKeyboardInteractorState extends State<SuperTextFieldKeyboardInteractor> {
  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    _log.log('_onKeyPressed', 'keyEvent: ${keyEvent.character}');
    if (keyEvent is! RawKeyDownEvent) {
      _log.log('_onKeyPressed', ' - not a "down" event. Ignoring.');
      return KeyEventResult.handled;
    }

    TextFieldActionResult instruction = TextFieldActionResult.notHandled;
    int index = 0;
    while (instruction == TextFieldActionResult.notHandled && index < widget.keyboardActions.length) {
      instruction = widget.keyboardActions[index](
        controller: widget.controller,
        selectableTextState: widget.textKey.currentState!,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    return instruction == TextFieldActionResult.handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: widget.focusNode,
      onKey: _onKeyPressed,
      child: widget.child,
    );
  }
}

class SuperTextFieldScrollview extends StatefulWidget {
  const SuperTextFieldScrollview({
    Key? key,
    required this.textKey,
    required this.textController,
    required this.scrollController,
    required this.padding,
    required this.viewportHeight,
    required this.estimatedLineHeight,
    required this.isMultiline,
    required this.child,
  }) : super(key: key);

  final GlobalKey<SelectableTextState> textKey;
  final AttributedTextEditingController textController;
  final ScrollController scrollController;
  final EdgeInsetsGeometry padding;
  final double? viewportHeight;
  final double estimatedLineHeight;
  final bool isMultiline;
  final Widget child;

  @override
  SuperTextFieldScrollviewState createState() => SuperTextFieldScrollviewState();
}

class SuperTextFieldScrollviewState extends State<SuperTextFieldScrollview> with SingleTickerProviderStateMixin {
  bool _scrollToStartOnTick = false;
  bool _scrollToEndOnTick = false;
  double _scrollAmountPerFrame = 0;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    widget.textController.addListener(_onSelectionOrContentChange);
  }

  @override
  void didUpdateWidget(SuperTextFieldScrollview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onSelectionOrContentChange);
      widget.textController.addListener(_onSelectionOrContentChange);
    }

    if (widget.viewportHeight != oldWidget.viewportHeight) {
      // After the current layout, ensure that the current text
      // selection is visible.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          _ensureSelectionExtentIsVisible();
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  SelectableTextState get _text => widget.textKey.currentState!;

  void _onSelectionOrContentChange() {
    // Use a post-frame callback to "ensure selection extent is visible"
    // so that any pending visual content changes can happen before
    // attempting to calculate the visual position of the selection extent.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (mounted) {
        _ensureSelectionExtentIsVisible();
      }
    });
  }

  void _ensureSelectionExtentIsVisible() {
    if (!widget.isMultiline) {
      _ensureSelectionExtentIsVisibleInSingleLineTextField();
    } else {
      _ensureSelectionExtentIsVisibleInMultilineTextField();
    }
  }

  void _ensureSelectionExtentIsVisibleInSingleLineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final extentOffset = _text.getOffsetAtPosition(selection.extent);

    final gutterExtent = 0; // _dragGutterExtent

    final myBox = context.findRenderObject() as RenderBox;
    final beyondLeftExtent = min(extentOffset.dx - widget.scrollController.offset - gutterExtent, 0).abs();
    final beyondRightExtent = max(
        extentOffset.dx - myBox.size.width - widget.scrollController.offset + gutterExtent + widget.padding.horizontal,
        0);

    if (beyondLeftExtent > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondLeftExtent)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondRightExtent > 0) {
      final newScrollPosition = (beyondRightExtent + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _ensureSelectionExtentIsVisibleInMultilineTextField() {
    final selection = widget.textController.selection;
    if (selection.extentOffset == -1) {
      return;
    }

    final extentOffset = _text.getOffsetAtPosition(selection.extent);

    final gutterExtent = 0; // _dragGutterExtent
    final extentLineIndex = (extentOffset.dy / widget.estimatedLineHeight).round();

    final myBox = context.findRenderObject() as RenderBox;
    final beyondTopExtent = min<double>(extentOffset.dy - widget.scrollController.offset - gutterExtent, 0).abs();
    final beyondBottomExtent = max<double>(
        ((extentLineIndex + 1) * widget.estimatedLineHeight) -
            myBox.size.height -
            widget.scrollController.offset +
            gutterExtent +
            (widget.estimatedLineHeight / 2) + // manual adjustment to avoid line getting half cut off
            widget.padding.vertical / 2,
        0);

    _log.log('_ensureSelectionExtentIsVisible', 'Ensuring extent is visible.');
    _log.log('_ensureSelectionExtentIsVisible', ' - interaction size: ${myBox.size}');
    _log.log('_ensureSelectionExtentIsVisible', ' - scroll extent: ${widget.scrollController.offset}');
    _log.log('_ensureSelectionExtentIsVisible', ' - extent rect: $extentOffset');
    _log.log('_ensureSelectionExtentIsVisible', ' - beyond top: $beyondTopExtent');
    _log.log('_ensureSelectionExtentIsVisible', ' - beyond bottom: $beyondBottomExtent');

    if (beyondTopExtent > 0) {
      final newScrollPosition = (widget.scrollController.offset - beyondTopExtent)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (beyondBottomExtent > 0) {
      final newScrollPosition = (beyondBottomExtent + widget.scrollController.offset)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);

      widget.scrollController.animateTo(
        newScrollPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _startScrollingToStart({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToStartOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToStartOnTick = true;
    _ticker.start();
  }

  void _stopScrollingToStart() {
    if (!_scrollToStartOnTick) {
      return;
    }

    _scrollToStartOnTick = false;
    _scrollAmountPerFrame = 0;
    _ticker.stop();
  }

  void _scrollToStart() {
    if (widget.scrollController.offset <= 0) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset - _scrollAmountPerFrame);
  }

  void _startScrollingToEnd({required double amountPerFrame}) {
    assert(amountPerFrame > 0);

    if (_scrollToEndOnTick) {
      _scrollAmountPerFrame = amountPerFrame;
      return;
    }

    _scrollToEndOnTick = true;
    _ticker.start();
  }

  void _stopScrollingToEnd() {
    if (!_scrollToEndOnTick) {
      return;
    }

    _scrollToEndOnTick = false;
    _scrollAmountPerFrame = 0;
    _ticker.stop();
  }

  void _scrollToEnd() {
    if (widget.scrollController.offset >= widget.scrollController.position.maxScrollExtent) {
      return;
    }

    widget.scrollController.position.jumpTo(widget.scrollController.offset + _scrollAmountPerFrame);
  }

  void _onTick(elapsedTime) {
    if (_scrollToStartOnTick) {
      _scrollToStart();
    }
    if (_scrollToEndOnTick) {
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.viewportHeight,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: NeverScrollableScrollPhysics(),
        scrollDirection: widget.isMultiline ? Axis.vertical : Axis.horizontal,
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

typedef RightClickListener = void Function(
    BuildContext textFieldContext, AttributedTextEditingController textController, Offset textFieldOffset);

enum _SelectionType {
  position,
  word,
  paragraph,
}

enum TextFieldActionResult {
  handled,
  notHandled,
}

typedef TextfieldKeyboardAction = TextFieldActionResult Function({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
});

const defaultTextfieldKeyboardActions = <TextfieldKeyboardAction>[
  copyTextWhenCmdCIsPressed,
  pasteTextWhenCmdVIsPressed,
  selectAllTextFieldWhenCmdAIsPressed,
  moveUpDownLeftAndRightWithArrowKeysInTextField,
  deleteTextWhenBackspaceOrDeleteIsPressedInTextField,
  insertNewlineInTextField,
  insertCharacterInTextField,
];

TextFieldActionResult copyTextWhenCmdCIsPressed({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isMetaPressed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
    return TextFieldActionResult.notHandled;
  }

  Clipboard.setData(ClipboardData(
    text: controller.selection.textInside(controller.text.text),
  ));

  return TextFieldActionResult.handled;
}

TextFieldActionResult pasteTextWhenCmdVIsPressed({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isMetaPressed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return TextFieldActionResult.notHandled;
  }

  final insertionOffset = controller.selection.extentOffset;
  Clipboard.getData('utf8').then((clipboardData) {
    if (clipboardData != null && clipboardData.text != null) {
      controller.text.insertString(
        textToInsert: clipboardData.text!,
        startOffset: insertionOffset,
      );
    }
  });

  return TextFieldActionResult.handled;
}

TextFieldActionResult selectAllTextFieldWhenCmdAIsPressed({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  if (!keyEvent.isMetaPressed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.keyA) {
    return TextFieldActionResult.notHandled;
  }

  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.text.length,
  );

  return TextFieldActionResult.handled;
}

TextFieldActionResult moveUpDownLeftAndRightWithArrowKeysInTextField({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  const arrowKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ];
  if (!arrowKeys.contains(keyEvent.logicalKey)) {
    return TextFieldActionResult.notHandled;
  }
  if (controller.selection.extentOffset == -1) {
    return TextFieldActionResult.notHandled;
  }

  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling left arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      controller: controller,
      selectableTextState: selectableTextState,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: true,
      movementModifiers: movementModifiers,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling right arrow key');

    final movementModifiers = <String, dynamic>{
      'movement_unit': 'character',
    };
    if (keyEvent.isMetaPressed) {
      movementModifiers['movement_unit'] = 'line';
    } else if (keyEvent.isAltPressed) {
      movementModifiers['movement_unit'] = 'word';
    }

    _moveHorizontally(
      controller: controller,
      selectableTextState: selectableTextState,
      expandSelection: keyEvent.isShiftPressed,
      moveLeft: false,
      movementModifiers: movementModifiers,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling up arrow key');
    _moveVertically(
      controller: controller,
      selectableTextState: selectableTextState,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: true,
    );
  } else if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    _log.log('moveUpDownLeftAndRightWithArrowKeys', ' - handling down arrow key');
    _moveVertically(
      controller: controller,
      selectableTextState: selectableTextState,
      expandSelection: keyEvent.isShiftPressed,
      moveUp: false,
    );
  }

  return TextFieldActionResult.handled;
}

void _moveHorizontally({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required bool expandSelection,
  required bool moveLeft,
  Map<String, dynamic> movementModifiers = const {},
}) {
  int newExtent;

  if (moveLeft) {
    if (controller.selection.extentOffset <= 0) {
      // Can't move further left.
      return null;
    }

    if (movementModifiers['movement_unit'] == 'line') {
      newExtent =
          selectableTextState.getPositionAtStartOfLine(TextPosition(offset: controller.selection.extentOffset)).offset;
    } else if (movementModifiers['movement_unit'] == 'word') {
      final text = controller.text.text;

      newExtent = controller.selection.extentOffset;
      newExtent -= 1; // we always want to jump at least 1 character.
      while (newExtent > 0 && text[newExtent - 1] != ' ' && text[newExtent - 1] != '\n') {
        newExtent -= 1;
      }
    } else {
      newExtent = controller.selection.extentOffset - 1;
    }
  } else {
    if (controller.selection.extentOffset >= controller.text.text.length) {
      // Can't move further right.
      return null;
    }

    if (movementModifiers['movement_unit'] == 'line') {
      final endOfLine =
          selectableTextState.getPositionAtEndOfLine(TextPosition(offset: controller.selection.extentOffset));

      final endPosition = TextPosition(offset: controller.text.text.length);
      final text = controller.text.text;

      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (text[endOfLine.offset] != '\n');

      // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
      //       cursor to jump to the next line because the cursor is placed after
      //       the final selected character. We don't want this, so in this case
      //       we `-1`.
      //
      //       However, if the line that is selected ends with an explicit `\n`,
      //       or if the line is the terminal line for the paragraph then we don't
      //       want to `-1` because that would leave a dangling character after the
      //       selection.
      // TODO: this is the concept of text affinity. Implement support for affinity.
      // TODO: with affinity, ensure it works as expected for right-aligned text
      // TODO: this logic fails for justified text - find a solution for that (#55)
      newExtent = isAutoWrapLine ? endOfLine.offset - 1 : endOfLine.offset;
    } else if (movementModifiers['movement_unit'] == 'word') {
      final extentPosition = controller.selection.extent;
      final text = controller.text.text;

      newExtent = extentPosition.offset;
      newExtent += 1; // we always want to jump at least 1 character.
      while (newExtent < text.length && text[newExtent] != ' ' && text[newExtent] != '\n') {
        newExtent += 1;
      }
    } else {
      newExtent = controller.selection.extentOffset + 1;
    }
  }

  controller.selection = TextSelection(
    baseOffset: expandSelection ? controller.selection.baseOffset : newExtent,
    extentOffset: newExtent,
  );
}

void _moveVertically({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required bool expandSelection,
  required bool moveUp,
}) {
  int? newExtent;

  if (moveUp) {
    newExtent = selectableTextState.getPositionOneLineUp(controller.selection.extent)?.offset;

    // If there is no line above the current selection, move selection
    // to the beginning of the available text.
    newExtent ??= 0;
  } else {
    newExtent = selectableTextState.getPositionOneLineDown(controller.selection.extent)?.offset;

    // If there is no line below the current selection, move selection
    // to the end of the available text.
    newExtent ??= controller.text.text.length;
  }

  controller.selection = TextSelection(
    baseOffset: expandSelection ? controller.selection.baseOffset : newExtent,
    extentOffset: newExtent,
  );
}

TextFieldActionResult insertCharacterInTextField({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.isMetaPressed || keyEvent.isControlPressed) {
    return TextFieldActionResult.notHandled;
  }

  if (!controller.selection.isCollapsed) {
    return TextFieldActionResult.notHandled;
  }
  if (keyEvent.character == null || keyEvent.character == '') {
    return TextFieldActionResult.notHandled;
  }

  final initialTextOffset = controller.selection.extentOffset;

  final existingAttributions = controller.text.getAllAttributionsAt(initialTextOffset);
  controller.text = controller.text.insertString(
    textToInsert: keyEvent.character!,
    startOffset: initialTextOffset,
    applyAttributions: existingAttributions,
  );
  controller.selection = TextSelection.collapsed(offset: initialTextOffset + 1);

  return TextFieldActionResult.handled;
}

TextFieldActionResult deleteTextWhenBackspaceOrDeleteIsPressedInTextField({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  final isBackspace = keyEvent.logicalKey == LogicalKeyboardKey.backspace;
  final isDelete = keyEvent.logicalKey == LogicalKeyboardKey.delete;
  if (!isBackspace && !isDelete) {
    return TextFieldActionResult.notHandled;
  }
  if (controller.selection.extentOffset < 0) {
    return TextFieldActionResult.notHandled;
  }

  // If the current selection is not collapsed, then delete that
  // selection. If the selection is collapsed, calculate a selection
  // that includes the next or previous character depending on
  // whether the user pressed backspace or delete.
  final deletionSelection = controller.selection.isCollapsed
      ? TextSelection(
          baseOffset: controller.selection.extentOffset,
          extentOffset:
              (controller.selection.extentOffset + (isBackspace ? -1 : 1)).clamp(0, controller.text.text.length),
        )
      : controller.selection;

  final newSelectionExtent = isBackspace && controller.selection.isCollapsed
      ? controller.selection.extentOffset - 1
      : controller.selection.start;

  controller.text = controller.text.removeRegion(
    startOffset: min(deletionSelection.baseOffset, deletionSelection.extentOffset),
    endOffset: max(deletionSelection.baseOffset, deletionSelection.extentOffset),
  );
  controller.selection = TextSelection.collapsed(offset: newSelectionExtent);

  return TextFieldActionResult.handled;
}

TextFieldActionResult insertNewlineInTextField({
  required AttributedTextEditingController controller,
  required SelectableTextState selectableTextState,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return TextFieldActionResult.notHandled;
  }
  if (!controller.selection.isCollapsed) {
    return TextFieldActionResult.notHandled;
  }

  final currentSelectionExtent = controller.selection.extent;

  controller.text = controller.text.insertString(
    textToInsert: '\n',
    startOffset: currentSelectionExtent.offset,
  );
  controller.selection = TextSelection.collapsed(offset: currentSelectionExtent.offset + 1);

  return TextFieldActionResult.handled;
}

class AttributedTextEditingController with ChangeNotifier {
  AttributedTextEditingController({
    AttributedText? text,
    TextSelection? selection,
  })  : _text = text ?? AttributedText(),
        _selection = selection ?? TextSelection.collapsed(offset: -1);

  void updateTextAndSelection({
    required AttributedText text,
    required TextSelection selection,
  }) {
    this.text = text;
    this.selection = selection;
  }

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newValue) {
    if (newValue != _text) {
      _text.removeListener(notifyListeners);
      _text = newValue;
      _text.addListener(notifyListeners);

      // Ensure that the existing selection does not overshoot
      // the end of the new text value
      if (_selection.end > _text.text.length) {
        _selection = _selection.copyWith(
          baseOffset: _selection.affinity == TextAffinity.downstream ? _selection.baseOffset : _text.text.length,
          extentOffset: _selection.affinity == TextAffinity.downstream ? _text.text.length : _selection.extentOffset,
        );
      }

      notifyListeners();
    }
  }

  TextSelection _selection;
  TextSelection get selection => _selection;
  set selection(TextSelection newValue) {
    if (newValue != _selection) {
      _selection = newValue;
      notifyListeners();
    }
  }

  bool isSelectionWithinTextBounds(TextSelection selection) {
    return selection.start <= text.text.length && selection.end <= text.text.length;
  }

  TextSpan buildTextSpan(AttributionStyleBuilder styleBuilder) {
    return text.computeTextSpan(styleBuilder);
  }

  void clear() {
    _text = AttributedText();
    _selection = TextSelection.collapsed(offset: -1);
  }
}
