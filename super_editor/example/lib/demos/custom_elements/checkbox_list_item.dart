import 'dart:async';

import 'package:example/demos/custom_elements/task.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class CheckBoxListItemNode extends ListItemNode {
  CheckBoxListItemNode({
    required String id,
    required Stream<Task> changes,
    required ValueSetter<Task> update,
    Map<String, dynamic>? metadata,
  })  : _update = update,
        super(
          id: id,
          itemType: ListItemType.unordered,
          text: AttributedText(),
          metadata: metadata,
        ) {
    _subscription = changes.listen((task) {
      _task = task;
      notifyListeners();
    });
  }

  final ValueSetter<Task> _update;
  late StreamSubscription<Task> _subscription;

  Task? _task;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  AttributedText get text => AttributedText(text: _task?.text ?? '');

  @override
  set text(AttributedText value) {
    final task = _task;
    if (task != null) {
      _update(task.copyWith(text: value.text));
    }
  }

  @override
  int get indent => _task?.indent ?? 0;

  @override
  set indent(int value) {
    final task = _task;
    if (task != null) {
      _update(task.copyWith(indent: value));
    }
  }

  bool get checked => _task?.checked ?? false;
  set checked(bool value) {
    final task = _task;
    if (task != null) {
      _update(task.copyWith(checked: value));
    }
  }

  @override
  bool hasEquivalentContent(Object other) =>
      other is CheckBoxListItemNode && checked == other.checked && indent == other.indent;
}

class CheckBoxListItemComponent extends StatelessWidget {
  const CheckBoxListItemComponent({
    Key? key,
    required this.textKey,
    required this.checked,
    required this.text,
    required this.styleBuilder,
    this.indent = 0,
    this.indentExtent = 25,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.showDebugPaint = false,
    required this.onChanged,
  }) : super(key: key);

  final GlobalKey textKey;
  final bool checked;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final int indent;
  final double indentExtent;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool showDebugPaint;
  final ValueChanged<bool> onChanged;

  void _handleValueChanged(bool? value) {
    if (value != null) {
      onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indentSpace = indentExtent * (indent + 1);

    return Row(
      children: [
        SizedBox(width: indentSpace),
        Checkbox(value: checked, onChanged: _handleValueChanged),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextComponent(
              key: textKey,
              text: text,
              textStyleBuilder: styleBuilder,
              textSelection: textSelection,
              selectionColor: selectionColor,
              showCaret: showCaret,
              caretColor: caretColor,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ),
      ],
    );
  }
}

Widget? checkBoxListItemBuilder(ComponentContext componentContext) {
  final node = componentContext.documentNode;
  if (node is! CheckBoxListItemNode) {
    return null;
  }

  final textSelection = componentContext.nodeSelection?.nodeSelection as TextSelection?;
  final showCaret = componentContext.showCaret && (componentContext.nodeSelection?.isExtent ?? false);

  return CheckBoxListItemComponent(
    textKey: componentContext.componentKey,
    checked: node.checked,
    text: node.text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    onChanged: (value) => node.checked = value,
    indent: node.indent,
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    showCaret: showCaret,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
  );
}
