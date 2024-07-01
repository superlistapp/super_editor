import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A grid where the user can navigate between its items and select one of them.
///
/// Includes the following keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" item selection up/down.
///   * Pressing LEFT/RIGHT moves the "active" item selection left/right.
///   * Pressing ENTER selects the currently active item.
class SelectableGrid<GridItemType> extends StatefulWidget {
  const SelectableGrid({
    super.key,
    this.focusNode,
    required this.value,
    required this.items,
    required this.itemBuilder,
    required this.columnCount,
    this.mainAxisExtent,
    this.onItemActivated,
    required this.onItemSelected,
    this.onCancel,
  });

  /// The [FocusNode] of the grid.
  final FocusNode? focusNode;

  /// The currently selected value or `null` if no item is selected.
  final GridItemType? value;

  /// The items that will be displayed on the grid.
  ///
  /// For each item, [itemBuilder] is called to build its visual representation.
  final List<GridItemType> items;

  /// Builds each item on the grid.
  ///
  /// This method is called for each item in [items], to build its visual representation.
  ///
  /// The provided `onTap` must be called when the item is tapped.
  final SelectableGridItemBuilder<GridItemType> itemBuilder;

  /// How many columns the grid must have.
  final int columnCount;

  /// The extent of each item on the grid.
  final double? mainAxisExtent;

  /// Called when the user activates an item on the grid.
  ///
  /// The activation can be performed by:
  ///    1. Pressing UP ARROW or DOWN ARROW.
  ///    2. Pressing LEFT ARROW or RIGHT ARROW.
  final ValueChanged<GridItemType?>? onItemActivated;

  /// Called when the user selects an item on the grid.
  ///
  /// The selection can be performed by:
  ///    1. Tapping on an item in the grid.
  ///    2. Pressing ENTER when the grid has an active item.
  final ValueChanged<GridItemType?> onItemSelected;

  /// Called when the user presses ESCAPE.
  final VoidCallback? onCancel;

  @override
  State<SelectableGrid<GridItemType>> createState() => _SelectableGridState<GridItemType>();
}

class _SelectableGridState<GridItemType> extends State<SelectableGrid<GridItemType>>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// Holds keys to each item on the grid.
  ///
  /// Used to scroll the grid to reveal the active item.
  final List<GlobalKey> _itemKeys = [];

  int? _activeIndex;

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
    if (selectedItemIndex < 0) {
      // A selected item was provided, but it isn't included in the list of items.
      _activeIndex = null;
      return;
    }

    // The grid was just displayed.
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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }
      _scrollToShowActiveItem(animationDuration);
    });
  }

  /// Scrolls the scrollable to display the selected item.
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
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
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
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_activeIndex == null || _activeIndex! >= widget.items.length - 1) {
        // We don't have an active item or we are at the end of the list. Activate the first item.
        newActiveIndex = 0;
      } else {
        // Activate the next item.
        newActiveIndex = _activeIndex! + 1;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_activeIndex == null || _activeIndex! <= 0) {
        // We don't have an active item or we are at the beginning of the list. Activate the last item.
        newActiveIndex = widget.items.length - 1;
      } else {
        // Activate the previous item.
        newActiveIndex = _activeIndex! - 1;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newActiveIndex = (_activeIndex ?? 0) + widget.columnCount;
      if (newActiveIndex >= widget.items.length - 1) {
        // We don't have an active item or we are at the end of the list. Activate the first item.
        newActiveIndex = 0;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newActiveIndex = (_activeIndex ?? 0) - widget.columnCount;
      if (newActiveIndex <= 0) {
        // We don't have an active item or we are at the beginning of the list. Activate the last item.
        newActiveIndex = widget.items.length - 1;
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
      onKeyEvent: _onKeyEvent,
      child: GridView.builder(
        clipBehavior: Clip.none,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columnCount,
          mainAxisSpacing: 2,
          mainAxisExtent: widget.mainAxisExtent,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return widget.itemBuilder(
            context,
            widget.items[index],
            _activeIndex == index,
            () => widget.onItemSelected(widget.items[index]),
          );
        },
      ),
    );
  }
}

/// Builds a grid item.
///
/// [isActive] is `true` if [item] is the currently active item on the grid, or `false` otherwise.
///
/// The active item is the currently focused item in the grid, which can be selected by pressing ENTER.
///
/// The provided [onTap] must be called when the button is tapped.
typedef SelectableGridItemBuilder<T> = Widget Function(BuildContext context, T item, bool isActive, VoidCallback onTap);
