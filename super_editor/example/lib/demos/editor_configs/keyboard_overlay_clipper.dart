import 'package:flutter/widgets.dart';

/// Clips out the area taken up by the toolbar that's mounted to
/// the keyboard so that the drag handles, magnifier, etc. don't
/// appear on top of the toolbar.
class KeyboardToolbarClipper extends CustomClipper<Rect> {
  const KeyboardToolbarClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height - 48);
  }

  @override
  bool shouldReclip(KeyboardToolbarClipper oldClipper) {
    return false;
  }
}
