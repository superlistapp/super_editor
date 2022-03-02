import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';

import '../../core/document.dart';

/// Style rules applied throughout a [SingleColumnDocumentLayout].
///
/// These rules are like CSS, specifically for a [SingleColumnDocumentLayout].
class SingleColumnLayoutStylesheet {
  const SingleColumnLayoutStylesheet({
    required this.margin,
    required this.standardContentWidth,
    required this.blockStyles,
    required this.inlineTextStyler,
  });

  /// Space added around the entire document.
  final EdgeInsetsGeometry margin;

  /// The width of a standard piece of content within the document,
  /// assuming there are no overriding width styles for that content.
  final double standardContentWidth;

  /// Styles that apply to entire categories of content types, e.g.,
  /// all header1's, all blockquotes.
  final DocumentBlockStyles blockStyles;

  /// Style adjuster that applies desired styles to inline text spans,
  /// e.g., bold, italics, strikethrough.
  final AttributionStyleAdjuster inlineTextStyler;

  /// Returns a copy of this object, with the given properties applied
  /// on top of it.
  SingleColumnLayoutStylesheet apply({
    double? standardContentWidth,
    EdgeInsetsGeometry? margin,
    DocumentBlockStyles? blockStyles,
  }) {
    return SingleColumnLayoutStylesheet(
      standardContentWidth: standardContentWidth ?? this.standardContentWidth,
      margin: margin ?? this.margin,
      blockStyles: blockStyles ?? this.blockStyles,
      inlineTextStyler: inlineTextStyler,
    );
  }

  SingleColumnLayoutStylesheet copyWith({
    EdgeInsetsGeometry? margin,
    double? standardContentWidth,
    DocumentBlockStyles? blockStyles,
    Map<Attribution, TextStyle?>? blockTextStyles,
    AttributionStyleAdjuster? inlineTextStyler,
  }) {
    return SingleColumnLayoutStylesheet(
      margin: margin ?? this.margin,
      standardContentWidth: standardContentWidth ?? this.standardContentWidth,
      blockStyles: blockStyles ?? this.blockStyles,
      inlineTextStyler: inlineTextStyler ?? this.inlineTextStyler,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnLayoutStylesheet &&
          runtimeType == other.runtimeType &&
          margin == other.margin &&
          standardContentWidth == other.standardContentWidth &&
          blockStyles == other.blockStyles &&
          inlineTextStyler == other.inlineTextStyler;

  @override
  int get hashCode =>
      margin.hashCode ^ standardContentWidth.hashCode ^ blockStyles.hashCode ^ inlineTextStyler.hashCode;
}

/// Adjusts the given [existingStyle] based on the given [attributions].
typedef AttributionStyleAdjuster = TextStyle Function(Set<Attribution> attributions, TextStyle existingStyle);

/// Styles for standard document block types, e.g., header1, header2, blockquote,
/// list item, image.
class DocumentBlockStyles {
  const DocumentBlockStyles({
    this.standardPadding = EdgeInsets.zero,
    required this.text,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.h5,
    required this.h6,
    required this.listItem,
    required this.blockquote,
    required this.image,
    required this.hr,
  });

  /// Padding applied to every content block.
  ///
  /// Each individual block type can contribute a padding adjustment, which
  /// is added on top of this value.
  final EdgeInsetsGeometry standardPadding;

  /// Styles for generic text blocks, e.g., paragraphs.
  final TextBlockStyle text;

  /// Styles applied to header1's.
  final TextBlockStyle h1;

  /// Styles applied to header2's.
  final TextBlockStyle h2;

  /// Styles applied to header3's.
  final TextBlockStyle h3;

  /// Styles applied to header4's.
  final TextBlockStyle h4;

  /// Styles applied to header5's.
  final TextBlockStyle h5;

  /// Styles applied to header6's.
  final TextBlockStyle h6;

  /// Styles applied to (ordered and unordered) list items.
  final TextBlockStyle listItem;

  /// Styles applied to blockquotes.
  final BlockquoteBlockStyle blockquote;

  /// Styles applied to images.
  final BlockStyle image;

  /// Styles applied to horizontal rules.
  final BlockStyle hr;

  /// Returns the [BlockStyle] for a text block of the given [blockType].
  ///
  /// Pass `null` for [blockType] if the text block is a paragraph.
  TextBlockStyle? textBlockStyleByAttribution(Attribution? blockType) {
    if (blockType == header1Attribution) {
      return h1;
    } else if (blockType == header2Attribution) {
      return h2;
    } else if (blockType == header3Attribution) {
      return h3;
    } else if (blockType == header4Attribution) {
      return h4;
    } else if (blockType == header5Attribution) {
      return h5;
    } else if (blockType == header6Attribution) {
      return h6;
    } else if (blockType == blockquoteAttribution) {
      return blockquote;
    } else {
      return text;
    }
  }

  DocumentBlockStyles copyWith({
    EdgeInsetsGeometry? standardPadding,
    TextBlockStyle? text,
    TextBlockStyle? h1,
    TextBlockStyle? h2,
    TextBlockStyle? h3,
    TextBlockStyle? h4,
    TextBlockStyle? h5,
    TextBlockStyle? h6,
    TextBlockStyle? listItem,
    BlockquoteBlockStyle? blockquote,
    BlockStyle? image,
    BlockStyle? hr,
  }) {
    return DocumentBlockStyles(
      standardPadding: standardPadding ?? this.standardPadding,
      text: text ?? this.text,
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      h3: h3 ?? this.h3,
      h4: h4 ?? this.h4,
      h5: h5 ?? this.h5,
      h6: h6 ?? this.h6,
      listItem: listItem ?? this.listItem,
      blockquote: blockquote ?? this.blockquote,
      image: image ?? this.image,
      hr: hr ?? this.hr,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentBlockStyles &&
          runtimeType == other.runtimeType &&
          standardPadding == other.standardPadding &&
          text == other.text &&
          h1 == other.h1 &&
          h2 == other.h2 &&
          h3 == other.h3 &&
          h4 == other.h4 &&
          h5 == other.h5 &&
          h6 == other.h6 &&
          listItem == other.listItem &&
          blockquote == other.blockquote &&
          image == other.image &&
          hr == other.hr;

  @override
  int get hashCode =>
      standardPadding.hashCode ^
      text.hashCode ^
      h1.hashCode ^
      h2.hashCode ^
      h3.hashCode ^
      h4.hashCode ^
      h5.hashCode ^
      h6.hashCode ^
      listItem.hashCode ^
      blockquote.hashCode ^
      image.hashCode ^
      hr.hashCode;
}

/// Visual styles that apply to any given block of content within a document layout.
class BlockStyle {
  const BlockStyle({
    this.paddingAdjustment,
    this.maxWidth,
  });

  /// Padding, which is applied on top of the standard block padding, to
  /// calculate the final padding for this block.
  final EdgeInsetsGeometry? paddingAdjustment;

  /// The max width of this block, or `null` for default sizing.
  final double? maxWidth;

  BlockStyle copyWith({
    EdgeInsetsGeometry? paddingAdjustment,
    double? maxWidth,
  }) {
    return BlockStyle(
      paddingAdjustment: paddingAdjustment ?? this.paddingAdjustment,
      maxWidth: maxWidth ?? this.maxWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockStyle &&
          runtimeType == other.runtimeType &&
          paddingAdjustment == other.paddingAdjustment &&
          maxWidth == other.maxWidth;

  @override
  int get hashCode => paddingAdjustment.hashCode ^ maxWidth.hashCode;
}

class TextBlockStyle extends BlockStyle {
  const TextBlockStyle({
    EdgeInsetsGeometry? paddingAdjustment,
    double? maxWidth,
    this.textStyle,
  }) : super(paddingAdjustment: paddingAdjustment, maxWidth: maxWidth);

  /// The base style for the text in this block.
  ///
  /// Additional styles may be applied to spans within the text block.
  final TextStyle? textStyle;

  @override
  TextBlockStyle copyWith({
    EdgeInsetsGeometry? paddingAdjustment,
    double? maxWidth,
    TextStyle? textStyle,
  }) {
    return TextBlockStyle(
      paddingAdjustment: paddingAdjustment ?? this.paddingAdjustment,
      maxWidth: maxWidth ?? this.maxWidth,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is TextBlockStyle && runtimeType == other.runtimeType && textStyle == other.textStyle;

  @override
  int get hashCode => super.hashCode ^ textStyle.hashCode;
}

class BlockquoteBlockStyle extends TextBlockStyle {
  const BlockquoteBlockStyle({
    EdgeInsetsGeometry? paddingAdjustment,
    double? maxWidth,
    TextStyle? textStyle,
    required this.backgroundColor,
    required this.borderRadius,
  }) : super(paddingAdjustment: paddingAdjustment, maxWidth: maxWidth, textStyle: textStyle);

  final Color backgroundColor;
  final BorderRadius borderRadius;

  @override
  BlockquoteBlockStyle copyWith({
    EdgeInsetsGeometry? paddingAdjustment,
    double? maxWidth,
    TextStyle? textStyle,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return BlockquoteBlockStyle(
      paddingAdjustment: paddingAdjustment ?? this.paddingAdjustment,
      maxWidth: maxWidth ?? this.maxWidth,
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is BlockquoteBlockStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode => super.hashCode ^ backgroundColor.hashCode ^ borderRadius.hashCode;
}

/// Styles applied to specific components within a [SingleColumnDocumentLayout].
///
/// Example: the width of an image that's set to full-bleed. The full-bleed
/// only applies to that one image, but a full-bleed might not make sense in
/// other document layouts. Therefore, rather than store that information within
/// the document, itself, that information is stored in this metadata.
///
/// These styles should be persisted with the document.
class SingleColumnCustomComponentStyles {
  const SingleColumnCustomComponentStyles({
    Map<String, double?> componentWidths = const {},
    Map<String, EdgeInsetsGeometry?> componentPaddings = const {},
  })  : _componentWidths = componentWidths,
        _componentPaddings = componentPaddings;

  final Map<String, double?> _componentWidths;

  /// Returns the desired width of the component tied to the given
  /// [nodeId], or `null` if there is no width preference.
  double? getWidth(String nodeId) {
    return _componentWidths[nodeId];
  }

  /// Returns all preferred component widths.
  Map<String, double?> get widths => _componentWidths;

  final Map<String, EdgeInsetsGeometry?> _componentPaddings;

  /// Returns the desired padding for the component tied to the given
  /// [nodeId], or `null` if no such preference exists.
  EdgeInsetsGeometry? getPadding(String nodeId) {
    return _componentPaddings[nodeId];
  }

  /// Returns all preferred component paddings.
  Map<String, EdgeInsetsGeometry?> get paddings => _componentPaddings;

  /// Returns a copy of this object with the given properties applied
  /// on top.
  ///
  /// For collections, the given collections are added to copies of the
  /// existing collections in this object.
  SingleColumnCustomComponentStyles apply({
    Map<String, double?> componentWidths = const {},
    Map<String, EdgeInsetsGeometry?> componentPaddings = const {},
  }) {
    return SingleColumnCustomComponentStyles(
      componentWidths: Map<String, double?>.from(_componentWidths)..addAll(componentWidths),
      componentPaddings: Map<String, EdgeInsetsGeometry?>.from(_componentPaddings)..addAll(componentPaddings),
    );
  }

  SingleColumnCustomComponentStyles copyWith({
    Map<String, double?>? componentWidths,
    Map<String, EdgeInsetsGeometry?>? componentPaddings,
  }) {
    return SingleColumnCustomComponentStyles(
      componentWidths: componentWidths ?? _componentWidths,
      componentPaddings: componentPaddings ?? _componentPaddings,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnCustomComponentStyles &&
          runtimeType == other.runtimeType &&
          _componentWidths == other._componentWidths &&
          _componentPaddings == other._componentPaddings;

  @override
  int get hashCode => _componentWidths.hashCode ^ _componentPaddings.hashCode;
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
