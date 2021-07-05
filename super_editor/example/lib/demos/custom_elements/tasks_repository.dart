import 'dart:async';

import 'package:example/demos/custom_elements/task.dart';

class TasksRepository {
  const TasksRepository();

  static final _tasksById = <String, Task>{};
  static final _subscriptions = <String, StreamController<Task>>{};

  Future<void> insertAll(Iterable<Task> tasks) async =>
      _tasksById.addAll(Map.fromEntries(tasks.map((e) => MapEntry(e.id, e))));

  Stream<Task?> watchTaskById(String id) {
    _subscriptions.putIfAbsent(id, () => StreamController.broadcast());
    return _subscriptions[id]!.stream.transform(_StartWithTransformer(_tasksById[id]));
  }

  Future<Task?> getTaskById(String id) async => _tasksById[id];

  void updateTask(Task task) {
    _tasksById[task.id] = task;
    _subscriptions[task.id]!.add(task);
  }
}

class _StartWithTransformer extends StreamTransformerBase<Task, Task?> {
  _StartWithTransformer(this.lastValue);
  final Task? lastValue;

  @override
  Stream<Task?> bind(Stream<Task?> stream) {
    return StreamTransformer<Task?, Task?>((input, cancelOnError) {
      late final StreamController<Task?> controller;
      late final StreamSubscription<Task?> subscription;

      controller = StreamController<Task?>(
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
