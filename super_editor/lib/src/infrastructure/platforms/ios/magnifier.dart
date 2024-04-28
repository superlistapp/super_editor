import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/super_textfield/infrastructure/outer_box_shadow.dart';
import 'package:super_editor/super_editor.dart';

/// An iOS magnifying glass that follows a [LayerLink].
class IOSFollowingMagnifier extends StatefulWidget {
  const IOSFollowingMagnifier.roundedRectangle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    required this.animationController,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _roundedRectangleMagnifierBuilder;

  const IOSFollowingMagnifier.circle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    required this.animationController,
    this.offsetFromFocalPoint = Offset.zero,
  }) : magnifierBuilder = _circleMagnifierBuilder;

  const IOSFollowingMagnifier({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    required this.animationController,
    this.offsetFromFocalPoint = Offset.zero,
    required this.magnifierBuilder,
  }) : super(key: key);

  final Key? magnifierKey;
  final LeaderLink leaderLink;
  final Offset offsetFromFocalPoint;
  final MagnifierBuilder magnifierBuilder;
  final AnimationController animationController;

  @override
  State<IOSFollowingMagnifier> createState() => _IOSFollowingMagnifierState();
}

class _IOSFollowingMagnifierState extends State<IOSFollowingMagnifier> {
  late CurvedAnimation _animation;

  @override
  void initState() {
    _animation = CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeOut,
    );
    super.initState();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = SuperEditorIosControlsScope.maybeRootOf(context)?.handleColor ?? Theme.of(context).primaryColor;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final percentage = _animation.value;

        return Follower.withOffset(
          link: widget.leaderLink,
          leaderAnchor: Alignment.center,
          followerAnchor: Alignment.topLeft,
          offset: Offset(
            widget.offsetFromFocalPoint.dx,
            // Animate the magnfier up on entrance and down on exit.
            widget.offsetFromFocalPoint.dy * percentage,
          ),
          // Theoretically, we should be able to use a leaderAnchor and followerAnchor of "center"
          // and avoid the following FractionalTranslation. However, when centering the follower,
          // we don't get the expect focal point within the magnified area. It's off-center. I'm not
          // sure why that happens, but using a followerAnchor of "topLeft" and then pulling back
          // by 50% solve the problem.
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Transform.scale(
              scaleY: max(percentage, 0.3),
              scaleX: percentage,
              child: Opacity(
                opacity: max(percentage, 0.3),
                child: widget.magnifierBuilder(
                  context,
                  MagnifierInfo(
                    // In theory, the offsetFromFocalPoint should either be `widget.offsetFromFocalPoint.dy` to match
                    // the actual offset, or it should be `widget.offsetFromFocalPoint.dy / magnificationLevel`. Neither
                    // of those align the focal point correctly. The following offset was found empirically to give the
                    // desired results.
                    offsetFromFocalPoint: Offset(
                      widget.offsetFromFocalPoint.dx - 23,
                      widget.offsetFromFocalPoint.dy + 140,
                    ),
                    animationPercentage: percentage,
                    borderColor: borderColor,
                  ),
                  widget.magnifierKey,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

typedef MagnifierBuilder = Widget Function(BuildContext, MagnifierInfo magnifierInfo, [Key? magnifierKey]);

Widget _roundedRectangleMagnifierBuilder(BuildContext context, MagnifierInfo magnifierInfo, [Key? magnifierKey]) =>
    IOSRoundedRectangleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
      animationPercentage: magnifierInfo.animationPercentage,
      borderColor: magnifierInfo.borderColor,
    );

Widget _circleMagnifierBuilder(BuildContext context, MagnifierInfo magnifierInfo, [Key? magnifierKey]) =>
    IOSCircleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
    );

class IOSRoundedRectangleMagnifyingGlass extends StatelessWidget {
  static const _magnification = 1.5;

  const IOSRoundedRectangleMagnifyingGlass({
    super.key,
    this.offsetFromFocalPoint = Offset.zero,
    this.animationPercentage = 100.0,
    required this.borderColor,
  });

  final Offset offsetFromFocalPoint;
  final double animationPercentage;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final percent = animationPercentage;
    const size = Size(133, 96);

    final borderWidth = lerpDouble(60.0, 3.0, percent)!;
    final borderRadius = lerpDouble(20.0, 50.0, percent)!;

    return Stack(
      children: [
        MagnifyingGlass(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          ),
          size: size,
          offsetFromFocalPoint: Offset(offsetFromFocalPoint.dx, offsetFromFocalPoint.dy),
          magnificationScale: _magnification,
        ),
        Container(
          width: size.width,
          height: size.height,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
              side: BorderSide(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            color: borderColor.withOpacity(1 - percent),
            shadows: const [
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

/// Parameters used to render the magnifier.
class MagnifierInfo {
  MagnifierInfo({
    required this.offsetFromFocalPoint,
    this.animationPercentage = 100.0,
    required this.borderColor,
  });

  final Offset offsetFromFocalPoint;
  final double animationPercentage;
  final Color borderColor;
}
