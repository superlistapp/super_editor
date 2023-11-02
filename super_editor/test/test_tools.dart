import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/links.dart';

/// A [UrlLauncher] that logs each attempt to launch a URL, but doesn't
/// attempt to actually launch the URLs.
class TestUrlLauncher implements UrlLauncher {
  final _urlLaunchLog = <Uri>[];

  List<Uri> get urlLaunchLog => _urlLaunchLog;

  void clearUrlLaunchLog() => _urlLaunchLog.clear();

  @override
  Future<bool> launchUrl(Uri url) async {
    _urlLaunchLog.add(url);
    return true;
  }
}

/// Extension on [WidgetTester] to make it easier to perform drag gestures.
extension DragExtensions on WidgetTester {
  /// Simulates a user drag from [startLocation] to `startLocation + totalDragOffset`.
  ///
  /// Starts a gesture at [startLocation] and repeatedly drags the gesture
  /// across [frameCount] frames, pumping a frame between each drag.
  /// The gesture moves a distance each frame that's calculated as
  /// `totalDragOffset / frameCount`.
  ///
  /// This method does not call `pumpAndSettle()`, so that the client can inspect
  /// the app state immediately after the drag completes.
  ///
  /// The client must call [TestGesture.up] on the returned [TestGesture].
  Future<TestGesture> dragByFrameCount({
    required Offset startLocation,
    required Offset totalDragOffset,
    int frameCount = 10,
  }) async {
    final dragPerFrame = Offset(totalDragOffset.dx / frameCount, totalDragOffset.dy / frameCount);

    final dragGesture = await startGesture(startLocation);
    for (int i = 0; i < frameCount; i += 1) {
      await dragGesture.moveBy(dragPerFrame);
      await pump();
    }

    return dragGesture;
  }
}
