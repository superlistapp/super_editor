import 'package:flutter/material.dart';

/// A scaffold to be used by all feature demos, to align the visual styles of
/// all feature demos.
class FeatureDemoScaffold extends StatelessWidget {
  const FeatureDemoScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color(0xFF222222),
            body: child,
          );
        },
      ),
    );
  }
}
