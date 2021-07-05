import 'dart:async';

import 'package:example/demos/custom_elements/task.dart';

class TasksRepository {
  final _tasksById = <String, Task>{};
  final _individualTaskControllers = <String, StreamController<Task?>>{};
  final _allTasksController = StreamController<List<Task>>.broadcast();

  Future<void> insertAll(Iterable<Task> tasks) async {
    _tasksById.addAll(Map.fromEntries(tasks.map((e) => MapEntry(e.id, e))));
    _allTasksController.add(_tasksById.values.toList());

    for (final task in tasks) {
      _individualTaskControllers[task.id]?.add(task);
    }
  }

  Future<void> insert(Task task) async {
    _tasksById[task.id] = task;
    _individualTaskControllers[task.id]?.add(task);
    _allTasksController.add(_tasksById.values.toList());
  }

  Stream<Task?> watchTaskById(String id) {
    _individualTaskControllers.putIfAbsent(id, () => StreamController<Task?>.broadcast());
    return _individualTaskControllers[id]!.stream.transform(_StartWithTransformer(_tasksById[id]));
  }

  Stream<List<Task>> watchAllTasks() =>
      _allTasksController.stream.transform(_StartWithTransformer<List<Task>>(_tasksById.values.toList()));

  Future<Task?> getTaskById(String id) async => _tasksById[id];

  Future<void> updateTask(Task task) async {
    _tasksById[task.id] = task;
    _individualTaskControllers[task.id]?.add(task);
    _allTasksController.add(_tasksById.values.toList());
  }

  Future<void> deleteTask(Task task) async {
    _tasksById.remove(task.id);
    _individualTaskControllers[task.id]?.add(null);
    _allTasksController.add(_tasksById.values.toList());
  }
}

class _StartWithTransformer<T> extends StreamTransformerBase<T, T> {
  _StartWithTransformer(this.lastValue);
  final T lastValue;

  @override
  Stream<T> bind(Stream<T> stream) {
    return StreamTransformer<T, T>((input, cancelOnError) {
      late final StreamController<T> controller;
      late final StreamSubscription<T> subscription;

      controller = StreamController<T>(
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
