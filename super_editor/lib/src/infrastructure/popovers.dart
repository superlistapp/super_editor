import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/platforms/mac/mac_ime.dart';

/// Widget that displays a [child] and blocks Flutter [Intent]s
/// that causes focus traversal.
class SuperEditorPopover extends StatelessWidget {
  const SuperEditorPopover({
    super.key,
    required this.child,
  });

  /// The popover to display.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: disabledMacIntents,
      child: child,
    );
  }
}
