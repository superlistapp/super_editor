import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/text.dart';

class TagTokenizer {
  /// Finds the word that surrounds the [caretPosition] in the [text], or `null`
  /// if the surrounding word is already tagged, or the caret isn't currently sitting in a word.
  static TagAroundCaret? findUntaggedTokenAroundCaret({
    required String triggerSymbol,
    required String nodeId,
    required AttributedText text,
    required TextNodePosition caretPosition,
    required bool Function(Set<Attribution>) tagFilter,
    Set<String> excludeCharacters = const {},
  }) {
    return findAttributedTokenAroundPosition(
      triggerSymbol,
      nodeId,
      text,
      caretPosition,
      tagFilter,
      excludeCharacters: excludeCharacters,
    );
  }

  static TagAroundCaret? findAttributedTokenAroundPosition(
    String triggerSymbol,
    String nodeId,
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
        (text[tokenEndOffset] != triggerSymbol || tokenEndOffset == tokenStartOffset)) {
      tokenEndOffset += 1;
    }

    final tokenRange = SpanRange(start: tokenStartOffset, end: tokenEndOffset);
    if (tokenRange.end - tokenRange.start <= 0) {
      return null;
    }

    final tagText = paragraphText.text.substring(tokenStartOffset, tokenEndOffset);
    if (!tagText.startsWith(triggerSymbol)) {
      return null;
    }

    final tokenAttributions =
        paragraphText.getAttributionSpansInRange(attributionFilter: (a) => true, range: tokenRange);
    if (!isTokenCandidate(tokenAttributions.map((span) => span.attribution).toSet())) {
      return null;
    }

    final tokenAroundCaret = TagAroundCaret(
      tagIndex: TagIndex(
        Tag(triggerSymbol, tagText.substring(1)),
        nodeId,
        tokenStartOffset,
        tokenEndOffset,
      ),
      caretOffset: position.offset,
    );

    return tokenAroundCaret;
  }

  static Set<TagIndex> findAllTagsInTextNode(TextNode textNode, String trigger) {
    final plainText = textNode.text.text;
    return plainText //
        .calculateAllWordBoundaries()
        .where((wordRange) => plainText[wordRange.start] == trigger)
        .map((tokenRange) {
          return TagIndex(
            Tag.fromTag(tokenRange.textInside(plainText)),
            textNode.id,
            tokenRange.start,
            tokenRange.end,
          );
        })
        .whereNotNull()
        .toSet();
  }

  const TagTokenizer._();
}

/// A [TagIndex], along with the current caret offset, which is expected to fall
/// somewhere within the bounds of the [TagIndex].
///
/// This data structure is useful for inspecting active typing into a token.
class TagAroundCaret {
  const TagAroundCaret({
    required this.tagIndex,
    required this.caretOffset,
  });

  /// The [TagIndex] that surrounds the caret.
  final TagIndex tagIndex;

  /// The text offset of the caret, from the start of the [TextNode] that
  /// contains the [tagIndex].
  final int caretOffset;

  /// The text offset of the caret from the start of the [tagIndex].
  int get caretOffsetInToken => caretOffset - tagIndex.startOffset;

  @override
  String toString() => "[TagAroundCaret] - tagIndex: '$tagIndex', caret offset in tag: $caretOffsetInToken";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagAroundCaret &&
          runtimeType == other.runtimeType &&
          tagIndex == other.tagIndex &&
          caretOffset == other.caretOffset;

  @override
  int get hashCode => tagIndex.hashCode ^ caretOffset.hashCode;
}

/// A [Tag] and its position within a [Document].
class TagIndex {
  const TagIndex(this.tag, this.nodeId, this.startOffset, this.endOffset);

  /// The plain-text tag value.
  final Tag tag;

  /// The node ID of the [TextNode] that contains this tag.
  final String nodeId;

  /// The text offset of the trigger symbol for this tag within the given [TextNode].
  final int startOffset;

  /// The fully-specified [DocumentPosition] associated with the tag's [startOffset].
  DocumentPosition get start => DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: startOffset));

  /// The text offset immediately after the final character in this tag, within the given [TextNode].
  final int endOffset;

  /// The fully-specified [DocumentPosition] associated with the tag's [endOffset].
  DocumentPosition get end => DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: endOffset));

  /// The [DocumentRange] from [start] to [end].
  DocumentRange get range => DocumentRange(start: start, end: end);

  /// Collects and returns all attributions in this tag's [TextNode], between the
  /// [start] of the tag and the [end] of the tag.
  AttributedSpans computeTagSpans(Document document) =>
      (document.getNodeById(nodeId) as TextNode).text.copyText(startOffset, endOffset - 1).spans;

  /// Assuming that this tag begins with the given [attribution], this method returns
  /// the [SpanRange] for the given [attribution], beginning at the [start] of this tag.
  SpanRange computeLeadingSpanForAttribution(Document document, Attribution attribution) {
    final text = (document.getNodeById(nodeId) as TextNode).text;
    if (!text.hasAttributionAt(startOffset, attribution: attribution)) {
      return SpanRange.empty;
    }

    return text.getAttributedRange({attribution}, startOffset);
  }

  @override
  String toString() => "[TokenIndex] - '${tag.tag}', $startOffset -> $endOffset, node: $nodeId";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagIndex &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          nodeId == other.nodeId &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset;

  @override
  int get hashCode => tag.hashCode ^ nodeId.hashCode ^ startOffset.hashCode ^ endOffset.hashCode;
}

/// A text tag, e.g., "@dash", "#flutter".
class Tag {
  factory Tag.fromTag(String tag) => Tag(tag[0], tag.substring(1));

  const Tag(this.trigger, this.token);

  /// The character that triggered the tag, e.g., "@".
  final String trigger;

  /// The token within the tag, e.g., returns "dash" from the tag "@dash"
  final String token;

  /// The full trigger + token, e.g., "@dash".
  String get tag => "$trigger$token";

  @override
  String toString() => "[Tag] - '$tag'";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && trigger == other.trigger && token == other.token;

  @override
  int get hashCode => trigger.hashCode ^ token.hashCode;
}
