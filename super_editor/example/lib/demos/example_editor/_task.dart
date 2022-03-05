import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// This file includes everything needed to add the concept of a task
/// to Super Editor. This includes a new type of [DocumentNode] that
/// represents a task, a new visual component to render the task in the
/// document, ...
/// TODO: complete the documentation

/// [DocumentNode] that represents a task to complete.
///
/// A task can either be complete, or incomplete.
class TaskNode extends TextNode {
  TaskNode({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    required bool isComplete,
  })  : _isComplete = isComplete,
        super(id: id, text: text, metadata: metadata) {
    putMetadataValue("blockType", const NamedAttribution("task"));
  }

  bool get isComplete => _isComplete;
  bool _isComplete;
  set isComplete(bool newValue) {
    if (newValue == _isComplete) {
      return;
    }

    _isComplete = newValue;
    notifyListeners();
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is TaskNode && isComplete == other.isComplete && text == other.text;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is TaskNode && runtimeType == other.runtimeType && isComplete == other.isComplete;

  @override
  int get hashCode => super.hashCode ^ isComplete.hashCode;
}

Widget? taskComponentBuilder(
  SingleColumnDocumentComponentContext componentContext,
  SingleColumnLayoutComponentViewModel componentViewModel,
) {
  if (componentViewModel is! TaskComponentViewModel) {
    return null;
  }

  return TaskComponent(
    textKey: componentContext.componentKey,
    viewModel: componentViewModel,
  );
}

class TaskViewModelBuilder implements ComponentViewModelBuilder {
  const TaskViewModelBuilder();

  @override
  SingleColumnLayoutComponentViewModel? build(Document document, DocumentNode node) {
    if (node is! TaskNode) {
      return null;
    }

    return TaskComponentViewModel(
      nodeId: node.id,
      padding: EdgeInsets.zero,
      isComplete: node.isComplete,
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
      caretColor: const Color(0x00000000),
    );
  }
}

class TaskComponentViewModel extends SingleColumnLayoutComponentViewModel {
  TaskComponentViewModel({
    required String nodeId,
    double? maxWidth,
    required EdgeInsetsGeometry padding,
    required this.isComplete,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.selection,
    required this.selectionColor,
    required this.caretColor,
    this.caret,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  final bool isComplete;
  final AttributedText text;
  final AttributionStyleBuilder textStyleBuilder;
  final TextDirection textDirection;
  final TextSelection? selection;
  final Color selectionColor;
  final TextPosition? caret;
  final Color caretColor;
  final bool highlightWhenEmpty;

  TaskComponentViewModel copyWith({
    String? nodeId,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    bool? isComplete,
    AttributedText? text,
    AttributionStyleBuilder? textStyleBuilder,
    TextDirection? textDirection,
    TextSelection? selection,
    Color? selectionColor,
    TextPosition? caret,
    Color? caretColor,
    bool? highlightWhenEmpty,
  }) {
    return TaskComponentViewModel(
      nodeId: nodeId ?? this.nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      padding: padding ?? this.padding,
      isComplete: isComplete ?? this.isComplete,
      text: text ?? this.text,
      textStyleBuilder: textStyleBuilder ?? this.textStyleBuilder,
      textDirection: textDirection ?? this.textDirection,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
      highlightWhenEmpty: highlightWhenEmpty ?? this.highlightWhenEmpty,
    );
  }
}

class TaskComponent extends StatelessWidget {
  const TaskComponent({
    Key? key,
    required this.textKey,
    required this.viewModel,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final TaskComponentViewModel viewModel;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final textStyle = viewModel.textStyleBuilder({});
    final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.25);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: BoxDecoration(
            border: showDebugPaint ? Border.all(width: 1, color: Colors.grey) : null,
          ),
          child: SizedBox(
            height: lineHeight,
            child: Checkbox(
              value: false,
              onChanged: (newValue) {
                // TODO:
              },
            ),
          ),
        ),
        Expanded(
          child: TextComponent(
            key: textKey,
            text: viewModel.text,
            textStyleBuilder: viewModel.textStyleBuilder,
            textSelection: viewModel.selection,
            selectionColor: viewModel.selectionColor,
            showCaret: viewModel.caret != null,
            caretColor: viewModel.caretColor,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}
