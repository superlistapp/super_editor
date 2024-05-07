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
  late final Color handleColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    handleColor = SuperEditorIosControlsScope.maybeRootOf(context)?.handleColor ?? Theme.of(context).primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        final percentage = widget.animationController.value;

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
            child: widget.magnifierBuilder(
              context,
              IosMagnifierViewModel(
                // In theory, the offsetFromFocalPoint should either be `widget.offsetFromFocalPoint.dy` to match
                // the actual offset, or it should be `widget.offsetFromFocalPoint.dy / magnificationLevel`. Neither
                // of those align the focal point correctly. The following offset was found empirically to give the
                // desired results.
                offsetFromFocalPoint: Offset(
                  widget.offsetFromFocalPoint.dx - 23,
                  (widget.offsetFromFocalPoint.dy + 140) * percentage,
                ),
                animationPercentage: widget.animationController.value,
                borderColor: handleColor,
              ),
              widget.magnifierKey,
            ),
          ),
        );
      },
    );
  }
}

typedef MagnifierBuilder = Widget Function(BuildContext, IosMagnifierViewModel magnifierInfo, [Key? magnifierKey]);

Widget _roundedRectangleMagnifierBuilder(BuildContext context, IosMagnifierViewModel magnifierInfo,
        [Key? magnifierKey]) =>
    IOSRoundedRectangleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
      animationPercentage: magnifierInfo.animationPercentage,
      borderColor: magnifierInfo.borderColor,
    );

Widget _circleMagnifierBuilder(BuildContext context, IosMagnifierViewModel magnifierInfo, [Key? magnifierKey]) =>
    IOSCircleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
    );

class IOSRoundedRectangleMagnifyingGlass extends StatelessWidget {
  static const _magnification = 1.5;

  const IOSRoundedRectangleMagnifyingGlass({
    super.key,
    this.offsetFromFocalPoint = Offset.zero,
    this.animationPercentage = 1.0,
    required this.borderColor,
  });

  final Offset offsetFromFocalPoint;
  final double animationPercentage;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final percent = defaultIosMagnifierAnimationCurve.transform(animationPercentage);

    final height = lerpDouble(30, 96, percent)!;
    final width = lerpDouble(4, 133, percent)!;
    final size = Size(width, height);

    final tintOpacity = 1.0 - Curves.easeIn.transform(animationPercentage);
    final borderRadius = lerpDouble(30.0, 50.0, percent)!;
    final borderWidth = lerpDouble(15.0, 3.0, percent)!;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        child: Stack(
          children: [
            if (percent >= 0.3)
              MagnifyingGlass(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                ),
                size: size,
                offsetFromFocalPoint: Offset(offsetFromFocalPoint.dx, offsetFromFocalPoint.dy),
                magnificationScale: _magnification,
              ),
            Opacity(
              opacity: Curves.easeOutQuint.transform(percent),
              child: Container(
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                    side: BorderSide(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  color: borderColor.withOpacity(tintOpacity),
                  shadows: const [
                    OuterBoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

/// Parameters used to render an iOS magnifier.
class IosMagnifierViewModel {
  IosMagnifierViewModel({
    required this.offsetFromFocalPoint,
    this.animationPercentage = 100.0,
    required this.borderColor,
  });

  final Offset offsetFromFocalPoint;
  final double animationPercentage;
  final Color borderColor;
}
