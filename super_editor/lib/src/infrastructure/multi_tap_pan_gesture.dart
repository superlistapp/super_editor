import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

///The callback for multiple taps on a gesture
///only adds a [count] parameter based on [GestureTapDragDownCallback].
typedef GestureMultiTapDownCallback = Function(TapDragDownDetails details, int count);

///The callback for multiple releases on a gesture
///only adds a [count] parameter based on [GestureTapDragUpCallback].
typedef GestureMultiTapUpCallback = Function(TapDragUpDetails details, int count);

///Detection for multiple taps.
class MultiTapAndPanGesture extends TapAndPanGestureRecognizer {
  MultiTapAndPanGesture({
    super.debugOwner,
    super.supportedDevices,
  }) {
    onTapDown = _onTapDown;
    onTapUp = _onTapUp;
  }

  ///From the perspective of code implementation,
  ///[onMultiTapDown] is just a wrapper for [onTapDown].
  ///When using it, you can only choose one of the two callbacks - [onMultiTapDown] and [onTapDown].
  GestureMultiTapDownCallback? onMultiTapDown;

  ///From the perspective of code implementation,
  ///[onMultiTapUp] is just a wrapper for [onTapUp].
  ///When using it, you can only choose one of the two callbacks - [onMultiTapUp] and [onTapUp].
  GestureMultiTapUpCallback? onMultiTapUp;

  _onTapDown(TapDragDownDetails details) {
    var tapCount = _getEffectiveConsecutiveTapCount(details.consecutiveTapCount);
    onMultiTapDown?.call(details, tapCount);
  }

  _onTapUp(TapDragUpDetails details) {
    var tapCount = _getEffectiveConsecutiveTapCount(details.consecutiveTapCount);
    onMultiTapUp?.call(details, tapCount);
  }

  ///This method is from the internal implementation of [TextField].
  static int _getEffectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        // From observation, these platform's reset their tap count to 0 when
        // the number of consecutive taps exceeds 3. For example on Debian Linux
        // with GTK, when going past a triple click, on the fourth click the
        // selection is moved to the precise click position, on the fifth click
        // the word at the position is selected, and on the sixth click the
        // paragraph at the position is selected.
        return rawCount <= 3 ? rawCount : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // From observation, these platform's either hold their tap count at 3.
        // For example on macOS, when going past a triple click, the selection
        // should be retained at the paragraph that was first selected on triple
        // click.
        return min(rawCount, 3);
      case TargetPlatform.windows:
        // From observation, this platform's consecutive tap actions alternate
        // between double click and triple click actions. For example, after a
        // triple click has selected a paragraph, on the next click the word at
        // the clicked position will be selected, and on the next click the
        // paragraph at the position is selected.
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }
}
