import 'package:flutter/material.dart';
import 'package:overlord/overlord.dart';

class IOSTextEditingFloatingToolbar extends StatelessWidget {
  const IOSTextEditingFloatingToolbar({
    Key? key,
    this.onCutPressed,
    this.onCopyPressed,
    this.onPastePressed,
    required this.focalPoint,
  }) : super(key: key);

  final VoidCallback? onCutPressed;
  final VoidCallback? onCopyPressed;
  final VoidCallback? onPastePressed;

  /// The point where the toolbar should point to.
  ///
  /// Represented as global coordinates.
  final Offset focalPoint;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return CupertinoPopoverToolbar(
      focalPoint: StationaryMenuFocalPoint(focalPoint),
      elevation: 8.0,
      backgroundColor: brightness == Brightness.dark ? const Color(0xFF333333) : Colors.white,
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
      ],
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
    required Brightness brightness,
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
            style: TextStyle(
              color: brightness == Brightness.dark ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
