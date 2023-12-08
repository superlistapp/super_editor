import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/super_editor.dart';

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
    this.boundaryKey,
    this.onTapOutside = _defaultPopoverOnTapOutside,
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

  @override
  State<PopoverScaffold> createState() => _PopoverScaffoldState();
}

class _PopoverScaffoldState extends State<PopoverScaffold> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LeaderLink _popoverLink = LeaderLink();

  late FollowerBoundary _screenBoundary;

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

    super.dispose();
  }

  void _updateFollowerBoundary() {
    if (widget.boundaryKey != null) {
      _screenBoundary = WidgetFollowerBoundary(
        boundaryKey: widget.boundaryKey,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } else {
      _screenBoundary = ScreenFollowerBoundary(
        screenSize: MediaQuery.sizeOf(context),
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
      onTapOutside: _onTapOutsideOfPopover,
      child: Actions(
        actions: disabledMacIntents,
        child: Follower.withAligner(
          link: _popoverLink,
          boundary: _screenBoundary,
          aligner: FunctionalAligner(
            delegate: (globalLeaderRect, followerSize) =>
                widget.popoverGeometry.align(globalLeaderRect, followerSize, widget.boundaryKey),
          ),
          child: ConstrainedBox(
            constraints: widget.popoverGeometry.constraints ?? const BoxConstraints(),
            child: widget.popoverBuilder(context),
          ),
        ),
      ),
    );
  }
}

/// A list where the user can navigate between its items and select one of them.
///
/// This widget shares focus with its [parentFocusNode]. This means that when the list requests focus,
/// [parentFocusNode] still has non-primary focus.
///
/// Includes the following keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" item selection up/down.
///   * Pressing UP with the first item active moves the active item selection to the last item.
///   * Pressing DOWN with the last item active moves the active item selection to the first item.
///   * Pressing ENTER selects the currently active item and closes the popover list.
class ItemSelectionList<T> extends StatefulWidget {
  const ItemSelectionList({
    super.key,
    required this.value,
    required this.items,
    required this.itemBuilder,
    this.onItemActivated,
    required this.onItemSelected,
    this.onCancel,
    this.focusNode,
    this.parentFocusNode,
  });

  /// The currently selected value or `null` if no item is selected.
  final T? value;

  /// The items that will be displayed in the popover list.
  ///
  /// For each item, [itemBuilder] is called to build its visual representation.
  final List<T> items;

  /// Builds each item in the popover list.
  ///
  /// This method is called for each item in [items], to build its visual representation.
  ///
  /// The provided `onTap` must be called when the item is tapped.
  final PopoverListItemBuilder<T> itemBuilder;

  /// Called when the user activates an item on the popover list.
  ///
  /// The activation can be performed by:
  ///    1. Opening the popover, when the selected item is activate.
  ///    2. Pressing UP ARROW or DOWN ARROW.
  final ValueChanged<T?>? onItemActivated;

  /// Called when the user selects an item on the popover list.
  ///
  /// The selection can be performed by:
  ///    1. Tapping on an item in the popover list.
  ///    2. Pressing ENTER when the popover list has an active item.
  final ValueChanged<T?> onItemSelected;

  /// Called when the user presses ESCAPE.
  final VoidCallback? onCancel;

  /// The [FocusNode] of the list.
  final FocusNode? focusNode;

  /// The [FocusNode], to which the list's [FocusNode] will be added as a child.
  ///
  /// In Flutter, [FocusNode]s have parents and children. This relationship allows an
  /// entire ancestor path to "have focus", but only the lowest level descendant
  /// in that path has "primary focus". This path is important because various
  /// widgets alter their presentation or behavior based on whether or not they
  /// currently have focus, even if they only have "non-primary focus".
  final FocusNode? parentFocusNode;

  @override
  State<ItemSelectionList<T>> createState() => ItemSelectionListState<T>();
}

@visibleForTesting
class ItemSelectionListState<T> extends State<ItemSelectionList<T>> with SingleTickerProviderStateMixin {
  final GlobalKey _scrollableKey = GlobalKey();

  @visibleForTesting
  final ScrollController scrollController = ScrollController();

  /// Holds keys to each item on the list.
  ///
  /// Used to scroll the list to reveal the active item.
  final List<GlobalKey> _itemKeys = [];

  int? _activeIndex;

  @override
  void initState() {
    super.initState();
    _activateSelectedItem();
  }

  @override
  void dispose() {
    scrollController.dispose();

    super.dispose();
  }

  void _activateSelectedItem() {
    final selectedItem = widget.value;

    if (selectedItem == null) {
      _activeIndex = null;
      return;
    }

    int selectedItemIndex = widget.items.indexOf(selectedItem);
    if (selectedItemIndex < 0) {
      // A selected item was provided, but it isn't included in the list of items.
      _activeIndex = null;
      return;
    }

    // We just opened the popover.
    // Jump to the active item without animation.
    _activateItem(selectedItemIndex, animationDuration: Duration.zero);
  }

  /// Activates the item at [itemIndex] and ensure it's visible on screen.
  ///
  /// The active item is selected when the user presses ENTER.
  void _activateItem(int? itemIndex, {required Duration animationDuration}) {
    _activeIndex = itemIndex;
    if (itemIndex != null) {
      widget.onItemActivated?.call(widget.items[itemIndex]);
    }

    // This method might be called before the widget was rendered.
    // For example, when the widget is created with a selected item,
    // this item is immediately activated, before the rendering pipeline is
    // executed. Therefore, the RenderBox won't be available at the same frame.
    //
    // Scrolls on the next frame to let the popover be laid-out first,
    // so we can access its RenderBox.
    onNextFrame((timeStamp) {
      _scrollToShowActiveItem(animationDuration);
    });
  }

  /// Scrolls the popover scrollable to display the selected item.
  void _scrollToShowActiveItem(Duration animationDuration) {
    if (_activeIndex == null) {
      return;
    }

    final key = _itemKeys[_activeIndex!];

    final childRenderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (childRenderBox == null) {
      return;
    }

    childRenderBox.showOnScreen(
      rect: Offset.zero & childRenderBox.size,
      duration: animationDuration,
      curve: Curves.easeIn,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (!const [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.escape,
    ].contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_activeIndex == null) {
        // The user pressed ENTER without an active item.
        // Clear the selected item.
        widget.onItemSelected(null);
        return KeyEventResult.handled;
      }

      widget.onItemSelected(widget.items[_activeIndex!]);

      return KeyEventResult.handled;
    }

    // The user pressed an arrow key. Update the active item.
    int? newActiveIndex;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_activeIndex == null || _activeIndex! >= widget.items.length - 1) {
        // We don't have an active item or we are at the end of the list. Activate the first item.
        newActiveIndex = 0;
      } else {
        // Activate the next item.
        newActiveIndex = _activeIndex! + 1;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_activeIndex == null || _activeIndex! <= 0) {
        // We don't have an active item or we are at the beginning of the list. Activate the last item.
        newActiveIndex = widget.items.length - 1;
      } else {
        // Activate the previous item.
        newActiveIndex = _activeIndex! - 1;
      }
    }

    setState(() {
      _activateItem(newActiveIndex, animationDuration: const Duration(milliseconds: 100));
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _itemKeys.clear();

    for (int i = 0; i < widget.items.length; i++) {
      _itemKeys.add(GlobalKey());
    }
    return Focus(
      focusNode: widget.focusNode,
      parentNode: widget.parentFocusNode,
      onKeyEvent: _onKeyEvent,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
          physics: const ClampingScrollPhysics(),
        ),
        child: PrimaryScrollController(
          controller: scrollController,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: _scrollableKey,
              primary: true,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.items.length; i++)
                      KeyedSubtree(
                        key: _itemKeys[i],
                        child: widget.itemBuilder(
                          context,
                          widget.items[i],
                          i == _activeIndex,
                          () => widget.onItemSelected(widget.items[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle shape with a fade-in transition.
class PopoverShape extends StatefulWidget {
  const PopoverShape({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PopoverShape> createState() => _PopoverShapeState();
}

class _PopoverShapeState extends State<PopoverShape> with SingleTickerProviderStateMixin {
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

/// Closes the popover when tapping outside.
void _defaultPopoverOnTapOutside(PopoverController controller) {
  controller.close();
}

/// Computes the position of a popover list relative to the dropdown button.
///
/// The following rules are applied, in order:
///
/// 1. If there is enough room to display the dropdown list beneath the button,
/// position it below the button.
///
/// 2. If there is enough room to display the dropdown list above the button,
/// position it above the button.
///
/// 3. Pin the dropdown list to the bottom of the `RenderBox` bound to [boundaryKey],
/// letting the dropdown list cover the button.
FollowerAlignment defaultPopoverAligner(Rect globalLeaderRect, Size followerSize, GlobalKey? boundaryKey) {
  final boundsBox = boundaryKey?.currentContext?.findRenderObject() as RenderBox?;
  final bounds = boundsBox != null
      ? Rect.fromPoints(
          boundsBox.localToGlobal(Offset.zero),
          boundsBox.localToGlobal(boundsBox.size.bottomRight(Offset.zero)),
        )
      : Rect.largest;
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

/// A function to align a Widget following a leader Widget.
///
/// If a [boundaryKey] is given, the alignment must be within the bounds of its `RenderBox`.
typedef PopoverAligner = FollowerAlignment Function(Rect globalLeaderRect, Size followerSize, GlobalKey? boundaryKey);

/// Builds a popover list item.
///
/// [isActive] is `true` if [item] is the currently active item on the list, or `false` otherwise.
///
/// The provided [onTap] must be called when the button is tapped.
typedef PopoverListItemBuilder<T> = Widget Function(BuildContext context, T item, bool isActive, VoidCallback onTap);

/// Builds a button is an [ItemSelectionList].
///
/// The provided [onTap] must be called when the button is tapped.
typedef PopoverListButtonBuilder<T> = Widget Function(BuildContext context, T? selectedItem, VoidCallback onTap);
