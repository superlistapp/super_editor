import 'dart:math';

import 'package:flutter/material.dart';

class AndroidTextFieldHandle extends StatelessWidget {
  const AndroidTextFieldHandle({
    Key? key,
    required this.handleType,
    required this.color,
    this.radius = 10,
  }) : super(key: key);

  final AndroidHandleType handleType;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    switch (handleType) {
      case AndroidHandleType.collapsed:
        return _buildCollapsed();
      case AndroidHandleType.upstream:
        return _buildUpstream();
      case AndroidHandleType.downstream:
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

enum AndroidHandleType {
  collapsed,
  upstream,
  downstream,
}
