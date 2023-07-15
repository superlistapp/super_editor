import 'package:attributed_text/attributed_text.dart';
import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/text.dart';

class TagFinder {
  static TagAroundCaret? findTagAroundPosition({
    required TagRule tagRule,
    required String nodeId,
    required AttributedText text,
    required TextNodePosition expansionPosition,
    required bool Function(Set<Attribution> tokenAttributions) isTokenCandidate,
  }) {
    final rawText = text.text;
    int tokenStartOffset = expansionPosition.offset;
    int tokenEndOffset = expansionPosition.offset;

    final terminatingCharacters = {
      ...tagRule.excludedCharacters,
      " ",
    };

    // TODO: use characters package to move forward and backward
    while (tokenStartOffset > 0 && !terminatingCharacters.contains(rawText[tokenStartOffset - 1])) {
      tokenStartOffset -= 1;
    }
    while (tokenEndOffset < rawText.length &&
        !terminatingCharacters.contains(rawText[tokenEndOffset]) &&
        (rawText[tokenEndOffset] != tagRule.trigger || tokenEndOffset == tokenStartOffset)) {
      tokenEndOffset += 1;
    }

    final tokenRange = SpanRange(start: tokenStartOffset, end: tokenEndOffset);
    if (tokenRange.end - tokenRange.start <= 0) {
      return null;
    }

    final tagText = text.text.substring(tokenStartOffset, tokenEndOffset);
    if (!tagText.startsWith(tagRule.trigger)) {
      return null;
    }

    final tokenAttributions = text.getAttributionSpansInRange(attributionFilter: (a) => true, range: tokenRange);
    if (!isTokenCandidate(tokenAttributions.map((span) => span.attribution).toSet())) {
      return null;
    }

    // FIXME: this return is a mismatch to the name of the method - the method expands around a position, but it isn't necessarily the caret
    final tagAroundPosition = TagAroundCaret(
      tagIndex: IndexedTag(
        Tag(tagRule.trigger, tagText.substring(1)),
        nodeId,
        tokenStartOffset,
      ),
      caretOffset: expansionPosition.offset,
    );

    return tagAroundPosition;
  }

  /// Finds and returns all tags in the given [textNode], which meet the given [rule].
  static Set<IndexedTag> findAllTagsInTextNode(TextNode textNode, TagRule rule) {
    final plainText = textNode.text.text;
    return plainText //
        .calculateAllWordBoundaries()
        .where((wordRange) => rule.isTag(wordRange.textInside(plainText)))
        .map((tokenRange) {
          return IndexedTag(
            Tag.fromTag(tokenRange.textInside(plainText)),
            textNode.id,
            tokenRange.start,
          );
        })
        .whereNotNull()
        .toSet();
  }

  const TagFinder._();
}

/// A [IndexedTag], along with the current caret offset, which is expected to fall
/// somewhere within the bounds of the [IndexedTag].
///
/// This data structure is useful for inspecting active typing into a token.
class TagAroundCaret {
  const TagAroundCaret({
    required this.tagIndex,
    required this.caretOffset,
  });

  /// The [IndexedTag] that surrounds the caret.
  final IndexedTag tagIndex;

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

/// A rule for matching a text token to a tag.
///
/// A tag begins with a [trigger] character, and is then followed by one or more
/// non-whitespace characters, except for [excludedCharacters].
class TagRule {
  const TagRule({
    required this.trigger,
    this.excludedCharacters = const {},
  }) : assert(trigger.length == 1, "Trigger must be exactly one character long");

  final String trigger;
  final Set<String> excludedCharacters;

  /// Returns `true` if the entire [candidate] complies with this [TagRule].
  ///
  /// For example, assume "#" is the trigger and that "." is an excluded character.
  ///
  ///     "#flutter" returns `true`.
  ///
  ///     "#flut.ter" returns `false`.
  ///
  ///     "flutter" returns `false`.
  ///
  bool isTag(String candidate) {
    if (!candidate.startsWith(trigger)) {
      return false;
    }
    if (candidate.contains(" ")) {
      return false;
    }

    for (final excludedCharacter in excludedCharacters) {
      if (candidate.contains(excludedCharacter)) {
        return false;
      }
    }

    return true;
  }

  /// Extracts and returns a compliant tag from the beginning of the given [candidate], or `null` if
  /// the [candidate] doesn't begin with a compliant tag.
  ///
  ///     "#flutter" -> "#flutter"
  ///     "#flut.ter" -> "#flut"
  ///     "#flutter dash" -> "#flutter"
  ///     "#.flutter" -> `null`
  ///     "flutter" -> `null`
  ///
  String? findTagAtBeginning(String candidate) {
    if (!candidate.startsWith(trigger)) {
      return null;
    }

    final buffer = StringBuffer(trigger);
    for (final character in candidate.characters.toList().sublist(1)) {
      if (excludedCharacters.contains(character)) {
        break;
      }

      buffer.write(character);
    }

    if (buffer.length == 1) {
      // We didn't find any non-excluded characters after the trigger.
      return null;
    }

    return buffer.toString();
  }
}

/// A [Tag] and its position within a [Document].
///
/// A tag is a segment of text, which usually fits some kind of pattern, such "#flutter", which begins
/// with a "#" and is followed by some number of non-whitespace characters.
///
/// A tag may be attributed, but there's no requirement that the [tag] in a [IndexedTag] have any
/// particular attributions applied to it. Moreover, if an attribution is applied, it's possible
/// that the attribution is currently out of sync with the tag text bounds. It's the client's
/// responsibility to monitor the attribution bounds and keep them in sync with the content.
/// The [IndexedTag] data structure is a tool that makes such management easier.
class IndexedTag {
  const IndexedTag(this.tag, this.nodeId, this.startOffset);

  /// The plain-text tag value.
  final Tag tag;

  /// The node ID of the [TextNode] that contains this tag.
  final String nodeId;

  /// The text offset of the trigger symbol for this tag within the given [TextNode].
  final int startOffset;

  /// The fully-specified [DocumentPosition] associated with the tag's [startOffset].
  DocumentPosition get start => DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: startOffset));

  /// The text offset immediately after the final character in this tag, within the given [TextNode].
  int get endOffset => startOffset + tag.raw.length;

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
  ///
  /// This is useful to determine whether a tag attribution fully spans the tag.
  SpanRange computeLeadingSpanForAttribution(Document document, Attribution attribution) {
    final text = (document.getNodeById(nodeId) as TextNode).text;
    if (!text.hasAttributionAt(startOffset, attribution: attribution)) {
      return SpanRange.empty;
    }

    return text.getAttributedRange({attribution}, startOffset);
  }

  @override
  String toString() => "[IndexedToken] - '${tag.raw}', $startOffset -> $endOffset, node: $nodeId";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexedTag &&
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
  String get raw => "$trigger$token";

  @override
  String toString() => "[Tag] - '$raw'";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && trigger == other.trigger && token == other.token;

  @override
  int get hashCode => trigger.hashCode ^ token.hashCode;
}
