import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A selection control, which displays a button with the selected item, and upon tap, displays a
/// popover list of available text options, from which the user can select a different
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
///    1. The popover is displayed as tall as all items in the list, if there's enough room, or
///    2. The popover is displayed as tall as the available space and becomes scrollable.
///
/// The popover list includes keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" item selection up/down.
///   * Pressing UP with the first item active moves the active item selection to the last item.
///   * Pressing DOWN with the last item active moves the active item selection to the first item.
///   * Pressing ENTER selects the currently active item and closes the popover list.
class TextItemSelector extends StatefulWidget {
  const TextItemSelector({
    super.key,
    required this.parentFocusNode,
    this.tapRegionGroupId,
    this.boundaryKey,
    required this.items,
    this.value,
    required this.onSelected,
    this.popoverGeometry,
    this.buttonSize,
    this.itemBuilder = defaultPopoverListItemBuilder,
    this.separatorBuilder,
  });

  /// The [FocusNode], to which the popover list's [FocusNode] will be added as a child.
  ///
  /// In Flutter, [FocusNode]s have parents and children. This relationship allows an
  /// entire ancestor path to "have focus", but only the lowest level descendant
  /// in that path has "primary focus". This path is important because various
  /// widgets alter their presentation or behavior based on whether or not they
  /// currently have focus, even if they only have "non-primary focus".
  ///
  /// When the popover list of items is visible, that list will have primary focus.
  /// Moreover, because the popover list is built in an `Overlay`, none of your
  /// widgets are in the natural focus path for that popover list. Therefore, if you
  /// need your widget tree to retain focus while the popover list is visible, then
  /// you need to provide the [FocusNode] that the popover list should use as its
  /// parent, thereby retaining focus for your widgets.
  final FocusNode parentFocusNode;

  /// A group ID for a tap region that is shared with the popover list.
  ///
  /// Tapping on a [TapRegion] with the same [tapRegionGroupId]
  /// won't invoke [onTapOutside].
  final String? tapRegionGroupId;

  /// A [GlobalKey] to a widget that determines the bounds where the popover list can be displayed.
  ///
  /// As the popover list follows the selected item, it can be displayed off-screen if this [TextItemSelector]
  /// is close to the bottom of the screen.
  ///
  /// Passing a [boundaryKey] causes the popover list to be confined to the bounds of the widget
  /// bound to the [boundaryKey].
  ///
  /// If `null`, the popover list is confined to the screen bounds, defined by the result of `MediaQuery.sizeOf`
  final GlobalKey? boundaryKey;

  /// The items that will be displayed in the popover list.
  ///
  /// For each item, its [TextItem.label] is displayed.
  final List<TextItem> items;

  /// The currently selected value or `null` if no item is selected.
  ///
  /// This value is used to build the button.
  final TextItem? value;

  /// Called when the user selects an item on the popover list.
  final void Function(TextItem? value) onSelected;

  /// Builds each item on the list.
  ///
  /// Defaults to [defaultPopoverListItemBuilder].
  final SelectableListItemBuilder<TextItem> itemBuilder;

  /// Builds a separator between each item.
  ///
  /// If `null`, no separator is displayed.
  final IndexedWidgetBuilder? separatorBuilder;

  /// The desired size of the button.
  ///
  /// If `null` a default fixed size is used.
  final Size? buttonSize;

  /// Controls the size and position of the popover.
  ///
  /// The popover is first sized, then positioned.
  final PopoverGeometry? popoverGeometry;

  @override
  State<TextItemSelector> createState() => _TextItemSelectorState();
}

class _TextItemSelectorState extends State<TextItemSelector> {
  final PopoverController _popoverController = PopoverController();
  final MaterialStatesController _buttonStatesController = MaterialStatesController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _popoverController.addListener(_onPopoverVisibilityChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _popoverController.dispose();
    _buttonStatesController.dispose();
    super.dispose();
  }

  void _onItemSelected(TextItem? value) {
    if (value == null) {
      return;
    }
    widget.onSelected(value);
    _popoverController.close();
  }

  void _onPopoverVisibilityChange() {
    _buttonStatesController.update(MaterialState.pressed, _popoverController.shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    return PopoverScaffold(
      popoverFocusNode: _focusNode,
      parentFocusNode: widget.parentFocusNode,
      tapRegionGroupId: widget.tapRegionGroupId,
      controller: _popoverController,
      buttonBuilder: _buildButton,
      popoverBuilder: _buildPopover,
      popoverGeometry: widget.popoverGeometry ?? const PopoverGeometry(align: popoverAligner),
    );
  }

  Widget _buildButton(BuildContext context) {
    final size = MaterialStateProperty.all(widget.buttonSize ?? const Size(97, 30));
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        TextButton(
          statesController: _buttonStatesController,
          onPressed: () => _popoverController.open(),
          style: defaultToolbarButtonStyle.copyWith(
            fixedSize: size,
            minimumSize: size,
            maximumSize: size,
          ),
          child: SizedBox(
            width: (widget.buttonSize?.width ?? 97) - 30,
            child: Text(
              widget.value?.label ?? '',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.black.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Positioned(
          right: 0,
          child: Icon(Icons.arrow_drop_down),
        ),
      ],
    );
  }

  Widget _buildPopover(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.hardEdge,
      color: Colors.white,
      child: SizedBox(
        child: ItemSelectionList<TextItem>(
          focusNode: _focusNode,
          value: widget.value,
          items: widget.items,
          itemBuilder: widget.itemBuilder,
          separatorBuilder: widget.separatorBuilder,
          onItemSelected: _onItemSelected,
          onCancel: () => _popoverController.close(),
        ),
      ),
    );
  }
}

Widget defaultPopoverListItemBuilder(BuildContext context, TextItem item, bool isActive, VoidCallback onTap) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: isActive ? Colors.grey.withOpacity(0.2) : Colors.transparent,
    ),
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// An option that is displayed as text by a [TextItemSelector].
///
/// Two [TextItem]s are considered to be equal if they have the same [id].
class TextItem {
  const TextItem({
    required this.id,
    required this.label,
  });

  /// The value that identifies this item.
  final String id;

  /// The text that is displayed.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
