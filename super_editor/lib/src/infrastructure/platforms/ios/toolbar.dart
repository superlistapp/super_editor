import 'package:flutter/material.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/src/infrastructure/colors.dart';

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

    return Theme(
      data: ThemeData(
        colorScheme: brightness == Brightness.light //
            ? const ColorScheme.light(primary: Colors.black)
            : const ColorScheme.dark(primary: Colors.white),
      ),
      child: CupertinoPopoverToolbar(
        focalPoint: StationaryMenuFocalPoint(focalPoint),
        elevation: 8.0,
        backgroundColor: brightness == Brightness.dark //
            ? iOSToolbarDarkBackgroundColor
            : iOSToolbarLightBackgroundColor,
        children: [
          if (onCutPressed != null)
            _buildButton(
              onPressed: onCutPressed!,
              title: 'Cut',
            ),
          if (onCopyPressed != null)
            _buildButton(
              onPressed: onCopyPressed!,
              title: 'Copy',
            ),
          if (onPastePressed != null)
            _buildButton(
              onPressed: onPastePressed!,
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
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
