import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A selection control, which displays a button with the selected icon, and upon tap, displays a
/// popover list of available icons, from which the user can select a different icon.
class IconSelector extends StatefulWidget {
  const IconSelector({
    super.key,
    this.parentFocusNode,
    this.tapRegionGroupId,
    this.boundaryKey,
    this.selectedIcon,
    required this.icons,
    required this.onSelected,
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
  final FocusNode? parentFocusNode;

  /// A group ID for a tap region that is shared with the popover list.
  ///
  /// Tapping on a [TapRegion] with the same [tapRegionGroupId]
  /// won't invoke [onTapOutside].
  final String? tapRegionGroupId;

  /// A [GlobalKey] to a widget that determines the bounds where the popover list can be displayed.
  ///
  /// As the popover list follows the selected item, it can be displayed off-screen if this [IconSelector]
  /// is close to the bottom of the screen.
  ///
  /// Passing a [boundaryKey] causes the popover list to be confined to the bounds of the widget
  /// bound to the [boundaryKey].
  ///
  /// If `null`, the popover list is confined to the screen bounds, defined by the result of `MediaQuery.sizeOf`.
  final GlobalKey? boundaryKey;

  /// The currently selected icon or `null` if no icon is selected.
  final IconItem? selectedIcon;

  /// The icons that will be displayed in the popover list.
  final List<IconItem> icons;

  /// Called when the user selects an icon on the popover list.
  final void Function(IconItem? value) onSelected;

  @override
  State<IconSelector> createState() => _IconSelectorState();
}

class _IconSelectorState extends State<IconSelector> {
  /// Shows and hides the popover.
  final PopoverController _popoverController = PopoverController();

  /// The [FocusNode] of the popover list.
  final FocusNode _popoverFocusNode = FocusNode();

  @override
  void dispose() {
    _popoverController.dispose();
    _popoverFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopoverScaffold(
      tapRegionGroupId: widget.tapRegionGroupId,
      controller: _popoverController,
      buttonBuilder: _buildButton,
      popoverFocusNode: _popoverFocusNode,
      parentFocusNode: widget.parentFocusNode,
      popoverGeometry: const PopoverGeometry(
        constraints: BoxConstraints(minHeight: 40),
        align: popoverAligner,
      ),
      popoverBuilder: (context) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.hardEdge,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: ItemSelectionList<IconItem>(
            axis: Axis.horizontal,
            focusNode: _popoverFocusNode,
            value: widget.selectedIcon,
            items: widget.icons,
            itemBuilder: _buildItem,
            onItemSelected: _onItemSelected,
            onCancel: () => _popoverController.close(),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconItem item, bool isActive, VoidCallback onTap) {
    return Container(
      height: 30,
      width: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: item == widget.selectedIcon
            ? toolbarButtonSelectedColor
            : isActive
                ? Colors.grey.withOpacity(0.2)
                : Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Icon(item.icon),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return TextButton(
      onPressed: () => _popoverController.open(),
      style: defaultToolbarButtonStyle,
      child: widget.selectedIcon == null //
          ? const SizedBox()
          : Icon(widget.selectedIcon!.icon),
    );
  }

  void _onItemSelected(IconItem? value) {
    _popoverController.close();
    widget.onSelected(value);
  }
}

/// An option that is displayed as an icon by a [IconSelector].
///
/// Two [IconItem]s are considered to be equal if they have the same [id].
class IconItem {
  const IconItem({
    required this.id,
    required this.icon,
  });

  /// The value that identifies this item.
  final String id;

  /// The icon that is displayed.
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IconItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
