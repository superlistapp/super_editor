import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' hide DragGestureRecognizer;

import 'package:super_editor/src/infrastructure/flutter/monodrag.dart';

/// Recognizes movement both horizontally and vertically.
///
/// Flutter's `PanGestureRecognizer` loses the gesture arena if there
/// is a `VerticalDragGestureRecognizer` in the tree.
///
/// This recognizer uses the same minimum distance as the `VerticalDragGestureRecognizer`
/// to accept a gesture
class EagerPanGestureRecognizer extends DragGestureRecognizer {
  EagerPanGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  bool Function()? canAccept;

  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
    return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity &&
        estimate.offset.distanceSquared > minDistance * minDistance;
  }

  @override
  void acceptGesture(int pointer) {
    if (canAccept?.call() ?? true) {
      super.acceptGesture(pointer);
    }
  }

  @override
  DragEndDetails? considerFling(VelocityEstimate estimate, PointerDeviceKind kind) {
    if (!isFlingGesture(estimate, kind)) {
      return null;
    }
    final maxVelocity = maxFlingVelocity ?? kMaxFlingVelocity;
    final dy = clampDouble(estimate.pixelsPerSecond.dy, -maxVelocity, maxVelocity);
    return DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(0, dy)),
      primaryVelocity: dy,
      globalPosition: finalPosition.global,
      localPosition: finalPosition.local,
    );
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    // Flutter's PanGestureRecognizer uses the pan slop, which is twice bigger than the hit slop,
    // to determine if the gesture should be accepted. Use the same distance used by the
    // VerticalDragGestureRecognizer.
    final res = globalDistanceMoved.abs() > computeHitSlop(pointerDeviceKind, gestureSettings);
    if (res && canAccept != null) {
      return canAccept!();
    } else {
      return res;
    }
  }

  @override
  Offset getDeltaForDetails(Offset delta) => delta;

  @override
  double? getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'pan';
}
