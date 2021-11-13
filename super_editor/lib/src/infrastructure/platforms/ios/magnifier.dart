import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/magnifier.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/outer_box_shadow.dart';

/// An iOS magnifying glass that follows a [LayerLink].
class IOSFollowingMagnifier extends StatelessWidget {
  const IOSFollowingMagnifier.roundedRectangle({
    Key? key,
    required this.layerLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _roundedRectangleMagnifierBuilder;

  const IOSFollowingMagnifier.circle({
    Key? key,
    required this.layerLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _circleMagnifierBuilder;

  const IOSFollowingMagnifier({
    Key? key,
    required this.layerLink,
    this.offsetFromFocalPoint = Offset.zero,
    required this.magnifierBuilder,
  }) : super(key: key);

  final LayerLink layerLink;
  final Offset offsetFromFocalPoint;
  final MagnifierBuilder magnifierBuilder;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      offset: offsetFromFocalPoint,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: magnifierBuilder(
          context,
          offsetFromFocalPoint,
        ),
      ),
    );
  }
}

typedef MagnifierBuilder = Widget Function(BuildContext, Offset offsetFromFocalPoint);

Widget _roundedRectangleMagnifierBuilder(BuildContext context, Offset offsetFromFocalPoint) =>
    IOSRoundedRectangleMagnifyingGlass(
      offsetFromFocalPoint: offsetFromFocalPoint,
    );

Widget _circleMagnifierBuilder(BuildContext context, Offset offsetFromFocalPoint) => IOSCircleMagnifyingGlass(
      offsetFromFocalPoint: offsetFromFocalPoint,
    );

class IOSRoundedRectangleMagnifyingGlass extends StatelessWidget {
  static const _magnification = 1.0;

  const IOSRoundedRectangleMagnifyingGlass({
    this.offsetFromFocalPoint = Offset.zero,
  });

  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MagnifyingGlass(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          size: const Size(72, 48),
          offsetFromFocalPoint: offsetFromFocalPoint,
          magnificationScale: _magnification,
        ),
        Container(
          width: 72,
          height: 48,
          decoration: const ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            shadows: [
              OuterBoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class IOSCircleMagnifyingGlass extends StatelessWidget {
  static const _diameter = 92.0;
  static const _magnification = 2.0;

  const IOSCircleMagnifyingGlass({
    this.offsetFromFocalPoint = Offset.zero,
  });

  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MagnifyingGlass(
          shape: const CircleBorder(),
          size: const Size(_diameter, _diameter),
          offsetFromFocalPoint: offsetFromFocalPoint,
          magnificationScale: _magnification,
        ),
        Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFAAAAAA), width: 1),
            gradient: const LinearGradient(
              colors: [
                Color(0x22000000),
                Color(0x00000000),
              ],
              stops: [
                0.0,
                0.5,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              OuterBoxShadow(
                color: Color(0x44000000),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
