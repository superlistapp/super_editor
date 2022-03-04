import 'dart:ui';

import 'document.dart';

/// Stylesheet for styling content within a single-column document layout.
///
/// A stylesheet is a series of priority-order rules that generate style
/// metadata, which is then applied to the layout and the blocks within the
/// layout.
class Stylesheet {
  const Stylesheet(this.rules);

  /// Priority-order list of style rules.
  final List<StyleRule> rules;
}

/// A single style rule within a [Stylesheet].
///
/// A style rule combines a [selector], which identifies desired blocks within
/// a single-column document, and a [styler], which generates style metadata
/// for those blocks.
///
/// There is no explicit contract for the style metadata. Different blocks might
/// expect different styles. For example, a paragraph might understand text styles,
/// but an image wouldn't. The style system ignores any style metadata that a
/// given block doesn't understand.
class StyleRule {
  const StyleRule(this.selector, this.styler);

  /// Selector that identifies document blocks that this rule should apply to.
  final BlockSelector selector;

  /// Styles the blocks that this rule applies to.
  final Styler styler;
}

/// Generates style metadata for the given [DocumentNode] within the [Document].
typedef Styler = Map<String, dynamic> Function(Document, DocumentNode);

/// Selects blocks in a document that match a given rule.
class BlockSelector {
  const BlockSelector(this.blockType)
      : precedingBlockType = null,
        followingBlockType = null;

  const BlockSelector.all()
      : blockType = null,
        precedingBlockType = null,
        followingBlockType = null;

  const BlockSelector._({
    this.blockType,
    this.precedingBlockType,
    this.followingBlockType,
  });

  /// The desired type of block, or `null` to match any block.
  final String? blockType;

  /// Type of block that appears immediately before the desired block.
  final String? precedingBlockType;

  /// Returns a modified version of this selector that only selects blocks
  /// that appear immediately after the given [blockType].
  BlockSelector after(String blockType) => BlockSelector._(
        blockType: blockType,
        precedingBlockType: blockType,
        followingBlockType: followingBlockType,
      );

  /// Type of block that appears immediately after the desired block.
  final String? followingBlockType;

  /// Returns a modified version of this selector that only selects blocks
  /// that appear immediately before the given [blockType].
  BlockSelector before(String blockType) => BlockSelector._(
        blockType: blockType,
        precedingBlockType: precedingBlockType,
        followingBlockType: blockType,
      );

  /// Returns `true` if this selector matches the block for the given [node], or
  /// `false`, otherwise.
  bool matches(Document document, DocumentNode node) {
    if (blockType != null && node.getMetadataValue("blockType") != blockType) {
      return false;
    }

    if (precedingBlockType != null) {
      final nodeBefore = document.getNodeBefore(node);
      if (nodeBefore == null || nodeBefore.getMetadataValue("blockType") != precedingBlockType) {
        return false;
      }
    }

    if (followingBlockType != null) {
      final nodeAfter = document.getNodeAfter(node);
      if (nodeAfter == null || nodeAfter.getMetadataValue("blockType") != followingBlockType) {
        return false;
      }
    }

    return true;
  }
}

/// Styles applied to the user's selection, e.g., caret, selected text.
class SelectionStyles {
  const SelectionStyles({
    required this.textCaretColor,
    required this.selectionColor,
  });

  final Color textCaretColor;
  final Color selectionColor;
}
