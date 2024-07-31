import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// SliverPadding with https://github.com/flutter/flutter/issues/149824 fixes
// TODO(knopp): Remove this once https://github.com/flutter/flutter/pull/149825 is in Flutter stable.

/// A sliver that applies padding on each side of another sliver.
///
/// Slivers are special-purpose widgets that can be combined using a
/// [CustomScrollView] to create custom scroll effects. A [SliverPadding]
/// is a basic sliver that insets another sliver by applying padding on each
/// side.
///
/// {@macro flutter.rendering.RenderSliverEdgeInsetsPadding}
///
/// See also:
///
///  * [CustomScrollView], which displays a scrollable list of slivers.
///  * [Padding], the box version of this widget.
class SliverPadding extends SingleChildRenderObjectWidget {
  /// Creates a sliver that applies padding on each side of another sliver.
  const SliverPadding({
    super.key,
    required this.padding,
    Widget? sliver,
  }) : super(child: sliver);

  /// The amount of space by which to inset the child sliver.
  final EdgeInsetsGeometry padding;

  @override
  RenderSliverPadding createRenderObject(BuildContext context) {
    return _RenderSliverPadding(
      padding: padding,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverPadding renderObject) {
    renderObject
      ..padding = padding
      ..textDirection = Directionality.of(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
  }
}

// Override the hitTestChildren method to fix https://github.com/flutter/flutter/issues/149824
class _RenderSliverPadding extends RenderSliverPadding {
  _RenderSliverPadding({required super.padding, required super.textDirection});

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    if (child != null && child!.geometry!.hitTestExtent > 0.0) {
      final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
      return result.addWithAxisOffset(
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
        mainAxisOffset: childMainAxisPosition(child!),
        crossAxisOffset: childCrossAxisPosition(child!),
        paintOffset: childParentData.paintOffset,
        hitTest: child!.hitTest,
      );
    }
    return false;
  }
}
