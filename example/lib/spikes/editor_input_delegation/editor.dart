import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'editor_layout_model.dart';
import 'editor_selection.dart';
import 'paragraph/editor_paragraph.dart';
import 'paragraph/editor_paragraph_component.dart';

const _loremIpsum1 =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
const _loremIpsum2 =
    'Nullam id elementum felis. Morbi ullamcorper gravida vulputate. Nulla sed gravida lorem. Nam tincidunt, arcu sit amet sodales aliquet, lectus magna volutpat felis, non pharetra risus risus dignissim mauris. Fusce diam massa, semper eu elementum in, dictum vel nulla. Etiam porta luctus augue, porttitor porta nibh. Donec risus arcu, viverra sed tincidunt id, lobortis non nulla. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean vel lobortis quam, ac pulvinar risus. Praesent laoreet tempor ex. Nunc eu ante nisl. Integer in magna ligula.';
const _loremIpsum3 =
    'Phasellus non gravida arcu. Pellentesque posuere orci et lorem fermentum, sed interdum metus vestibulum. Maecenas suscipit mollis sagittis. Mauris quis est blandit libero vehicula fringilla eget in augue. Etiam mi lectus, ullamcorper ac odio nec, maximus ultricies enim. Aenean nec est non nunc tincidunt rhoncus. Proin laoreet vitae libero ut faucibus. Donec bibendum laoreet dolor eu varius. Pellentesque ullamcorper turpis quis viverra semper.';

class Editor extends StatefulWidget {
  const Editor({
    Key key,
    this.showDebugPaint = false,
  }) : super(key: key);

  final showDebugPaint;

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  FocusNode _rootFocusNode;

  final _displayNodes = <DocDisplayNode>[
    DocDisplayNode(
      key: GlobalKey(debugLabel: 'paragraph1'),
      paragraph: _loremIpsum1,
    ),
    DocDisplayNode(
      key: GlobalKey(debugLabel: 'paragraph2'),
      paragraph: _loremIpsum2,
    ),
    DocDisplayNode(
      key: GlobalKey(debugLabel: 'paragraph3'),
      paragraph: _loremIpsum3,
    ),
  ];

  Offset _dragStart;
  Rect _dragRect;

  final _cursorStyle = ValueNotifier(SystemMouseCursors.basic);

  EditorSelection _editorSelection;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();

    _editorSelection = EditorSelection(
      displayNodes: _displayNodes,
    );
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyPressed(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      return KeyEventResult.handled;
    }

    print('Key pressed');

    if (_editorSelection.nodeWithCursor == null) {
      print(' - no node with cursor. Returning.');
      return KeyEventResult.handled;
    }

    final isDirectionalKey = keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowUp ||
        keyEvent.logicalKey == LogicalKeyboardKey.arrowDown;
    print(' - is directional key? $isDirectionalKey');
    print(' - is editor selection collapsed? ${_editorSelection.isCollapsed}');
    print(' - is shift pressed? ${keyEvent.isShiftPressed}');
    if (isDirectionalKey && !_editorSelection.isCollapsed && !keyEvent.isShiftPressed && !keyEvent.isMetaPressed) {
      print('Collapsing editor selection, then returning.');
      _editorSelection.collapse();
      return KeyEventResult.handled;
    }

    // Handle delete and backspace for a selection.
    // TODO: add all characters to this condition.
    final isDestructiveKey =
        keyEvent.logicalKey == LogicalKeyboardKey.backspace || keyEvent.logicalKey == LogicalKeyboardKey.delete;
    final shouldDeleteSelection = isDestructiveKey;
    if (!_editorSelection.isCollapsed && shouldDeleteSelection) {
      _editorSelection.deleteSelection();

      if (isDestructiveKey) {
        // Destructive keys only want deletion. The deletion is done.
        // Return.
        return KeyEventResult.handled;
      }
    }

    // Delegate key processing to the component with the cursor.
    final componentWithCursor = (_editorSelection.nodeWithCursor?.key?.currentState);
    if (componentWithCursor != null) {
      print('Delegating key press');
      (componentWithCursor as EditorComponent).onKeyPressed(
        keyEvent: keyEvent,
        editorSelection: _editorSelection,
        currentComponentSelection: _editorSelection.nodeWithCursor.selection,
      );
    }

    return KeyEventResult.handled;
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _clearSelection();

      bool nodeTapped = false;
      for (final displayNode in _editorSelection.displayNodes) {
        final editorComponent = displayNode.key.currentState as EditorParagraphState;
        if (_cursorIntersects(editorComponent, details.localPosition)) {
          final componentOffset = _localCursorOffset(editorComponent, details.localPosition);
          final selection = editorComponent.getSelectionAtOffset(componentOffset);
          displayNode.selection = selection;

          _editorSelection.baseOffsetNode = displayNode;
          _editorSelection.extentOffsetNode = displayNode;
          _editorSelection.nodeWithCursor = displayNode;

          nodeTapped = true;
        }
      }

      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      if (!nodeTapped) {
        _rootFocusNode.requestFocus();
        _editorSelection.nodeWithCursor = null;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    setState(() {
      _clearSelection();
      _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragRect = Rect.fromPoints(_dragStart, details.localPosition);
    _updateCursorStyle(details.localPosition);
    _updateDragSelection();

    setState(() {
      // empty because the drag rect update needs to happen before
      // update selection.
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
    for (final displayNode in _editorSelection.displayNodes) {
      displayNode.selection = null;
    }
  }

  void _updateDragSelection() {
    DocDisplayNode firstSelectedNode;
    DocDisplayNode lastSelectedNode;

    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    final isDraggingDown = _dragStart.dy < _dragRect.bottom;

    for (final displayNode in _editorSelection.displayNodes) {
      final editorComponent = displayNode.key.currentState as EditorComponent;

      final dragIntersection = _getDragIntersectionWith(editorComponent);
      if (dragIntersection != null) {
        print('Drag intersects: ${displayNode.key}');
        print('Intersection: $dragIntersection');
        final selection = editorComponent.getSelectionInRect(dragIntersection, isDraggingDown);
        print('Drag selection: ${selection.componentSelection}');
        print('');
        displayNode.selection = selection;

        if (firstSelectedNode == null) {
          firstSelectedNode = displayNode;
        }
        lastSelectedNode = displayNode;
      }
    }

    // _editorSelection.clear();
    if (firstSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.baseOffsetNode = firstSelectedNode;
      } else {
        _editorSelection.extentOffsetNode = firstSelectedNode;
      }
    }
    if (lastSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.extentOffsetNode = lastSelectedNode;
      } else {
        _editorSelection.baseOffsetNode = lastSelectedNode;
      }
    }
    print('Base node: ${_editorSelection.baseOffsetNode.key}');
    print('Base selection: ${_editorSelection.baseOffsetNode.selection.componentSelection}');
    print('Extent node: ${_editorSelection.extentOffsetNode.key}');
    print('Extent selection: ${_editorSelection.extentOffsetNode.selection.componentSelection}');

    _editorSelection.nodeWithCursor = isDraggingDown ? lastSelectedNode : firstSelectedNode;

    // TODO: is there a more appropriate place to setState()?
    setState(() {});
  }

  Rect _getDragIntersectionWith(EditorParagraphState editorComponent) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentBox = editorComponent.context.findRenderObject() as RenderBox;
    final contentOffset = contentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & contentBox.size;

    if (_dragRect.overlaps(contentRect)) {
      // Report the drag rectangle based at (0, 0) so that the
      // editor component can treat it as local coords.
      return _dragRect.translate(-contentOffset.dx, -contentOffset.dy);
    } else {
      return null;
    }
  }

  void _onMouseMove(PointerEvent pointerEvent) {
    _updateCursorStyle(pointerEvent.localPosition);
  }

  void _updateCursorStyle(Offset cursorOffset) {
    for (final displayNode in _editorSelection.displayNodes) {
      final editorComponent = displayNode.key.currentState as EditorParagraphState;

      if (_cursorIntersects(editorComponent, cursorOffset)) {
        final localCursorOffset = _localCursorOffset(editorComponent, cursorOffset);
        final desiredCursor = editorComponent.getCursorForOffset(localCursorOffset);
        if (desiredCursor != null && desiredCursor != _cursorStyle.value) {
          _cursorStyle.value = desiredCursor;
        } else if (desiredCursor == null && _cursorStyle.value != SystemMouseCursors.basic) {
          _cursorStyle.value = SystemMouseCursors.basic;
        }

        // The cursor can't intersect multiple components, so
        // there is nothing more for us to do. Return.
        return;
      }
    }

    _cursorStyle.value = SystemMouseCursors.basic;
  }

  bool _cursorIntersects(EditorParagraphState editorComponent, Offset cursorOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentBox = editorComponent.context.findRenderObject() as RenderBox;
    final contentOffset = contentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & contentBox.size;

    return contentRect.contains(cursorOffset);
  }

  Offset _localCursorOffset(EditorParagraphState editorComponent, Offset cursorOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentBox = editorComponent.context.findRenderObject() as RenderBox;
    final contentOffset = contentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & contentBox.size;

    return cursorOffset - contentRect.topLeft;
  }

  @override
  Widget build(BuildContext context) {
    return _buildEditorChrome(
      context: context,
      editorComponents: _buildContentComponents(context),
    );
  }

  Widget _buildEditorChrome({
    @required BuildContext context,
    @required Widget editorComponents,
  }) {
    print('Show debug paint? ${widget.showDebugPaint}');
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
      child: _buildCursorStyle(
        child: RawKeyboardListener(
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
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1000),
                    child: editorComponents,
                  ),
                ),
                _buildDragSelection(),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildContentComponents(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF312F2C),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );

    return AnimatedBuilder(
        animation: _editorSelection,
        builder: (context, child) {
          print('Building editor components:');
          for (final displayNode in _editorSelection.displayNodes) {
            print(' - ${displayNode.key}: ${displayNode.selection?.componentSelection}');
            if (displayNode == _editorSelection.nodeWithCursor) {
              print('   - ^ has cursor');
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final displayNode in _editorSelection.displayNodes) ...[
                EditorParagraph(
                  key: displayNode.key,
                  text: displayNode.paragraph,
                  textSelection: (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection,
                  style: textStyle,
                  hasCursor: displayNode == _editorSelection.nodeWithCursor,
                  highlightWhenEmpty: !_editorSelection.isCollapsed &&
                      (displayNode.selection as ParagraphEditorComponentSelection)?.componentSelection != null,
                  showDebugPaint: widget.showDebugPaint,
                ),
                SizedBox(height: 16),
              ],
            ],
          );
        });
  }
}

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
  });

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
