import 'dart:ui';

import 'package:flutter/material.dart';

/// A magnifying glass that enlarges the content beneath it.
///
/// Magnifies the content beneath this [MagnifyingGlass] at a level of
/// [magnificationScale] and displays that content in a [shape] of
/// the given [size].
///
/// By default, [MagnifyingGlass] expects to be placed directly on top
/// of the content that it magnifies. Due to the way that magnification
/// works, if [MagnifyingGlass] is displayed with an offset from the
/// content that it magnifies, that offset must be provided as
/// [offsetFromFocalPoint].
///
/// [MagnifyingGlass] was designed to operate across the entire screen.
/// Using a [MagnifyingGlass] in a confined region may result in the
/// magnifier mis-aligning the content that is magnifies.
class MagnifyingGlass extends StatelessWidget {
  const MagnifyingGlass({
    Key? key,
    this.offsetFromFocalPoint = Offset.zero,
    required this.shape,
    required this.size,
    required this.magnificationScale,
  }) : super(key: key);

  /// The offset from where the magnification is applied, to where this
  /// magnifier is displayed, in density independent pixels.
  ///
  /// An [offsetFromFocalPoint] of `Offset.zero` would indicate that this
  /// [MagnifyingGlass] is displayed directly over the point of magnification.
  final Offset offsetFromFocalPoint;

  /// The shape of the magnifying glass.
  final ShapeBorder shape;

  /// The size of the magnifying glass.
  final Size size;

  /// The level of magnification applied to the content beneath this
  /// [MagnifyingGlass], expressed as a multiple of the natural dimensions.
  final double magnificationScale;

  @override
  Widget build(BuildContext context) {
    return ClipPath.shape(
      shape: shape,
      child: BackdropFilter(
        filter: _createMagnificationFilter(),
        child: SizedBox.fromSize(
          size: size,
        ),
      ),
    );
  }

  ImageFilter _createMagnificationFilter() {
    // When displayed without scaling, the content inside the magnifier looks
    // like this:
    //    ________________
    //   |                |
    //   |     center     |
    //   |________________|
    //
    // Applying scaling causes the content to grow outward shifting the center
    // away from the magnifier's center, like this:
    //    ________________
    //   |                |
    //   |                |
    //   |_________c e n t|e r
    //
    // To correct this, we shift the content in the opposite direction before scaling,
    // so it appears like this before scaling:
    //    ________________
    //   |center          |
    //   |                |
    //   |________________|
    //
    // After scaling, the content shifts again due to the scaling effect. However,
    // the pre-shift ensures that the center of the content aligns correctly within
    // the magnifier, like this:
    //    ________________
    //   |                |
    //   |   c e n t e r  |
    //   |________________|
    //
    final magnifierMatrix = Matrix4.identity()
      // Calculate the extra size introduced by scaling and move the content
      // back by half of that amount.
      //
      // For example:
      //
      // If the magnifier is 133px wide with a magnification scale of 1.5,
      // the scaled width will be:
      //    133px * 1.5 = 199.5px.
      //
      // The width increases by 66.5px in total. Since the growth is symmetric,
      // we shift the content left by half the increase (66.5px / 2 = 33.25px)
      // to re-center it under the magnifier after the scaling.
      ..translate(
        -(size.width * magnificationScale - size.width) / 2,
        -(size.height * magnificationScale - size.height) / 2,
      )
      // Apply the scaling transformation to magnify the content.
      ..scale(magnificationScale, magnificationScale)
      // Move the content to the center of where the app wants to
      // display the magnifier.
      ..translate(offsetFromFocalPoint.dx, offsetFromFocalPoint.dy);
    return ImageFilter.matrix(magnifierMatrix.storage);
  }
}
