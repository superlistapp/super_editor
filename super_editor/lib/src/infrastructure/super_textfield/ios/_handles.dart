import 'package:flutter/material.dart';

/// An iOS-style expanded text selection handle.
///
/// On iOS, drag handles are drawn differently depending on
/// whether the handle appears in the [HandleDirection.upstream]
/// position (the left side in left-to-right text), or in the
/// [HandleDirection.downstream] position (the right side in
/// right-to-left text). The upstream handle displays a vertical
/// caret with a circle on top of the caret. The downstream handle
/// displays a vertical caret with a circle on the bottom of the caret.
///
/// [IOSTextFieldHandle] doesn't handle any gestures. The responsibility
/// of user interaction is left to the client for the following reasons:
///   * the touch area should be larger than the painted area because
///     the handle is very thin
///   * handle drag gestures may need to co-exist with other gestures
///     related to text interaction
class IOSTextFieldHandle extends StatelessWidget {
  const IOSTextFieldHandle.upstream({
    Key? key,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
    this.ballRadius = 4,
    this.handleDirection = HandleDirection.upstream,
  }) : super(key: key);

  const IOSTextFieldHandle.downstream({
    Key? key,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
    this.ballRadius = 4,
    this.handleDirection = HandleDirection.downstream,
  }) : super(key: key);

  const IOSTextFieldHandle({
    Key? key,
    required this.color,
    required this.caretHeight,
    this.caretWidth = 2,
    this.ballRadius = 4,
    required this.handleDirection,
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

  /// The end of the text selection that this handle occupies.
  final HandleDirection handleDirection;

  @override
  Widget build(BuildContext context) {
    final ballDiameter = ballRadius * 2;
    final verticalOffset = handleDirection == HandleDirection.upstream ? -ballRadius : ballRadius;

    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show the ball on the top for an upstream handle
          if (handleDirection == HandleDirection.upstream)
            Container(
              width: ballDiameter,
              height: ballDiameter,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Container(
            width: 2,
            height: caretHeight + ballRadius,
            color: color,
          ),
          // Show the ball on the bottom for a downstream handle
          if (handleDirection == HandleDirection.downstream)
            Container(
              width: ballDiameter,
              height: ballDiameter,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// The end of a text selection that a handle occupies.
enum HandleDirection {
  /// The upstream side of a text selection.
  ///
  /// The upstream side in left-to-right text is the left
  /// side. In right-to-left text, it's the right side.
  upstream,

  /// The downstream side of a text selection.
  ///
  /// The downstream side in left-to-right text is the right
  /// side. In right-to-left text, it's the left side.
  downstream,
}

enum HandleDragMode {
  collapsed,
  base,
  extent,
}
