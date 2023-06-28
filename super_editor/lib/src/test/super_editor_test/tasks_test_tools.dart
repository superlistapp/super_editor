import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';

/// Queries the state of [TaskComponent]s in a [SuperEditor].
class TaskInspector {
  TaskInspector._();

  static bool isChecked(String nodeId, [Finder? superEditorFinder]) {
    final checkbox = _findTaskCheckbox(nodeId, superEditorFinder);
    return checkbox.value == true;
  }
}

/// Extension on [WidgetTester] that interacts with [TaskComponent]s in a [SuperEditor].
extension TaskRobot on WidgetTester {
  Future<void> tapOnCheckbox(String nodeId, [Finder? superEditorFinder]) async {
    final checkbox = _findTaskCheckbox(nodeId, superEditorFinder);
    await tap(find.byWidget(checkbox));
    await pumpAndSettle();
  }
}

TaskComponent _findTaskComponent(String nodeId, [Finder? superEditorFinder]) {
  return SuperEditorInspector.findWidgetForComponent(nodeId, superEditorFinder) as TaskComponent;
}

Checkbox _findTaskCheckbox(String nodeId, [Finder? superEditorFinder]) {
  final taskWidget = _findTaskComponent(nodeId, superEditorFinder);

  final checkboxes = find.descendant(of: find.byWidget(taskWidget), matching: find.byType(Checkbox)).evaluate();
  assert(checkboxes.isNotEmpty, "Couldn't find the Checkbox widget within a task widget with node ID: $nodeId");
  assert(checkboxes.length == 1,
      "Found multiple Checkbox widgets within a task widget. We don't know which one to use. Node id: $nodeId");
  return checkboxes.first.widget as Checkbox;
}
