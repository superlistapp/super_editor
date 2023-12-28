import 'package:flutter/material.dart';

/// A rounded rectangle shape with a fade-in transition.
class RoundedRectanglePopoverAppearance extends StatefulWidget {
  const RoundedRectanglePopoverAppearance({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<RoundedRectanglePopoverAppearance> createState() => _RoundedRectanglePopoverAppearanceState();
}

class _RoundedRectanglePopoverAppearanceState extends State<RoundedRectanglePopoverAppearance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _containerFadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _containerFadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: FadeTransition(
        opacity: _containerFadeInAnimation,
        child: widget.child,
      ),
    );
  }
}
