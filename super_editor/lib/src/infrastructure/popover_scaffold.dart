import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/mac/mac_ime.dart';

/// A scaffold, which builds a popover selection system, comprised of a button and a popover
/// that's positioned near the button.
///
/// Unlike Flutter `DropdownButton`, which displays the popover in a separate route,
/// this widget displays its popover in an `Overlay`. By using an `Overlay`, focus can be shared
/// between the popover's `FocusNode` and an arbitrary parent `FocusNode`.
///
/// The popover visibility is changed by calling [PopoverController.open] or [PopoverController.close].
/// The popover is automatically closed when the user taps outside of its bounds.
///
/// Provide a [popoverGeometry] to control the size and position of the popover. The popover
/// is first sized given the [PopoverGeometry.constraints] and then positioned using the
/// [PopoverGeometry.align].
///
/// When the popover is displayed it requests focus to itself, so the user can
/// interact with the content using the keyboard.
class PopoverScaffold extends StatefulWidget {
  const PopoverScaffold({
    super.key,
    required this.controller,
    required this.buttonBuilder,
    required this.popoverBuilder,
    this.popoverGeometry = const PopoverGeometry(),
    this.popoverFocusNode,
    this.parentFocusNode,
    this.boundaryKey,
    this.onTapOutside = _PopoverScaffoldState.closePopoverOnTapOutside,
    this.tapRegionGroupId,
  });

  /// Shows and hides the popover.
  final PopoverController controller;

  /// Builds a button that is always displayed.
  final WidgetBuilder buttonBuilder;

  /// Builds the content of the popover.
  final WidgetBuilder popoverBuilder;

  /// Controls the size and position of the popover.
  ///
  /// The popover is first sized, then positioned.
  final PopoverGeometry popoverGeometry;

  /// The [FocusNode] which is bound to the popover.
  ///
  /// Focus will be requested to this [FocusNode] when the popover is displayed.
  final FocusNode? popoverFocusNode;

  /// The [FocusNode], to which the popover [FocusNode] will be added as a child.
  ///
  /// In Flutter, [FocusNode]s have parents and children. This relationship allows an
  /// entire ancestor path to "have focus", but only the lowest level descendant
  /// in that path has "primary focus". This path is important because various
  /// widgets alter their presentation or behavior based on whether or not they
  /// currently have focus, even if they only have "non-primary focus".
  ///
  /// When the popover is visible, it will have primary focus.
  /// Moreover, because the popover is built in an `Overlay`, none of your
  /// widgets are in the natural focus path for that popover. Therefore, if you
  /// need your widget tree to retain focus while the popover is visible, then
  /// you need to provide the [FocusNode] that the popover should use as its
  /// parent, thereby retaining focus for your widgets.
  final FocusNode? parentFocusNode;

  /// A [GlobalKey] to a widget that determines the bounds where the popover can be displayed.
  ///
  /// Passing a [boundaryKey] causes the popover to be confined to the bounds of the widget
  /// bound to the [boundaryKey].
  ///
  /// If `null`, the popover is confined to the screen bounds, defined by the result of `MediaQuery.sizeOf`.
  final GlobalKey? boundaryKey;

  /// Called when the user taps outside of the popover.
  ///
  /// If `null`, tapping outside closes the popover.
  final void Function(PopoverController) onTapOutside;

  /// A group ID for a tap region that is shared with the popover.
  ///
  /// Tapping on a [TapRegion] with the same [tapRegionGroupId]
  /// won't invoke [onTapOutside].
  final String? tapRegionGroupId;

  @override
  State<PopoverScaffold> createState() => _PopoverScaffoldState();
}

class _PopoverScaffoldState extends State<PopoverScaffold> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LeaderLink _popoverLink = LeaderLink();
  final FocusNode _scaffoldFocusNode = FocusNode();

  late Size _screenSize;
  late FollowerBoundary _screenBoundary;

  /// Closes the popover when tapping outside.
  static void closePopoverOnTapOutside(PopoverController controller) {
    controller.close();
  }

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onPopoverControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFollowerBoundary();
  }

  @override
  void didUpdateWidget(covariant PopoverScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onPopoverControllerChanged);
      widget.controller.addListener(_onPopoverControllerChanged);
    }

    if (oldWidget.boundaryKey != widget.boundaryKey) {
      _updateFollowerBoundary();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPopoverControllerChanged);
    _popoverLink.dispose();
    _scaffoldFocusNode.dispose();

    super.dispose();
  }

  void _updateFollowerBoundary() {
    _screenSize = MediaQuery.sizeOf(context);
    if (widget.boundaryKey != null) {
      _screenBoundary = WidgetFollowerBoundary(
        boundaryKey: widget.boundaryKey,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } else {
      _screenBoundary = ScreenFollowerBoundary(
        screenSize: _screenSize,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    }
  }

  void _onPopoverControllerChanged() {
    if (widget.controller.shouldShow) {
      _overlayController.show();
      if (widget.popoverFocusNode != null) {
        onNextFrame((timeStamp) {
          widget.popoverFocusNode!.requestFocus();
        });
      }
    } else {
      _overlayController.hide();
    }
  }

  void _onTapOutsideOfPopover(PointerDownEvent e) {
    widget.onTapOutside(widget.controller);
  }

  BoxConstraints _computePopoverConstraints() {
    if (widget.popoverGeometry.constraints != null) {
      return widget.popoverGeometry.constraints!;
    }

    if (widget.boundaryKey != null) {
      // Let the popover be at most the size of the boundary widget.
      final boundaryBox = widget.boundaryKey!.currentContext!.findRenderObject() as RenderBox;
      return BoxConstraints(
        maxHeight: boundaryBox.size.height,
        maxWidth: boundaryBox.size.width,
      );
    }

    // Let the popover be at most the size of the screen.
    return BoxConstraints(
      maxHeight: _screenSize.height,
      maxWidth: _screenSize.width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildPopover,
      child: Leader(
        link: _popoverLink,
        child: widget.buttonBuilder(context),
      ),
    );
  }

  Widget _buildPopover(BuildContext context) {
    return TapRegion(
      groupId: widget.tapRegionGroupId,
      onTapOutside: _onTapOutsideOfPopover,
      child: Actions(
        actions: disabledMacIntents,
        child: Follower.withAligner(
          link: _popoverLink,
          boundary: _screenBoundary,
          aligner: FunctionalAligner(
            delegate: (globalLeaderRect, followerSize) =>
                widget.popoverGeometry.align(globalLeaderRect, followerSize, _screenSize, widget.boundaryKey),
          ),
          child: ConstrainedBox(
            constraints: _computePopoverConstraints(),
            child: Focus(
              parentNode: widget.parentFocusNode,
              child: widget.popoverBuilder(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Controls the visibility of a popover.
class PopoverController with ChangeNotifier {
  /// Whether the popover should be displayed.
  bool get shouldShow => _shouldShow;
  bool _shouldShow = false;

  void open() {
    if (_shouldShow) {
      return;
    }
    _shouldShow = true;
    notifyListeners();
  }

  void close() {
    if (!_shouldShow) {
      return;
    }
    _shouldShow = false;
    notifyListeners();
  }

  void toggle() {
    if (shouldShow) {
      close();
    } else {
      open();
    }
  }
}

/// The offset and size of a popover.
class PopoverGeometry {
  const PopoverGeometry({
    this.align = defaultPopoverAligner,
    this.constraints,
  });

  /// Positions the popover.
  ///
  /// If the `boundaryKey` is non-`null`, the popover must be positioned within the bounds of
  /// the `RenderBox` bound to `boundaryKey`.
  final PopoverAligner align;

  /// [BoxConstraints] applied to the popover.
  ///
  /// If `null`, the popover can use all the available space.
  final BoxConstraints? constraints;
}

/// A function to align a Widget following a leader Widget.
///
/// If a [boundaryKey] is given, the alignment must be within the bounds of its `RenderBox`.
typedef PopoverAligner = FollowerAlignment Function(
    Rect globalLeaderRect, Size followerSize, Size screenSize, GlobalKey? boundaryKey);

/// Computes the position of a popover relative to the button.
///
/// The following rules are applied, in order:
///
/// 1. If there is enough room to display the popover beneath the button,
/// position it below the button.
///
/// 2. If there is enough room to display the popover above the button,
/// position it above the button.
///
/// 3. Pin the popover to the bottom of the `RenderBox` bound to [boundaryKey],
/// letting the popover cover the button.
FollowerAlignment defaultPopoverAligner(
    Rect globalLeaderRect, Size followerSize, Size screenSize, GlobalKey? boundaryKey) {
  final boundsBox = boundaryKey?.currentContext?.findRenderObject() as RenderBox?;
  final bounds = boundsBox != null
      ? Rect.fromPoints(
          boundsBox.localToGlobal(Offset.zero),
          boundsBox.localToGlobal(boundsBox.size.bottomRight(Offset.zero)),
        )
      : Offset.zero & screenSize;
  late FollowerAlignment alignment;

  if (globalLeaderRect.bottom + followerSize.height < bounds.bottom) {
    // The follower fits below the leader.
    alignment = const FollowerAlignment(
      leaderAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      followerOffset: Offset(0, 20),
    );
  } else if (globalLeaderRect.top - followerSize.height > bounds.top) {
    // The follower fits above the leader.
    alignment = const FollowerAlignment(
      leaderAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      followerOffset: Offset(0, -20),
    );
  } else {
    // There isn't enough room to fully display the follower below or above the leader.
    // Pin the popover list to the bottom, letting the follower cover the leader.
    alignment = const FollowerAlignment(
      leaderAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      followerOffset: Offset(0, 20),
    );
  }

  return alignment;
}
