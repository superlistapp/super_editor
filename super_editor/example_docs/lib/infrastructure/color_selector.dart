import 'package:example_docs/infrastructure/selectable_grid.dart';
import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

/// A selection control, which displays a button with the selected color, and upon tap, displays a
/// color picker with the available colors, from which the user can select a different color.
///
/// Includes the following keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" color selection up/down.
///   * Pressing LEFT/RIGHT moves the "active" color selection left/right.
///   * Pressing ENTER selects the currently active color.
class ColorSelector extends StatefulWidget {
  const ColorSelector({
    super.key,
    this.parentFocusNode,
    this.tapRegionGroupId,
    this.boundaryKey,
    this.selectedColor,
    this.colors = defaultColors,
    this.columnCount = 10,
    this.showClearButton = false,
    required this.onSelected,
    required this.colorButtonBuilder,
  });

  /// The [FocusNode], to which the color picker's [FocusNode] will be added as a child.
  ///
  /// See [PopoverScaffold.parentFocusNode] for more information.
  final FocusNode? parentFocusNode;

  /// A group ID for a tap region that is shared with the color picker.
  ///
  /// Tapping on a [TapRegion] with the same [tapRegionGroupId]
  /// won't invoke [onTapOutside].
  final String? tapRegionGroupId;

  /// A [GlobalKey] to a widget that determines the bounds where the color picker can be displayed.
  ///
  /// See [PopoverScaffold.boundaryKey] for more information.
  final GlobalKey? boundaryKey;

  /// The currently selected color or `null` if no color is selected.
  final Color? selectedColor;

  /// The colors that will be displayed in the color picker.
  ///
  /// Each color is displayed as a circle.
  final List<Color> colors;

  /// Defines the number of columns that the color picker should have.
  final int columnCount;

  /// Whether or not the color picker should display a "Clear" button.
  ///
  /// Pressing that button call [onSelected] with a `null` value.
  final bool showClearButton;

  /// Called when the user selects an item on the color picker.
  final void Function(Color? value) onSelected;

  /// Builds the button of this [ColorSelector].
  final Widget Function(BuildContext context, Color? selectedColor) colorButtonBuilder;

  @override
  State<ColorSelector> createState() => _ColorSelectorState();
}

class _ColorSelectorState extends State<ColorSelector> {
  /// Shows and hides the popover.
  final PopoverController _popoverController = PopoverController();

  /// The [FocusNode] of the color picker.
  final FocusNode _popoverFocusNode = FocusNode();

  @override
  void dispose() {
    _popoverController.dispose();
    _popoverFocusNode.dispose();
    super.dispose();
  }

  void _onItemSelected(Color? value) {
    _popoverController.close();
    widget.onSelected(value);
  }

  /// Decides a foreground color for a [background] color based on the brightness of the [background].
  ///
  /// Returns [Colors.white] if [background] is a dark color and [Colors.black] otherwise.
  Color _getColorForCheckIcon(Color background) {
    // Adapted from https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color/3943023#3943023.
    final intensity = (0.299 * background.red) + (0.587 * background.green) + (0.114 * background.blue);
    return intensity > 130 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return PopoverScaffold(
      controller: _popoverController,
      tapRegionGroupId: widget.tapRegionGroupId,
      buttonBuilder: _buildButton,
      popoverFocusNode: _popoverFocusNode,
      parentFocusNode: widget.parentFocusNode,
      boundaryKey: widget.boundaryKey,
      popoverBuilder: (context) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showClearButton) //
                _buildClearButton(),
              if (widget.showClearButton) //
                const SizedBox(height: 3),
              _buildColorGrid(),
              _buildCustomColorsButton(),
              _buildFooterButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return TextButton(
      onPressed: () => _popoverController.open(),
      style: defaultToolbarButtonStyle,
      child: widget.colorButtonBuilder(context, widget.selectedColor),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: 243,
      height: 32,
      child: TextButton.icon(
        onPressed: () => _onItemSelected(null),
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(Colors.black),
          backgroundColor: MaterialStateProperty.resolveWith(getButtonColor),
          padding: MaterialStateProperty.all(const EdgeInsets.all(5)),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
          ),
        ),
        icon: const Icon(Icons.format_color_reset),
        label: const SizedBox(
          width: double.infinity,
          child: Text(
            'None',
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  Widget _buildColorGrid() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (widget.colors.length / widget.columnCount * 20),
        maxWidth: 243,
      ),
      child: SelectableGrid<Color>(
        focusNode: _popoverFocusNode,
        value: widget.selectedColor,
        items: widget.colors,
        itemBuilder: _buildPopoverGridItem,
        onItemSelected: _onItemSelected,
        onCancel: () => _popoverController.close(),
        columnCount: widget.columnCount,
        mainAxisExtent: 18,
      ),
    );
  }

  Widget _buildPopoverGridItem(BuildContext context, Color item, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: item,
              shape: BoxShape.circle,
              boxShadow: [
                if (isActive) //
                  const BoxShadow(
                    blurRadius: 3,
                  )
              ],
            ),
          ),
          if (item == widget.selectedColor) //
            Icon(
              Icons.check,
              size: 15,
              color: _getColorForCheckIcon(item),
            )
        ],
      ),
    );
  }

  Widget _buildCustomColorsButton() {
    return SizedBox(
      width: 243,
      height: 24,
      child: TextButton(
        onPressed: () {},
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(Colors.black),
          backgroundColor: MaterialStateProperty.resolveWith(getButtonColor),
          padding: MaterialStateProperty.all(const EdgeInsets.all(5)),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
          ),
        ),
        child: const SizedBox(
          width: double.infinity,
          child: Text(
            'Custom Colors',
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () {},
          style: defaultToolbarButtonStyle,
          child: const Icon(Icons.add_circle_outline),
        ),
        TextButton(
          onPressed: () {},
          style: defaultToolbarButtonStyle,
          child: const Icon(Icons.colorize),
        ),
      ],
    );
  }
}

const defaultColors = [
  Colors.black,
  Color(0xFF434343),
  Color(0xFF666666),
  Color(0xFF999999),
  Color(0xFFB7B7B7),
  Color(0xFFCCCCCC),
  Color(0xFFD9D9D9),
  Color(0xFFEFEFEF),
  Color(0xFFF3F3F3),
  Color(0xFFDFE0E3),
  //
  Color(0xFF980201),
  Color(0xFFFF0000),
  Color(0xFFFF9900),
  Color(0xFFFFFF00),
  Color(0xFF01FF00),
  Color(0xFF02FFFF),
  Color(0xFF4A86E8),
  Color(0xFF0602FF),
  Color(0xFF9901FF),
  Color(0xFFFF00FF),
  //
  Color(0xFFE6B8AF),
  Color(0xFFF4CCCC),
  Color(0xFFFCE5CD),
  Color(0xFFFFF2CC),
  Color(0xFFD9EAD3),
  Color(0xFFD0E0E3),
  Color(0xFFC9DAF8),
  Color(0xFFCFE2F3),
  Color(0xFFD9D2E9),
  Color(0xFFEAD1DC),
  //
  Color(0xFFDD7E6A),
  Color(0xFFEA9999),
  Color(0xFFF9CB9C),
  Color(0xFFFFE599),
  Color(0xFFB6D7A8),
  Color(0xFFA2C4C9),
  Color(0xFFA4C2F4),
  Color(0xFF9FC5E8),
  Color(0xFFB4A7D6),
  Color(0xFFD5A6BD),
  //
  Color(0xFFCC4125),
  Color(0xFFE06666),
  Color(0xFFF6B26B),
  Color(0xFFFFD965),
  Color(0xFF93C47E),
  Color(0xFF76A5AF),
  Color(0xFF6D9EEB),
  Color(0xFF6FA8DC),
  Color(0xFF8E7CC3),
  Color(0xFFC27BA0),
  //
  Color(0xFFA61C01),
  Color(0xFFCC0200),
  Color(0xFFE69139),
  Color(0xFFF1C233),
  Color(0xFF6AA84F),
  Color(0xFF45808E),
  Color(0xFF3C78D8),
  Color(0xFF3D85C6),
  Color(0xFF674EA7),
  Color(0xFFA64D78),
  //
  Color(0xFF85200C),
  Color(0xFF990201),
  Color(0xFFB45F07),
  Color(0xFFBF9001),
  Color(0xFF38761D),
  Color(0xFF144F5C),
  Color(0xFF1155CC),
  Color(0xFF0B5394),
  Color(0xFF351D75),
  Color(0xFF741B46),
  //
  Color(0xFF5B0E03),
  Color(0xFF660202),
  Color(0xFF783E03),
  Color(0xFF7F6001),
  Color(0xFF274E13),
  Color(0xFF0C343D),
  Color(0xFF1B4487),
  Color(0xFF093763),
  Color(0xFF20124D),
  Color(0xFF4C1230),
  //
];
