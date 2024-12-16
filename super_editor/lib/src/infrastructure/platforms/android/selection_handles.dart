import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// An Android-style mobile selection drag handle.
///
/// Android renders three different types of handles: collapsed, upstream, and downstream.
///
/// All three types of handles look like 3/4 of a circle combined with 1/4 of a square (with
/// a pointy corner). The primary difference between each handle appearance is the way the
/// pointy corner is directed.
///
///  * Collapsed: The pointy corner points up.
///  * Upstream: The pointy corner points to the upper right (marking the start of a selection).
///  * Downstream: The pointy corner points to the upper left (marking the end of a selection).
class AndroidSelectionHandle extends StatelessWidget {
  static const defaultTouchRegionExpansion = EdgeInsets.only(left: 16, right: 16, bottom: 16);

  const AndroidSelectionHandle({
    Key? key,
    required this.handleType,
    required this.color,
    this.radius = 10,
    this.touchRegionExpansion = defaultTouchRegionExpansion,
    this.showDebugTouchRegion = false,
  }) : super(key: key);

  /// The type of handle, e.g., collapsed, upstream, downstream.
  final HandleType handleType;

  /// The color of the handle.
  final Color color;

  /// The radius of the handle - each handle is essentially a circle with one pointy
  /// corner.
  final double radius;

  /// Invisible space added around the handle to increase the touch area the handle.
  ///
  /// This invisible area expands the intrinsic size of the handle, and therefore the
  /// visual handle will no longer be aligned exactly with the content that's following.
  /// The parent layout needs to adjust the positioning of the handle to account for
  /// the [touchRegionExpansion].
  final EdgeInsets touchRegionExpansion;

  /// Whether to render the [touchRegionExpansion] with a translucent color for visual
  /// debugging.
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
        color: showDebugTouchRegion ? Colors.red.withValues(alpha: 0.5) : Colors.transparent,
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
