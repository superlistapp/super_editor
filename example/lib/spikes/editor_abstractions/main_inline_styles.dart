import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:example/spikes/editor_abstractions/selectable_text/selectable_text.dart';
import 'package:flutter/material.dart' hide SelectableText;

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: InlineStyleExampleScreen(),
    ),
  ));
}

class InlineStyleExampleScreen extends StatefulWidget {
  @override
  _InlineStyleExampleScreenState createState() => _InlineStyleExampleScreenState();
}

class _InlineStyleExampleScreenState extends State<InlineStyleExampleScreen> {
  final List<TextRange> _boldRanges = [];
  final List<TextRange> _italicsRanges = [];
  final List<TextRange> _strikethroughRanges = [];
  TextSpan _richText;
  String _plainText;

  @override
  void initState() {
    super.initState();
    _computeStyledText();
  }

  void _computeStyledText() {
    AttributedText _text = AttributedText(
      text: 'This is some text for testing',
    );

    for (final range in _boldRanges) {
      _text.addAttribution('bold', range);
    }
    for (final range in _italicsRanges) {
      _text.addAttribution('italics', range);
    }
    for (final range in _strikethroughRanges) {
      _text.addAttribution('strikethrough', range);
    }

    setState(() {
      _richText = _text.computeTextSpan(TextStyle(
        fontSize: 24,
      ));
      _plainText = _richText.toPlainText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Table(
        defaultColumnWidth: IntrinsicColumnWidth(),
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
          TableRow(
            children: [
              _buildRowTitle('Styled Text'),
              SelectableText(
                key: GlobalKey(),
                richText: _richText ?? TextSpan(text: 'error'),
              ),
            ],
          ),
          TableRow(
            children: [
              _buildRowTitle('Test a normal RichText'),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: 'This is first. ',
                    ),
                    TextSpan(
                      text: 'This is second. ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'This is third.',
                    ),
                  ],
                ),
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

  Widget _buildCellSelector(List<TextRange> rangesToUpdate) {
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
    Key key,
    @required this.cellCount,
    this.cellWidth = 10,
    this.cellHeight = 10,
    this.onRangesChange,
  }) : super(key: key);

  final int cellCount;
  final double cellWidth;
  final double cellHeight;
  final void Function(List<TextRange>) onRangesChange;

  @override
  _TextRangeSelectorState createState() => _TextRangeSelectorState();
}

class _TextRangeSelectorState extends State<TextRangeSelector> {
  List<bool> _selectedCells;
  String _selectionMode;

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

    final ranges = <TextRange>[];
    int rangeStart = -1;
    for (int i = 0; i < _selectedCells.length; ++i) {
      if (_selectedCells[i]) {
        if (rangeStart < 0) {
          rangeStart = i;
        }
      } else if (rangeStart >= 0) {
        ranges.add(TextRange(start: rangeStart, end: i - 1));
        rangeStart = -1;
      }
    }
    if (rangeStart >= 0) {
      ranges.add(TextRange(start: rangeStart, end: widget.cellCount - 1));
    }

    print('Reporting ranges:');
    for (final range in ranges) {
      print(' - $range');
    }

    widget.onRangesChange(ranges);
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
