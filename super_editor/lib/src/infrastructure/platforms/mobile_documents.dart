import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/_scrolling.dart';
import 'package:super_editor/src/infrastructure/document_gestures.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';

class DocumentKeys {
  static const mobileToolbar = ValueKey("document_mobile_toolbar");
  static const magnifier = ValueKey("document_magnifier");
  static const iOsCaret = ValueKey("document_ios_caret");
  static const androidCaret = ValueKey("document_android_caret");
  static const androidCaretHandle = ValueKey("document_android_caret_handle");
  static const upstreamHandle = ValueKey("document_upstream_handle");
  static const downstreamHandle = ValueKey("document_downstream_handle");

  DocumentKeys._();
}

/// Builds a full-screen collapsed drag handle display, with the handle positioned near the [focalPoint],
/// and with the handle attached to the given [handleKey].
///
/// The [handleKey] is used to find the handle in the widget tree for various purposes,
/// e.g., within tests to verify the presence or absence of the handle.
///
/// The [handleKey] must be attached to the handle, not the top-level widget returned
/// from this builder, because the [handleKey] might be used to verify the size and location
/// of the handle. For example:
///
/// ```dart
/// Widget buildCollapsedHandle(context, handleKey, focalPoint) {
///   return Follower(
///     link: focalPoint,
///     child: CollapsedHandle(
///       key: handleKey,
///     ),
///   );
/// }
/// ```
typedef DocumentCollapsedHandleBuilder = Widget Function(BuildContext, Key handleKey, LeaderLink focalPoint);

/// Builds a full-screen display of a set of expanded drag handles, with the handles positioned near the
/// [upstreamFocalPoint] and [downstreamFocalPoint], respectively, and with the handles attached to the
/// given [upstreamHandleKey] and [downstreamHandleKey], respectively.
///
/// The [upstreamHandleKey] and [downstreamHandleKey] are used to find the handles in the widget tree for
/// various purposes, e.g., within tests to verify the presence or absence of the handles.
///
/// The handle keys must be attached to the handles, not the top-level widget returned
/// from this builder, because the handle keys might be used to verify the size and location
/// of the handles. For example:
///
/// ```dart
/// Widget buildCollapsedHandle(context, upstreamHandleKey, upstreamFocalPoint, downstreamHandleKey, downstreamFocalPoint) {
///   return Stack(
///     children: [
///       Follower(
///        link: upstreamFocalPoint,
///        child: UpstreamHandle(key: upstreamHandleKey),
///       ),
///       Follower(
///        link: downstreamFocalPoint,
///        child: DownstreamHandle(key: downstreamHandleKey),
///       ),
///     ],
///   );
/// }
/// ```
typedef DocumentExpandedHandlesBuilder = Widget Function(
  BuildContext,
  Key upstreamHandleKey,
  LeaderLink upstreamFocalPoint,
  Key downstreamHandleKey,
  LeaderLink downstreamFocalPoint,
);

/// Builds a full-screen floating toolbar display, with the toolbar positioned near the
/// [focalPoint], and with the toolbar attached to the given [mobileToolbarKey].
///
/// The [mobileToolbarKey] is used to find the toolbar in the widget tree for various purposes,
/// e.g., within tests to verify the presence or absence of a toolbar. If your builder chooses
/// not to build a toolbar, e.g., returns a `SizedBox()` instead of a toolbar, then the
/// you shouldn't use the [mobileToolbarKey].
///
/// The [mobileToolbarKey] must be attached to the toolbar, not the top-level widget returned
/// from this builder, because the [mobileToolbarKey] might be used to verify the size and location
/// of the toolbar. For example:
///
/// ```dart
/// Widget buildMagnifier(context, mobileToolbarKey, focalPoint) {
///   return Follower(
///     link: focalPoint,
///     child: Toolbar(
///       key: mobileToolbarKey,
///       width: 100,
///       height: 42,
///       magnification: 1.5,
///     ),
///   );
/// }
/// ```
typedef DocumentFloatingToolbarBuilder = Widget Function(
  BuildContext context,
  Key mobileToolbarKey,
  LeaderLink focalPoint,
);

/// Builds a full-screen magnifier display, with the magnifier following the given [focalPoint],
/// and with the magnifier attached to the given [magnifierKey].
///
/// The [magnifierKey] is used to find the magnifier in the widget tree for various purposes,
/// e.g., within tests to verify the presence or absence of a magnifier. If your builder chooses
/// not to build a magnifier, e.g., returns a `SizedBox()` instead of a magnifier, then the
/// you shouldn't use the [magnifierKey].
///
/// The [magnifierKey] must be attached to the magnifier, not the top-level widget returned
/// from this builder, because the [magnifierKey] might be used to verify the size and location
/// of the magnifier. For example:
///
/// ```dart
/// Widget buildMagnifier(context, magnifierKey, focalPoint) {
///   return Follower(
///     link: focalPoint,
///     child: Magnifier(
///       key: magnifierKey,
///       width: 100,
///       height: 42,
///       magnification: 1.5,
///     ),
///   );
/// }
/// ```
typedef DocumentMagnifierBuilder = Widget Function(BuildContext, Key magnifierKey, LeaderLink focalPoint);

/// Global flag that disables long-press selection for Android and iOS, as a hack for Superlist, because
/// Superlist has a custom long-press behavior per-component.
///
/// This is a hack and is expected to be replaced ASAP. Issue: https://github.com/superlistapp/super_editor/issues/1547
///
/// The underlying issue is that the document layout components have a gesture mode of "translucent", which
/// lets both the document component and the overall document gesture interactor both respond to the touch
/// event. As a result, if a user long-presses on a component to re-order it, that long-press also triggers
/// the long-press text selection behavior within the standard document interactor.
@Deprecated("Don't use this unless you're Superlist. This will be removed ASAP. See issue #1547.")
bool disableLongPressSelectionForSuperlist = false;

/// Controls the display and position of a magnifier and a floating toolbar.
class MagnifierAndToolbarController with ChangeNotifier {
  /// Whether the magnifier should be displayed.
  bool get shouldDisplayMagnifier => _isMagnifierVisible;
  bool _isMagnifierVisible = false;

  /// Shows the magnify, and hides the toolbar.
  void showMagnifier() {
    hideToolbar();

    _isMagnifierVisible = true;

    notifyListeners();
  }

  /// Hides the magnifier.
  void hideMagnifier() {
    _isMagnifierVisible = false;
    notifyListeners();
  }

  /// Whether the toolbar should be displayed.
  bool get shouldDisplayToolbar => _shouldDisplayToolbar;
  bool _shouldDisplayToolbar = false;

  /// Whether the toolbar currently has a designated display position.
  ///
  /// The toolbar should not be displayed if this is `false`, even if
  /// [shouldDisplayToolbar] is `true`.
  bool get isToolbarPositioned => _toolbarTopAnchor != null && _toolbarBottomAnchor != null;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears above the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar above this point. If not, use [toolbarBottomAnchor].
  Offset? get toolbarTopAnchor => _toolbarTopAnchor;
  Offset? _toolbarTopAnchor;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears below the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar below this point. If not, use [toolbarTopAnchor].
  Offset? get toolbarBottomAnchor => _toolbarBottomAnchor;
  Offset? _toolbarBottomAnchor;

  /// Minimum space from the screen edges.
  EdgeInsets? get screenPadding => _screenPadding;
  set screenPadding(EdgeInsets? value) {
    if (value != _screenPadding) {
      _screenPadding = value;
      notifyListeners();
    }
  }

  EdgeInsets? _screenPadding;

  /// Sets the toolbar's position to the given [topAnchor] and [bottomAnchor].
  ///
  /// Setting the position will not cause the toolbar to be displayed on it's own.
  /// To display the toolbar, call [showToolbar], too.
  void positionToolbar({
    required Offset topAnchor,
    required Offset bottomAnchor,
  }) {
    if (topAnchor != _toolbarTopAnchor || bottomAnchor != _toolbarBottomAnchor) {
      _toolbarTopAnchor = topAnchor;
      _toolbarBottomAnchor = bottomAnchor;
      notifyListeners();
    }
  }

  /// Toggles the toolbar from visible to not visible, or vis-a-versa.
  void toggleToolbar() {
    if (_shouldDisplayToolbar) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  /// Shows the toolbar, and hides the magnifier.
  void showToolbar() {
    if (_shouldDisplayToolbar) {
      return;
    }

    hideMagnifier();
    _shouldDisplayToolbar = true;

    notifyListeners();
  }

  /// Hides the toolbar.
  void hideToolbar() {
    if (!_shouldDisplayToolbar) {
      return;
    }

    _shouldDisplayToolbar = false;

    notifyListeners();
  }
}

/// Controls the display and position of a magnifier and a floating toolbar
/// using a [MagnifierAndToolbarController] as the source of truth.
class GestureEditingController with ChangeNotifier {
  GestureEditingController({
    required this.selectionLinks,
    required MagnifierAndToolbarController overlayController,
    required LayerLink magnifierFocalPointLink,
  })  : _magnifierFocalPointLink = magnifierFocalPointLink,
        _overlayController = overlayController {
    _overlayController.addListener(_toolbarChanged);
  }

  @override
  void dispose() {
    _overlayController.removeListener(_toolbarChanged);
    super.dispose();
  }

  final SelectionLayerLinks selectionLinks;

  /// A `LayerLink` whose top-left corner sits at the location where the
  /// magnifier should magnify.
  LayerLink get magnifierFocalPointLink => _magnifierFocalPointLink;
  final LayerLink _magnifierFocalPointLink;

  /// Controls the magnifier and the toolbar.
  MagnifierAndToolbarController get overlayController => _overlayController;
  late MagnifierAndToolbarController _overlayController;
  set overlayController(MagnifierAndToolbarController value) {
    if (_overlayController != value) {
      _overlayController.removeListener(_toolbarChanged);
      _overlayController = value;
      _overlayController.addListener(_toolbarChanged);
    }
  }

  /// Whether the toolbar currently has a designated display position.
  ///
  /// The toolbar should not be displayed if this is `false`, even if
  /// [shouldDisplayToolbar] is `true`.
  bool get isToolbarPositioned => _overlayController.isToolbarPositioned;

  /// Whether the toolbar should be displayed.
  bool get shouldDisplayToolbar => _overlayController.shouldDisplayToolbar;

  /// Whether the magnifier should be displayed.
  bool get shouldDisplayMagnifier => _overlayController.shouldDisplayMagnifier;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears above the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar above this point. If not, use [toolbarBottomAnchor].
  Offset? get toolbarTopAnchor => _overlayController.toolbarTopAnchor;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears below the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar below this point. If not, use [toolbarTopAnchor].
  Offset? get toolbarBottomAnchor => _overlayController.toolbarBottomAnchor;

  /// Minimum space from the screen edges.
  EdgeInsets? get screenPadding => _overlayController.screenPadding;

  /// Shows the toolbar, and hides the magnifier.
  void showToolbar() {
    _overlayController.showToolbar();
  }

  /// Hides the toolbar.
  void hideToolbar() {
    _overlayController.hideToolbar();
  }

  /// Shows the magnify, and hides the toolbar.
  void showMagnifier() {
    _overlayController.showMagnifier();
  }

  /// Hides the magnifier.
  void hideMagnifier() {
    _overlayController.hideMagnifier();
  }

  /// Toggles the toolbar from visible to not visible, or vis-a-versa.
  void toggleToolbar() {
    _overlayController.toggleToolbar();
  }

  /// Sets the toolbar's position to the given [topAnchor] and [bottomAnchor].
  ///
  /// Setting the position will not cause the toolbar to be displayed on it's own.
  /// To display the toolbar, call [showToolbar], too.
  void positionToolbar({
    required Offset topAnchor,
    required Offset bottomAnchor,
  }) {
    _overlayController.positionToolbar(
      topAnchor: topAnchor,
      bottomAnchor: bottomAnchor,
    );
  }

  void _toolbarChanged() {
    notifyListeners();
  }
}

/// Auto-scrolls a given `ScrollPosition` based on the current position of
/// a drag handle near the boundary of the scroll region.
///
/// Clients of this object provide access to a desired `ScrollPosition` and
/// a viewport `RenderBox`. Clients also update this object whenever the
/// drag handle moves. Then, this object starts/stops auto-scrolling the
/// given `ScrollPosition` as needed, based on how close the drag handle
/// position sits to the edge of the scrollable boundary.
class DragHandleAutoScroller {
  DragHandleAutoScroller({
    required TickerProvider vsync,
    required AxisOffset dragAutoScrollBoundary,
    required ScrollPosition Function() getScrollPosition,
    required RenderBox Function() getViewportBox,
  })  : _autoScroller = AutoScroller(vsync: vsync),
        _dragAutoScrollBoundary = dragAutoScrollBoundary,
        _getScrollPosition = getScrollPosition,
        _getViewportBox = getViewportBox;

  void dispose() {
    _autoScroller.dispose();
  }

  final AutoScroller _autoScroller;
  final AxisOffset _dragAutoScrollBoundary;

  /// Returns the `ScrollPosition` that this auto-scroller should control.
  final ScrollPosition Function() _getScrollPosition;

  /// Returns the `RenderBox` of the viewport that belongs to the `Scrollable`
  /// that this auto-scroller controls.
  final RenderBox Function() _getViewportBox;

  /// Jumps to a scroll offset so that the given [offsetInViewport] is
  /// visible within the viewport boundary.
  ///
  /// Does nothing, if the given [offsetInViewport] is already visible within the viewport boundary.
  void ensureOffsetIsVisible(Offset offsetInViewport) {
    editorGesturesLog.fine("Ensuring content offset is visible in scrollable: $offsetInViewport");

    final scrollPosition = _getScrollPosition();
    final currentScrollOffset = scrollPosition.pixels;
    editorGesturesLog.fine("Current scroll offset: $currentScrollOffset");

    if (offsetInViewport.dy < _dragAutoScrollBoundary.leading) {
      // The offset is above the leading boundary. We need to scroll up
      editorGesturesLog.fine("The scrollable needs to scroll up to make offset visible.");

      // If currentScrollOffset isn't greater than zero it means we are already
      // at the top edge of the scrollable, so we can't scroll further up.
      if (currentScrollOffset > 0.0) {
        // Jump to the position where the offset sits at the leading boundary.
        scrollPosition.jumpTo(
          currentScrollOffset + (offsetInViewport.dy - _dragAutoScrollBoundary.leading),
        );
      }
    } else if (offsetInViewport.dy > _getViewportBox().size.height - _dragAutoScrollBoundary.trailing) {
      // The offset is below the trailing boundary. We need to scroll down
      editorGesturesLog.fine('The scrollable needs to scroll down to make offset visible.');
      // If currentScrollOffset isn't lesser than the maxScrollExtent it means
      // we are already at the bottom edge of the scrollable, so we can't scroll further down.
      if (currentScrollOffset < scrollPosition.maxScrollExtent) {
        // Jump to the position where the offset sits at the trailing boundary
        scrollPosition.jumpTo(
          currentScrollOffset +
              (offsetInViewport.dy - (_getViewportBox().size.height - _dragAutoScrollBoundary.trailing)),
        );
      }
    }
  }

  /// Prepares this auto-scroller to automatically scroll its `ScrollPosition`
  /// based on calls to [updateAutoScrollHandleMonitoring].
  void startAutoScrollHandleMonitoring() {
    _autoScroller.scrollPosition = _getScrollPosition();
  }

  /// Starts/stops auto-scrolling as necessary, based on the given
  /// [dragEndInViewport] and [viewportHeight].
  ///
  /// This method must be called in the following order:
  ///
  ///  1. [startAutoScrollHandleMonitoring]
  ///  2. 1+ calls to [updateAutoScrollHandleMonitoring]
  ///  3. [stopAutoScrollHandleMonitoring]
  void updateAutoScrollHandleMonitoring({
    required Offset dragEndInViewport,
  }) {
    if (dragEndInViewport.dy < _dragAutoScrollBoundary.leading &&
        _getScrollPosition().pixels > _getScrollPosition().minScrollExtent) {
      editorGesturesLog.finest('Metrics say we should try to scroll up');

      final leadingScrollBoundary = _dragAutoScrollBoundary.leading;
      final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
      final speedPercent = (1.0 - (gutterAmount / leadingScrollBoundary)).clamp(0.0, 1.0);

      _autoScroller.startScrollingUp(speedPercent);
    } else {
      _autoScroller.stopScrollingUp();
    }

    if (_getViewportBox().size.height - dragEndInViewport.dy < _dragAutoScrollBoundary.trailing &&
        _getScrollPosition().pixels < _getScrollPosition().maxScrollExtent) {
      editorGesturesLog.finest('Metrics say we should try to scroll down');

      final trailingScrollBoundary = _dragAutoScrollBoundary.trailing;
      final gutterAmount = (_getViewportBox().size.height - dragEndInViewport.dy).clamp(0.0, trailingScrollBoundary);
      final speedPercent = 1.0 - (gutterAmount / trailingScrollBoundary);

      _autoScroller.startScrollingDown(speedPercent);
    } else {
      _autoScroller.stopScrollingDown();
    }
  }

  /// Stops any on-going auto-scrolling and removes references there were
  /// setup in [startAutoScrollHandleMonitoring].
  void stopAutoScrollHandleMonitoring() {
    _autoScroller.stopScrolling();
    _autoScroller.scrollPosition = null;
  }
}
