import 'package:super_editor/src/infrastructure/strings.dart';

/// User interaction heuristics that simulate observed behavior on
/// iOS devices.
class IosHeuristics {
  /// Adjusts a user's tap offset within a text field, or a paragraph, by
  /// moving the caret to a word boundary, as observed on iOS.
  static int adjustTapOffset(String text, int tapOffset) {
    assert(tapOffset >= 0 && tapOffset < text.length);
    if (tapOffset == 0) {
      return 0;
    }

    final upstreamWordStart = text.moveOffsetUpstreamByWord(tapOffset) ?? 0;
    final upstreamWordEnd = text.moveOffsetDownstreamByWord(upstreamWordStart) ?? text.length;

    final downstreamWordEnd = text.moveOffsetDownstreamByWord(tapOffset) ?? text.length;
    final downstreamWordStart = text.moveOffsetUpstreamByWord(downstreamWordEnd) ?? 0;

    if (text[tapOffset] == " ") {
      // User tapped between words. Pick the nearest word.
      return downstreamWordStart - tapOffset < tapOffset - upstreamWordEnd ? downstreamWordStart : upstreamWordEnd;
    } else {
      // User tapped within a word. Adjust the offset to the end of the
      // word unless the user is within 1 character of the start of the word.
      if (tapOffset <= upstreamWordEnd) {
        // The tap position is within the upstream word.
        return tapOffset - upstreamWordStart <= 1 ? upstreamWordStart : upstreamWordEnd;
      } else {
        // The tap position is within the downstream word.
        return tapOffset - downstreamWordStart <= 1 ? downstreamWordStart : downstreamWordEnd;
      }
    }
  }

  const IosHeuristics._();
}
