import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SelectableText extends StatefulWidget {
  const SelectableText({
    @required Key key,
    this.text,
    this.textSelection,
    this.hasCursor = false,
    this.style,
  }) : super(key: key);

  final String text;
  final TextSelection textSelection;
  final bool hasCursor;
  final TextStyle style;

  @override
  SelectableTextState createState() => SelectableTextState();
}

class SelectableTextState extends State<SelectableText> {
  final GlobalKey _textKey = GlobalKey();

  RenderParagraph get renderParagraph => _textKey.currentContext?.findRenderObject() as RenderParagraph;

  TextSelection getSelectionAtOffset(Offset localOffset) {
    return TextSelection.collapsed(
      offset: renderParagraph.getPositionForOffset(localOffset).offset,
    );
  }

  TextSelection getSelectionInRect(Rect selectionArea, bool isDraggingDown) {
    int startOffset =
        selectionArea.topLeft.dy < 0 ? 0 : renderParagraph.getPositionForOffset(selectionArea.topLeft).offset;
    int endOffset = selectionArea.bottomRight.dy > renderParagraph.size.height
        ? widget.text.length
        : renderParagraph.getPositionForOffset(selectionArea.bottomRight).offset;

    final selection = TextSelection(
      baseOffset: isDraggingDown ? startOffset : endOffset,
      extentOffset: isDraggingDown ? endOffset : startOffset,
    );

    return selection;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: TextSelectionPainter(
            paragraph: renderParagraph,
            selection: widget.textSelection,
          ),
        ),
        Text(
          widget.text,
          key: _textKey,
          style: widget.style ?? Theme.of(context).textTheme.bodyText1,
        ),
        CustomPaint(
          painter: CursorPainter(
            paragraph: renderParagraph,
            cursorOffset: widget.textSelection.extentOffset,
            lineHeight: widget.style.fontSize * widget.style.height,
            caretHeight: (widget.style.fontSize * widget.style.height) * 0.8,
            isTextEmpty: widget.text == null || widget.text.isEmpty,
            showCursor: widget.hasCursor,
          ),
        ),
      ],
    );
  }
}

class TextSelectionPainter extends CustomPainter {
  TextSelectionPainter({
    @required this.paragraph,
    @required this.selection,
  });

  final RenderParagraph paragraph;
  final TextSelection selection;
  final Paint selectionPaint = Paint()..color = Colors.lightGreenAccent;

  @override
  void paint(Canvas canvas, Size size) {
    if (paragraph == null || selection == null || selection.baseOffset == selection.extentOffset) {
      return;
    }

    final selectionBoxes = paragraph.getBoxesForSelection(selection);

    for (final box in selectionBoxes) {
      final rect = box.toRect();
      canvas.drawRect(
        // Note: If the rect has no width then we've selected an empty line. Give
        //       that line a slight width for visibility.
        rect.width > 0 ? rect : Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
        selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TextSelectionPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph || selection != oldDelegate.selection;
  }
}

class CursorPainter extends CustomPainter {
  CursorPainter({
    @required this.paragraph,
    @required this.cursorOffset,
    @required this.caretHeight,
    @required this.lineHeight,
    @required this.isTextEmpty,
    @required this.showCursor,
  });

  final RenderParagraph paragraph;
  final int cursorOffset;
  final double caretHeight; // TODO: find a way to get this from the TextPainter, which is the correct place to get it.
  final double lineHeight; // TODO: this should probably also come from the TextPainter.
  final bool isTextEmpty;
  final bool showCursor;
  final Paint cursorPaint = Paint()..color = Colors.black54;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showCursor || paragraph == null || cursorOffset == null) {
      return;
    }

    final caretOffset = isTextEmpty
        ? paragraph.getOffsetForCaret(TextPosition(offset: cursorOffset), Rect.zero)
        : Offset(0, (lineHeight - caretHeight) / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        caretOffset.dx.roundToDouble(),
        caretOffset.dy.roundToDouble(),
        1,
        caretHeight.roundToDouble(),
      ),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(CursorPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph ||
        cursorOffset != oldDelegate.cursorOffset ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        showCursor != oldDelegate.showCursor;
  }
}
