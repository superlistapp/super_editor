import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

extension Scheduler on WidgetsBinding {
  /// Runs the given [action] as soon as possible, given the status of Flutter's pipeline.
  ///
  /// Flutter throws an error if a widget ever calls `setState()` while widget building
  /// is already underway. This can happen when an [action] sends signals that might cause
  /// a widget to call `setState()`. For example, setting a value on a `ValueNotifier`
  /// might trigger a `ListenableBuilder` to rebuild somewhere else in the tree. As a
  /// result, if code sets the value on a `ValueNotifier` during Flutter's build phase,
  /// Flutter will crash. This extension helps avoid such a crash.
  ///
  /// When [runAsSoonAsPossible] is called *outside* of a Flutter build phase, [action]
  /// is executed immediately.
  ///
  /// When [runAsSoonAsPossible] is called *during* a Flutter build phase, [action] is
  /// executed at the end of the current frame with [addPostFrameCallback].
  void runAsSoonAsPossible(VoidCallback action, {String debugLabel = "anonymous action"}) {
    schedulerLog.info("Running action as soon as possible: '$debugLabel'.");
    if (schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // The Flutter pipeline is in the middle of a build phase. Schedule the desired
      // action for the end of the current frame.
      schedulerLog.info("Scheduling another frame to run '$debugLabel' because Flutter is building widgets right now.");
      addPostFrameCallback((timeStamp) {
        schedulerLog.info("Flutter is done building widgets. Running '$debugLabel' at the end of the frame.");
        action();
      });
    } else {
      // The Flutter pipeline isn't building widgets right now. Execute the action
      // immediately.
      schedulerLog.info("Flutter isn't building widgets right now. Running '$debugLabel' immediately.");
      action();
    }
  }
}
