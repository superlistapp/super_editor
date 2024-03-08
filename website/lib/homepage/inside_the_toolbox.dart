import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class InsideTheToolbox extends StatelessWidget {
  const InsideTheToolbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              _buildTitle(),
              const SizedBox(height: 12),
              _buildDescription(),
              const SizedBox(height: 80),
              _buildSuperTextField(),
              _buildSelectableText(),
              _buildAttributedText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: SelectableText(
        'Inside the toolbox',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 38,
          height: 46 / 38,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDescription() {
    return const SelectableText(
      "Super Editor is more than just one big editor. It's a full toolbox!",
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSuperTextField() {
    return _buildToolDescription(
      title: 'SuperTextField',
      description:
          "SuperTextField is a custom implementation of a text field based on the same philosophy as Super Editor.",
      demo: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: SuperTextField(
          textStyleBuilder: _textfieldStyleBuilder,
          hintBuilder: (context) {
            return Text(
              'start typing here...',
              style: _textfieldStyleBuilder({}).copyWith(
                color: Colors.grey,
              ),
            );
          },
          hintBehavior: HintBehavior.displayHintUntilTextEntered,
        ),
      ),
    );
  }

  Widget _buildSelectableText() {
    return _buildToolDescription(
      title: 'SelectableText',
      description: "Super Editor includes a SelectableText widget built from the ground up. Instead of building "
          "gesture detection into SelectableText, we provide all the painting abilities, and you hook up whatever "
          "gestures you'd like. This makes Super Editor's SelectableText fundamentally different and more composable "
          "than Flutter's SelectableText.\n\nSuper Editor's text editor and SuperTextField are both based on this "
          "implementation of SelectableText\n\nIn this example, we paint text with a selection, but no gestures are "
          "hooked up at all. If you can select text with code then you can select text any way you choose.",
      demo: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SuperTextWithSelection.single(
            richText: const TextSpan(
              text: 'This text is selectable. The caret and selection rendering is custom.',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            userSelection: const UserSelection(
              selection: TextSelection(
                baseOffset: 13,
                extentOffset: 23,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttributedText() {
    return _buildToolDescription(
      title: 'AttributedText',
      description: "At the heart of everything in Super Editor is AttributedText, a representation of text along with"
          ' any number of "attributions". These attributions can represent styles, like bold and italics, or more '
          "complicated things like links.\n\nThe closest thing that Flutter offers to Super Editor's AttributedText "
          "is TextSpans, which are used for applying partial styles to text. But TextSpans include rendering-specific"
          " references, and they don't support overlapping spans. AttributedText has nothing to do with rendering, "
          "and it allows you to have as many overlapping spans as you'd like.",
      demo: _AttributedTextDemo(),
    );
  }

  Widget _buildToolDescription({
    required String title,
    required String description,
    required Widget demo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 24,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SelectableText(description),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ),
                child: demo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _textfieldStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    color: Colors.black,
    fontSize: 14,
  );
}

class _AttributedTextDemo extends StatefulWidget {
  @override
  _AttributedTextDemoState createState() => _AttributedTextDemoState();
}

class _AttributedTextDemoState extends State<_AttributedTextDemo> {
  final List<SpanRange> _boldRanges = [];
  final List<SpanRange> _italicsRanges = [];
  final List<SpanRange> _strikethroughRanges = [];

  late String _plainText;
  late TextSpan _richText;

  @override
  void initState() {
    super.initState();
    _computeStyledText();
  }

  void _computeStyledText() {
    final text = AttributedText(
      'This is some text styled with AttributedText',
    );

    for (final range in _boldRanges) {
      text.addAttribution(boldAttribution, range);
    }
    for (final range in _italicsRanges) {
      text.addAttribution(italicsAttribution, range);
    }
    for (final range in _strikethroughRanges) {
      text.addAttribution(strikethroughAttribution, range);
    }

    setState(() {
      _richText = text.computeTextSpan((Set<Attribution> attributions) {
        TextStyle newStyle = const TextStyle(
          color: Colors.white,
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
      _plainText = _richText.toPlainText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRowTitle('Bold'),
          _buildCellSelector(_boldRanges),
          _buildRowTitle('Italics'),
          _buildCellSelector(_italicsRanges),
          _buildRowTitle('Strikethrough'),
          _buildCellSelector(_strikethroughRanges),
          _buildRowTitle('Attributed Text'),
          SuperTextWithSelection.single(
            key: GlobalKey(),
            richText: _richText,
          ),
        ],
      ),
    );
  }

  Widget _buildRowTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.tealAccent,
        ),
      ),
    );
  }

  Widget _buildCellSelector(List<SpanRange> rangesToUpdate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / _plainText.length;

        return TextRangeSelector(
          cellCount: _plainText.length,
          cellWidth: cellWidth,
          cellHeight: 20,
          onRangesChange: (newRanges) {
            rangesToUpdate
              ..clear()
              ..addAll(newRanges);
            _computeStyledText();
          },
        );
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
    return (localOffset.dx / widget.cellWidth).floor().clamp(0.0, widget.cellCount - 1).toInt();
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
        ranges.add(SpanRange(rangeStart, i - 1));
        rangeStart = -1;
      }
    }
    if (rangeStart >= 0) {
      ranges.add(SpanRange(rangeStart, widget.cellCount - 1));
    }

    widget.onRangesChange?.call(ranges);
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
              border: Border.all(color: _isSelected(index) ? Colors.tealAccent : Colors.grey),
              color: _isSelected(index) ? Colors.tealAccent.withOpacity(0.7) : Colors.grey.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
