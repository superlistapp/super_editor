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

/// Extensions on [State] that provide concise, convenient control over
/// common Flutter pipeline scheduling needs.
extension Frames on State {
  /// Runs the given [stateChange] within `setState()` as early as possible.
  ///
  /// Given that `setState()` is called, it can't be run during Flutter's
  /// build phase. If Flutter is currently in the middle of the build
  /// phase, another frame is scheduled, and [stateChange] is run after the
  /// current build phase completes. Otherwise, [stateChange] is run immediately.
  void setStateAsSoonAsPossible(VoidCallback stateChange) {
    WidgetsBinding.instance.runAsSoonAsPossible(
      () {
        if (!mounted) {
          return;
        }

        // ignore: invalid_use_of_protected_member
        setState(() {
          stateChange();
        });
      },
    );
  }

  /// Runs the given [work] in a post-frame callback, but only if the [State]
  /// is still `mounted`.
  void onNextFrame(void Function(Duration timeStamp) work) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }

      // Do the work.
      work(timeStamp);
    });
  }

  /// Adds a post-frame callback, which then calls `setState()` to trigger
  /// another build, which is useful when you discover during a build that
  /// you need another build immediately.
  ///
  /// Discovering that you need another build during a build is typically
  /// the result of what we call the "extra frame problem". Some piece of
  /// information is unavailable until layout has run, which then reveals
  /// that you need to adjust other widgets, resulting in the need to schedule
  /// another build. Consider things like drag handles, a magnifier, or a
  /// toolbar, which follow the user's selection.
  ///
  /// Developers should be very careful when using this method because it can
  /// easily cause infinite rebuilds. It must only be called in conditionals that
  /// won't be triggered on every frame. Otherwise, every frame will schedule
  /// another frame and the pipeline will never go idle.
  ///
  /// This method may be called with, or without state changes:
  ///
  ///     scheduleBuildAfterBuild();
  ///
  ///     schedulerBuildAfterBuild(() {
  ///       myVar1 = "Hello";
  ///       myVar2 = "World";
  ///     });
  ///
  void scheduleBuildAfterBuild([VoidCallback? stateChange]) {
    onNextFrame((_) {
      // ignore: invalid_use_of_protected_member
      setState(() {
        stateChange?.call();
      });
    });
  }
}
