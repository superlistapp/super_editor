import 'package:example/demos/custom_elements/checkbox_list_item.dart';
import 'package:example/demos/custom_elements/tasks_repository.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';

class CustomVisitor implements CustomMarkdownVisitor {
  const CustomVisitor(this._repository);
  final TasksRepository _repository;

  @override
  DocumentNode? visitElementBefore(md.Element element) {
    switch (element.tag) {
      case 'task':
        final taskId = element.attributes['id']!;
        return CheckBoxListItemNode(
          id: taskId,
          changes: _repository.watchTaskById(taskId),
          update: _repository.updateTask,
        );
    }

    return null;
  }
}

final _taskPattern = RegExp(r'^ {0,3}<@\s*task:(.*?)\s*@>$');

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
