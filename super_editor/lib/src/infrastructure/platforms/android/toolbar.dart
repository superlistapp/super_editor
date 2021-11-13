import 'package:flutter/material.dart';

class AndroidTextEditingFloatingToolbar extends StatelessWidget {
  const AndroidTextEditingFloatingToolbar({
    Key? key,
    required this.onCutPressed,
    required this.onCopyPressed,
    required this.onPastePressed,
    required this.onSelectAllPressed,
  }) : super(key: key);

  final VoidCallback onCutPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onPastePressed;
  final VoidCallback onSelectAllPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(4),
      elevation: 3,
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            onPressed: onCutPressed,
            title: 'Cut',
          ),
          _buildButton(
            onPressed: onCopyPressed,
            title: 'Copy',
          ),
          _buildButton(
            onPressed: onPastePressed,
            title: 'Paste',
          ),
          _buildButton(
            onPressed: onSelectAllPressed,
            title: 'Select All',
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
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
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
