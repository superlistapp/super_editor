import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class AttributedTextDemo extends StatefulWidget {
  @override
  _AttributedTextDemoState createState() => _AttributedTextDemoState();
}

class _AttributedTextDemoState extends State<AttributedTextDemo> {
  final List<SpanRange> _boldRanges = [];
  final List<SpanRange> _italicsRanges = [];
  final List<SpanRange> _strikethroughRanges = [];
  TextSpan? _richText;
  late String _plainText;

  @override
  void initState() {
    super.initState();
    _computeStyledText();
  }

  void _computeStyledText() {
    AttributedText _text = AttributedText(
      text: 'This is some text styled with AttributedText',
    );

    for (final range in _boldRanges) {
      _text.addAttribution(boldAttribution, range);
    }
    for (final range in _italicsRanges) {
      _text.addAttribution(italicsAttribution, range);
    }
    for (final range in _strikethroughRanges) {
      _text.addAttribution(strikethroughAttribution, range);
    }

    setState(() {
      _richText = _text.computeTextSpan((Set<Attribution> attributions) {
        TextStyle newStyle = const TextStyle(
          color: Colors.black,
          fontSize: 30,
        );
        for (final attribution in attributions) {
          if (attribution == boldAttribution) {
            newStyle = newStyle.copyWith(
              fontWeight: FontWeight.bold,
            );
          } else if (attribution == italicsAttribution) {
            newStyle = newStyle.copyWith(
              fontStyle: FontStyle.italic,
            );
          } else if (attribution == strikethroughAttribution) {
            newStyle = newStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            );
          }
        }
        return newStyle;
      });
      _plainText = _richText!.toPlainText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20.0),
            child: Text(
              'AttributedText',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 20.0),
            child: Text(
              '''AttributedText is a data structure that supports an arbitrary number of 
"attribution spans". These attributions can be anything, and mean anything.

AttributedText easily facilitates the creation of a TextSpan based on its attributions. 
That TextSpan can then be rendered by Flutter, as usual.

Try it yourself by adding and removing attributions to characters in a string...''',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 600,
            child: Divider(),
          ),
          const SizedBox(height: 24),
          Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  _buildRowTitle('Bold'),
                  _buildCellSelector(_boldRanges),
                ],
              ),
              TableRow(
                children: [
                  _buildRowTitle('Italics'),
                  _buildCellSelector(_italicsRanges),
                ],
              ),
              TableRow(
                children: [
                  _buildRowTitle('Strikethrough'),
                  _buildCellSelector(_strikethroughRanges),
                ],
              ),
              const TableRow(
                children: [
                  SizedBox(height: 24),
                  SizedBox(height: 24),
                ],
              ),
              TableRow(
                children: [
                  _buildRowTitle('Attributed Text'),
                  SuperTextWithSelection.single(
                    richText: _richText ?? const TextSpan(text: 'error'),
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(title),
    );
  }

  Widget _buildCellSelector(List<SpanRange> rangesToUpdate) {
    return TextRangeSelector(
      cellCount: _plainText.length,
      cellWidth: 11,
      cellHeight: 20,
      onRangesChange: (newRanges) {
        rangesToUpdate
          ..clear()
          ..addAll(newRanges);
        _computeStyledText();
      },
    );
  }
}

class TextRangeSelector extends StatefulWidget {
  const TextRangeSelector({
    Key? key,
    required this.cellCount,
    this.cellWidth = 10,
    this.cellHeight = 10,
    this.onRangesChange,
  }) : super(key: key);

  final int cellCount;
  final double cellWidth;
  final double cellHeight;
  final void Function(List<SpanRange>)? onRangesChange;

  @override
  _TextRangeSelectorState createState() => _TextRangeSelectorState();
}

class _TextRangeSelectorState extends State<TextRangeSelector> {
  late List<bool> _selectedCells;
  String? _selectionMode;

  @override
  void initState() {
    super.initState();
    _selectedCells = List.filled(widget.cellCount, false);
  }

  bool _isSelected(int index) {
    return _selectedCells[index];
  }

  void _onTapUp(TapUpDetails details) {
    final selectedCellIndex = _getCellIndexFromLocalOffset(details.localPosition);
    setState(() {
      _selectedCells[selectedCellIndex] = !_selectedCells[selectedCellIndex];
      _reportSelectedRanges();
    });
  }

  void _onPanStart(DragStartDetails details) {
    final selectedCellIndex = _getCellIndexFromLocalOffset(details.localPosition);
    _selectionMode = _selectedCells[selectedCellIndex] ? 'deselect' : 'select';
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final selectedCellIndex = _getCellIndexFromLocalOffset(details.localPosition);
    setState(() {
      _selectedCells[selectedCellIndex] = _selectionMode == 'select';
      _reportSelectedRanges();
    });
  }

  int _getCellIndexFromLocalOffset(Offset localOffset) {
    return ((localOffset.dx / widget.cellWidth).floor()).clamp(0.0, widget.cellCount - 1).toInt();
  }

  void _reportSelectedRanges() {
    if (widget.onRangesChange == null) {
      return;
    }

    final ranges = <SpanRange>[];
    int rangeStart = -1;
    for (int i = 0; i < _selectedCells.length; ++i) {
      if (_selectedCells[i]) {
        if (rangeStart < 0) {
          rangeStart = i;
        }
      } else if (rangeStart >= 0) {
        ranges.add(SpanRange(start: rangeStart, end: i - 1));
        rangeStart = -1;
      }
    }
    if (rangeStart >= 0) {
      ranges.add(SpanRange(start: rangeStart, end: widget.cellCount - 1));
    }

    widget.onRangesChange!(ranges);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _onTapUp,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          widget.cellCount,
          (index) => Container(
            width: widget.cellWidth,
            height: widget.cellHeight,
            decoration: BoxDecoration(
              border: Border.all(width: 1, color: _isSelected(index) ? Colors.red : Colors.grey),
              color: _isSelected(index) ? Colors.red.withOpacity(0.7) : Colors.grey.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
