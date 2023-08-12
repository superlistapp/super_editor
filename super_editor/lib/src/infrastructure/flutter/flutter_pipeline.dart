import 'package:flutter/widgets.dart';

/// Extensions on [State] that provide concise, convenient control over
/// common Flutter pipeline scheduling needs.
extension Frames on State {
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
  /// easily cause infinite rebuilds. It must only called in conditionals that
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
      setState(() {
        stateChange?.call();
      });
    });
  }
}
