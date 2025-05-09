import 'package:flutter/widgets.dart';

/// A horizontal portion of the screen, which includes part of the window's app
/// bar, along with content, which appears directly below that app bar partial.
class ScreenPartial extends StatelessWidget {
  const ScreenPartial({
    super.key,
    this.appBarHeight = 36,
    this.partialAppBar,
    required this.content,
  });

  final double appBarHeight;
  final Widget? partialAppBar;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: appBarHeight,
          color: const Color(0xFF2f2f2f),
          child: partialAppBar,
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF222222),
            child: content,
          ),
        ),
      ],
    );
  }
}
