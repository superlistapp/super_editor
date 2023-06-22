import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/default_editor/text.dart';

class TagTokenizer {
  /// Finds the word that surrounds the [caretPosition] in the [text], or `null`
  /// if the surrounding word is already tagged, or the caret isn't currently sitting in a word.
  static TagTokenAroundCaret? findUntaggedTokenAroundCaret({
    required String triggerSymbol,
    required AttributedText text,
    required TextNodePosition caretPosition,
    required bool Function(Set<Attribution>) tagFilter,
    Set<String> excludeCharacters = const {},
  }) {
    return findAttributedTokenAroundPosition(
      triggerSymbol,
      text,
      caretPosition,
      tagFilter,
      excludeCharacters: excludeCharacters,
    );
  }

  static TagTokenAroundCaret? findAttributedTokenAroundPosition(
    String triggerSymbol,
    AttributedText paragraphText,
    TextNodePosition position,
    bool Function(Set<Attribution> tokenAttributions) isTokenCandidate, {
    Set<String> excludeCharacters = const {},
  }) {
    final text = paragraphText.text;
    int tokenStartOffset = position.offset;
    int tokenEndOffset = position.offset;

    final terminatingCharacters = {
      ...excludeCharacters,
      " ",
    };

    // TODO: use characters package to move forward and backward
    while (tokenStartOffset > 0 && !terminatingCharacters.contains(text[tokenStartOffset - 1])) {
      tokenStartOffset -= 1;
    }
    while (tokenEndOffset < text.length &&
        !terminatingCharacters.contains(text[tokenEndOffset]) &&
        text[tokenEndOffset] != triggerSymbol) {
      tokenEndOffset += 1;
    }

    final tokenRange = SpanRange(start: tokenStartOffset, end: tokenEndOffset - 1);
    final tokenAttributions = paragraphText.getAllAttributionsThroughout(tokenRange);
    if (!isTokenCandidate(tokenAttributions)) {
      return null;
    }

    final token = text.substring(tokenStartOffset, tokenEndOffset);

    return TagTokenAroundCaret(
      token: TagToken(
        token,
        tokenStartOffset,
        tokenEndOffset,
      ),
      caretOffset: position.offset,
    );
  }

  const TagTokenizer._();
}

/// A [TagToken], along with the current caret offset, which is expected to fall
/// somewhere within the bounds of the [TagToken].
///
/// This data structure is useful for inspecting active typing into a token.
class TagTokenAroundCaret {
  const TagTokenAroundCaret({
    required this.token,
    required this.caretOffset,
  });

  final TagToken token;

  final int caretOffset;

  int get caretOffsetInToken => caretOffset - token.startOffset;

  @override
  String toString() =>
      "[TokenAroundCaret] - token: '${token.value}', start: ${token.startOffset}, end: ${token.endOffset}, caret offset in token: $caretOffsetInToken";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagTokenAroundCaret &&
          runtimeType == other.runtimeType &&
          token.value == other.token.value &&
          caretOffsetInToken == other.caretOffsetInToken;

  @override
  int get hashCode => token.value.hashCode ^ caretOffsetInToken.hashCode;
}

/// A text [value], along with its text offsets within some [TextNode].
class TagToken {
  const TagToken(this.value, this.startOffset, this.endOffset);

  final String value;

  final int startOffset;

  // The final index, plus 1, to match normal String semantics, rather than matching AttributionSpan semantics.
  final int endOffset;

  @override
  String toString() => "[Token] - '$value', $startOffset -> $endOffset";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagToken &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset;

  @override
  int get hashCode => value.hashCode ^ startOffset.hashCode ^ endOffset.hashCode;
}
