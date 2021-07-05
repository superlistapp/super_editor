import 'package:example/demos/custom_elements/task_item.dart';
import 'package:example/demos/custom_elements/tasks_repository.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';

final _taskPattern = RegExp(r'^ {0,}<@\s*task:(.*?)\s*@>$');

class TaskSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => _taskPattern;

  const TaskSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current)!;
    final taskId = match[1]!.trim();
    parser.advance();

    return md.Element.withTag('task')..attributes['id'] = taskId;
  }
}

class TaskNodeVisitor implements CustomNodeVisitor {
  const TaskNodeVisitor(this._repository);
  final TasksRepository _repository;

  @override
  DocumentNode? visitElementBefore(md.Element element) {
    if (element.tag == 'task') {
      final taskId = element.attributes['id']!;
      return TaskItemNode(
        id: taskId,
        text: AttributedText(),
        changes: _repository.watchTaskById(taskId),
        update: _repository.updateTask,
      );
    }

    return null;
  }
}
