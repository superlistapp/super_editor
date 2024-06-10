import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

class AndroidSelectionHandle extends StatelessWidget {
  static const defaultTouchRegionExpansion = EdgeInsets.all(16);

  const AndroidSelectionHandle({
    Key? key,
    required this.handleType,
    required this.color,
    this.radius = 10,
    this.touchRegionExpansion = defaultTouchRegionExpansion,
    this.showDebugTouchRegion = false,
  }) : super(key: key);

  final HandleType handleType;
  final Color color;
  final double radius;
  final EdgeInsets touchRegionExpansion;
  final bool showDebugTouchRegion;

  @override
  Widget build(BuildContext context) {
    late final Widget handle;
    switch (handleType) {
      case HandleType.collapsed:
        handle = _buildCollapsed();
      case HandleType.upstream:
        handle = _buildUpstream();
      case HandleType.downstream:
        handle = _buildDownstream();
    }

    return Container(
      padding: touchRegionExpansion,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: showDebugTouchRegion ? Colors.red.withOpacity(0.5) : Colors.transparent,
      ),
      child: handle,
    );
  }

  Widget _buildCollapsed() {
    return Transform.rotate(
      angle: -pi / 4,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius),
            bottomLeft: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
        ),
      ),
    );
  }

  Widget _buildUpstream() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildDownstream() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
      ),
    );
  }
}
