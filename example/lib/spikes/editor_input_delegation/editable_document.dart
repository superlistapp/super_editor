import 'package:example/spikes/editor_input_delegation/composition/document_composer.dart';
import 'package:example/spikes/editor_input_delegation/document/rich_text_document.dart';
import 'package:example/spikes/editor_input_delegation/layout/document_layout.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'selection/editor_selection.dart';

/// A user-editable rich text document.
///
/// An `EditableDocument` brings together the key pieces needed
/// to display a user-editable rich text document:
///  * document model
///  * document layout
///  * document interaction (tapping, dragging, typing)
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
///
/// An `EditableDocument` displays the entire document, and therefore
/// it does not handle any scrolling concerns. That responsibility
/// is left to the parent of an `EditableDocument`.
class EditableDocument extends StatefulWidget {
  const EditableDocument({
    Key key,
    this.document,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Changing the `document` instance will clear any existing
  /// user selection and replace the entire previous document
  /// with the new one.
  final RichTextDocument document;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final showDebugPaint;

  @override
  _EditableDocumentState createState() => _EditableDocumentState();
}

class _EditableDocumentState extends State<EditableDocument> {
  // Holds a reference to the current `RichTextDocument` and
  // maintains a `DocumentSelection`. The `DocumentComposer`
  // is responsible for editing the `RichTextDocument` based on
  // the current `DocumentSelection`.
  final DocumentComposer _documentComposer = DocumentComposer();

  // GlobalKey used to access the `DocumentLayoutState` to figure
  // out where in the document the user taps or drags.
  final _docLayoutKey = GlobalKey<DocumentLayoutState>();

  FocusNode _rootFocusNode;

  // Tracks user drag gestures for selection purposes.
  Offset _dragStart;
  Offset _dragEnd;
  Rect _dragRect;

  // Determines the current mouse cursor style displayed on screen.
  final _cursorStyle = ValueNotifier(SystemMouseCursors.basic);

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _documentComposer.document = widget.document;
  }

  @override
  void didUpdateWidget(EditableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document) {
      _documentComposer.selection = null;
      _documentComposer.document = widget.document;
    }
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    print('EditableDocument: onKeyPressed()');
    _documentComposer.onKeyPressed(
      keyEvent: keyEvent,
      documentLayout: _docLayoutKey.currentState,
    );

    return KeyEventResult.handled;
  }

  void _onTapDown(TapDownDetails details) {
    print('EditableDocument: onTapDown()');
    _clearSelection();

    final docOffset = _getDocOffset(details.localPosition);
    final docPosition = _docLayoutKey.currentState.getDocumentPositionAtOffset(docOffset);
    print(' - tapped document position: $docPosition');

    if (docPosition != null) {
      // Place the document selection at the location where the
      // user tapped.
      _documentComposer.selection = DocumentSelection.collapsed(
        position: docPosition,
      );
    } else {
      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      _rootFocusNode.requestFocus();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;

    _clearSelection();
    _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragEnd = details.localPosition;
      _dragRect = Rect.fromPoints(_dragStart, details.localPosition);
      _updateCursorStyle(details.localPosition);
      _updateDragSelection();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragRect = null;
    });
  }

  void _onPanCancel() {
    setState(() {
      _dragRect = null;
    });
  }

  void _clearSelection() {
    _documentComposer.selection = null;
  }

  void _updateDragSelection() {
    final docStartDrag = _getDocOffset(_dragStart);
    final docEndDrag = _getDocOffset(_dragEnd);

    final docSelection = _docLayoutKey.currentState.getDocumentSelectionInRegion(docStartDrag, docEndDrag);
    print('Drag document selection: $docSelection');

    _documentComposer.selection = docSelection;
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
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

  @override
  Widget build(BuildContext context) {
    return _buildIgnoreKeyPresses(
      child: _buildCursorStyle(
        child: _buildKeyboardAndMouseInput(
          child: Stack(
            children: [
              _buildDocumentContainer(
                child: AnimatedBuilder(
                  animation: _documentComposer,
                  builder: (context, child) {
                    return DocumentLayout(
                      key: _docLayoutKey,
                      document: _documentComposer.document,
                      documentSelection: _documentComposer.nodeSelections,
                      showDebugPaint: widget.showDebugPaint,
                    );
                  },
                ),
              ),
              if (widget.showDebugPaint) _buildDragSelection(),
            ],
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
        LogicalKeySet(LogicalKeyboardKey.enter): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): DoNothingIntent(),
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
    return RawKeyboardListener(
      focusNode: _rootFocusNode,
      onKey: _onKeyPressed,
      autofocus: true,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        behavior: HitTestBehavior.translucent,
        child: child,
      ),
    );
  }

  Widget _buildDocumentContainer({
    Widget child,
  }) {
    return Row(
      children: [
        Spacer(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: child,
        ),
        Spacer(),
      ],
    );
  }

  Widget _buildDragSelection() {
    return Positioned.fill(
      child: CustomPaint(
        painter: DragRectanglePainter(
          selectionRect: _dragRect,
        ),
        size: Size.infinite,
      ),
    );
  }
}

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
      canvas.drawRect(selectionRect, _selectionPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
