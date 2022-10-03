/// Configures the aspects of a document that show debug paint.
class DebugPaintConfig {
  const DebugPaintConfig({
    this.scrolling = false,
    this.gestures = false,
    this.scrollingMinimapId,
    this.layout = false,
  });

  final bool scrolling;
  final bool gestures;
  final String? scrollingMinimapId;
  final bool layout;
}
