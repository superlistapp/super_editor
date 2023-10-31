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
  /// Drags from the [startLocation] by [dragAmount] in multiple frames.
  ///
  /// The [dragAmount] is distributed evenly between [frameCount] frames.
  ///
  /// The caller must end the gesture by calling [TestGesture.up].
  Future<TestGesture> dragInMultipleFrames({
    required Offset startLocation,
    required Offset dragAmount,
    required int frameCount,
  }) async {
    final dragPerFrame = Offset(dragAmount.dx / frameCount, dragAmount.dy / frameCount);

    final dragGesture = await startGesture(startLocation);
    for (int i = 0; i < frameCount; i += 1) {
      await dragGesture.moveBy(dragPerFrame);
      await pump();
    }

    return dragGesture;
  }
}
