/// Values that reflect standard or default floating cursor policies.
class FloatingCursorPolicies {
  static const defaultFloatingCursorHeight = 20.0;
  static const defaultFloatingCursorWidth = 2.0;

  /// The maximum horizontal distance from the bounds of selectable text, for which we want to render
  /// the floating cursor.
  ///
  /// Beyond this distance, no floating cursor is rendered.
  static const maximumDistanceToBeNearText = 30.0;
}
