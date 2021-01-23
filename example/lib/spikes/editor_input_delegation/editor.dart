import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'editor_paragraph.dart';

const _loremIpsum1 =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
const _loremIpsum2 =
    'Nullam id elementum felis. Morbi ullamcorper gravida vulputate. Nulla sed gravida lorem. Nam tincidunt, arcu sit amet sodales aliquet, lectus magna volutpat felis, non pharetra risus risus dignissim mauris. Fusce diam massa, semper eu elementum in, dictum vel nulla. Etiam porta luctus augue, porttitor porta nibh. Donec risus arcu, viverra sed tincidunt id, lobortis non nulla. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean vel lobortis quam, ac pulvinar risus. Praesent laoreet tempor ex. Nunc eu ante nisl. Integer in magna ligula.';
const _loremIpsum3 =
    'Phasellus non gravida arcu. Pellentesque posuere orci et lorem fermentum, sed interdum metus vestibulum. Maecenas suscipit mollis sagittis. Mauris quis est blandit libero vehicula fringilla eget in augue. Etiam mi lectus, ullamcorper ac odio nec, maximus ultricies enim. Aenean nec est non nunc tincidunt rhoncus. Proin laoreet vitae libero ut faucibus. Donec bibendum laoreet dolor eu varius. Pellentesque ullamcorper turpis quis viverra semper.';

class Editor extends StatefulWidget {
  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  FocusNode _rootFocusNode;
  bool _hasFocus = false;

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

  TextEditingController _paragraph1Controller;
  TextEditingController _paragraph2Controller;
  TextEditingController _paragraph3Controller;

  EditorController _editorController;

  Offset _dragStart;
  Rect _dragRect;

  MouseCursor _cursorStyle = SystemMouseCursors.basic;

  EditorSelection _editorSelection = EditorSelection();
  DocDisplayNode _nodeWithCursor;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode()
      ..addListener(_onFocusChange)
      ..requestFocus();

    _paragraph1Controller = TextEditingController(text: _loremIpsum1);
    _paragraph2Controller = TextEditingController(text: _loremIpsum2);
    _paragraph3Controller = TextEditingController(text: _loremIpsum3);
    _editorController = EditorController();
  }

  @override
  void dispose() {
    _editorController.dispose();
    _paragraph1Controller.dispose();
    _paragraph2Controller.dispose();
    _paragraph3Controller.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    print('_onFocusChange(), hasFocus: ${_rootFocusNode.hasFocus}');
    if (_rootFocusNode.hasFocus && !_hasFocus) {
      _hasFocus = true;
      RawKeyboard.instance.addListener(_onKeyPressed);
    } else if (!_rootFocusNode.hasFocus) {
      _hasFocus = false;
      RawKeyboard.instance.removeListener(_onKeyPressed);
    }
  }

  void _onKeyPressed(RawKeyEvent event) {
    print('Key pressed');

    // if (_editorController.selectedComponentKey != null) {
    //   print('Forwarding key event to: ${_editorController.selectedComponentKey}');
    //   final wasHandled = _editorController.selectedComponentKey.currentState.onKeyPressed(event);
    //
    //   if (!wasHandled) {
    //     print('Key was not handled');
    //     print('Is down event? ${event is RawKeyDownEvent}: $event');
    //     if (event.logicalKey == LogicalKeyboardKey.arrowDown && event is RawKeyDownEvent) {
    //       final currentComponentIndex = _docKeys.indexOf(_editorController.selectedComponentKey);
    //       if (currentComponentIndex < _docKeys.length - 1) {
    //         _docKeys[currentComponentIndex + 1].currentState.acceptSelection(true);
    //       }
    //     } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && event is RawKeyDownEvent) {
    //       final currentComponentIndex = _docKeys.indexOf(_editorController.selectedComponentKey);
    //       if (currentComponentIndex > 0) {
    //         _docKeys[currentComponentIndex - 1].currentState.acceptSelection(false);
    //       }
    //     }
    //   }
    // }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      for (final displayNode in _displayNodes) {
        displayNode.selection = null;
      }

      bool nodeTapped = false;
      for (final displayNode in _displayNodes) {
        final editorComponent = displayNode.key.currentState as EditorParagraphState;
        if (_cursorIntersects(editorComponent, details.localPosition)) {
          final componentOffset = _localCursorOffset(editorComponent, details.localPosition);
          final selection = editorComponent.getSelectionAtOffset(componentOffset);
          displayNode.selection = selection;

          _nodeWithCursor = displayNode;

          nodeTapped = true;
        }
      }

      // The user tapped in an area of the editor where there is no content node.
      // Give focus back to the root of the editor.
      if (!nodeTapped) {
        _rootFocusNode.requestFocus();
        _nodeWithCursor = null;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    setState(() {
      _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragRect = Rect.fromPoints(_dragStart, details.localPosition);
    _updateCursor(details.localPosition);
    _updateDragSelection();

    setState(() {
      // empty because the drag rect update needs to happen before
      // update selection.
    });
    //
    // // Forward this message on to the method that determines the
    // // desired cursor style.
    // _configureMouseStyle(details.localPosition);
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

  void _updateDragSelection() {
    DocDisplayNode firstSelectedNode;
    DocDisplayNode lastSelectedNode;

    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    final isDraggingDown = _dragStart.dy < _dragRect.bottom;

    for (final displayNode in _displayNodes) {
      final editorComponent = displayNode.key.currentState as EditorParagraphState;

      final dragIntersection = _getDragIntersectionWith(editorComponent);
      if (dragIntersection != null) {
        print('Drag intersects: ${displayNode.key}');
        final selection = editorComponent.getSelectionInRect(dragIntersection, isDraggingDown);
        print('Drag selection: $selection');
        print('');
        displayNode.selection = selection;

        if (firstSelectedNode == null) {
          firstSelectedNode = displayNode;
        }
        lastSelectedNode = displayNode;
      } else {
        editorComponent.clearSelection();
      }
    }

    _editorSelection.clear();
    if (firstSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.baseOffsetKey = firstSelectedNode.key;
        _editorSelection.baseOffsetSelection = firstSelectedNode.selection;
      } else {
        _editorSelection.extentOffsetKey = firstSelectedNode.key;
        _editorSelection.extentOffsetSelection = firstSelectedNode.selection;
      }
    }
    if (lastSelectedNode != null) {
      if (isDraggingDown) {
        _editorSelection.extentOffsetKey = lastSelectedNode.key;
        _editorSelection.extentOffsetSelection = lastSelectedNode.selection;
      } else {
        _editorSelection.baseOffsetKey = lastSelectedNode.key;
        _editorSelection.baseOffsetSelection = lastSelectedNode.selection;
      }
    }

    _nodeWithCursor = isDraggingDown ? lastSelectedNode : firstSelectedNode;

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
    _updateCursor(pointerEvent.localPosition);
  }

  void _updateCursor(Offset cursorOffset) {
    for (final displayNode in _displayNodes) {
      final editorComponent = displayNode.key.currentState as EditorParagraphState;

      if (_cursorIntersects(editorComponent, cursorOffset)) {
        final localCursorOffset = _localCursorOffset(editorComponent, cursorOffset);
        final desiredCursor = editorComponent.cursorForOffset(localCursorOffset);
        if (desiredCursor != null && desiredCursor != _cursorStyle) {
          setState(() {
            _cursorStyle = desiredCursor;
          });
        } else if (desiredCursor == null && _cursorStyle != SystemMouseCursors.basic) {
          setState(() {
            _cursorStyle = SystemMouseCursors.basic;
          });
        }

        // The cursor can't intersect multiple components, so
        // there is nothing more for us to do. Return.
        return;
      }
    }

    setState(() {
      _cursorStyle = SystemMouseCursors.basic;
    });
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
    @required List<Widget> editorComponents,
  }) {
    return Listener(
      onPointerHover: _onMouseMove,
      child: MouseRegion(
        cursor: _cursorStyle,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          behavior: HitTestBehavior.translucent,
          child: Focus(
            focusNode: _rootFocusNode,
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1000),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: editorComponents,
                    ),
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

  List<Widget> _buildContentComponents(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF312F2C),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );

    return [
      for (final displayNode in _displayNodes) ...[
        EditorParagraph(
          key: displayNode.key,
          text: displayNode.paragraph,
          textSelection: displayNode.selection,
          style: textStyle,
          hasCursor: displayNode == _nodeWithCursor,
        ),
        SizedBox(height: 16),
      ],
    ];
  }
}

class EditorController with ChangeNotifier {
  GlobalKey<EditorParagraphState> _selectedComponentKey;
  GlobalKey<EditorParagraphState> get selectedComponentKey => _selectedComponentKey;

  TextEditingController _activeTextController;
  TextEditingController get activeTextController => _activeTextController;

  void setSelection({
    @required GlobalKey<EditorParagraphState> newComponentKey,
    @required TextEditingController newTextController,
  }) {
    print('Setting selected component key to: ${newComponentKey}');
    if (_selectedComponentKey != null && newComponentKey != _selectedComponentKey) {
      print('Clearing selection from $_selectedComponentKey');
      _selectedComponentKey.currentState.clearSelection();
    }

    _selectedComponentKey = newComponentKey;
    _activeTextController = newTextController;
    print('Selected component key is now: $selectedComponentKey');
    notifyListeners();
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

class DocDisplayNode {
  DocDisplayNode({
    @required this.key,
    @required this.paragraph,
  });

  final GlobalKey key;
  final String paragraph;
  dynamic selection;
}

class EditorSelection {
  EditorSelection({
    this.baseOffsetKey,
    this.baseOffsetSelection,
    this.extentOffsetKey,
    this.extentOffsetSelection,
  });

  GlobalKey baseOffsetKey;
  dynamic baseOffsetSelection;

  GlobalKey extentOffsetKey;
  dynamic extentOffsetSelection;

  void clear() {
    baseOffsetKey = null;
    baseOffsetSelection = null;
    extentOffsetKey = null;
    extentOffsetSelection = null;
  }
}
