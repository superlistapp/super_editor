import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

/// A selection control, which displays a button with the selected text, and upon tap, displays a
/// popover list of available texts, from which the user can select a different text.
///
/// Includes the following keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" text selection up/down.
///   * Pressing UP with the first text active moves the active text selection to the last text.
///   * Pressing DOWN with the last text active moves the active text selection to the first text.
///   * Pressing ENTER selects the currently active text.
class TextItemSelector extends StatefulWidget {
  const TextItemSelector({
    super.key,
    required this.parentFocusNode,
    this.tapRegionGroupId,
    this.boundaryKey,
    this.selectedText,
    required this.items,
    this.popoverGeometry,
    this.buttonSize,
    this.itemBuilder = defaultPopoverListItemBuilder,
    this.separatorBuilder,
    required this.onSelected,
  });

  /// The [FocusNode], to which the popover list's [FocusNode] will be added as a child.
  ///
  /// See [PopoverScaffold.parentFocusNode] for more information.
  final FocusNode parentFocusNode;

  /// A group ID for a tap region that is shared with the popover list.
  ///
  /// Tapping on a [TapRegion] with the same [tapRegionGroupId]
  /// won't invoke [onTapOutside].
  final String? tapRegionGroupId;

  /// A [GlobalKey] to a widget that determines the bounds where the popover list can be displayed.
  ///
  /// See [PopoverScaffold.boundaryKey] for more information.
  final GlobalKey? boundaryKey;

  /// The currently selected text or `null` if no text is selected.
  ///
  /// This value is used to build the button.
  final TextItem? selectedText;

  /// The items that will be displayed in the popover list.
  ///
  /// For each item, its [TextItem.label] is displayed.
  final List<TextItem> items;

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

  /// Called when the user selects an item on the popover list.
  final void Function(TextItem? value) onSelected;

  @override
  State<TextItemSelector> createState() => _TextItemSelectorState();
}

class _TextItemSelectorState extends State<TextItemSelector> {
  final PopoverController _popoverController = PopoverController();
  final WidgetStatesController _buttonStatesController = WidgetStatesController();
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
    _buttonStatesController.update(WidgetState.pressed, _popoverController.shouldShow);
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
      popoverGeometry:
          widget.popoverGeometry ?? const PopoverGeometry(aligner: FunctionalPopoverAligner(popoverAligner)),
    );
  }

  Widget _buildButton(BuildContext context) {
    final size = WidgetStateProperty.all(widget.buttonSize ?? const Size(97, 30));
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
              widget.selectedText?.label ?? '',
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
          value: widget.selectedText,
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
