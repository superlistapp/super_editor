import 'package:flutter/widgets.dart';

/// Type of handle for touch editing.
enum HandleType {
  /// Handle at a specific document position for a collapsed selection.
  collapsed,

  /// Handle on the upstream side of an expanded selection.
  upstream,

  /// Handle on the downstream side of an expanded selection.
  downstream,
}

/// Configuration used to display a toolbar.
class ToolbarConfig {
  ToolbarConfig({
    required this.focalPoint,
  });

  /// The desired point where a toolbar arrow should point to.
  ///
  /// Represented as global coordinates.
  final Offset focalPoint;
}
