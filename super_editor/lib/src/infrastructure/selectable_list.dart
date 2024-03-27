import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/super_editor.dart';

/// A list where the user can navigate between its items and select one of them.
///
/// Includes the following keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" item selection up/down.
///   * Pressing UP with the first item active moves the active item selection to the last item.
///   * Pressing DOWN with the last item active moves the active item selection to the first item.
///   * Pressing ENTER selects the currently active item.
class ItemSelectionList<T> extends StatefulWidget {
  const ItemSelectionList({
    super.key,
    required this.value,
    required this.items,
    this.axis = Axis.vertical,
    required this.itemBuilder,
    this.separatorBuilder,
    this.onItemActivated,
    required this.onItemSelected,
    this.onCancel,
    this.focusNode,
  });

  /// The currently selected value or `null` if no item is selected.
  final T? value;

  /// The items that will be displayed in the popover list.
  ///
  /// For each item, [itemBuilder] is called to build its visual representation.
  final List<T> items;

  /// Determines if the list should be displayed vertically or horizontally.
  final Axis axis;

  /// Builds each item in the popover list.
  ///
  /// This method is called for each item in [items], to build its visual representation.
  ///
  /// The provided `onTap` must be called when the item is tapped.
  final SelectableListItemBuilder<T> itemBuilder;

  /// Builds a separator for each item in the list.
  ///
  /// If `null`, no separator is displayed.
  final IndexedWidgetBuilder? separatorBuilder;

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
                child: _buildItemsLayout(
                  children: [
                    for (int i = 0; i < widget.items.length; i++) ...[
                      if (i > 0 && widget.separatorBuilder != null) //
                        widget.separatorBuilder!(context, i),
                      KeyedSubtree(
                        key: _itemKeys[i],
                        child: widget.itemBuilder(
                          context,
                          widget.items[i],
                          i == _activeIndex,
                          () => widget.onItemSelected(widget.items[i]),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a `Row` or `Column` which displays the items, depending
  /// whether the list is configured to be displayed horizontally or vertically.
  Widget _buildItemsLayout({required List<Widget> children}) {
    return widget.axis == Axis.horizontal //
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
  }
}

/// Builds a list item.
///
/// [isActive] is `true` if [item] is the currently active item on the list, or `false` otherwise.
///
/// The active item is the currently focused item in the list, which can be selected by pressing ENTER.
///
/// The provided [onTap] must be called when the button is tapped.
typedef SelectableListItemBuilder<T> = Widget Function(BuildContext context, T item, bool isActive, VoidCallback onTap);
