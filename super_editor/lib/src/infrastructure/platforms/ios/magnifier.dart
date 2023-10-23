import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/super_textfield/infrastructure/magnifier.dart';
import 'package:super_editor/src/super_textfield/infrastructure/outer_box_shadow.dart';

/// An iOS magnifying glass that follows a [LayerLink].
class IOSFollowingMagnifier extends StatelessWidget {
  const IOSFollowingMagnifier.roundedRectangle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _roundedRectangleMagnifierBuilder;

  const IOSFollowingMagnifier.circle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _circleMagnifierBuilder;

  const IOSFollowingMagnifier({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.offsetFromFocalPoint = Offset.zero,
    required this.magnifierBuilder,
  }) : super(key: key);

  final Key? magnifierKey;
  final LeaderLink leaderLink;
  final Offset offsetFromFocalPoint;
  final MagnifierBuilder magnifierBuilder;

  @override
  Widget build(BuildContext context) {
    return Follower.withOffset(
      link: leaderLink,
      leaderAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      offset: offsetFromFocalPoint,
      child: magnifierBuilder(
        context,
        offsetFromFocalPoint,
        magnifierKey,
      ),
    );
  }
}

typedef MagnifierBuilder = Widget Function(BuildContext, Offset offsetFromFocalPoint, [Key? magnifierKey]);

Widget _roundedRectangleMagnifierBuilder(BuildContext context, Offset offsetFromFocalPoint, [Key? magnifierKey]) =>
    IOSRoundedRectangleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: offsetFromFocalPoint,
    );

Widget _circleMagnifierBuilder(BuildContext context, Offset offsetFromFocalPoint, [Key? magnifierKey]) =>
    IOSCircleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: offsetFromFocalPoint,
    );

class IOSRoundedRectangleMagnifyingGlass extends StatelessWidget {
  static const _magnification = 1.5;

  const IOSRoundedRectangleMagnifyingGlass({
    super.key,
    this.offsetFromFocalPoint = Offset.zero,
  });

  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
        MagnifyingGlass(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          size: const Size(72, 48),
          offsetFromFocalPoint: offsetFromFocalPoint,
          magnificationScale: _magnification,
        ),
      ],
    );
  }
}

class IOSCircleMagnifyingGlass extends StatelessWidget {
  static const _diameter = 92.0;
  static const _magnification = 2.0;

  const IOSCircleMagnifyingGlass({
    super.key,
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
