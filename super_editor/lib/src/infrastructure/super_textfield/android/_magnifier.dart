import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/magnifier.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/outer_box_shadow.dart';

/// An Android magnifying glass that follows a [LayerLink].
class AndroidFollowingMagnifier extends StatelessWidget {
  const AndroidFollowingMagnifier({
    Key? key,
    required this.layerLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : super(key: key);

  final LayerLink layerLink;
  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      offset: offsetFromFocalPoint,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: AndroidMagnifyingGlass(
          offsetFromFocalPoint: offsetFromFocalPoint,
        ),
      ),
    );
  }
}

class AndroidMagnifyingGlass extends StatelessWidget {
  static const _width = 92.0;
  static const _height = 48.0;
  static const _cornerRadius = 8.0;

  const AndroidMagnifyingGlass({
    this.offsetFromFocalPoint = Offset.zero,
  });

  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MagnifyingGlass(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          offsetFromFocalPoint: offsetFromFocalPoint,
          size: const Size(_width, _height),
          magnificationScale: 1.5,
        ),
        Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cornerRadius),
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
