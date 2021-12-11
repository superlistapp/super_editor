/// Type of handle for touch editing.
enum HandleType {
  /// Handle at a specific document position for a collapsed selection.
  collapsed,

  /// Handle on the upstream side of an expanded selection.
  upstream,

  /// Handle on the downstream side of an expanded selection.
  downstream,
}
