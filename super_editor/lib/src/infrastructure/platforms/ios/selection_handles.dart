import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// An iOS-style text selection handle.
///
/// On iOS, drag handles are drawn differently depending on
/// whether the handle appears in the [HandleType.upstream]
/// position (the left side in left-to-right text), or in the
/// [HandleType.downstream] position (the right side in
/// right-to-left text). The upstream handle displays a vertical
/// caret with a circle on top of the caret. The downstream handle
/// displays a vertical caret with a circle on the bottom of the caret.
///
/// The collapsed handle looks like a standard text caret.
///
/// [IOSSelectionHandle] doesn't handle any gestures. The responsibility
/// of user interaction is left to the client for the following reasons:
///   * the touch area should be larger than the painted area because
///     the handle is very thin
///   * handle drag gestures may need to co-exist with other gestures
///     related to text interaction
class IOSSelectionHandle extends StatelessWidget {
  const IOSSelectionHandle.upstream({
    Key? key,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
    this.ballRadius = 4,
    this.handleType = HandleType.upstream,
  }) : super(key: key);

  const IOSSelectionHandle.downstream({
    Key? key,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
    this.ballRadius = 4,
    this.handleType = HandleType.downstream,
  }) : super(key: key);

  /// The color of the caret and ball in the handle.
  final Color color;

  /// The height of the caret, excluding the ball.
  final double caretHeight;

  /// The width of the caret, excluding the ball.
  final double caretWidth;

  /// The radius of the ball that's displayed above or
  /// below the caret.
  final double ballRadius;

  /// The type of handle, e.g., upstream, downstream, collapsed.
  final HandleType handleType;

  @override
  Widget build(BuildContext context) {
    switch (handleType) {
      case HandleType.upstream:
      case HandleType.downstream:
        return _buildExpandedHandle();
      default:
        throw Exception("Bad handle type: $handleType");
    }
  }

  Widget _buildExpandedHandle() {
    final ballDiameter = ballRadius * 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show the ball on the top for an upstream handle
        if (handleType == HandleType.upstream)
          Container(
            width: ballDiameter,
            height: ballDiameter,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        Container(
          width: caretWidth,
          height: caretHeight,
          color: color,
        ),
        // Show the ball on the bottom for a downstream handle
        if (handleType == HandleType.downstream)
          Container(
            width: ballDiameter,
            height: ballDiameter,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// An iOS-style caret/collapsed selection handle.
class IOSCollapsedHandle extends StatelessWidget {
  const IOSCollapsedHandle({
    Key? key,
    this.controller,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
  }) : super(key: key);

  /// The controller for the handle/caret's blinking behavior.
  final BlinkController? controller;

  /// The color of the caret and ball in the handle.
  final Color color;

  /// The height of the caret, excluding the ball.
  final double caretHeight;

  /// The width of the caret, excluding the ball.
  final double caretWidth;

  @override
  Widget build(BuildContext context) {
    return BlinkingCaret(
      controller: controller,
      caretOffset: Offset.zero,
      caretHeight: caretHeight,
      width: caretWidth,
      color: color,
      borderRadius: BorderRadius.zero,
      isTextEmpty: false,
      showCaret: true,
    );
  }
}
