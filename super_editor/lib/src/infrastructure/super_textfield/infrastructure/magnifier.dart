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
  /// magnifier is displayed.
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
    final magnifierMatrix = Matrix4.identity()
      ..translate(offsetFromFocalPoint.dx * magnificationScale, offsetFromFocalPoint.dy * magnificationScale)
      ..scale(magnificationScale, magnificationScale);

    return ImageFilter.matrix(magnifierMatrix.storage);
  }
}
