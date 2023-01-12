import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// This file includes everything needed to add the concept of a task
/// to Super Editor. This includes:
///
///  * [TaskNode], which represents a logical task.
///  * [TaskComponentViewModel], which configures the visual appearance
///    of a task in a document.
///  * [taskStyles], which applies desired styles to tasks in a document.
///  * [TaskComponentBuilder], which creates new [TaskComponentViewModel]s
///    and [TaskComponent]s, for every [TaskNode] in the document.
///  * [TaskComponent], which renders a task in a document.

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
    // Set a block type so that TaskNode's can be styled by
    // StyleRule's.
    putMetadataValue("blockType", const NamedAttribution("task"));
  }

  /// Whether this task is complete.
  bool get isComplete => _isComplete;
  bool _isComplete;
  set isComplete(bool newValue) {
    if (newValue == _isComplete) {
      return;
    }

    _isComplete = newValue;
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

class CompleteTaskRequest implements EditorRequest {
  CompleteTaskRequest({
    required this.nodeId,
  });

  final String nodeId;
}

class CompleteTaskCommand implements EditorCommand {
  CompleteTaskCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(EditorContext.document);
    (document.getNodeById(nodeId) as TaskNode).isComplete = true;
    executor.logChanges([NodeChangeEvent(nodeId)]);
  }
}

/// Styles all task components to apply top padding
final taskStyles = StyleRule(
  const BlockSelector("task"),
  (document, node) {
    if (node is! TaskNode) {
      return {};
    }

    return {
      "padding": const CascadingPadding.only(top: 24),
    };
  },
);

/// Builds [TaskComponentViewModel]s and [TaskComponent]s for every
/// [TaskNode] in a document.
class TaskComponentBuilder implements ComponentBuilder {
  TaskComponentBuilder(this._editor);

  final DocumentEditor _editor;

  @override
  TaskComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! TaskNode) {
      return null;
    }

    return TaskComponentViewModel(
      nodeId: node.id,
      padding: EdgeInsets.zero,
      isComplete: node.isComplete,
      setComplete: (bool isComplete) {
        _editor.execute(CompleteTaskRequest(nodeId: node.id));
      },
      text: node.text,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! TaskComponentViewModel) {
      return null;
    }

    return TaskComponent(
      textKey: componentContext.componentKey,
      viewModel: componentViewModel,
    );
  }
}

/// View model that configures the appearance of a [TaskComponent].
///
/// View models move through various style phases, which fill out
/// various properties in the view model. For example, one phase applies
/// all [StyleRule]s, and another phase configures content selection
/// and caret appearance.
class TaskComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  TaskComponentViewModel({
    required String nodeId,
    double? maxWidth,
    required EdgeInsetsGeometry padding,
    required this.isComplete,
    required this.setComplete,
    required this.text,
    TextComponentTextStyles? textStyler,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding) {
    if (textStyler != null) {
      super.textStyler = textStyler;
    }
  }

  bool isComplete;
  void Function(bool) setComplete;

  @override
  AttributedText text;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  @override
  TaskComponentViewModel copy() {
    return TaskComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      isComplete: isComplete,
      setComplete: setComplete,
      text: text,
      textStyler: textStyler,
      textDirection: textDirection,
      selection: selection,
      selectionColor: selectionColor,
      highlightWhenEmpty: highlightWhenEmpty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TaskComponentViewModel &&
          runtimeType == other.runtimeType &&
          isComplete == other.isComplete &&
          setComplete == other.setComplete &&
          isTextViewModelEquivalent(other);

  @override
  int get hashCode => super.hashCode ^ isComplete.hashCode ^ setComplete.hashCode ^ textHashCode;
}

/// A document component that displays a complete-able task.
///
/// This is the widget that appears in the document layout for
/// an individual task. This widget includes a checkbox that the
/// user can tap to toggle the completeness of the task.
///
/// The appearance of a [TaskComponent] is configured by the given
/// [viewModel].
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Checkbox(
            value: viewModel.isComplete,
            onChanged: (newValue) {
              viewModel.setComplete(newValue!);
            },
          ),
        ),
        Expanded(
          child: TextComponent(
            key: textKey,
            text: viewModel.text,
            textStyleBuilder: (attributions) {
              // Show a strikethrough across the entire task if it's complete.
              final style = viewModel.textStyleBuilder(attributions);
              return viewModel.isComplete
                  ? style.copyWith(
                      decoration: style.decoration == null
                          ? TextDecoration.lineThrough
                          : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
                    )
                  : style;
            },
            textSelection: viewModel.selection,
            selectionColor: viewModel.selectionColor,
            highlightWhenEmpty: viewModel.highlightWhenEmpty,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}
