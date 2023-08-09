import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports layout constraints from outside a viewport, so that those constraints
/// can be used inside of a viewport.
///
/// This widget was designed to solve a nuanced problem within `SuperEditor` and
/// `SuperReader`. For the purpose of this explanation, `SuperEditor` will be
/// used to refer to both `SuperEditor` and `SuperReader`.
///
/// ## The Problem
/// `SuperEditor` needs to use a special pair of widgets to size its gesture
/// area due to the presence of a scrollable viewport in the middle of `SuperEditor`'s
/// widget tree. To understand why this complexity is needed, the following
/// points are important to understand:
///
///  1. `SuperEditor` places its gesture detector BEHIND the document so that
///     individual components in the document have the first chance to handle
///     taps, drags, etc.
///  2. Individual components within the document layout need to be able to
///     respond to gestures.
///  3. The document layout sits inside of a scrollable viewport.
///
/// Given these invariants, the question becomes: where do we place `SuperEditor`'s
/// gesture system, and how do we make it cover the full `SuperEditor` bounds?
///
/// The following are some options that we've considered, but won't work.
///
/// ### Place gestures around the scrollable viewport
///
///     _buildGestureSystem(
///       child: IgnorePointer(
///         child DocumentScrollable(
///           child: DocumentLayout(),
///         ),
///       ),
///     );
///
/// In this approach we place the gesture system behind the scrollable viewport.
/// This approach gives us the correct size for the gesture bounds. But, for
/// touch events to get back to the gesture system, we have to `IgnorePointer`
/// around the scrollable, so that the scrollable doesn't steal all the gestures.
/// Unfortunately, if we ignore gestures for the scrollable, it forces us to also
/// ignore gestures within the document layout, which violates requirement #2.
///
/// ### Gesture area inside the scrollable with LayoutBuilder for size
///
///     LayoutBuilder(
///       builder: (context, constraints) {
///         final viewportSize = constraints.biggest;
///
///         return Stack(
///           children: [
///             DocumentScrollable(
///               child: DocumentLayout(),
///             ),
///             _buildGestureSystem(viewportSize),
///           ],
///         );
///       },
///     );
///
/// In this approach, we place a `LayoutBuilder` outside of the scrollable, which then
/// tells us the size of the viewport. We provide that size to the gesture system, which
/// sits INSIDE the scrollable, and the gesture system makes itself exactly the same
/// size as the viewport.
///
/// This approach works, but it has a downside. We can't calculate an intrinsic height
/// for `SuperEditor`, because `LayoutBuilder` throws an exception when calculating
/// intrinsic height. We felt it was important to be able to calculate intrinsic height.
///
/// ## The Solution
/// To solve this problem we introduce two widgets, which are connected by a notifier.
///
/// The first widget, [ViewportBoundsReporter], measures the available space OUTSIDE the
/// scrollable viewport during layout, and reports it to the notifier.
///
/// The second widget, [ViewportBoundsReplicator], sits INSIDE the scrollable where
/// the vertical constraint is infinite. During layout, this widget reads the size
/// info from the notifier and sizes itself based on those constraints, instead of
/// using its incoming constraints.
///
/// As a result, the gesture area makes itself exactly the same size as the viewport
/// that surrounds it.
///
/// Intended use:
///
///     ViewportBoundsReporter(
///       contentConstraints: gestureConstraintsNotifier,
///       // This is the scrollable viewport.
///       child: DocumentScrollable(
///         child: MoreSubTree(
///           child: Stack(
///             children: [
///               // This gesture system needs to be as tall as the
///               // DocumentScrollable ancestor above, and it needs
///               // to sit behind the document layout.
///               ViewportBoundsReplicator(
///                 contentConstraints: gestureConstraintsNotifier,
///                 child: _buildGestureSystem(),
///               ),
///               // This is the document layout, which contains the
///               // individual components that need to have the first
///               // change to respond to gestures.
///               _buildDocumentLayout(),
///             ),
///           ),
///         ),
///       ),
///     );
///
/// See also:
///   * [ViewportBoundsReplicator] - which constrains itself with the constraints
///     selected by this widget.
class ViewportBoundsReporter extends SingleChildRenderObjectWidget {
  const ViewportBoundsReporter({
    required this.viewportOuterConstraints,
    required super.child,
  });

  /// The layout constraints that apply outside of the scrollable viewport.
  ///
  /// This widget is expected to build around the scrollable viewport. This
  /// widget then reports its layout constraints to this notifier to be used
  /// by a descendant [ViewportBoundsReplicator].
  final ValueNotifier<BoxConstraints> viewportOuterConstraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderViewportBoundsReporter() //
      ..viewportOuterConstraints = viewportOuterConstraints;
  }

  @override
  void updateRenderObject(BuildContext context, RenderViewportBoundsReporter renderObject) {
    renderObject.viewportOuterConstraints = viewportOuterConstraints;
  }
}

class RenderViewportBoundsReporter extends RenderProxyBox {
  late ValueNotifier<BoxConstraints> viewportOuterConstraints;

  @override
  void performLayout() {
    // We must report the desired constraints before running layout on our child,
    // because these constraints will impact the child's desired size. This impact is
    // indirect. The widget that uses these content constraints is probably a
    // deep descendant of our `child`.
    viewportOuterConstraints.value = BoxConstraints(
      minWidth: constraints.maxWidth < double.infinity ? constraints.maxWidth : 0,
      minHeight: constraints.maxHeight < double.infinity ? constraints.maxHeight : 0,
    );

    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
  }
}

/// A widget that sizes itself based on [viewportOuterConstraints], rather than its
/// incoming layout constraints.
///
/// See [ViewportBoundsReporter] for an explanation about why that widget and this
/// widget are necessary.
class ViewportBoundsReplicator extends SingleChildRenderObjectWidget {
  const ViewportBoundsReplicator({
    required this.viewportOuterConstraints,
    required super.child,
  });

  /// The layout constraints that apply outside of the scrollable viewport.
  ///
  /// This widget attempts to apply [viewportOuterConstraints] to itself, instead
  /// of its incoming layout constraints.
  final ValueNotifier<BoxConstraints> viewportOuterConstraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderViewportBoundsReplicator()..viewportOuterConstraints = viewportOuterConstraints;
  }

  @override
  void updateRenderObject(BuildContext context, RenderViewportBoundsReplicator renderObject) {
    renderObject.viewportOuterConstraints = viewportOuterConstraints;
  }
}

class RenderViewportBoundsReplicator extends RenderProxyBox {
  // Note: we don't need to listen to changes because the constraints only
  // change when our ancestor runs layout. If our ancestor runs layout, then
  // we will run layout, too.
  late ValueNotifier<BoxConstraints> viewportOuterConstraints;

  @override
  void performLayout() {
    final childConstraints = viewportOuterConstraints.value.enforce(constraints);

    child!.layout(childConstraints, parentUsesSize: true);
    size = child!.size;
  }
}
