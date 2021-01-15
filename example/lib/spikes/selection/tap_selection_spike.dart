import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '_multi_tap_gesture.dart';

/// Spike:
/// Can we orchestrate text selection from the widget tree?
///
/// Note:
/// No serious thought was put into the breakdown of widgets, objects,
/// or methods in this spike. This spike should not be used as a
/// template for future code structure.
///
/// Conclusion:
/// Yes, we can calculate text selection ranges from the widget tree
/// with `Text` widgets. However, calculating these ranges requires
/// routine use of `RenderParagraph` references that are accessed
/// from the widget tree. This is technically acceptable, but indicates
/// that we might be better off operating within the render tree.
///
/// Forward Thinking:
/// We could introduce the concept of a `Selectable` widget, which
/// offers a callback that is invoked with a drag rectangle, allowing
/// a given `StatefulWidget` to take any desired action. This would
/// then facilitate the creation of widgets like `EditorParagraph`,
/// `EditorImage`, and `EditorBullets`, which can interpret the
/// meaning of selection for its content. For example, this breakdown
/// of responsibility might help implement copy/paste when selecting
/// an image in between paragraphs.
///
/// This spike implements:
///  • double-tap to select a whole word.
///  • double-tap and drag to select a series of whole words, including
///    across paragraphs.
///  • triple-tap to select a whole paragraph.
///  • triple-tap and drag to select a series of whole paragraphs.
///  • single-tap anywhere to deselect everything.
///  • single-tap and drag to select with character precision across
///    paragraphs.
///  • text cursor icon when sitting over text or dragging
///
/// Anti-Goals:
///  • selection while scrolling
///  • selection within a `TextField`
///  • selection across assets and non-`Text` widgets

void main() {
  runApp(MaterialApp(
    home: Scaffold(body: TapSelectionSpike()),
    debugShowCheckedModeBanner: false,
  ));
}

class TapSelectionSpike extends StatefulWidget {
  @override
  _TapSelectionSpikeState createState() => _TapSelectionSpikeState();
}

class _TapSelectionSpikeState extends State<TapSelectionSpike> {
  static final String _paragraphText =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.';
  final List<String> _paragraphs = [
    _paragraphText,
    _paragraphText,
    _paragraphText,
  ];
  final List<GlobalKey> _paragraphKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];
  final List<ParagraphSelection> _paragraphSelections = [];

  /// Is the mouse currently on top of text? Used to configure
  /// the mouse style.
  bool _isHoveringOverText = false;

  bool _isFullWordDragSelection = false;
  bool _isFullParagraphDragSelection = false;
  Offset _dragStart;
  Rect _dragRect;

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    setState(() {
      _dragRect = Rect.fromLTWH(_dragStart.dx, _dragStart.dy, 1, 1);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragRect = Rect.fromPoints(_dragStart, details.localPosition);

      _updateDragSelection();
    });

    // Forward this message on to the method that determines the
    // desired cursor style.
    _configureMouseStyle(details.localPosition);
  }

  void _updateDragSelection() {
    SelectedParagraph startSelectParagraph;
    List<SelectedParagraph> wholeSelectParagraphs = [];
    SelectedParagraph endSelectParagraph;

    for (int i = 0; i < _paragraphKeys.length; ++i) {
      final currentParagraph = _paragraphKeys[i].currentContext.findRenderObject() as RenderParagraph;
      final currentParagraphTopLeft = currentParagraph.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      final currentParagraphBottomRight = currentParagraph.localToGlobal(currentParagraph.size.bottomRight(Offset.zero),
          ancestor: context.findRenderObject());

      if (_dragRect.topLeft.dy >= currentParagraphTopLeft.dy &&
          _dragRect.topLeft.dy <= currentParagraphBottomRight.dy) {
        print('Start: $i');
        startSelectParagraph = SelectedParagraph(
          paragraphKey: _paragraphKeys[i],
          renderParagraph: currentParagraph,
          paragraph: _paragraphs[i],
        );
      }
      if (_dragRect.bottomRight.dy >= currentParagraphTopLeft.dy &&
          _dragRect.bottomRight.dy <= currentParagraphBottomRight.dy) {
        print('End: $i');
        endSelectParagraph = SelectedParagraph(
          paragraphKey: _paragraphKeys[i],
          renderParagraph: currentParagraph,
          paragraph: _paragraphs[i],
        );
      }
      if (_dragRect.topLeft.dy <= currentParagraphTopLeft.dy &&
          _dragRect.bottomRight.dy >= currentParagraphBottomRight.dy) {
        wholeSelectParagraphs.add(
          SelectedParagraph(
            paragraphKey: _paragraphKeys[i],
            renderParagraph: currentParagraph,
            paragraph: _paragraphs[i],
          ),
        );
      }
    }

    print('Start paragraph: ${startSelectParagraph?.hashCode}');
    print('End paragraph: ${endSelectParagraph?.hashCode}');
    print('Whole select: $wholeSelectParagraphs');
    print('');

    _clearSelection();

    if (wholeSelectParagraphs.isEmpty && startSelectParagraph == null && endSelectParagraph == null) {
      // The user is dragging in open space. No text selections.
      return;
    }

    if (wholeSelectParagraphs.isEmpty &&
        ((startSelectParagraph == null && endSelectParagraph != null) ||
            (startSelectParagraph != null && endSelectParagraph == null) ||
            startSelectParagraph?.paragraphKey == endSelectParagraph?.paragraphKey)) {
      _selectInnerParagraph(
        startSelectParagraph ?? endSelectParagraph,
        _isFullParagraphDragSelection
            ? SelectionMode.paragraph
            : _isFullWordDragSelection
                ? SelectionMode.word
                : SelectionMode.character,
      );
    } else {
      _selectAcrossParagraphs(
        startSelection: startSelectParagraph,
        wholeSelections: wholeSelectParagraphs,
        endSelection: endSelectParagraph,
        selectionMode: _isFullParagraphDragSelection
            ? SelectionMode.paragraph
            : _isFullWordDragSelection
                ? SelectionMode.word
                : SelectionMode.character,
      );
    }
  }

  void _clearSelection() {
    _paragraphSelections.clear();
  }

  void _selectInnerParagraph(SelectedParagraph paragraph, SelectionMode selectionMode) {
    final localDragStart =
        paragraph.renderParagraph.globalToLocal(_dragRect.topLeft, ancestor: context.findRenderObject());
    final localDragEnd =
        paragraph.renderParagraph.globalToLocal(_dragRect.bottomRight, ancestor: context.findRenderObject());

    final selectionStart = localDragStart.dy >= 0
        ? paragraph.renderParagraph.getPositionForOffset(localDragStart)
        : TextPosition(offset: 0);
    print('Selection start: $selectionStart');
    final selectionEnd = localDragEnd.dy <= paragraph.renderParagraph.size.height
        ? paragraph.renderParagraph.getPositionForOffset(localDragEnd)
        : TextPosition(offset: paragraph.paragraph.length);
    print('Selection end: $selectionEnd');

    _paragraphSelections.add(ParagraphSelection(
      selectedParagraph: paragraph,
      startSelection: selectionStart,
      endSelection: selectionEnd,
      selectionMode: selectionMode,
    ));
  }

  void _selectAcrossParagraphs({
    @required SelectedParagraph startSelection,
    @required List<SelectedParagraph> wholeSelections,
    @required SelectedParagraph endSelection,
    @required SelectionMode selectionMode,
  }) {
    // Possible null if drag start is not on top of text.
    if (startSelection != null) {
      _selectInnerParagraph(startSelection, selectionMode);
    }
    // Possible null if drag end is not on top of text.
    if (endSelection != null) {
      _selectInnerParagraph(endSelection, selectionMode);
    }
    for (final selectedParagraph in wholeSelections) {
      _paragraphSelections.add(ParagraphSelection(
        selectedParagraph: selectedParagraph,
        startSelection: TextPosition(offset: 0),
        endSelection: TextPosition(offset: selectedParagraph.paragraph.length),
        selectionMode: SelectionMode.paragraph,
      ));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragRect = null;
      _isFullParagraphDragSelection = false;
    });
  }

  void _onPanCancel() {
    setState(() {
      _dragRect = null;
    });
  }

  void _onTap() {
    print('Tap!');
    setState(() {
      _clearSelection();
    });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    print('onDoubleTapDown');
    _isFullWordDragSelection = true;

    final selectedParagraph = _findParagraphAtPosition(details.localPosition);
    print('Selected paragraph: ${selectedParagraph?.paragraph}');
    if (selectedParagraph == null) {
      return;
    }

    final textRenderBox = selectedParagraph.renderParagraph;
    final paragraphTouchPosition =
        textRenderBox.globalToLocal(details.localPosition, ancestor: context.findRenderObject());
    final textOffset = textRenderBox.getPositionForOffset(paragraphTouchPosition);
    print('TextOffset: ${textOffset.offset}');
    final wordRange = textRenderBox.getWordBoundary(textOffset);
    final selectedWord = wordRange.textInside(selectedParagraph.paragraph);
    print('Selected word: "$selectedWord"');

    setState(() {
      _clearSelection();

      if (selectedWord.trim().isEmpty) {
        // The selected word is blank space. Don't select.
        return;
      }

      _paragraphSelections.add(
        ParagraphSelection(
          selectedParagraph: selectedParagraph,
          startSelection: TextPosition(offset: wordRange.start),
          endSelection: TextPosition(offset: wordRange.end),
          selectionMode: SelectionMode.word,
        ),
      );
    });
  }

  void _onDoubleTap() {
    print('onDoubleTap');
    _isFullWordDragSelection = false;
  }

  void _onTripleTapDown(TapDownDetails details) {
    print('onTripleTapDown');
    _isFullParagraphDragSelection = true;

    final selectedParagraph = _findParagraphAtPosition(details.localPosition);
    if (selectedParagraph == null) {
      return;
    }

    final textRenderBox = selectedParagraph.renderParagraph;
    final paragraphTouchPosition =
        textRenderBox.globalToLocal(details.localPosition, ancestor: context.findRenderObject());
    final textOffset = textRenderBox.getPositionForOffset(paragraphTouchPosition);
    final paragraphRange = _getParagraphBoundary(selectedParagraph.paragraph, textOffset);
    final selectedText = paragraphRange.textInside(selectedParagraph.paragraph);

    setState(() {
      _clearSelection();

      if (selectedText.trim().isEmpty) {
        // The selected word is blank space. Don't select.
        return;
      }

      _paragraphSelections.add(
        ParagraphSelection(
          selectedParagraph: selectedParagraph,
          startSelection: TextPosition(offset: paragraphRange.start),
          endSelection: TextPosition(offset: paragraphRange.end),
          selectionMode: SelectionMode.paragraph,
        ),
      );
    });
  }

  void _onTripleTap() {
    print('onTripleTap');
    _isFullParagraphDragSelection = false;
  }

  SelectedParagraph _findParagraphAtPosition(Offset position) {
    for (int i = 0; i < _paragraphKeys.length; ++i) {
      final renderParagraph = _paragraphKeys[i].currentContext.findRenderObject() as RenderParagraph;
      final paragraphRect =
          renderParagraph.localToGlobal(Offset.zero, ancestor: context.findRenderObject()) & renderParagraph.size;
      if (paragraphRect.contains(position)) {
        return SelectedParagraph(
          paragraphKey: _paragraphKeys[i],
          renderParagraph: renderParagraph,
          paragraph: _paragraphs[i],
        );
      }
    }

    return null;
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

  void _onMouseMove(PointerEvent pointerEvent) {
    _configureMouseStyle(pointerEvent.localPosition);
  }

  void _configureMouseStyle(Offset localPosition) {
    final hoveredParagraph = _findParagraphAtPosition(localPosition);

    if (hoveredParagraph != null) {
      final positionInParagraph =
          hoveredParagraph.renderParagraph.globalToLocal(localPosition, ancestor: context.findRenderObject());
      final hoveredTextOffset = hoveredParagraph.renderParagraph.getPositionForOffset(positionInParagraph);

      if (hoveredTextOffset != null) {
        List<TextBox> boxes = hoveredParagraph.renderParagraph.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: hoveredParagraph.paragraph.length,
          ),
        );

        for (final box in boxes) {
          if (box.toRect().contains(positionInParagraph)) {
            if (!_isHoveringOverText) {
              setState(() {
                _isHoveringOverText = true;
              });
            }
            return;
          }
        }
      }
    }

    if (_isHoveringOverText) {
      setState(() {
        _isHoveringOverText = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: _onMouseMove,
      child: MouseRegion(
        cursor: _isHoveringOverText ? SystemMouseCursors.text : SystemMouseCursors.basic,
        child: Stack(
          children: [
            _buildTextContent(),
            _buildDragToSelect(),
          ],
        ),
      ),
    );
  }

  /// Displays text content, and paints solid color selection rectangles
  /// for selected text.
  Widget _buildTextContent() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _paragraphs.length; ++i) ...[
              SelectableParagraph(
                paragraphKey: _paragraphKeys[i],
                paragraph: _paragraphs[i],
                selectionBoxes: _paragraphSelections
                        .firstWhere((selection) => selection.selectedParagraph.paragraphKey == _paragraphKeys[i],
                            orElse: () => null)
                        ?.textBoxes ??
                    const [],
              ),
              SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  /// Processes all selection gestures, and paints a selection rectangle.
  Widget _buildDragToSelect() {
    return Positioned.fill(
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
            () => TapSequenceGestureRecognizer(),
            (TapSequenceGestureRecognizer recognizer) {
              recognizer
                ..onTap = _onTap
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
        child: CustomPaint(
          painter: DragRectanglePainter(
            selectionRect: _dragRect,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// A paragraph that is currently selected.
///
/// Includes the `GlobalKey` attached to the `Text` widget, the `String`
/// text within the `Text` widget, and the `RenderParagraph` that backs
/// the `Text` widget.
class SelectedParagraph {
  SelectedParagraph({
    @required this.paragraphKey,
    @required this.renderParagraph,
    @required this.paragraph,
  });

  final GlobalKey paragraphKey;
  final RenderParagraph renderParagraph;
  final String paragraph;
}

/// Selected portion of a given `SelectedParagraph`.
class ParagraphSelection {
  ParagraphSelection({
    @required this.selectedParagraph,
    @required this.startSelection,
    @required this.endSelection,
    @required SelectionMode selectionMode,
  }) {
    switch (selectionMode) {
      case SelectionMode.character:
        _textBoxes = selectedParagraph.renderParagraph.getBoxesForSelection(
          TextSelection(baseOffset: startSelection.offset, extentOffset: endSelection.offset),
        );
        break;
      case SelectionMode.word:
        final firstWord = selectedParagraph.renderParagraph.getWordBoundary(startSelection);
        final lastWord = selectedParagraph.renderParagraph.getWordBoundary(endSelection);
        _textBoxes = selectedParagraph.renderParagraph.getBoxesForSelection(
          TextSelection(baseOffset: firstWord.start, extentOffset: lastWord.end),
        );
        break;
      case SelectionMode.paragraph:
        _textBoxes = selectedParagraph.renderParagraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: selectedParagraph.paragraph.length),
        );
        break;
    }
  }

  final SelectedParagraph selectedParagraph;
  final TextPosition startSelection;
  final TextPosition endSelection;
  List<TextBox> _textBoxes;
  List<TextBox> get textBoxes => _textBoxes;
}

/// The minimum selection size when dragging.
enum SelectionMode {
  character,
  word,
  paragraph,
}

/// Displays a `Text` widget along with colored rectangles for the
/// selected text, represented by the given `selectionBoxes`.
class SelectableParagraph extends StatefulWidget {
  const SelectableParagraph({
    Key key,
    @required this.paragraphKey,
    this.paragraph,
    this.selectionBoxes = const [],
  }) : super(key: key);

  final GlobalKey paragraphKey;
  final String paragraph;
  final List<TextBox> selectionBoxes;

  @override
  _SelectableParagraphState createState() => _SelectableParagraphState();
}

class _SelectableParagraphState extends State<SelectableParagraph> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: SelectionPainter(selectionBoxes: List.from(widget.selectionBoxes)),
        ),
        Text(
          widget.paragraph,
          key: widget.paragraphKey,
        ),
      ],
    );
  }
}

/// Paints the given `selectionBoxes` with a color.
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
