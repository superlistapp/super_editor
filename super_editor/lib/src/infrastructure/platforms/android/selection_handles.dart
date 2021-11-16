import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

class AndroidSelectionHandle extends StatelessWidget {
  const AndroidSelectionHandle({
    Key? key,
    required this.handleType,
    required this.color,
    this.radius = 10,
  }) : super(key: key);

  final HandleType handleType;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    switch (handleType) {
      case HandleType.collapsed:
        return _buildCollapsed();
      case HandleType.upstream:
        return _buildUpstream();
      case HandleType.downstream:
        return _buildDownstream();
    }
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
