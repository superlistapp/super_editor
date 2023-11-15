import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/mac/mac_ime.dart';
import 'package:super_editor/super_editor.dart';

/// A selection control, which displays a selected item, and upon tap, displays a
/// popover list of available options, from which the user can select a different
/// option.
///
/// Unlike Flutter `DropdownButton`, which displays the popover list in a separate route,
/// this widget displays its popover list in an `Overlay`. By using an `Overlay`, focus can be shared
/// with the [parentFocusNode]. This means that when the popover list requests focus, [parentFocusNode]
/// still has non-primary focus.
///
/// The popover list is positioned based on the following rules:
///
///    1. The popover is displayed below the selected item, if there's enough room, or
///    2. The popover is displayed above the selected item, if there's enough room, or
///    3. The popover is displayed with its bottom aligned with the bottom of
///         the given boundary, and it covers the selected item.
///
/// The popover list height is based on the following rules:
///
///    1. The popover height is constrained by [popoverGeometry.contraints], if provided,
///       becoming scrollable if there isn't enough room to display all items, or
///    2. The popover is displayed as tall as all items in the list, if there's enough room, or
///    3. The popover is displayed as tall as the available space and becomes scrollable.
///

///
/// The popover list includes keyboard selection behaviors:
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
  ///
  /// This value is passed to [buttonBuilder] to build the visual representation of the selected item.
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
  final FocusNode? parentFocusNode;

  @override
  State<ItemSelectionList<T>> createState() => ItemSelectionListState<T>();
}

@visibleForTesting
class ItemSelectionListState<T> extends State<ItemSelectionList<T>> with SingleTickerProviderStateMixin {
  int? _activeIndex;

  @visibleForTesting
  ScrollController get scrollController => _scrollController;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _scrollableKey = GlobalKey();

  /// Holds keys to each item on the list.
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _activateSelectedItem();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  void _activateSelectedItem() {
    final selectedItem = widget.value;

    if (selectedItem == null) {
      _activeIndex = null;
      return;
    }

    int selectedItemIndex = widget.items.indexOf(selectedItem);
    if (selectedItemIndex > -1) {
      // We just opened the popover.
      // Jump to the active item without animation.
      _activateItem(selectedItemIndex, Duration.zero);
    } else {
      // A selected item was provided, but it isn't included in the list of items.
      _activeIndex = null;
    }
  }

  /// Called when the user taps an item or presses ENTER with an active item.
  void _selectItem(T? item) {
    widget.onItemSelected(item);
  }

  /// Activates the item at [itemIndex] and ensure it's visible on screen.
  void _activateItem(int? itemIndex, Duration animationDuration) {
    _activeIndex = itemIndex;
    if (itemIndex != null) {
      widget.onItemActivated?.call(widget.items[itemIndex]);
    }

    // Scrolls on the next frame to let the popover to be
    // laid-out first, so we can access its RenderBox.
    onNextFrame((timeStamp) {
      _ensureActiveItemIsVisible(animationDuration);
    });
  }

  /// Scrolls the popover scrollable to display the selected item.
  void _ensureActiveItemIsVisible(Duration animationDuration) {
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
    if (event is! KeyDownEvent) {
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
        _selectItem(null);
        return KeyEventResult.handled;
      }

      _selectItem(widget.items[_activeIndex!]);

      return KeyEventResult.handled;
    }

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
      _activateItem(newActiveIndex, const Duration(milliseconds: 100));
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    _itemKeys.clear();

    for (int i = 0; i < widget.items.length; i++) {
      final key = GlobalKey();
      children.add(Container(
        key: key,
        child: widget.itemBuilder(
          context,
          widget.items[i],
          i == _activeIndex,
          () => _selectItem(widget.items[i]),
        ),
      ));
      _itemKeys.add(key);
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
          controller: _scrollController,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: _scrollableKey,
              primary: true,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
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

/// A widget which displays a button built in [buttonBuilder] with a popover
/// which follows the button.
///
/// The popover is displayed in an `Overlay` and its visibility is changed by calling
/// [PopoverController.open] or [PopoverController.close]. The popover is automatically closed
/// when the user taps outside of its bounds.
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
    this.onKeyEvent,
    this.popoverFocusNode,
    this.boundaryKey,
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

  /// Called at each key press while the popover has focus.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// [FocusNode] which will share focus with the popover.
  final FocusNode? popoverFocusNode;

  /// A [GlobalKey] to a widget that determines the bounds where the popover can be displayed.
  ///
  /// As the popover follows the selected item, it can be displayed off-screen if this [PopoverScaffold]
  /// is close to the bottom of the screen.
  ///
  /// Passing a [boundaryKey] causes the popover to be confined to the bounds of the widget
  /// bound to the [boundaryKey].
  ///
  /// If `null`, the popover is confined to the screen bounds, defined by the result of `MediaQuery.sizeOf`.
  final GlobalKey? boundaryKey;

  @override
  State<PopoverScaffold> createState() => _PopoverScaffoldState();
}

class _PopoverScaffoldState extends State<PopoverScaffold> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LeaderLink _popoverLink = LeaderLink();
  late FocusNode _popoverFocusNode;

  late FollowerBoundary _screenBoundary;

  @override
  void initState() {
    super.initState();

    _popoverFocusNode = widget.popoverFocusNode ?? FocusNode();
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

    if (oldWidget.popoverFocusNode != widget.popoverFocusNode) {
      if (oldWidget.popoverFocusNode == null) {
        _popoverFocusNode.dispose();
      }

      _popoverFocusNode = widget.popoverFocusNode ?? FocusNode();
    }

    if (oldWidget.boundaryKey != widget.boundaryKey) {
      _updateFollowerBoundary();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPopoverControllerChanged);
    _popoverLink.dispose();

    if (widget.popoverFocusNode == null) {
      _popoverFocusNode.dispose();
    }

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
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // Wait until next frame to request focus, so that the parent relationship
        // can be established between our focus node and the parent focus node.
        _popoverFocusNode.requestFocus();
      });
    } else {
      _overlayController.hide();
    }
  }

  void _onTapOutsideOfDropdown(PointerDownEvent e) {
    widget.controller.close();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildDropdown,
      child: Leader(
        link: _popoverLink,
        child: widget.buttonBuilder(context),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    return TapRegion(
      onTapOutside: _onTapOutsideOfDropdown,
      child: Actions(
        actions: disabledMacIntents,
        child: Follower.withAligner(
          link: _popoverLink,
          boundary: _screenBoundary,
          aligner: _DelegateAligner(
            delegate: widget.popoverGeometry.align,
            boundaryKey: widget.boundaryKey,
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

/// A [FollowerAligner] which uses a [delegate] to align a [Follower].
class _DelegateAligner implements FollowerAligner {
  _DelegateAligner({
    required this.delegate,
    this.boundaryKey,
  });

  /// Called to determine the position of the [Follower].
  final PopoverAligner delegate;

  /// A [GlobalKey] to a widget that determines the bounds where the popover list can be displayed.
  ///
  /// If non-`null`, the [FollowerAlignment] returned by the [delegate] must be within the bounds of its `RenderBox`.
  final GlobalKey? boundaryKey;

  @override
  FollowerAlignment align(Rect globalLeaderRect, Size followerSize) {
    return delegate(globalLeaderRect, followerSize, boundaryKey);
  }
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
    // Pin the dropdown list to the bottom, letting the follower cover the leader.
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
