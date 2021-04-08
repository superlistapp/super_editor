import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '_doc_model.dart';

/// A set of widgets that correspond to the various `DocumentContent`s
/// defined within the document model.
///
/// This approach explores what it might look like to have a widget
/// that corresponds per semantic model node. Another approach to
/// widget breakdowns might be to define widgets based on editor
/// capabilities:
///  - selectable
///  - composable
///  - repositionable
///  - etc.
/// Or, the ideal use of widgets might be something else, entirely.

/// Behaviors that every editor widget is expected to implement.
abstract class EditorComponent {
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  });
  void onDragSelectionEnd();

  void clearContentSelection() {}
}

/// The title at the top of a document.
class EditorTitleComponent extends StatefulWidget {
  const EditorTitleComponent({
    Key key,
    @required this.title,
  }) : super(key: key);

  final DocumentTitle title;

  @override
  _EditorTitleComponentState createState() => _EditorTitleComponentState();
}

class _EditorTitleComponentState extends State<EditorTitleComponent> with EditorComponent {
  final GlobalKey<_EditorTextState> _editorTextKey = GlobalKey();
  TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.title.text);
  }

  @override
  void didUpdateWidget(EditorTitleComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO:
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  }) {
    _editorTextKey.currentState.onDragSelectionChange(
      dragBounds: dragBounds,
      renderEditor: renderEditor,
    );
  }

  @override
  void onDragSelectionEnd() {
    _editorTextKey.currentState.onDragSelectionEnd();
  }

  void clearContentSelection() {
    _editorTextKey.currentState.clearContentSelection();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorText(
      key: _editorTextKey,
      textController: _textController,
      text: widget.title.text,
      style: TextStyle(
        fontSize: 28,
        color: const Color(0xFF222222),
        height: 1.4,
      ),
    );
  }
}

/// Any given paragraph within a document.
class EditorParagraphComponent extends StatefulWidget {
  const EditorParagraphComponent({
    Key key,
    @required this.paragraph,
  }) : super(key: key);

  final DocumentParagraph paragraph;

  @override
  _EditorParagraphComponentState createState() => _EditorParagraphComponentState();
}

class _EditorParagraphComponentState extends State<EditorParagraphComponent> with EditorComponent {
  final GlobalKey<_EditorTextState> _editorTextKey = GlobalKey();
  TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.paragraph.text);
  }

  @override
  void didUpdateWidget(EditorParagraphComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO:
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  }) {
    _editorTextKey.currentState.onDragSelectionChange(
      dragBounds: dragBounds,
      renderEditor: renderEditor,
    );
  }

  @override
  void onDragSelectionEnd() {
    _editorTextKey.currentState.onDragSelectionEnd();
  }

  void clearContentSelection() {
    _editorTextKey.currentState.clearContentSelection();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorText(
      key: _editorTextKey,
      textController: _textController,
      text: widget.paragraph.text,
      style: TextStyle(
        fontSize: 18,
        color: Colors.black,
        height: 1.4,
      ),
    );
  }
}

/// Any given list item within a document.
class EditorListItemComponent extends StatefulWidget {
  const EditorListItemComponent({
    Key key,
    @required this.listItem,
  }) : super(key: key);

  final DocumentListItem listItem;

  @override
  _EditorListItemComponentState createState() => _EditorListItemComponentState();
}

class _EditorListItemComponentState extends State<EditorListItemComponent> with EditorComponent {
  final GlobalKey<_EditorTextState> _editorTextKey = GlobalKey();
  TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.listItem.text);
  }

  @override
  void didUpdateWidget(EditorListItemComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO:
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  }) {
    _editorTextKey.currentState.onDragSelectionChange(
      dragBounds: dragBounds,
      renderEditor: renderEditor,
    );
  }

  @override
  void onDragSelectionEnd() {
    _editorTextKey.currentState.onDragSelectionEnd();
  }

  void clearContentSelection() {
    _editorTextKey.currentState.clearContentSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ),
        ),
        Expanded(
          child: _EditorText(
            key: _editorTextKey,
            textController: _textController,
            text: widget.listItem.text,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Any given horizontal rule within a document.
class EditorHorizontalRuleComponent extends StatefulWidget {
  const EditorHorizontalRuleComponent({
    Key key,
  }) : super(key: key);

  @override
  _EditorHorizontalRuleComponentState createState() => _EditorHorizontalRuleComponentState();
}

class _EditorHorizontalRuleComponentState extends State<EditorHorizontalRuleComponent> with EditorComponent {
  bool _isSelected = false;

  @override
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  }) {
    setState(() {
      _isSelected = true;
    });
  }

  @override
  void onDragSelectionEnd() {
    setState(() {
      _isSelected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SelectionOutline(
      isSelected: _isSelected,
      child: Container(
        width: double.infinity,
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.grey,
      ),
    );
  }
}

/// Behaviors required by all editable text in a document, e.g.,
/// title, paragraph, list item.
class _EditorText extends StatefulWidget {
  const _EditorText({
    Key key,
    @required this.textController,
    this.text = '',
    this.style,
  }) : super(key: key);

  final TextEditingController textController;
  final String text;
  final TextStyle style;

  @override
  _EditorTextState createState() => _EditorTextState();
}

class _EditorTextState extends State<_EditorText> implements EditorComponent {
  FocusNode _focusNode;
  bool _isSelected = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_EditorText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO:
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void onDragSelectionChange({
    @required Rect dragBounds,
    @required RenderBox renderEditor,
  }) {
    setState(() {
      _isSelected = true;
    });

    final renderBox = context.findRenderObject() as RenderBox;
    final renderEditable = _findRenderEditableChild(renderBox);
    // print('RenderEditable: $renderEditable');
    if (renderEditable != null) {
      final textTopLeftInEditor = renderEditable.localToGlobal(Offset.zero, ancestor: renderEditor);
      final dragStartsAboveText = dragBounds.topLeft.dy < textTopLeftInEditor.dy;
      final globalStartPosition = renderEditor.localToGlobal(dragBounds.topLeft);
      final startPosition =
          dragStartsAboveText ? TextPosition(offset: 0) : renderEditable.getPositionForPoint(globalStartPosition);
      // print('Start position: $startPosition');

      final textBottomRightInEditor =
          renderEditable.localToGlobal(renderEditable.size.bottomRight(Offset.zero), ancestor: renderEditor);
      final dragEndsBelowText = dragBounds.bottomRight.dy > textBottomRightInEditor.dy;
      final globalEndPosition = renderEditor.localToGlobal(dragBounds.bottomRight);
      final endPosition = dragEndsBelowText
          ? TextPosition(offset: renderEditable.text.text.length)
          : renderEditable.getPositionForPoint(globalEndPosition);
      // print('End position: $endPosition');

      // final selectedText = renderEditable.text.text.substring(startPosition.offset, endPosition.offset);
      // print('Selected text: "$selectedText"');

      widget.textController.selection =
          TextSelection(baseOffset: startPosition.offset, extentOffset: endPosition.offset);
      renderEditable.selectionColor = Colors.green;
      // print(
      //     'Selection: ${renderEditable.selection}, start: ${renderEditable.selection.start}, end: ${renderEditable.selection.end}');
    }
  }

  RenderEditable _findRenderEditableChild(RenderObject searchRoot) {
    RenderEditable renderEditable;

    void Function(RenderObject) visitCallback;
    visitCallback = (child) {
      if (child is! RenderEditable) {
        child.visitChildren(visitCallback);
      } else {
        renderEditable = child;
        // print(' -- Found RenderEditable: $child');
      }
    };
    searchRoot.visitChildren(visitCallback);

    // print(' -- Returning renderEditable: $renderEditable');
    return renderEditable;
  }

  @override
  void onDragSelectionEnd() {
    setState(() {
      _isSelected = false;
    });
  }

  void clearContentSelection() {
    // print('Clearing paragraph selection: $this');
    widget.textController.selection = TextSelection.collapsed(offset: -1);
  }

  @override
  Widget build(BuildContext context) {
    return _SelectionOutline(
      isSelected: _isSelected,
      child: EditableText(
        controller: widget.textController,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        style: widget.style ?? Theme.of(context).textTheme.bodyText1,
        cursorColor: Colors.black,
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.lightGreenAccent,
        rendererIgnoresPointer: true,
      ),
    );
  }
}

class _SelectionOutline extends StatelessWidget {
  const _SelectionOutline({
    Key key,
    this.isSelected,
    this.child,
  }) : super(key: key);

  final bool isSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
