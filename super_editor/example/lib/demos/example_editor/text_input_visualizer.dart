import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class SuperEditorImeDebugger extends StatefulWidget {
  const SuperEditorImeDebugger({
    Key? key,
    required this.watcher,
    this.componentBuilders = const [
      _buildSetEditingTextEvent,
      _buildTextDeltaEvents,
      _buildKeyEvent,
      _buildGenericEvent,
    ],
  }) : super(key: key);

  final TextInputDebugger watcher;

  final List<TextInputDebugComponentBuilder> componentBuilders;

  @override
  State<SuperEditorImeDebugger> createState() => _SuperEditorImeDebuggerState();
}

class _SuperEditorImeDebuggerState extends State<SuperEditorImeDebugger> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.watcher.addListener(_scrollOnNextFrame);
    _scrollOnNextFrame();
  }

  @override
  void didUpdateWidget(covariant SuperEditorImeDebugger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watcher != widget.watcher) {
      oldWidget.watcher.removeListener(_scrollOnNextFrame);
      widget.watcher.addListener(_scrollOnNextFrame);
      _scrollOnNextFrame();
    }
  }

  @override
  void dispose() {
    widget.watcher.removeListener(_scrollOnNextFrame);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollOnNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: widget.watcher,
              builder: (context, child) {
                return ListView.separated(
                  controller: _scrollController,
                  itemCount: widget.watcher.events.length,
                  itemBuilder: (context, index) => _buildLogItem(context, widget.watcher.events[index]),
                  separatorBuilder: (context, index) => SizedBox(height: 20),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.watcher.clear,
              child: Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, TextInputDebugEvent event) {
    Widget? content;
    for (final builder in widget.componentBuilders) {
      content = builder(context, event);
      if (content != null) {
        break;
      }
    }

    if (content == null) {
      throw Exception('No component for $event');
    }

    return content;
  }
}

typedef TextInputDebugComponentBuilder = Widget? Function(BuildContext context, TextInputDebugEvent event);

const defaultTextInputDebugComponentBuilders = <TextInputDebugComponentBuilder>[
  _buildSetEditingTextEvent,
  _buildTextDeltaEvents,
  _buildKeyEvent,
  _buildGenericEvent,
];

Widget? _buildSetEditingTextEvent(BuildContext context, TextInputDebugEvent event) {
  final textEditingValue = event.data;
  if (textEditingValue is! TextEditingValue) {
    return null;
  }

  return ListTile(
    leading: Icon(
      Icons.arrow_upward,
      color: Colors.green,
    ),
    title: Text(
      event.method,
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _createTextWithSingleAttribution(
          label: 'Text',
          text: textEditingValue.text,
          attribution: _insertionOffsetAttribution,
          selection: textEditingValue.selection,
        ),
        SizedBox(height: 5),
        _createTextWithSingleAttribution(
          label: 'Selection',
          text: textEditingValue.selection.toString(),
        ),
        SizedBox(height: 5),
        _createTextWithSingleAttribution(
          label: 'Composing region',
          text: textEditingValue.composing.toString(),
        ),
      ],
    ),
  );
}

Widget? _buildTextDeltaEvents(BuildContext context, TextInputDebugEvent event) {
  final params = event.data;
  if (params is! List<TextEditingDelta>) {
    return null;
  }

  final deltaComponents = params.map(
    (delta) {
      if (delta is TextEditingDeltaInsertion) {
        return _buildInsertionDeltaEvent(context, delta);
      }

      if (delta is TextEditingDeltaReplacement) {
        return _buildReplacementDeltaEvent(context, delta);
      }

      if (delta is TextEditingDeltaDeletion) {
        return _buildDeletionDeltaEvent(context, delta);
      }

      if (delta is TextEditingDeltaNonTextUpdate) {
        return _buildNonTextDeltaEvent(context, delta);
      }

      return SizedBox();
    },
  ).toList();
  return ListTile(
    leading: Icon(
      Icons.arrow_downward,
      color: Colors.blue,
    ),
    title: Text(
      event.method,
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...deltaComponents,
      ],
    ),
  );
}

Widget _buildInsertionDeltaEvent(BuildContext context, TextEditingDeltaInsertion delta) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _createTextWithSingleAttribution(
        label: 'Delta kind',
        text: delta.runtimeType.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'OldText',
        text: delta.oldText,
        attribution: _insertionOffsetAttribution,
        range: TextRange(
          start: delta.insertionOffset,
          end: delta.insertionOffset,
        ),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Inserted Text',
        text: delta.textInserted,
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Insertion Offset',
        text: delta.insertionOffset.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'IME new text',
        text: delta.apply(TextEditingValue(text: delta.oldText)).text,
        attribution: _newTextAttribution,
        range: TextRange(
          start: delta.insertionOffset,
          end: delta.insertionOffset + delta.textInserted.length,
        ),
        selection: delta.selection,
      ),
      _createTextWithSingleAttribution(
        label: 'Selection',
        text: delta.selection.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Composing region',
        text: delta.composing.toString(),
      ),
    ],
  );
}

Widget _buildReplacementDeltaEvent(BuildContext context, TextEditingDeltaReplacement delta) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _createTextWithSingleAttribution(
        label: 'Delta kind',
        text: delta.runtimeType.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'OldText',
        text: delta.oldText,
        attribution: _textRemovedAttribution,
        range: delta.replacedRange,
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Range',
        text: delta.replacedRange.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'IME new text',
        text: delta.apply(TextEditingValue(text: delta.oldText)).text,
        attribution: _newTextAttribution,
        range: TextRange(
          start: delta.replacedRange.start,
          end: delta.replacedRange.start + delta.replacementText.length,
        ),
        selection: delta.selection,
      ),
      _createTextWithSingleAttribution(
        label: 'Selection',
        text: delta.selection.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Composing region',
        text: delta.composing.toString(),
      ),
    ],
  );
}

Widget _buildDeletionDeltaEvent(BuildContext context, TextEditingDeltaDeletion delta) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _createTextWithSingleAttribution(
        label: 'Delta kind',
        text: delta.runtimeType.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'OldText',
        text: delta.oldText,
        attribution: _textRemovedAttribution,
        range: delta.deletedRange,
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Range',
        text: delta.deletedRange.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'IME new text',
        text: delta.apply(TextEditingValue(text: delta.oldText)).text,
        selection: delta.selection,
      ),
      _createTextWithSingleAttribution(
        label: 'Selection',
        text: delta.selection.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Composing region',
        text: delta.composing.toString(),
      ),
    ],
  );
}

Widget _buildNonTextDeltaEvent(BuildContext context, TextEditingDeltaNonTextUpdate delta) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _createTextWithSingleAttribution(
        label: 'Delta kind',
        text: delta.runtimeType.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'IME Text',
        text: delta.apply(TextEditingValue(text: delta.oldText)).text,
        selection: delta.selection,
      ),
      _createTextWithSingleAttribution(
        label: 'Selection',
        text: delta.selection.toString(),
      ),
      SizedBox(height: 5),
      _createTextWithSingleAttribution(
        label: 'Composing region',
        text: delta.composing.toString(),
      ),
    ],
  );
}

Widget? _buildKeyEvent(BuildContext context, TextInputDebugEvent event) {
  final keyEvent = event.data;
  if (keyEvent is! RawKeyDownEvent) {
    return null;
  }

  return ListTile(
    leading: Icon(
      Icons.arrow_downward,
      color: Colors.blue,
    ),
    title: Text(
      event.method,
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _createTextWithSingleAttribution(
          label: 'Key',
          text: keyEvent.data.physicalKey.debugName ?? keyEvent.data.keyLabel,
        ),
      ],
    ),
  );
}

Widget _buildGenericEvent(BuildContext context, TextInputDebugEvent event) {
  return ListTile(
    leading: event.direction == TextInputMessageDirection.fromIme //
        ? Icon(
            Icons.arrow_downward,
            color: Colors.blue,
          )
        : Icon(
            Icons.arrow_upward,
            color: Colors.green,
          ),
    title: Text(
      event.method,
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Text(event.data.toString()),
  );
}

TextStyle _deltaTextStyler(Set<Attribution> attributions) {
  TextStyle newStyle = TextStyle(
    color: Colors.black,
    fontSize: 14,
  );

  if (attributions.contains(boldAttribution)) {
    newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
  }

  if (attributions.contains(_insertionOffsetAttribution)) {
    newStyle = newStyle.copyWith(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.bold,
    );
  }

  if (attributions.contains(_newTextAttribution)) {
    newStyle = newStyle.copyWith(
      decoration: TextDecoration.underline,
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );
  }

  if (attributions.contains(_textRemovedAttribution)) {
    newStyle = newStyle.copyWith(
      decoration: TextDecoration.underline,
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
  }

  return newStyle;
}

Widget _createTextWithSingleAttribution({
  String label = '',
  required String text,
  Attribution? attribution,
  TextRange? range,
  TextSelection? selection,
}) {
  final transposedSelection = selection != null //
      ? selection.copyWith(
          baseOffset: selection.baseOffset + label.length + 2,
          extentOffset: selection.extentOffset + label.length + 2,
        )
      : null;

  final spans = AttributedSpans()
    ..addAttribution(
      newAttribution: boldAttribution,
      start: 0,
      end: label.length,
    );

  if (attribution != null && range != null) {
    spans.addAttribution(
      newAttribution: attribution,
      start: range.start + label.length + 2,
      end: range.end + label.length + 1,
    );
  }

  return SuperTextWithSelection.single(
    richText: AttributedText(
      text: '$label: $text',
      spans: spans,
    ).computeTextSpan(_deltaTextStyler),
    userSelection: selection != null //
        ? UserSelection(
            selection: transposedSelection!,
            blinkCaret: false,
          )
        : null,
  );
}

const _insertionOffsetAttribution = const NamedAttribution('insertionOffset');
const _newTextAttribution = const NamedAttribution('newTextOffset');
const _textRemovedAttribution = const NamedAttribution('textRemovedAttribution');
