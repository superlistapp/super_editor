import 'package:flutter/material.dart';

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    this.color = Colors.grey,
    this.thickness = 1,
  });

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: color,
      thickness: thickness,
    );
  }
}
