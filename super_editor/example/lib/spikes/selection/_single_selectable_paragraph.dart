import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';

import '_multi_tap_gesture.dart';

/// A single paragraph that implements tap selection within itself.
///
/// This was the original implementation of text selection during the
/// double-tap and triple-tap selection spike. It was later discovered
/// that integrating other touch input required the selection behavior
/// to be moved outside the individual paragraphs. This implementation
/// is preserved so that you can see a minimal implementation of
/// tap-text-selection.
class SelectableParagraph extends StatefulWidget {
  const SelectableParagraph({
    Key key,
    @required this.paragraphKey,
    this.selectionController,
    this.paragraph,
  }) : super(key: key);

  final GlobalKey paragraphKey;
  final SelectionController selectionController;
  final String paragraph;

  @override
  _SelectableParagraphState createState() => _SelectableParagraphState();
}

class _SelectableParagraphState extends State<SelectableParagraph> {
  final List<TextBox> _selectionBoxes = [];

  @override
  void initState() {
    super.initState();
    widget.selectionController?.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(SelectableParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionController != widget.selectionController) {
      oldWidget.selectionController.removeListener(_onSelectionChange);
      widget.selectionController.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selectionController?.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    setState(() {
      if (widget.selectionController.selectedParagraphKey != widget.paragraphKey) {
        _selectionBoxes.clear();
      }
    });
  }

  void _onTap() {
    print('Tap!');
    setState(() {
      _selectionBoxes.clear();
      widget.selectionController.clearSelection();
    });
  }

  void _onDoubleTap(TapDownDetails details) {
    final textRenderBox = widget.paragraphKey.currentContext.findRenderObject() as RenderParagraph;
    final textOffset = textRenderBox.getPositionForOffset(details.localPosition);
    // print('TextOffset: ${textOffset.offset}');
    final wordRange = textRenderBox.getWordBoundary(textOffset);
    final selectedWord = wordRange.textInside(widget.paragraph);
    print('Selected word: "$selectedWord"');

    setState(() {
      _selectionBoxes.clear();

      if (selectedWord.trim().isEmpty) {
        // The selected word is blank space. Don't select.
        return;
      }

      _selectionBoxes.addAll(textRenderBox.getBoxesForSelection(TextSelection(
        baseOffset: wordRange.start,
        extentOffset: wordRange.end,
      )));
      print('${_selectionBoxes.length} selection boxes');

      widget.selectionController.setActiveSelection(widget.paragraphKey);
    });
  }

  void _onTripleTap(TapDownDetails details) {
    final textRenderBox = widget.paragraphKey.currentContext.findRenderObject() as RenderParagraph;
    final textOffset = textRenderBox.getPositionForOffset(details.localPosition);
    final paragraphRange = _getParagraphBoundary(widget.paragraph, textOffset);
    final selectedParagraph = paragraphRange.textInside(widget.paragraph);
    print('Selected paragraph: "$selectedParagraph"');

    setState(() {
      _selectionBoxes.clear();

      if (selectedParagraph.trim().isEmpty) {
        // The selected word is blank space. Don't select.
        return;
      }

      _selectionBoxes.addAll(textRenderBox.getBoxesForSelection(TextSelection(
        baseOffset: paragraphRange.start,
        extentOffset: paragraphRange.end,
      )));
      print('${_selectionBoxes.length} selection boxes');

      widget.selectionController.setActiveSelection(widget.paragraphKey);
    });
  }

  TextRange _getParagraphBoundary(String text, TextPosition textPosition) {
    int startIndex = textPosition.offset;
    int endIndex = textPosition.offset;

    while (startIndex > 0 && text[startIndex] != '\n') {
      startIndex -= 1;
    }

    while (endIndex < text.length && text[endIndex] != '\n') {
      endIndex += 1;
    }

    return TextRange(start: startIndex, end: endIndex);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: customize cursor behavior so that a text cursor only shows when
    //       it is truly above text characters. Currently a text cursor is
    //       shown even when its above empty space at the end of the paragraph.
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
            () => TapSequenceGestureRecognizer(),
            (TapSequenceGestureRecognizer recognizer) {
              if (!widget.selectionController.isSelectionActive ||
                  widget.selectionController.selectedParagraphKey == widget.paragraphKey) {
                recognizer
                  ..onTap = _onTap
                  ..onDoubleTap = () {
                    print('Double tap!');
                  }
                  ..onDoubleTapDown = _onDoubleTap
                  ..onTripleTap = () {
                    print('Triple tap!');
                  }
                  ..onTripleTapDown = _onTripleTap;
              }
            },
          )
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: SelectionPainter(selectionBoxes: List.from(_selectionBoxes)),
            ),
            Text(
              widget.paragraph,
              key: widget.paragraphKey,
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionController with ChangeNotifier {
  bool get isSelectionActive => _selectedParagraphKey != null;

  GlobalKey _selectedParagraphKey;
  GlobalKey get selectedParagraphKey => _selectedParagraphKey;

  void setActiveSelection(GlobalKey paragraphKey) {
    if (paragraphKey != _selectedParagraphKey) {
      _selectedParagraphKey = paragraphKey;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedParagraphKey = null;
    notifyListeners();
  }
}

class SelectionPainter extends CustomPainter {
  SelectionPainter({
    List<TextBox> selectionBoxes,
  }) : _selectionBoxes = selectionBoxes;

  final List<TextBox> _selectionBoxes;

  final Paint _selectionPaint = Paint()..color = Colors.lightGreenAccent;

  @override
  void paint(Canvas canvas, Size size) {
    if (_selectionBoxes == null) {
      return;
    }

    for (final selectionBox in _selectionBoxes) {
      canvas.drawRect(
        selectionBox.toRect(),
        _selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) {
    return !const ListEquality().equals(oldDelegate._selectionBoxes, _selectionBoxes);
  }
}
