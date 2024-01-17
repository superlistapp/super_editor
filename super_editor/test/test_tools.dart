import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document_selection.dart';
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
    final dragGesture = await startGesture(startLocation);
    await dragContinuation(dragGesture, totalDragOffset, frameCount: frameCount);

    return dragGesture;
  }

  /// Simulates a user drag with an existing [gesture].
  ///
  /// This is useful, for example, when simulating multiple drags without the user
  /// lifting his finger.
  Future<void> dragContinuation(
    TestGesture dragGesture,
    Offset delta, {
    int frameCount = 10,
  }) async {
    final dragPerFrame = Offset(delta.dx / frameCount, delta.dy / frameCount);

    for (int i = 0; i < frameCount; i += 1) {
      await dragGesture.moveBy(dragPerFrame);
      await pump();
    }
  }
}

/// Compares two selections, ignoring selection affinities.
///
/// Some node positions, like [TextNodePosition], have a concept of affinity (upstream/downstream),
/// which is used when making particular selection decisions, but doesn't impact equivalency.
Matcher selectionEquivalentTo(DocumentSelection expectedSelection) => EquivalentSelectionMatcher(expectedSelection);

/// A [Matcher] that compares two selections, ignoring selection affinities.
///
/// Some node positions, like [TextNodePosition], have a concept of affinity (upstream/downstream),
/// which is used when making particular selection decisions, but doesn't impact equivalency.
class EquivalentSelectionMatcher extends Matcher {
  EquivalentSelectionMatcher(
    this.expectedSelection,
  );

  final DocumentSelection expectedSelection;

  @override
  Description describe(Description description) {
    return description.add("given selection is equivalent to expected selection");
  }

  @override
  bool matches(covariant Object target, Map<dynamic, dynamic> matchState) {
    return _calculateMismatchReason(target, matchState) == null;
  }

  @override
  Description describeMismatch(
    covariant Object target,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final mismatchReason = _calculateMismatchReason(target, matchState);
    if (mismatchReason != null) {
      mismatchDescription.add(mismatchReason);
    }
    return mismatchDescription;
  }

  String? _calculateMismatchReason(
    Object target,
    Map<dynamic, dynamic> matchState,
  ) {
    if (target is! DocumentSelection) {
      return "the given target isn't a DocumentSelection";
    }

    if (target.base.nodeId != expectedSelection.base.nodeId) {
      return "The selection doesn't start at the expected node.\nExpected: $expectedSelection\nActual: $target";
    }

    if (target.extent.nodeId != expectedSelection.extent.nodeId) {
      return "The selection doesn't end at the expected node.\nExpected: $expectedSelection\nActual: $target";
    }

    if (!target.base.nodePosition.isEquivalentTo(expectedSelection.base.nodePosition)) {
      // The base node positions aren't the same.
      return 'The selection starts at the correct node, but at a wrong position.\nExpected: $expectedSelection\nActual: $target';
    }

    if (!target.extent.nodePosition.isEquivalentTo(expectedSelection.extent.nodePosition)) {
      // The extent node positions aren't the same.
      return 'The selection ends at the correct node, but at a wrong position.\nExpected: $expectedSelection\nActual: $target';
    }

    return null;
  }
}
