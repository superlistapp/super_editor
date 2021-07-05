import 'dart:async';

import 'package:example/demos/custom_elements/task.dart';

class TasksRepository {
  const TasksRepository();

  static final _tasksById = <String, Task>{
    'aaa111': const Task(id: 'aaa111', checked: true, text: 'First task.'),
    'bbb222': const Task(id: 'bbb222', checked: false, text: 'Second task.'),
    'ccc333': const Task(
      id: 'ccc333',
      checked: true,
      text: 'Third task. Look, I\'m nested!',
      indent: 1,
    ),
    'ddd444': const Task(
      id: 'ddd444',
      checked: true,
      text: 'Fourth task. Look, I\'m even more nested!',
      indent: 2,
    ),
    'toggling-all-the-time': const Task(
      id: 'toggling-all-the-time',
      checked: false,
      text: "I'm the task that is constantly toggling its checked state all the time.",
    ),
  };

  static final _subscriptions = <String, StreamController<Task>>{};

  Stream<Task> watchTaskById(String id) {
    _subscriptions.putIfAbsent(id, () => StreamController.broadcast());
    return _subscriptions[id]!.stream.transform(_StartWithTransformer(_tasksById[id]!));
  }

  Future<Task?> getTaskById(String id) async => _tasksById[id]!;

  void updateTask(Task task) {
    _tasksById[task.id] = task;
    _subscriptions[task.id]!.add(task);
  }
}

class _StartWithTransformer extends StreamTransformerBase<Task, Task> {
  _StartWithTransformer(this.lastValue);
  final Task lastValue;

  @override
  Stream<Task> bind(Stream<Task> stream) {
    return StreamTransformer<Task, Task>((input, cancelOnError) {
      late final StreamController<Task> controller;
      late final StreamSubscription<Task> subscription;

      controller = StreamController<Task>(
        sync: true,
        onListen: () {
          controller.add(lastValue);
          subscription = input.listen(
            controller.add,
            onDone: () => controller.close(),
          );
        },
        onPause: ([resumeSignal]) => subscription.pause(resumeSignal),
        onResume: () => subscription.resume(),
        onCancel: () => subscription.cancel(),
      );

      return controller.stream.listen(null);
    }).bind(stream);
  }
}
