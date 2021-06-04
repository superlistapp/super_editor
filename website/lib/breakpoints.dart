import 'package:flutter/widgets.dart';

class Breakpoints {
  Breakpoints._();

  /// Whether the navigation links in the header should be collapsed into a
  /// separate off-screen drawer or not.
  static bool collapsedNavigation(BuildContext context) {
    return MediaQuery.of(context).size.width <= 540;
  }

  /// Whether the body content should use a single-column layout or not.
  static bool singleColumnLayout(BuildContext context) {
    return MediaQuery.of(context).size.width <= 768;
  }
}
