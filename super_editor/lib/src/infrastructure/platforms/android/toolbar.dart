import 'package:flutter/material.dart';

class AndroidTextEditingFloatingToolbar extends StatelessWidget {
  const AndroidTextEditingFloatingToolbar({
    Key? key,
    this.onCutPressed,
    this.onCopyPressed,
    this.onPastePressed,
    this.onSelectAllPressed,
  }) : super(key: key);

  final VoidCallback? onCutPressed;
  final VoidCallback? onCopyPressed;
  final VoidCallback? onPastePressed;
  final VoidCallback? onSelectAllPressed;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      borderRadius: BorderRadius.circular(1),
      elevation: 1,
      color: brightness == Brightness.dark ? const Color(0xFF424242) : Colors.white,
      type: MaterialType.card,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCutPressed != null)
            _buildButton(
              onPressed: onCutPressed!,
              title: 'Cut',
              brightness: brightness,
            ),
          if (onCopyPressed != null)
            _buildButton(
              onPressed: onCopyPressed!,
              title: 'Copy',
              brightness: brightness,
            ),
          if (onPastePressed != null)
            _buildButton(
              onPressed: onPastePressed!,
              title: 'Paste',
              brightness: brightness,
            ),
          if (onSelectAllPressed != null)
            _buildButton(
              onPressed: onSelectAllPressed!,
              title: 'Select All',
              brightness: brightness,
            ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
    required Brightness brightness,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          title,
          style: TextStyle(
            color: brightness == Brightness.dark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
