import 'package:flutter/material.dart';

class IOSTextEditingFloatingToolbar extends StatelessWidget {
  const IOSTextEditingFloatingToolbar({
    Key? key,
    required this.onCutPressed,
    required this.onCopyPressed,
    required this.onPastePressed,
  }) : super(key: key);

  final VoidCallback onCutPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onPastePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      color: const Color(0xFF222222),
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
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
