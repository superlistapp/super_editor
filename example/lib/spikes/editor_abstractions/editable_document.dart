import 'dart:ui';

import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'core/document.dart';
import 'core/document_editor.dart';
import 'core/document_composer.dart';
import 'core/document_layout.dart';
import 'core/document_selection.dart';

import 'default_editor/document_composer_actions.dart';
import 'default_editor/text.dart';
import 'default_editor/paragraph.dart';
import 'default_editor/list_items.dart';
import 'default_editor/image.dart';
import 'default_editor/horizontal_rule.dart';
import 'custom_components/text_with_hint.dart';
import 'gestures/multi_tap_gesture.dart';

/// A user-editable rich text document.
///
/// An `EditableDocument` brings together the key pieces needed
/// to display a user-editable rich text document:
///  * document model
///  * document layout
///  * document interaction (tapping, dragging, typing, scrolling)
///  * document composer
///
/// The document model is responsible for holding the content of a
/// rich text document. The document model provides access to the
/// nodes within the document, and facilitates document edit
/// operations.
///
/// Document layout is responsible for positioning and rendering the
/// various visual components in the document. It's also responsible
/// for linking logical document nodes to visual document components
/// to facilitate user interactions like tapping and dragging.
///
/// Document interaction is responsible for taking appropriate actions
/// in response to user taps, drags, and key presses.
///
/// Document composer is responsible for owning and altering document
/// selection, as well as manipulating the logical document, e.g.,
/// typing new characters, deleting characters, deleting selections.
class EditableDocument extends StatefulWidget {
  const EditableDocument({
    Key key,
    this.document,
    @required this.editor,
    this.scrollController,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// The rich text document to be edited within this `EditableDocument`.
  ///
  /// Changing the `document` instance will clear any existing
  /// user selection and replace the entire previous document
  /// with the new one.
  final RichTextDocument document;

  /// The `editor` is responsible for performing all content
  /// manipulation operations on the supplied `document`.
  final DocumentEditor editor;

  final ScrollController scrollController;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final showDebugPaint;

  @override
  _EditableDocumentState createState() => _EditableDocumentState();
}

class _EditableDocumentState extends State<EditableDocument> with SingleTickerProviderStateMixin {
  final _dragGutterExtent = 100;
  final _maxDragSpeed = 20;

  // Holds a reference to the current `RichTextDocument` and
  // maintains a `DocumentSelection`. The `DocumentComposer`
  // is responsible for editing the `RichTextDocument` based on
  // the current `DocumentSelection`.
  DocumentComposer _documentComposer;

  // GlobalKey used to access the `DocumentLayoutState` to figure
  // out where in the document the user taps or drags.
  final _docLayoutKey = GlobalKey<DocumentLayoutState>();

  FocusNode _rootFocusNode;

  ScrollController _scrollController;

  // Tracks user drag gestures for selection purposes.
  SelectionType _selectionType = SelectionType.position;
  Offset _dragStartInViewport;
  Offset _dragStartInDoc;
  Offset _dragEndInViewport;
  Offset _dragEndInDoc;
  Rect _dragRectInViewport;

  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;
  Ticker _ticker;

  // Determines the current mouse cursor style displayed on screen.
  final _cursorStyle = ValueNotifier(SystemMouseCursors.basic);

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _ticker = createTicker(_onTick);
    _scrollController =
        _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);
  }

  @override
  void didUpdateWidget(EditableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document) {
      _createDocumentComposer();
    }
    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController.removeListener(_updateDragSelection);
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = (widget.scrollController ?? ScrollController())..addListener(_updateDragSelection);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _createDocumentComposer() {
    print('Creating the document composer');
    if (_documentComposer != null) {
      _documentComposer.selection.removeListener(_onSelectionChange);
    }
    setState(() {
      _documentComposer = DocumentComposer(
        document: widget.document,
        editor: widget.editor,
        layout: _docLayoutKey.currentState,
        keyboardActions: _composerKeyboardActions,
      );
      _documentComposer.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    });
  }

  void _onSelectionChange() {
    print('EditableDocument: _onSelectionChange()');
    setState(() {});
  }

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    print('EditableDocument: onKeyPressed()');
    _documentComposer.onKeyPressed(
      keyEvent: keyEvent,
    );

    return KeyEventResult.handled;
  }

  void _onTapDown(TapDownDetails details) {
    print('EditableDocument: onTapDown()');
    _clearSelection();
    _selectionType = SelectionType.position;

    final docOffset = _getDocOffset(details.localPosition);
    print(' - document offset: $docOffset');
    final docPosition = _docLayoutKey.currentState.getDocumentPositionAtOffset(docOffset);
    print(' - tapped document position: $docPosition');

    if (docPosition != null) {
      // Place the document selection at the location where the
      // user tapped.
      _documentComposer.selectPosition(docPosition);
    } else {
      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      _rootFocusNode.requestFocus();
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _selectionType = SelectionType.word;

    print('EditableDocument: onDoubleTap()');
    _clearSelection();

    final docOffset = _getDocOffset(details.localPosition);
    final docPosition = _docLayoutKey.currentState.getDocumentPositionAtOffset(docOffset);
    print(' - tapped document position: $docPosition');

    if (docPosition != null) {
      final didSelectWord = _documentComposer.selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayoutKey.currentState,
      );
      if (!didSelectWord) {
        // Place the document selection at the location where the
        // user tapped.
        _documentComposer.selectPosition(docPosition);
      }
    } else {
      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      _rootFocusNode.requestFocus();
    }
  }

  void _onDoubleTap() {
    _selectionType = SelectionType.position;
  }

  void _onTripleTapDown(TapDownDetails details) {
    _selectionType = SelectionType.paragraph;

    print('EditableDocument: onTripleTapDown()');
    _clearSelection();

    final docOffset = _getDocOffset(details.localPosition);
    final docPosition = _docLayoutKey.currentState.getDocumentPositionAtOffset(docOffset);
    print(' - tapped document position: $docPosition');

    if (docPosition != null) {
      final didSelectParagraph = _documentComposer.selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayoutKey.currentState,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _documentComposer.selectPosition(docPosition);
      }
    } else {
      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      _rootFocusNode.requestFocus();
    }
  }

  void _onTripleTap() {
    _selectionType = SelectionType.position;
  }

  void _onPanStart(DragStartDetails details) {
    print('_onPanStart()');
    _dragStartInViewport = details.localPosition;
    _dragStartInDoc = _getDocOffset(_dragStartInViewport);

    _clearSelection();
    _dragRectInViewport = Rect.fromLTWH(_dragStartInViewport.dx, _dragStartInViewport.dy, 1, 1);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    print('_onPanUpdate()');
    setState(() {
      _dragEndInViewport = details.localPosition;
      _dragEndInDoc = _getDocOffset(_dragEndInViewport);
      _dragRectInViewport = Rect.fromPoints(_dragStartInViewport, _dragEndInViewport);
      print(' - drag rect: $_dragRectInViewport');
      _updateCursorStyle(details.localPosition);
      _updateDragSelection();

      _scrollIfNearBoundary();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartInDoc = null;
      _dragEndInDoc = null;
      _dragRectInViewport = null;
    });

    _stopScrollingUp();
    _stopScrollingDown();
  }

  void _onPanCancel() {
    setState(() {
      _dragStartInDoc = null;
      _dragEndInDoc = null;
      _dragRectInViewport = null;
    });

    _stopScrollingUp();
    _stopScrollingDown();
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    _dragEndInDoc = _getDocOffset(_dragEndInViewport);

    _documentComposer.selectRegion(
      documentLayout: _docLayoutKey.currentState,
      baseOffset: _dragStartInDoc,
      extentOffset: _dragEndInDoc,
      selectionType: _selectionType,
    );
  }

  void _clearSelection() {
    _documentComposer.clearSelection();
  }

  void _updateCursorStyle(Offset cursorOffset) {
    final docOffset = _getDocOffset(cursorOffset);
    final desiredCursor = _docLayoutKey.currentState.getDesiredCursorAtOffset(docOffset);

    if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
      _cursorStyle.value = desiredCursor;
    } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
      _cursorStyle.value = SystemMouseCursors.basic;
    }
  }

  // Given an `offset` within this `EditableDocument`, returns that `offset`
  // in the coordinate space of the `DocumentLayout` for the rich text document.
  Offset _getDocOffset(Offset offset) {
    final docBox = _docLayoutKey.currentContext.findRenderObject() as RenderBox;
    return docBox.globalToLocal(offset, ancestor: context.findRenderObject());
  }

  // ------ scrolling -------
  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final newScrollOffset =
          (_scrollController.offset + event.scrollDelta.dy).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newScrollOffset);

      _updateDragSelection();
    }
  }

  void _scrollIfNearBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_dragEndInViewport.dy < _dragGutterExtent) {
      _startScrollingUp();
    } else {
      _stopScrollingUp();
    }
    if (editorBox.size.height - _dragEndInViewport.dy < _dragGutterExtent) {
      _startScrollingDown();
    } else {
      _stopScrollingDown();
    }
  }

  void _startScrollingUp() {
    if (_scrollUpOnTick) {
      return;
    }

    _scrollUpOnTick = true;
    _ticker.start();
  }

  void _stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    _scrollUpOnTick = false;
    _ticker.stop();
  }

  void _scrollUp() {
    if (_scrollController.offset <= 0) {
      return;
    }

    final gutterAmount = _dragEndInViewport.dy.clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    _scrollController.position.jumpTo(_scrollController.offset - scrollAmount);
  }

  void _startScrollingDown() {
    if (_scrollDownOnTick) {
      return;
    }

    _scrollDownOnTick = true;
    _ticker.start();
  }

  void _stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    _scrollDownOnTick = false;
    _ticker.stop();
  }

  void _scrollDown() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent) {
      return;
    }

    final editorBox = context.findRenderObject() as RenderBox;
    final gutterAmount = (editorBox.size.height - _dragEndInViewport.dy).clamp(0.0, _dragGutterExtent);
    final speedPercent = 1.0 - (gutterAmount / _dragGutterExtent);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    _scrollController.position.jumpTo(_scrollController.offset + scrollAmount);
  }

  void _onTick(elapsedTime) {
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_documentComposer == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _createDocumentComposer();
      });
    }

    return _buildIgnoreKeyPresses(
      child: _buildCursorStyle(
        child: _buildKeyboardAndMouseInput(
          child: SizedBox.expand(
            child: Stack(
              children: [
                _buildDocumentContainer(
                  child: ValueListenableBuilder(
                    valueListenable: _documentComposer?.selection ?? AlwaysStoppedAnimation(0),
                    builder: (context, value, child) {
                      print('Creating document layout with selection:');
                      print(' - ${_documentComposer?.selection?.value}');
                      return AnimatedBuilder(
                          animation: widget.document,
                          builder: (context, child) {
                            return DocumentLayout(
                              key: _docLayoutKey,
                              document: widget.document,
                              documentSelection: _documentComposer?.selection?.value,
                              componentBuilder: defaultComponentBuilder,
                              showDebugPaint: widget.showDebugPaint,
                            );
                          });
                    },
                  ),
                ),
                Positioned.fill(
                  child: widget.showDebugPaint ? _buildDragSelection() : SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps the `child` with a `Shortcuts` widget that ignores arrow keys,
  /// enter, backspace, and delete.
  ///
  /// This doesn't prevent the editor from responding to these keys, it just
  /// prevents Flutter from attempting to do anything with them. I put this
  /// here because I was getting recurring sounds from the Mac window as
  /// I pressed various key combinations. This hack prevents most of them.
  /// TODO: figure out the correct way to deal with this situation.
  Widget _buildIgnoreKeyPresses({
    @required Widget child,
  }) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Up arrow
        LogicalKeySet(LogicalKeyboardKey.arrowUp): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta): DoNothingIntent(),
        // Down arrow
        LogicalKeySet(LogicalKeyboardKey.arrowDown): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        // Left arrow
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        // Right arrow
        LogicalKeySet(LogicalKeyboardKey.arrowRight): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.alt): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.meta): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.meta, LogicalKeyboardKey.alt):
            DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.shift, LogicalKeyboardKey.meta):
            DoNothingIntent(),
        // Misc keys
        LogicalKeySet(LogicalKeyboardKey.enter): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.tab): DoNothingIntent(),
      },
      child: child,
    );
  }

  Widget _buildCursorStyle({
    Widget child,
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

  Widget _buildKeyboardAndMouseInput({
    Widget child,
  }) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: RawKeyboardListener(
        focusNode: _rootFocusNode,
        onKey: _onKeyPressed,
        autofocus: true,
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
          child: child,
        ),
      ),
    );
  }

  Widget _buildDocumentContainer({
    Widget child,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Spacer(),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: child,
          ),
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildDragSelection() {
    return CustomPaint(
      painter: DragRectanglePainter(
        selectionRect: _dragRectInViewport,
      ),
      size: Size.infinite,
    );
  }
}

final ComponentBuilder defaultComponentBuilder = ({
  @required BuildContext context,
  @required RichTextDocument document,
  @required DocumentNode currentNode,
  // TODO: get rid of selectedNode param
  @required DocumentNodeSelection nodeSelection,
  @required GlobalKey key,
  bool showDebugPaint = false,
}) {
  print('Building a document component for node: ${currentNode.id}');
  if (currentNode is ParagraphNode) {
    final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
        ? null
        : nodeSelection.nodeSelection as TextSelection;
    if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
      print('ERROR: Building a paragraph component but the selection is not a TextSelection: ${currentNode.id}');
    }
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;
    final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

    // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
    // if (hasCursor) {
    //   print('   - ^ has cursor');
    // }

    print(' - building a paragraph with selection:');
    print('   - base: ${textSelection?.base}');
    print('   - extent: ${textSelection?.extent}');

    if (document.getNodeIndex(currentNode) == 0 && currentNode.text.text.isEmpty && !hasCursor) {
      print(' - this is the title node');
      return TextWithHintComponent(
        documentComponentKey: key,
        text: currentNode.text,
        textType: currentNode.textType,
        hintText: 'Enter your title',
        textAlign: currentNode.textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    } else if (document.nodes.length <= 2 &&
        document.getNodeIndex(currentNode) == 1 &&
        currentNode.text.text.isEmpty &&
        !hasCursor) {
      print(' - this is the 1st paragraph node');
      return TextWithHintComponent(
        documentComponentKey: key,
        text: currentNode.text,
        textType: currentNode.textType,
        hintText: 'Enter your content...',
        textAlign: currentNode.textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    } else {
      return TextComponent(
        key: key,
        text: currentNode.text,
        textType: currentNode.textType,
        textAlign: currentNode.textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    }
  } else if (currentNode is ImageNode) {
    final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return ImageComponent(
      componentKey: key,
      imageUrl: currentNode.imageUrl,
      isSelected: isSelected,
    );
  } else if (currentNode is ListItemNode && currentNode.type == ListItemType.unordered) {
    final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

    return UnorderedListItemComponent(
      textKey: key,
      text: currentNode.text,
      indent: currentNode.indent,
      textSelection: textSelection,
      hasCursor: hasCursor,
      showDebugPaint: showDebugPaint,
    );
  } else if (currentNode is ListItemNode && currentNode.type == ListItemType.ordered) {
    int index = 1;
    DocumentNode nodeAbove = document.getNodeBefore(currentNode);
    while (nodeAbove != null &&
        nodeAbove is ListItemNode &&
        nodeAbove.type == ListItemType.ordered &&
        nodeAbove.indent >= currentNode.indent) {
      if ((nodeAbove as ListItemNode).indent == currentNode.indent) {
        index += 1;
      }
      nodeAbove = document.getNodeBefore(nodeAbove);
    }

    final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

    return OrderedListItemComponent(
      textKey: key,
      listIndex: index,
      text: currentNode.text,
      textSelection: textSelection,
      hasCursor: hasCursor,
      indent: currentNode.indent,
      showDebugPaint: showDebugPaint,
    );
  } else if (currentNode is HorizontalRuleNode) {
    final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return HorizontalRuleComponent(
      componentKey: key,
      isSelected: isSelected,
    );
  } else {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 100,
      child: Placeholder(),
    );
  }
};

final _composerKeyboardActions = <ComposerKeyboardAction>[
  ComposerKeyboardAction.simple(
    action: doNothingWhenThereIsNoSelection,
  ),
  ComposerKeyboardAction.simple(
    action: indentListItemWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: unindentListItemWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: splitListItemWhenEnterPressed,
  ),
  ComposerKeyboardAction.simple(
    action: applyBoldWhenCmdBIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: applyItalicsWhenCmdIIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: collapseSelectionWhenDirectionalKeyIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteBoxWhenBackspaceOrDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: insertCharacterInParagraph,
  ),
  ComposerKeyboardAction.simple(
    action: insertCharacterInTextComposable,
  ),
  ComposerKeyboardAction.simple(
    action: insertNewlineInParagraph,
  ),
  ComposerKeyboardAction.simple(
    action: splitParagraphWhenEnterPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteCharacterWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: mergeNodeWithPreviousWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteCharacterWhenDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: mergeNodeWithNextWhenDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: moveUpDownLeftAndRightWithArrowKeys,
  ),
];

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
    Listenable repaint,
  }) : super(repaint: repaint);

  final Rect selectionRect;
  final Paint _selectionPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      print('Painting drag rect: $selectionRect');
      canvas.drawRect(selectionRect, _selectionPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
