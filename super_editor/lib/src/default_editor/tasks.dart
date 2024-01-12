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
      Styles.padding: const CascadingPadding.only(top: 24),
    };
  },
);

/// Builds [TaskComponentViewModel]s and [TaskComponent]s for every
/// [TaskNode] in a document.
class TaskComponentBuilder implements ComponentBuilder {
  TaskComponentBuilder(this._editor);

  final Editor _editor;

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
        _editor.execute([
          ChangeTaskCompletionRequest(
            nodeId: node.id,
            isComplete: isComplete,
          ),
        ]);
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
    this.composingRegion,
    this.showComposingUnderline = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  bool isComplete;
  void Function(bool) setComplete;

  @override
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
  TextRange? composingRegion;
  @override
  bool showComposingUnderline;

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
      composingRegion: composingRegion,
      showComposingUnderline: showComposingUnderline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TaskComponentViewModel &&
          runtimeType == other.runtimeType &&
          isComplete == other.isComplete &&
          text == other.text &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          highlightWhenEmpty == other.highlightWhenEmpty &&
          composingRegion == other.composingRegion &&
          showComposingUnderline == other.showComposingUnderline;

  @override
  int get hashCode =>
      super.hashCode ^
      isComplete.hashCode ^
      text.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      highlightWhenEmpty.hashCode ^
      composingRegion.hashCode ^
      showComposingUnderline.hashCode;
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

  /// Computes the [TextStyle] for this task's inner [TextComponent].
  TextStyle _computeStyles(Set<Attribution> attributions) {
    // Show a strikethrough across the entire task if it's complete.
    final style = widget.viewModel.textStyleBuilder(attributions);
    return widget.viewModel.isComplete
        ? style.copyWith(
            decoration: style.decoration == null
                ? TextDecoration.lineThrough
                : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
          )
        : style;
  }

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
            textStyleBuilder: _computeStyles,
            textSelection: widget.viewModel.selection,
            selectionColor: widget.viewModel.selectionColor,
            highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
            composingRegion: widget.viewModel.composingRegion,
            showComposingUnderline: widget.viewModel.showComposingUnderline,
            showDebugPaint: widget.showDebugPaint,
          ),
        ),
      ],
    );
  }
}

ExecutionInstruction enterToInsertNewTask({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

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
  final node = editContext.document.getNodeById(selection.extent.nodeId);
  if (node is! TaskNode) {
    return ExecutionInstruction.continueExecution;
  }

  final splitOffset = (selection.extent.nodePosition as TextNodePosition).offset;

  editContext.editor.execute([
    SplitExistingTaskRequest(
      existingNodeId: node.id,
      splitOffset: splitOffset,
    ),
  ]);

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction backspaceToConvertTaskToParagraph({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! TaskNode) {
    return ExecutionInstruction.continueExecution;
  }

  if ((editContext.composer.selection!.extent.nodePosition as TextPosition).offset > 0) {
    // The selection isn't at the beginning.
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.execute([
    DeleteUpstreamAtBeginningOfNodeRequest(node),
  ]);

  return ExecutionInstruction.haltExecution;
}

class ChangeTaskCompletionRequest implements EditRequest {
  ChangeTaskCompletionRequest({required this.nodeId, required this.isComplete});

  final String nodeId;
  final bool isComplete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeTaskCompletionRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          isComplete == other.isComplete;

  @override
  int get hashCode => nodeId.hashCode ^ isComplete.hashCode;
}

class ChangeTaskCompletionCommand implements EditCommand {
  ChangeTaskCompletionCommand({required this.nodeId, required this.isComplete});

  final String nodeId;
  final bool isComplete;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final taskNode = context.find<MutableDocument>(Editor.documentKey).getNodeById(nodeId);
    if (taskNode is! TaskNode) {
      return;
    }

    taskNode.isComplete = isComplete;

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(nodeId),
      ),
    ]);
  }
}

class ConvertParagraphToTaskRequest implements EditRequest {
  const ConvertParagraphToTaskRequest({
    required this.nodeId,
    this.isComplete = false,
  });

  final String nodeId;
  final bool isComplete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvertParagraphToTaskRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          isComplete == other.isComplete;

  @override
  int get hashCode => nodeId.hashCode ^ isComplete.hashCode;
}

class ConvertParagraphToTaskCommand implements EditCommand {
  const ConvertParagraphToTaskCommand({
    required this.nodeId,
    this.isComplete = false,
  });

  final String nodeId;
  final bool isComplete;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
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

    executor.executeCommand(
      ReplaceNodeCommand(existingNodeId: existingNode.id, newNode: taskNode),
    );
  }
}

class ConvertTaskToParagraphCommand implements EditCommand {
  const ConvertTaskToParagraphCommand({
    required this.nodeId,
    this.paragraphMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? paragraphMetadata;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final taskNode = node as TaskNode;
    final newMetadata = Map<String, dynamic>.from(paragraphMetadata ?? {});
    newMetadata["blockType"] = paragraphAttribution;

    final newParagraphNode = ParagraphNode(
      id: taskNode.id,
      text: taskNode.text,
      metadata: newMetadata,
    );
    document.replaceNode(oldNode: taskNode, newNode: newParagraphNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(taskNode.id),
      )
    ]);
  }
}

class SplitExistingTaskRequest implements EditRequest {
  const SplitExistingTaskRequest({
    required this.existingNodeId,
    required this.splitOffset,
    this.newNodeId,
  });

  final String existingNodeId;
  final int splitOffset;
  final String? newNodeId;
}

class SplitExistingTaskCommand implements EditCommand {
  const SplitExistingTaskCommand({
    required this.nodeId,
    required this.splitOffset,
    this.newNodeId,
  });

  final String nodeId;
  final int splitOffset;
  final String? newNodeId;

  @override
  void execute(EditContext editContext, CommandExecutor executor) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    final selection = composer.selection;

    // We only care when the caret sits at the end of a TaskNode.
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    // We only care about TaskNodes.
    final node = document.getNodeById(selection.extent.nodeId);
    if (node is! TaskNode) {
      return;
    }

    // Ensure the split offset is valid.
    if (splitOffset < 0 || splitOffset > node.text.length + 1) {
      return;
    }

    final newTaskNode = TaskNode(
      id: newNodeId ?? Editor.createNodeId(),
      text: node.text.copyText(splitOffset),
      isComplete: false,
    );

    // Remove the text after the caret from the currently selected TaskNode.
    node.text = node.text.removeRegion(startOffset: splitOffset, endOffset: node.text.length);

    // Insert a new TextNode after the currently selected TaskNode.
    document.insertNodeAfter(existingNode: node, newNode: newTaskNode);

    // Move the caret to the beginning of the new TaskNode.
    final oldSelection = composer.selection;
    final oldComposingRegion = composer.composingRegion.value;
    final newSelection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newTaskNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );

    composer.setSelectionWithReason(newSelection, SelectionReason.userInteraction);
    composer.setComposingRegion(null);

    executor.logChanges([
      SplitTaskIntention.start(),
      DocumentEdit(
        NodeChangeEvent(node.id),
      ),
      DocumentEdit(
        NodeInsertedEvent(newTaskNode.id, document.getNodeIndexById(newTaskNode.id)),
      ),
      SelectionChangeEvent(
        oldSelection: oldSelection,
        newSelection: newSelection,
        changeType: SelectionChangeType.pushCaret,
        reason: SelectionReason.userInteraction,
      ),
      ComposingRegionChangeEvent(
        oldComposingRegion: oldComposingRegion,
        newComposingRegion: null,
      ),
      SplitTaskIntention.end(),
    ]);
  }
}

class SplitTaskIntention extends Intention {
  SplitTaskIntention.start() : super.start();

  SplitTaskIntention.end() : super.end();
}
