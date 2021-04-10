import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: InlineSpanSpike(),
    ),
  );
}

@immutable
class InlineSpanSpike extends StatelessWidget {
  const InlineSpanSpike({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Spike')),
      body: Column(
        children: [
          ListTile(
            onTap: () {
              Navigator.of(context).push(
                InlineSpanSpikeScreen.route(false),
              );
            },
            title: Text('Without WidgetSpan'),
          ),
          ListTile(
            onTap: () {
              Navigator.of(context).push(
                InlineSpanSpikeScreen.route(true),
              );
            },
            title: Text('With WidgetSpan'),
          ),
        ],
      ),
    );
  }
}

@immutable
class InlineSpanSpikeScreen extends StatefulWidget {
  static Route route(bool withWidgetSpan) {
    return MaterialPageRoute(builder: (BuildContext context) {
      return InlineSpanSpikeScreen(withWidgetSpan: withWidgetSpan);
    });
  }

  const InlineSpanSpikeScreen({
    Key key,
    @required this.withWidgetSpan,
  }) : super(key: key);

  final bool withWidgetSpan;

  @override
  _InlineSpanSpikeScreenState createState() => _InlineSpanSpikeScreenState();
}

class _InlineSpanSpikeScreenState extends State<InlineSpanSpikeScreen> {
  final _value = ValueNotifier<bool>(false);

  FocusNode _focusNode;
  InlineSpanController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Lorem ipsum dol😎or sit ut
    // 0   5  10  15   20   25
    // |--------------------|
    //           Italic
    //        |--------|
    //    |-------|
    //      Bold
    //
    _controller = InlineSpanController(text: 'Lorem ipsum 😎 dolor  sit ut');
    _controller.addInsert(
      InlineSpanInsert(0, _controller.text.length, InlineSpanStyle.Text, TextStyle(fontSize: 24.0)),
    );
    _controller.addInsert(InlineSpanInsert(5, 15, InlineSpanStyle.Bold));
    _controller.addInsert(InlineSpanInsert(10, 20, InlineSpanStyle.Italic));
    _controller.addInsert(
      InlineSpanInsert.width(12, 1, InlineSpanStyle.Text, TextStyle(fontSize: 32.0)),
    );
    _controller.addInsert(InlineSpanInsert.width(21, 3, InlineSpanStyle.Large));
    _controller.addInsert(InlineSpanInsert.width(21, 3, InlineSpanStyle.Red));

    if (widget.withWidgetSpan) {
      _controller.addInsert(
        InlineSpanInsert.widget(
          21,
          ValueListenableBuilder(
            valueListenable: _value,
            builder: (BuildContext context, bool value, Widget child) {
              return Container(
                alignment: Alignment.center,
                width: 64.0,
                height: 64.0,
                color: Colors.purple,
                child: Checkbox(
                  value: value,
                  onChanged: (bool value) => _value.value = value,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Spike')),
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.withWidgetSpan) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(width: 2.0),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: null,
                  ),
                ),
                const SizedBox(height: 32.0),
              ],
              Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 2.0),
                ),
                child: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (BuildContext context, TextEditingValue value, Widget child) {
                    final mediaQuery = MediaQuery.of(context);
                    final defaultText = DefaultTextStyle.of(context);
                    return RichText(
                      text: _controller.buildTextSpan(style: defaultText.style),
                      textScaleFactor: mediaQuery.textScaleFactor,
                      textWidthBasis: defaultText.textWidthBasis,
                      textHeightBehavior: defaultText.textHeightBehavior,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InlineSpanController extends TextEditingController {
  InlineSpanController({String text}) : super(text: text);

  final _inserts = <InlineSpanInsert>[];

  List<InlineSpanInsert> get inserts => List.unmodifiable(_inserts);

  void addInsert(InlineSpanInsert insert) {
    _inserts.add(insert);
    notifyListeners();
  }

  void removeInsert(InlineSpanInsert insert) {
    _inserts.remove(insert);
    notifyListeners();
  }

  int nextTransition(int index) {
    int limit = text.length;
    for (final item in _inserts) {
      if (item.start > index && item.start < limit) {
        limit = item.start;
      }
      if (item.end > index && item.end < limit) {
        limit = item.end;
      }
    }
    return limit;
  }

  List<InlineSpanInsert> insertsForIndex(int index) {
    final result = <InlineSpanInsert>[];
    for (final item in _inserts) {
      if (index >= item.start && index < item.end) {
        result.add(item);
      }
    }
    return result;
  }

  @override
  TextSpan buildTextSpan({BuildContext context, TextStyle style, bool withComposing}) {
    final result = <InlineSpan>[];
    var start = 0, end = nextTransition(start);
    while (start != end) {
      final indexInserts = insertsForIndex(start);
      final widgetInsert = indexInserts.firstWhere(
        (el) => el.style == InlineSpanStyle.Widget,
        orElse: () => null,
      );
      if (widgetInsert != null) {
        indexInserts.remove(widgetInsert);
      }
      final textStyle = indexInserts.fold(style.copyWith(), _applyStyle);
      if (widgetInsert != null) {
        result.add(
          WidgetSpan(
            child: widgetInsert.child,
            style: textStyle,
          ),
        );
      }
      result.add(
        TextSpan(
          text: text.substring(start, end),
          style: indexInserts.fold(style.copyWith(), _applyStyle),
        ),
      );
      start = end;
      end = nextTransition(start);
    }
    return TextSpan(children: result, style: style.copyWith());
  }

  TextStyle _applyStyle(TextStyle textStyle, InlineSpanInsert insert) {
    if (insert.textStyle != null) {
      textStyle = textStyle.merge(insert.textStyle);
    }
    switch (insert.style) {
      case InlineSpanStyle.Bold:
        return textStyle.copyWith(fontWeight: FontWeight.bold);
      case InlineSpanStyle.Italic:
        return textStyle.copyWith(fontStyle: FontStyle.italic);
      case InlineSpanStyle.Underline:
        return textStyle.copyWith(decoration: TextDecoration.underline);
      case InlineSpanStyle.Large:
        return textStyle.copyWith(fontSize: textStyle.fontSize + 10.0);
      case InlineSpanStyle.Medium:
        return textStyle.copyWith(fontSize: textStyle.fontSize + 5.0);
      case InlineSpanStyle.Small:
        return textStyle.copyWith(fontSize: textStyle.fontSize - 5.0);
      case InlineSpanStyle.Red:
        return textStyle.copyWith(color: Colors.red);
        break;
      default:
        return textStyle;
    }
  }
}

class InlineSpanInsert {
  const InlineSpanInsert.widget(this.start, this.child)
      : this.end = start + 1,
        this.style = InlineSpanStyle.Widget,
        textStyle = null;

  const InlineSpanInsert.width(this.start, int width, this.style, [this.textStyle])
      : this.end = start + 1 + width,
        this.child = null;

  const InlineSpanInsert(this.start, this.end, this.style, [this.textStyle]) : this.child = null;

  final int start;
  final int end;
  final InlineSpanStyle style;
  final TextStyle textStyle;
  final Widget child;

  @override
  String toString() => '{$start~$end, $style, $textStyle}';
}

enum InlineSpanStyle {
  Text,
  Bold,
  Italic,
  Underline,
  Large,
  Medium,
  Small,
  Red,
  Widget,
}
