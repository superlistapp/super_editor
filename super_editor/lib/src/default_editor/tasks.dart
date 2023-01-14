import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        _editor.executeCommand(EditorCommandFunction((document, transaction) {
          // Technically, this line could be called without the editor, but
          // that's only because Super Editor hasn't fully separated document
          // queries from document edits. In the future, all edits will have
          // to go through a dedicated editing interface.
          node.isComplete = isComplete;
        }));
      },
      text: node.text,
      textStyleBuilder: noStyleBuilder,
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
      key: componentContext.componentKey,
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
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  bool isComplete;
  void Function(bool) setComplete;
  AttributedText text;

  @override
  AttributionStyleBuilder textStyleBuilder;
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
      textStyleBuilder: textStyleBuilder,
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
          text == other.text &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          highlightWhenEmpty == other.highlightWhenEmpty;

  @override
  int get hashCode =>
      super.hashCode ^
      isComplete.hashCode ^
      setComplete.hashCode ^
      text.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      highlightWhenEmpty.hashCode;
}

/// A document component that displays a complete-able task.
///
/// This is the widget that appears in the document layout for
/// an individual task. This widget includes a checkbox that the
/// user can tap to toggle the completeness of the task.
///
/// The appearance of a [TaskComponent] is configured by the given
/// [viewModel].
class TaskComponent extends StatefulWidget {
  const TaskComponent({
    Key? key,
    required this.viewModel,
    this.showDebugPaint = false,
  }) : super(key: key);

  final TaskComponentViewModel viewModel;
  final bool showDebugPaint;

  @override
  State<TaskComponent> createState() => _TaskComponentState();
}

class _TaskComponentState extends State<TaskComponent> with ProxyDocumentComponent<TaskComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable => childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Checkbox(
            value: widget.viewModel.isComplete,
            onChanged: (newValue) {
              widget.viewModel.setComplete(newValue!);
            },
          ),
        ),
        Expanded(
          child: TextComponent(
            key: _textKey,
            text: widget.viewModel.text,
            textStyleBuilder: (attributions) {
              // Show a strikethrough across the entire task if it's complete.
              final style = widget.viewModel.textStyleBuilder(attributions);
              return widget.viewModel.isComplete
                  ? style.copyWith(
                      decoration: style.decoration == null
                          ? TextDecoration.lineThrough
                          : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
                    )
                  : style;
            },
            textSelection: widget.viewModel.selection,
            selectionColor: widget.viewModel.selectionColor,
            highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
            showDebugPaint: widget.showDebugPaint,
          ),
        ),
      ],
    );
  }
}

ExecutionInstruction enterToInsertNewTask({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  // We only care about ENTER.
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }

  // We only care when the selection is collapsed to a caret.
  final selection = editContext.composer.selection;
  if (selection == null || !selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  // We only care about TaskNodes.
  final node = editContext.editor.document.getNodeById(selection.extent.nodeId);
  if (node is! TaskNode) {
    return ExecutionInstruction.continueExecution;
  }

  // The document selection is a caret sitting at the end of a TaskNode.
  // Insert a new TaskNode below the current TaskNode, and move the caret down.
  editContext.editor.executeCommand(
    InsertNewTaskOrSplitExistingTaskCommand(editContext.composer),
  );

  return ExecutionInstruction.haltExecution;
}

class ConvertParagraphToTaskCommand implements EditorCommand {
  const ConvertParagraphToTaskCommand({
    required this.nodeId,
    this.isCompleted = false,
  });

  final String nodeId;
  final bool isCompleted;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final existingNode = document.getNodeById(nodeId);
    if (existingNode is! ParagraphNode) {
      editorOpsLog.warning(
          "Tried to convert ParagraphNode with ID '$nodeId' to TaskNode, but that node has the wrong type: ${existingNode.runtimeType}");
      return;
    }

    final taskNode = TaskNode(
      id: existingNode.id,
      text: existingNode.text,
      isComplete: false,
    );

    transaction.replaceNode(oldNode: existingNode, newNode: taskNode);
  }
}

class InsertNewTaskOrSplitExistingTaskCommand implements EditorCommand {
  const InsertNewTaskOrSplitExistingTaskCommand(this._composer);

  final DocumentComposer _composer;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final selection = _composer.selection;

    // We only care when the caret sits at the end of a TaskNode.
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    // We only care about TaskNodes.
    final node = document.getNodeById(selection.extent.nodeId);
    if (node is! TaskNode) {
      return;
    }

    // Split the task text at the caret, moving everything after the caret down to the
    // new TaskNode.
    //
    // If the caret sits at the end of the task text, then this behavior is equivalent
    // to inserting a new, empty TaskNode after the current TaskNode.
    final selectionTextOffset = (selection.extent.nodePosition as TextNodePosition).offset;
    final newTaskNode = TaskNode(
      id: DocumentEditor.createNodeId(),
      text: node.text.copyText(selectionTextOffset),
      isComplete: false,
    );
    node.text = node.text.removeRegion(startOffset: selectionTextOffset, endOffset: node.text.text.length);

    transaction.insertNodeAfter(existingNode: node, newNode: newTaskNode);

    _composer.selectionNotifier.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newTaskNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );
  }
}
