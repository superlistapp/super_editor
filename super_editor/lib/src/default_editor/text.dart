// ignore_for_file: avoid_renaming_method_parameters

import 'dart:collection';
import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/composable_text.dart';
import 'package:super_editor/src/infrastructure/flutter/geometry.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/key_event_extensions.dart';
import 'package:super_editor/src/infrastructure/strings.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'layout_single_column/layout_single_column.dart';
import 'list_items.dart';
import 'multi_node_editing.dart';
import 'paragraph.dart';
import 'selection_upstream_downstream.dart';
import 'text_tools.dart';

class TextNode extends DocumentNode with ChangeNotifier {
  TextNode({
    required this.id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
  }) : _text = text {
    this.metadata = metadata;
    _text.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _text.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  final String id;

  AttributedText _text;

  /// The content text within this [TextNode].
  AttributedText get text => _text;
  set text(AttributedText newText) {
    if (newText != _text) {
      _text.removeListener(notifyListeners);
      _text = newText;
      _text.addListener(notifyListeners);

      notifyListeners();
    }
  }

  @override
  TextNodePosition get beginningPosition => const TextNodePosition(offset: 0);

  @override
  TextNodePosition get endPosition => TextNodePosition(offset: text.length);

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position2 but received a ${position2.runtimeType}');
    }

    return position1.offset < position2.offset ? position1 : position2;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position2 but received a ${position2.runtimeType}');
    }

    return position1.offset > position2.offset ? position1 : position2;
  }

  /// Returns a [DocumentSelection] within this [TextNode] from [startIndex] to [endIndex].
  DocumentSelection selectionBetween(int startIndex, int endIndex) {
    return DocumentSelection(
      base: DocumentPosition(
        nodeId: id,
        nodePosition: TextNodePosition(offset: startIndex),
      ),
      extent: DocumentPosition(
        nodeId: id,
        nodePosition: TextNodePosition(offset: endIndex),
      ),
    );
  }

  /// Returns a collapsed [DocumentSelection], positioned within this [TextNode] at the
  /// given [collapsedIndex].
  DocumentSelection selectionAt(int collapsedIndex) {
    return DocumentSelection.collapsed(
      position: positionAt(collapsedIndex),
    );
  }

  /// Returns a [DocumentPosition] within this [TextNode] at the given text [index].
  DocumentPosition positionAt(int index) {
    return DocumentPosition(
      nodeId: id,
      nodePosition: TextNodePosition(offset: index),
    );
  }

  /// Returns a [DocumentRange] within this [TextNode] between [startIndex] and [endIndex].
  DocumentRange rangeBetween(int startIndex, int endIndex) {
    return DocumentRange(
      start: DocumentPosition(
        nodeId: id,
        nodePosition: TextNodePosition(offset: startIndex),
      ),
      end: DocumentPosition(
        nodeId: id,
        nodePosition: TextNodePosition(offset: endIndex),
      ),
    );
  }

  @override
  TextNodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  }) {
    assert(base is TextNodePosition);
    assert(extent is TextNodePosition);

    return TextNodeSelection(
      baseOffset: (base as TextNodePosition).offset,
      extentOffset: (extent as TextNodePosition).offset,
      affinity: extent.affinity,
    );
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is TextSelection);

    return (selection as TextSelection).textInside(text.text);
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is TextNode && text == other.text && super.hasEquivalentContent(other);
  }

  @override
  String toString() => '[TextNode] - text: $text, metadata: ${copyMetadata()}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is TextNode && runtimeType == other.runtimeType && id == other.id && _text == other._text;

  @override
  int get hashCode => super.hashCode ^ id.hashCode ^ _text.hashCode;
}

extension DocumentSelectionWithText on Document {
  /// Returns `true` if all the text within the given [selection] contains at least
  /// some characters with each of the given [attributions].
  ///
  /// All non-text content is ignored.
  bool doesSelectedTextContainAttributions(DocumentSelection selection, Set<Attribution> attributions) {
    final nodes = getNodesInside(selection.base, selection.extent);
    if (nodes.isEmpty) {
      return false;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = getRangeBetween(selection.base, selection.extent);

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        final baseOffset = (selection.base.nodePosition as TextPosition).offset;
        final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        startOffset = 0;
        endOffset = max(textNode.text.length - 1, 0);
      }

      final selectionRange = SpanRange(startOffset, endOffset);

      if (textNode.text.hasAttributionsWithin(
        attributions: attributions,
        range: selectionRange,
      )) {
        return true;
      }
    }

    return false;
  }

  /// Returns all attributions that appear throughout the entirety of the selected range.
  Set<Attribution> getAllAttributions(DocumentSelection selection) {
    final attributions = <Attribution>{};

    final nodes = getNodesInside(selection.base, selection.extent);
    if (nodes.isEmpty) {
      return attributions;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = getRangeBetween(selection.base, selection.extent);

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        final baseOffset = (selection.base.nodePosition as TextPosition).offset;
        final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = SpanRange(startOffset, endOffset);

      final attributionsInRange = textNode //
          .text
          .getAllAttributionsThroughout(selectionRange);

      attributions.addAll(attributionsInRange);
    }
    return attributions;
  }

  /// Returns all attributions of type [T] that appear throughout the entirety of the selected range.
  Set<T> getAttributionsByType<T>(DocumentSelection selection) {
    final attributions = <T>{};

    final nodes = getNodesInside(selection.base, selection.extent);
    if (nodes.isEmpty) {
      return attributions;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = getRangeBetween(selection.base, selection.extent);

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        final baseOffset = (selection.base.nodePosition as TextPosition).offset;
        final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = SpanRange(startOffset, endOffset);

      final attributionsInRange = textNode //
          .text
          .getAllAttributionsThroughout(selectionRange)
          .whereType<T>();

      attributions.addAll(attributionsInRange);
    }
    return attributions;
  }
}

extension Words on String {
  /// Returns a list of [TextRange]s, one that spans every word in the [String]
  /// ordered from upstream to downstream.
  List<TextRange> calculateAllWordBoundaries() {
    final List<TextRange> textSelections = [];
    var offset = 0;

    while (offset < length) {
      if (this[offset] == ' ') {
        offset++;
        continue;
      }

      final currentPosition = TextPosition(offset: offset);
      final textSelection = expandPositionToWord(text: this, textPosition: currentPosition);
      textSelections.add(textSelection);

      offset += textSelection.end - textSelection.start + 1;
    }
    return textSelections;
  }
}

/// A logical selection within a [TextNode].
///
/// The selection begins at [baseOffset] and ends at [extentOffset].
class TextNodeSelection extends TextSelection implements NodeSelection {
  TextNodeSelection.fromTextSelection(TextSelection textSelection)
      : super(
          baseOffset: textSelection.baseOffset,
          extentOffset: textSelection.extentOffset,
          affinity: textSelection.affinity,
          isDirectional: textSelection.isDirectional,
        );

  const TextNodeSelection.collapsed({
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) : super(
          baseOffset: offset,
          extentOffset: offset,
          affinity: affinity,
        );

  const TextNodeSelection({
    required int baseOffset,
    required int extentOffset,
    TextAffinity affinity = TextAffinity.downstream,
    bool isDirectional = false,
  }) : super(
          baseOffset: baseOffset,
          extentOffset: extentOffset,
          affinity: affinity,
          isDirectional: isDirectional,
        );

  @override
  TextNodePosition get base => TextNodePosition(offset: baseOffset, affinity: affinity);

  @override
  TextNodePosition get extent => TextNodePosition(offset: extentOffset, affinity: affinity);
}

/// A logical position within a [TextNode].
class TextNodePosition extends TextPosition implements NodePosition {
  TextNodePosition.fromTextPosition(TextPosition position)
      : super(offset: position.offset, affinity: position.affinity);

  const TextNodePosition({
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) : super(offset: offset, affinity: affinity);

  @override
  bool isEquivalentTo(NodePosition other) {
    if (other is! TextNodePosition) {
      return false;
    }

    // Equivalency is determined by text offset. Affinity is ignored, because
    // affinity doesn't alter the actual location in the text that a
    // TextNodePosition refers to.
    return offset == other.offset;
  }

  TextNodePosition copyWith({
    int? offset,
    TextAffinity? affinity,
  }) {
    return TextNodePosition(
      offset: offset ?? this.offset,
      affinity: affinity ?? this.affinity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is TextNodePosition && runtimeType == other.runtimeType && offset == other.offset;

  @override
  int get hashCode => super.hashCode ^ super.offset.hashCode;
}

/// Mixin for all [SingleColumnLayoutComponentViewModel]s that represent
/// a text-based block, e.g., paragraph, blockquote, list item.
///
/// This mixin enforces a consistent contract for all such view models.
/// Each view model can add more properties, but they must at least
/// support the properties in this mixin. Additionally, [applyStyles]
/// provides consistent application of text-based styling for all
/// view models that add this mixin.
mixin TextComponentViewModel on SingleColumnLayoutComponentViewModel {
  AttributedText get text;
  set text(AttributedText text);

  AttributionStyleBuilder get textStyleBuilder;
  set textStyleBuilder(AttributionStyleBuilder styleBuilder);

  TextDirection get textDirection;
  set textDirection(TextDirection direction);

  TextAlign get textAlignment;
  set textAlignment(TextAlign alignment);

  TextSelection? get selection;
  set selection(TextSelection? selection);

  Color get selectionColor;
  set selectionColor(Color color);

  bool get highlightWhenEmpty;
  set highlightWhenEmpty(bool highlight);

  TextRange? get composingRegion;
  set composingRegion(TextRange? composingRegion);

  bool get showComposingUnderline;
  set showComposingUnderline(bool showComposingUnderline);

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);

    textAlignment = styles[Styles.textAlign] ?? textAlignment;

    textStyleBuilder = (attributions) {
      final baseStyle = styles[Styles.textStyle] ?? noStyleBuilder({});
      final inlineTextStyler = styles[Styles.inlineTextStyler] as AttributionStyleAdjuster;

      return inlineTextStyler(attributions, baseStyle);
    };
  }
}

/// Document component that displays hint text when its content text
/// is empty.
///
/// Internally uses a [TextComponent] to display the content text.
class TextWithHintComponent extends StatefulWidget {
  const TextWithHintComponent({
    Key? key,
    required this.text,
    this.hintText,
    this.hintStyleBuilder,
    this.textAlign,
    this.textDirection,
    required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AttributedText text;
  final AttributedText? hintText;
  final AttributionStyleBuilder? hintStyleBuilder;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final AttributionStyleBuilder textStyleBuilder;
  final Map<String, dynamic> metadata;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool highlightWhenEmpty;
  final TextRange? composingRegion;
  final bool showComposingUnderline;
  final bool showDebugPaint;

  @override
  State createState() => _TextWithHintComponentState();
}

class _TextWithHintComponentState extends State<TextWithHintComponent>
    with ProxyDocumentComponent<TextWithHintComponent>, ProxyTextComposable {
  final _childTextComponentKey = GlobalKey<TextComponentState>();

  @override
  GlobalKey get childDocumentComponentKey => _childTextComponentKey;

  @override
  TextComposable get childTextComposable => _childTextComponentKey.currentState!;

  TextStyle _styleBuilder(Set<Attribution> attributions) {
    final attributionsWithBlock = Set.of(attributions);
    final blockType = widget.metadata['blockType'];
    if (blockType != null && blockType is Attribution) {
      attributionsWithBlock.add(blockType);
    }

    final contentStyle = widget.textStyleBuilder(attributionsWithBlock);
    final hintStyle = contentStyle.merge(widget.hintStyleBuilder?.call(attributionsWithBlock) ?? const TextStyle());
    return hintStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.text.text.isEmpty)
          IgnorePointer(
            child: Text.rich(
              widget.hintText?.computeTextSpan(_styleBuilder) ?? const TextSpan(text: ''),
            ),
          ),
        TextComponent(
          key: _childTextComponentKey,
          text: widget.text,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          textStyleBuilder: widget.textStyleBuilder,
          metadata: widget.metadata,
          textSelection: widget.textSelection,
          selectionColor: widget.selectionColor,
          highlightWhenEmpty: widget.highlightWhenEmpty,
          composingRegion: widget.composingRegion,
          showComposingUnderline: widget.showComposingUnderline,
          showDebugPaint: widget.showDebugPaint,
        ),
      ],
    );
  }
}

/// Displays text in a document.
///
/// This is the standard component for text display.
class TextComponent extends StatefulWidget {
  const TextComponent({
    Key? key,
    required this.text,
    this.textAlign,
    this.textDirection,
    this.textScaler,
    required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AttributedText text;

  final TextAlign? textAlign;

  final TextDirection? textDirection;

  /// The text scaling policy.
  ///
  /// Defaults to `MediaQuery.textScalerOf()`.
  final TextScaler? textScaler;

  final AttributionStyleBuilder textStyleBuilder;

  final Map<String, dynamic> metadata;

  final TextSelection? textSelection;

  final Color selectionColor;

  final bool highlightWhenEmpty;

  /// The span of text that's currently sitting in the IME's composing region,
  /// which is underlined by this component.
  final TextRange? composingRegion;

  /// Whether to underline the [composingRegion].
  ///
  /// Showing the underline is optional because the behavior differs between
  /// platforms, e.g., Mac shows an underline but Windows and Linux don't.
  final bool showComposingUnderline;

  final bool showDebugPaint;

  @override
  TextComponentState createState() => TextComponentState();
}

class TextComponentState extends State<TextComponent> with DocumentComponent implements TextComposable {
  final _textKey = GlobalKey<ProseTextState>();

  @visibleForTesting
  ProseTextLayout get textLayout => _textKey.currentState!.textLayout;

  @override
  TextNodePosition? getPositionAtOffset(Offset localOffset) {
    // TODO: Change this implementation to use exact position instead of nearest position
    //       After extracting super_text, looking up the exact offset broke the
    //       ability to tap into empty TextWithHintComponents. To fix this, we
    //       switched to the nearest position. Add a different version of this
    //       API for nearest position and then let clients pick the one that's
    //       right for them.
    final textPosition = textLayout.getPositionNearestToOffset(localOffset);

    return TextNodePosition.fromTextPosition(textPosition);
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $nodePosition');
    }
    return textLayout.getOffsetAtPosition(nodePosition);
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    if (nodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $nodePosition');
    }

    final textNodePosition = nodePosition as TextPosition;
    final characterBox = getRectForPosition(textNodePosition);

    return textNodePosition.affinity == TextAffinity.upstream ? characterBox.leftEdge : characterBox.rightEdge;
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $nodePosition');
    }

    final offset = getOffsetForPosition(nodePosition);
    final lineHeight = textLayout.getHeightForCaret(nodePosition) ?? textLayout.getLineHeightAtPosition(nodePosition);
    return Rect.fromLTWH(offset.dx, offset.dy, 0, lineHeight);
  }

  @override
  Rect getRectForSelection(dynamic baseNodePosition, dynamic extentNodePosition) {
    if (baseNodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $baseNodePosition');
    }
    if (extentNodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $extentNodePosition');
    }

    final selection = TextSelection(
      baseOffset: baseNodePosition.offset,
      extentOffset: extentNodePosition.offset,
    );

    if (selection.isCollapsed) {
      // A collapsed selection reports no boxes, but we want to return a rect at the
      // selection's x-offset with a height that matches the text. Try to calculate
      // a selection rectangle based on the character that's either after, or before, the
      // collapsed selection position.
      final rectForPosition = getRectForPosition(extentNodePosition);
      if (rectForPosition.height > 0) {
        return rectForPosition;
      }

      TextBox? characterBox = textLayout.getCharacterBox(extentNodePosition);
      if (characterBox != null) {
        final rect = characterBox.toRect();
        return Rect.fromLTWH(rect.left, rect.top, 0, rect.height);
      }

      // We didn't find a character at the given offset. That offset might be at the end
      // of the text. Try looking one character upstream.
      characterBox = extentNodePosition.offset > 0
          ? textLayout.getCharacterBox(TextPosition(offset: extentNodePosition.offset - 1))
          : null;
      if (characterBox != null) {
        final rect = characterBox.toRect();
        // Use the right side of the character because this is the character that appears
        // BEFORE the position we want, which means the position we want is just after
        // this character box.
        return Rect.fromLTWH(rect.right, rect.top, 0, rect.height);
      }

      // We couldn't find a character box, which means the text is empty. Return
      // the caret height, or the estimated line height.
      final caretHeight = textLayout.getHeightForCaret(selection.extent);
      return caretHeight != null
          ? Rect.fromLTWH(0, 0, 0, caretHeight)
          : Rect.fromLTWH(0, 0, 0, textLayout.estimatedLineHeight);
    }

    final boxes = textLayout.getBoxesForSelection(selection);
    Rect boundingBox = boxes.isNotEmpty ? boxes.first.toRect() : Rect.zero;
    for (int i = 1; i < boxes.length; ++i) {
      boundingBox = boundingBox.expandToInclude(boxes[i].toRect());
    }

    return boundingBox;
  }

  @override
  TextNodePosition getBeginningPosition() {
    return const TextNodePosition(offset: 0);
  }

  @override
  TextNodePosition getBeginningPositionNearX(double x) {
    return TextNodePosition.fromTextPosition(
      textLayout.getPositionInFirstLineAtX(x),
    );
  }

  @override
  TextNodePosition? movePositionLeft(NodePosition textPosition, [MovementModifier? movementModifier]) {
    if (textPosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textPosition.offset > widget.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    if (textPosition.offset == 0) {
      // Can't move any further left.
      return null;
    }

    if (movementModifier == MovementModifier.line) {
      return getPositionAtStartOfLine(
        TextNodePosition(offset: textPosition.offset),
      );
    } else if (movementModifier == MovementModifier.word) {
      final newOffset = getAllText().moveOffsetUpstreamByWord(textPosition.offset);
      if (newOffset == null) {
        return textPosition;
      }

      return TextNodePosition(offset: newOffset);
    } else if (movementModifier == MovementModifier.paragraph) {
      return const TextNodePosition(offset: 0);
    }

    final newOffset = getAllText().moveOffsetUpstreamByCharacter(textPosition.offset);
    return newOffset != null ? TextNodePosition(offset: newOffset) : textPosition;
  }

  @override
  TextNodePosition? movePositionRight(NodePosition textPosition, [MovementModifier? movementModifier]) {
    if (textPosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textPosition.offset >= widget.text.length) {
      // Can't move further right.
      return null;
    }

    if (movementModifier == MovementModifier.line) {
      final endOfLine = getPositionAtEndOfLine(
        TextNodePosition(offset: textPosition.offset),
      );

      final TextPosition endPosition = getEndPosition();

      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (widget.text.text[endOfLine.offset] != '\n');

      // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
      //       cursor to jump to the next line because the cursor is placed after
      //       the final selected character. We don't want this, so in this case
      //       we `-1`.
      //
      //       However, if the line that is selected ends with an explicit `\n`,
      //       or if the line is the terminal line for the paragraph then we don't
      //       want to `-1` because that would leave a dangling character after the
      //       selection.
      // TODO: this is the concept of text affinity. Implement support for affinity.
      // TODO: with affinity, ensure it works as expected for right-aligned text
      // TODO: this logic fails for justified text - find a solution for that (#55)
      return isAutoWrapLine
          ? TextNodePosition(offset: endOfLine.offset - 1)
          : TextNodePosition.fromTextPosition(endOfLine);
    }
    if (movementModifier == MovementModifier.word) {
      final newOffset = getAllText().moveOffsetDownstreamByWord(textPosition.offset);
      if (newOffset == null) {
        return textPosition;
      }

      return TextNodePosition(offset: newOffset);
    } else if (movementModifier == MovementModifier.paragraph) {
      return TextNodePosition(offset: getAllText().length);
    }

    final newOffset = getAllText().moveOffsetDownstreamByCharacter(textPosition.offset);
    return newOffset != null ? TextNodePosition(offset: newOffset) : textPosition;
  }

  @override
  TextNodePosition? movePositionUp(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > widget.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineUp = getPositionOneLineUp(textNodePosition);
    if (positionOneLineUp == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineUp);
  }

  @override
  TextNodePosition? movePositionDown(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > widget.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineDown = getPositionOneLineDown(textNodePosition);
    if (positionOneLineDown == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineDown);
  }

  @override
  TextNodePosition getEndPosition() {
    return TextNodePosition(offset: widget.text.length);
  }

  @override
  TextNodePosition getEndPositionNearX(double x) {
    return TextNodePosition.fromTextPosition(textLayout.getPositionInLastLineAtX(x));
  }

  @override
  TextNodeSelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return TextNodeSelection.fromTextSelection(textLayout.getSelectionInRect(localBaseOffset, localExtentOffset));
  }

  @override
  TextNodeSelection getCollapsedSelectionAt(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      throw Exception('The given node position ($textNodePosition) is not compatible with TextComponent');
    }

    return TextNodeSelection.collapsed(offset: textNodePosition.offset);
  }

  @override
  TextNodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    if (basePosition is! TextNodePosition) {
      throw Exception('Expected a basePosition of type TextNodePosition but received: $basePosition');
    }
    if (extentPosition is! TextNodePosition) {
      throw Exception('Expected an extentPosition of type TextNodePosition but received: $extentPosition');
    }

    return TextNodeSelection(
      baseOffset: basePosition.offset,
      extentOffset: extentPosition.offset,
    );
  }

  @override
  TextNodeSelection getSelectionOfEverything() {
    return TextNodeSelection(
      baseOffset: 0,
      extentOffset: widget.text.length,
    );
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return textLayout.isTextAtOffset(localOffset) ? SystemMouseCursors.text : null;
  }

  @override
  String getAllText() {
    return widget.text.text;
  }

  @override
  String getContiguousTextAt(TextNodePosition textPosition) {
    return getContiguousTextSelectionAt(textPosition).textInside(widget.text.text);
  }

  @override
  TextNodeSelection getWordSelectionAt(TextNodePosition textPosition) {
    return TextNodeSelection.fromTextSelection(
      textLayout.getWordSelectionAt(textPosition),
    );
  }

  @override
  TextNodeSelection getContiguousTextSelectionAt(TextNodePosition textPosition) {
    final text = widget.text.text;
    if (text.isEmpty) {
      return const TextNodeSelection.collapsed(offset: -1);
    }

    int start = min(textPosition.offset, text.length - 1);
    int end = min(textPosition.offset, text.length - 1);
    while (start > 0 && text[start - 1] != '\n') {
      start -= 1;
    }
    while (end < text.length && text[end] != '\n') {
      end += 1;
    }
    return TextNodeSelection(
      baseOffset: start,
      extentOffset: end,
    );
  }

  @override
  TextNodePosition? getPositionOneLineUp(NodePosition textPosition) {
    if (textPosition is! TextNodePosition) {
      throw Exception('Expected position of type NodePosition but received ${textPosition.runtimeType}');
    }

    final positionOneLineUp = textLayout.getPositionOneLineUp(textPosition);
    if (positionOneLineUp == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineUp);
  }

  @override
  TextNodePosition? getPositionOneLineDown(NodePosition textPosition) {
    if (textPosition is! TextNodePosition) {
      throw Exception('Expected position of type NodePosition but received ${textPosition.runtimeType}');
    }

    final positionOneLineDown = textLayout.getPositionOneLineDown(textPosition);
    if (positionOneLineDown == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineDown);
  }

  @override
  TextNodePosition getPositionAtEndOfLine(TextNodePosition textPosition) {
    return TextNodePosition.fromTextPosition(
      textLayout.getPositionAtEndOfLine(textPosition),
    );
  }

  @override
  TextNodePosition getPositionAtStartOfLine(TextNodePosition textNodePosition) {
    return TextNodePosition.fromTextPosition(
      textLayout.getPositionAtStartOfLine(textNodePosition),
    );
  }

  /// Return the [TextStyle] for the character at [offset].
  ///
  /// If the caret sits at the beginning of the text, the style
  /// of the first character is returned.
  ///
  /// If the caret sits at the end of the text, the style
  /// of the last character is returned.
  ///
  /// If the text is empty, the style computed by the widget's `textStyleBuilder`
  /// without any attributions is returned.
  TextStyle getTextStyleAt(int offset) {
    final attributions = widget.text.getAllAttributionsAt(offset < widget.text.length //
        ? offset
        : widget.text.length - 1);

    return _textStyleWithBlockType(attributions);
  }

  TextAlign? get textAlign => widget.textAlign;

  TextDirection? get textDirection => widget.textDirection;

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.finer('Building a TextComponent with key: ${widget.key}');

    return IgnorePointer(
      child: SuperText(
        key: _textKey,
        richText: widget.text.computeTextSpan(_textStyleWithBlockType),
        textAlign: widget.textAlign ?? TextAlign.left,
        textDirection: widget.textDirection ?? TextDirection.ltr,
        textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
        layerBeneathBuilder: (context, textLayout) {
          return Stack(
            children: [
              // Selection highlight beneath the text.
              if (widget.text.length > 0)
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: SelectionHighlightStyle(
                    color: widget.selectionColor,
                  ),
                  selection: widget.textSelection ?? const TextSelection.collapsed(offset: -1),
                )
              else if (widget.highlightWhenEmpty)
                TextLayoutEmptyHighlight(
                  textLayout: textLayout,
                  style: SelectionHighlightStyle(
                    color: widget.selectionColor,
                  ),
                ),
              // Underline beneath the composing region.
              if (widget.composingRegion != null)
                TextUnderlineLayer(
                  textLayout: textLayout,
                  underlines: [
                    TextLayoutUnderline(
                      style: UnderlineStyle(
                        color: widget.textStyleBuilder({}).color ?? //
                            (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                      ),
                      range: widget.composingRegion!,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  /// Creates a `TextStyle` based on the given [attributions], plus any
  /// "block type" that's specified in [widget.metadata].
  TextStyle _textStyleWithBlockType(Set<Attribution> attributions) {
    final attributionsWithBlockType = Set<Attribution>.from(attributions);
    Attribution? blockType = widget.metadata['blockType'];
    if (blockType != null) {
      attributionsWithBlockType.add(blockType);
    }

    return widget.textStyleBuilder(attributionsWithBlockType);
  }
}

/// A [ProxyDocumentComponent] that adds [TextComposable] capabilities so
/// that simple text-based proxy components can meet their expected contract
/// without going through the work of defining a stateful widget that mixes in
/// the [ProxyDocumentComponent] methods.
///
/// Using a [ProxyTextDocumentComponent] is never technically necessary.
/// Custom [DocumentComponent]s can achieve a similar result by mixing in
/// [ProxyDocumentComponent] within a `State` object. This widget is provided
/// as a convenience so that some components can be defined as stateless
/// widgets while still providing access to component behaviors and text layout queries.
class ProxyTextDocumentComponent extends StatefulWidget {
  const ProxyTextDocumentComponent({
    super.key,
    required this.textComponentKey,
    required this.child,
  });

  final GlobalKey textComponentKey;

  /// The widget subtree, which must include a widget that implements `TextComposable`,
  /// and that `TextComposable` must be bound to the given [textComponentKey].
  final Widget child;

  @override
  State<ProxyTextDocumentComponent> createState() => _ProxyTextDocumentComponentState();
}

class _ProxyTextDocumentComponentState extends State<ProxyTextDocumentComponent>
    with ProxyDocumentComponent<ProxyTextDocumentComponent>, ProxyTextComposable {
  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => widget.textComponentKey;

  @override
  TextComposable get childTextComposable => childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AddTextAttributionsRequest implements EditRequest {
  AddTextAttributionsRequest({
    required this.documentRange,
    required this.attributions,
    this.autoMerge = true,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;
  final bool autoMerge;
}

// TODO: the add/remove/toggle commands are almost identical except for what they
//       do to ranges of text. Pull out the common range calculation behavior.
/// Applies the given `attributions` to the given `documentSelection`.
class AddTextAttributionsCommand implements EditCommand {
  AddTextAttributionsCommand({
    required this.documentRange,
    required this.attributions,
    this.autoMerge = true,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;
  final bool autoMerge;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing AddTextAttributionsCommand');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final nodes = document.getNodesInside(documentRange.start, documentRange.end);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentRange');
      return;
    }

    // Calculate a normalized DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final normalRange = documentRange.normalize(document);
    editorDocLog.info(' - node range: $normalRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');

        startOffset = (normalRange.start.nodePosition as TextPosition).offset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalRange.end.nodePosition as TextPosition).offset - 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (normalRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - adding part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - adding full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    // Add attributions.
    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value.toSpanRange();
        editorDocLog.info(' - adding attribution: $attribution. Range: $range');

        // Create a new AttributedText with updated attribution spans, so that the presentation system can
        // see that we made a change, and re-renders the text in the document.
        node.text = AttributedText(
          node.text.text,
          node.text.spans.copy()
            ..addAttribution(
              newAttribution: attribution,
              start: range.start,
              end: range.end,
              autoMerge: autoMerge,
            ),
        );

        executor.logChanges([
          DocumentEdit(
            AttributionChangeEvent(
              nodeId: node.id,
              change: AttributionChange.added,
              range: range,
              attributions: attributions,
            ),
          ),
        ]);
      }
    }

    editorDocLog.info(' - done adding attributions');
  }
}

class RemoveTextAttributionsRequest implements EditRequest {
  RemoveTextAttributionsRequest({
    required this.documentRange,
    required this.attributions,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;
}

/// Removes the given `attributions` from the given `documentSelection`.
class RemoveTextAttributionsCommand implements EditCommand {
  RemoveTextAttributionsCommand({
    required this.documentRange,
    required this.attributions,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing RemoveTextAttributionsCommand');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final nodes = document.getNodesInside(documentRange.start, documentRange.end);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentRange');
      return;
    }

    // Normalize the DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final normalizedRange = documentRange.normalize(document);
    editorDocLog.info(' - node range: $normalizedRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');

        startOffset = (normalizedRange.start.nodePosition as TextPosition).offset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalizedRange.end.nodePosition as TextPosition).offset - 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (normalizedRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - adding part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalizedRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - adding full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    // Add attributions.
    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value.toSpanRange();
        editorDocLog.info(' - removing attribution: $attribution. Range: $range');

        // Create a new AttributedText with updated attribution spans, so that the presentation system can
        // see that we made a change, and re-renders the text in the document.
        node.text = AttributedText(
          node.text.text,
          node.text.spans.copy()
            ..removeAttribution(
              attributionToRemove: attribution,
              start: range.start,
              end: range.end,
            ),
        );

        executor.logChanges([
          DocumentEdit(
            AttributionChangeEvent(
              nodeId: node.id,
              change: AttributionChange.removed,
              range: range,
              attributions: attributions,
            ),
          ),
        ]);
      }
    }

    editorDocLog.info(' - done adding attributions');
  }
}

class ToggleTextAttributionsRequest implements EditRequest {
  ToggleTextAttributionsRequest({
    required this.documentRange,
    required this.attributions,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;
}

/// Applies the given `attributions` to the given `documentSelection`,
/// if none of the content in the selection contains any of the
/// given `attributions`. Otherwise, all the given `attributions`
/// are removed from the content within the `documentSelection`.
class ToggleTextAttributionsCommand implements EditCommand {
  ToggleTextAttributionsCommand({
    required this.documentRange,
    required this.attributions,
  });

  final DocumentRange documentRange;
  final Set<Attribution> attributions;

  // TODO: The structure of this command looks nearly identical to the two other attribution
  // commands above. We collect nodes and then we loop through them to apply an operation.
  // Try to de-dup this code. Maybe use a private base class called ChangeTextAttributionsCommand
  // and provide a hook for the specific operation: add, remove, toggle.
  @override
  void execute(EditContext context, CommandExecutor executor) {
    editorDocLog.info('Executing ToggleTextAttributionsCommand');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final nodes = document.getNodesInside(documentRange.start, documentRange.end);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentRange');
      return;
    }

    // Normalize DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final normalizedRange = documentRange.normalize(document);
    editorDocLog.info(' - node range: $normalizedRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, SpanRange>();

    bool alreadyHasAttributions = true;

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');

        startOffset = (normalizedRange.start.nodePosition as TextPosition).offset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalizedRange.end.nodePosition as TextPosition).offset - 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (normalizedRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - toggling part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (normalizedRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - toggling full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.length - 1, 0);
      }

      final selectionRange = SpanRange(startOffset, endOffset);

      alreadyHasAttributions = alreadyHasAttributions &&
          textNode.text.hasAttributionsThroughout(
            attributions: attributions,
            range: selectionRange,
          );

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value;

        editorDocLog.info(' - toggling attribution: $attribution. Range: $range');

        if (alreadyHasAttributions) {
          // Attribution is present throughout the user selection. Remove attribution.

          editorDocLog.info(' - Removing attribution: $attribution. Range: $range');

          // Create a new AttributedText with updated attribution spans, so that the presentation system can
          // see that we made a change, and re-renders the text in the document.
          node.text = AttributedText(
            node.text.text,
            node.text.spans.copy(),
          )..removeAttribution(
              attribution,
              range,
            );
        } else {
          // Attribution isn't present throughout the user selection. Apply attribution.

          editorDocLog.info(' - Adding attribution: $attribution. Range: $range');

          // Create a new AttributedText with updated attribution spans, so that the presentation system can
          // see that we made a change, and re-renders the text in the document.
          node.text = AttributedText(
            node.text.text,
            node.text.spans.copy(),
          )..addAttribution(
              attribution,
              range,
            );
        }

        final wasAttributionAdded = node.text.hasAttributionAt(range.start, attribution: attribution);
        executor.logChanges([
          DocumentEdit(
            AttributionChangeEvent(
              nodeId: node.id,
              change: wasAttributionAdded ? AttributionChange.added : AttributionChange.removed,
              range: range,
              attributions: attributions,
            ),
          ),
        ]);
      }
    }

    editorDocLog.info(' - done toggling attributions');
  }
}

/// A [NodeChangeEvent] for the addition or removal of a set of attributions.
class AttributionChangeEvent extends NodeChangeEvent {
  AttributionChangeEvent({
    required String nodeId,
    required this.change,
    required this.range,
    required this.attributions,
  }) : super(nodeId);

  final AttributionChange change;
  final SpanRange range;
  final Set<Attribution> attributions;

  @override
  String toString() => "AttributionChangeEvent ('$nodeId' - ${range.start} -> ${range.end} ($change): '$attributions')";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is AttributionChangeEvent &&
          runtimeType == other.runtimeType &&
          change == other.change &&
          range == other.range &&
          const DeepCollectionEquality().equals(attributions, other.attributions);

  @override
  int get hashCode => super.hashCode ^ change.hashCode ^ range.hashCode ^ attributions.hashCode;
}

enum AttributionChange {
  added,
  removed;
}

/// Changes layout styles, like padding and width, of a component within a [SingleColumnDocumentLayout].
class ChangeSingleColumnLayoutComponentStylesRequest implements EditRequest {
  const ChangeSingleColumnLayoutComponentStylesRequest({
    required this.nodeId,
    required this.styles,
  });

  final String nodeId;
  final SingleColumnLayoutComponentStyles styles;
}

class ChangeSingleColumnLayoutComponentStylesCommand implements EditCommand {
  ChangeSingleColumnLayoutComponentStylesCommand({
    required this.nodeId,
    required this.styles,
  });

  final String nodeId;
  final SingleColumnLayoutComponentStyles styles;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId)!;

    styles.applyTo(node);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(node.id),
      ),
    ]);
  }
}

class InsertTextRequest implements EditRequest {
  InsertTextRequest({
    required this.documentPosition,
    required this.textToInsert,
    required this.attributions,
  }) : assert(documentPosition.nodePosition is TextPosition);

  final DocumentPosition documentPosition;
  final String textToInsert;
  final Set<Attribution> attributions;
}

class InsertTextCommand implements EditCommand {
  InsertTextCommand({
    required this.documentPosition,
    required this.textToInsert,
    required this.attributions,
  }) : assert(documentPosition.nodePosition is TextPosition);

  final DocumentPosition documentPosition;
  final String textToInsert;
  final Set<Attribution> attributions;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);

    final textNode = document.getNodeById(documentPosition.nodeId);
    if (textNode is! TextNode) {
      editorDocLog.shout('ERROR: can\'t insert text in a node that isn\'t a TextNode: $textNode');
      return;
    }

    final textPosition = documentPosition.nodePosition as TextPosition;
    final textOffset = textPosition.offset;
    textNode.text = textNode.text.insertString(
      textToInsert: textToInsert,
      startOffset: textOffset,
      applyAttributions: attributions,
    );

    executor.logChanges([
      DocumentEdit(
        TextInsertionEvent(
          nodeId: textNode.id,
          offset: textOffset,
          text: AttributedText(textToInsert),
        ),
      ),
    ]);

    executor.executeCommand(
      ChangeSelectionCommand(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(
              offset: textOffset + textToInsert.length,
              affinity: textPosition.affinity,
            ),
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.userInteraction,
        notifyListeners: false,
      ),
    );
  }
}

class TextInsertionEvent extends NodeChangeEvent {
  TextInsertionEvent({
    required String nodeId,
    required this.offset,
    required this.text,
  }) : super(nodeId);

  final int offset;
  final AttributedText text;

  @override
  String toString() => "TextInsertionEvent ('$nodeId' - $offset -> '${text.text}')";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TextInsertionEvent &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          text == other.text;

  @override
  int get hashCode => super.hashCode ^ offset.hashCode ^ text.hashCode;
}

class TextDeletedEvent extends NodeChangeEvent {
  const TextDeletedEvent(
    String nodeId, {
    required this.offset,
    required this.deletedText,
  }) : super(nodeId);

  final int offset;
  final AttributedText deletedText;

  @override
  String toString() => "TextDeletedEvent ('$nodeId' - $offset -> '${deletedText.text}')";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TextDeletedEvent &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          deletedText == other.deletedText;

  @override
  int get hashCode => super.hashCode ^ offset.hashCode ^ deletedText.hashCode;
}

class ConvertTextNodeToParagraphRequest implements EditRequest {
  const ConvertTextNodeToParagraphRequest({
    required this.nodeId,
    this.newMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? newMetadata;
}

class ConvertTextNodeToParagraphCommand extends EditCommand {
  ConvertTextNodeToParagraphCommand({
    required this.nodeId,
    this.newMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? newMetadata;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);

    final extentNode = document.getNodeById(nodeId) as TextNode;
    if (extentNode is ParagraphNode) {
      extentNode.putMetadataValue('blockType', paragraphAttribution);
    } else {
      final newParagraphNode = ParagraphNode(
        id: extentNode.id,
        text: extentNode.text,
        metadata: newMetadata,
      );

      document.replaceNode(oldNode: extentNode, newNode: newParagraphNode);
    }

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(extentNode.id),
      ),
    ]);
  }
}

class InsertAttributedTextRequest implements EditRequest {
  const InsertAttributedTextRequest(this.documentPosition, this.textToInsert);

  final DocumentPosition documentPosition;
  final AttributedText textToInsert;
}

class InsertAttributedTextCommand implements EditCommand {
  InsertAttributedTextCommand({
    required this.documentPosition,
    required this.textToInsert,
  }) : assert(documentPosition.nodePosition is TextPosition);

  final DocumentPosition documentPosition;
  final AttributedText textToInsert;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final textNode = document.getNodeById(documentPosition.nodeId);
    if (textNode is! TextNode) {
      editorDocLog.shout('ERROR: can\'t insert text in a node that isn\'t a TextNode: $textNode');
      return;
    }

    final textOffset = (documentPosition.nodePosition as TextPosition).offset;

    textNode.text = textNode.text.insert(
      textToInsert: textToInsert,
      startOffset: textOffset,
    );

    executor.logChanges([
      DocumentEdit(
        TextInsertionEvent(
          nodeId: textNode.id,
          offset: textOffset,
          text: textToInsert,
        ),
      ),
    ]);
  }
}

ExecutionInstruction anyCharacterToInsertInTextContent({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(
    document: editContext.document,
    selection: editContext.composer.selection!,
  )) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.character == null || keyEvent.character == '') {
    return ExecutionInstruction.continueExecution;
  }
  if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!) || keyEvent.isArrowKeyPressed) {
    return ExecutionInstruction.continueExecution;
  }

  String character = keyEvent.character!;

  // On web, keys like shift and alt are sending their full name
  // as a character, e.g., "Shift" and "Alt". This check prevents
  // those keys from inserting their name into content.
  if (isKeyEventCharacterBlacklisted(character) && character != 'Tab') {
    return ExecutionInstruction.continueExecution;
  }

  // The web reports a tab as "Tab". Intercept it and translate it to a space.
  if (character == 'Tab') {
    character = ' ';
  }

  final didInsertCharacter = editContext.commonOps.insertCharacter(character);

  return didInsertCharacter ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

class InsertCharacterAtCaretRequest implements EditRequest {
  const InsertCharacterAtCaretRequest({
    required this.character,
    this.ignoreComposerAttributions = false,
  });

  final String character;
  final bool ignoreComposerAttributions;
}

class InsertCharacterAtCaretCommand extends EditCommand {
  InsertCharacterAtCaretCommand({
    required this.character,
    this.ignoreComposerAttributions = false,
  });

  final String character;
  final bool ignoreComposerAttributions;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    if (composer.selection == null) {
      return;
    }

    if (!composer.selection!.isCollapsed) {
      _deleteExpandedSelection(
        context: context,
        executor: executor,
        document: document,
        composer: composer,
      );
    }

    final extentNodePosition = composer.selection!.extent.nodePosition;
    if (extentNodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      _insertBlockLevelNewline(
        context: context,
        executor: executor,
        document: document,
        composer: composer,
      );
    }

    final extentNode = document.getNodeById(composer.selection!.extent.nodeId)!;
    if (extentNode is! TextNode) {
      editorOpsLog.fine(
          "Couldn't insert character because Super Editor doesn't know how to handle a node of type: $extentNode");
      return;
    }

    // Delegate the action to the standard insert-character behavior.
    _insertCharacterInTextComposable(
      character,
      context: context,
      document: document,
      composer: composer,
      ignoreComposerAttributions: ignoreComposerAttributions,
      executor: executor,
    );
  }
}

void _deleteExpandedSelection({
  required EditContext context,
  required CommandExecutor executor,
  required Document document,
  required DocumentComposer composer,
}) {
  final newSelectionPosition = _getDocumentPositionAfterExpandedDeletion(
    document: document,
    selection: composer.selection!,
  );

  // Delete the selected content.
  executor.executeCommand(
    DeleteContentCommand(
      documentRange: composer.selection!,
    ),
  );

  executor.executeCommand(
    ChangeSelectionCommand(
      DocumentSelection.collapsed(position: newSelectionPosition),
      SelectionChangeType.deleteContent,
      SelectionReason.userInteraction,
    ),
  );
}

DocumentPosition _getDocumentPositionAfterExpandedDeletion({
  required Document document,
  required DocumentSelection selection,
}) {
  // Figure out where the caret should appear after the
  // deletion.
  // TODO: This calculation depends upon the first
  //       selected node still existing after the deletion. This
  //       is a fragile expectation and should be revisited.
  final basePosition = selection.base;
  final baseNode = document.getNode(basePosition);
  if (baseNode == null) {
    throw Exception('Failed to _getDocumentPositionAfterDeletion because the base node no longer exists.');
  }
  final baseNodeIndex = document.getNodeIndexById(baseNode.id);

  final extentPosition = selection.extent;
  final extentNode = document.getNode(extentPosition);
  if (extentNode == null) {
    throw Exception('Failed to _getDocumentPositionAfterDeletion because the extent node no longer exists.');
  }
  final extentNodeIndex = document.getNodeIndexById(extentNode.id);

  final topNodeIndex = min(baseNodeIndex, extentNodeIndex);
  final topNode = document.getNodeAt(topNodeIndex)!;
  final topNodePosition = baseNodeIndex < extentNodeIndex ? basePosition.nodePosition : extentPosition.nodePosition;

  final bottomNodeIndex = max(baseNodeIndex, extentNodeIndex);
  final bottomNode = document.getNodeAt(bottomNodeIndex)!;
  final bottomNodePosition = baseNodeIndex < extentNodeIndex ? extentPosition.nodePosition : basePosition.nodePosition;

  DocumentPosition newSelectionPosition;

  if (baseNodeIndex != extentNodeIndex) {
    if (topNodePosition == topNode.beginningPosition && bottomNodePosition == bottomNode.endPosition) {
      // All nodes in the selection will be deleted. Assume that the base
      // node will be retained and converted into a paragraph, if it's not
      // already a paragraph.
      newSelectionPosition = DocumentPosition(
        nodeId: baseNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      );
    } else if (topNodePosition == topNode.beginningPosition) {
      // The top node will be deleted, but only part of the bottom node
      // will be deleted.
      newSelectionPosition = DocumentPosition(
        nodeId: bottomNode.id,
        nodePosition: bottomNode.beginningPosition,
      );
    } else if (bottomNodePosition == bottomNode.endPosition) {
      // The bottom node will be deleted, but only part of the top node
      // will be deleted.
      newSelectionPosition = DocumentPosition(
        nodeId: topNode.id,
        nodePosition: topNodePosition,
      );
    } else {
      // Part of the top and bottom nodes will be deleted, but both of
      // those nodes will remain.

      // The caret should end up at the base position
      newSelectionPosition = baseNodeIndex <= extentNodeIndex ? selection.base : selection.extent;
    }
  } else {
    // Selection is within a single node.
    //
    // If it's an upstream/downstream selection node, then the whole node
    // is selected, and it will be replaced by a Paragraph Node.
    //
    // Otherwise, it must be a TextNode, in which case we need to figure
    // out which DocumentPosition contains the earlier TextNodePosition.
    if (basePosition.nodePosition is UpstreamDownstreamNodePosition) {
      // Assume that the node was replace with an empty paragraph.
      newSelectionPosition = DocumentPosition(
        nodeId: baseNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      );
    } else if (basePosition.nodePosition is TextNodePosition) {
      final baseOffset = (basePosition.nodePosition as TextNodePosition).offset;
      final extentOffset = (extentPosition.nodePosition as TextNodePosition).offset;

      newSelectionPosition = DocumentPosition(
        nodeId: baseNode.id,
        nodePosition: TextNodePosition(offset: min(baseOffset, extentOffset)),
      );
    } else {
      throw Exception(
          'Unknown selection position type: $basePosition, for node: $baseNode, within document selection: $selection');
    }
  }

  return newSelectionPosition;
}

void _insertBlockLevelNewline({
  required EditContext context,
  required CommandExecutor executor,
  required Document document,
  required DocumentComposer composer,
}) {
  if (composer.selection == null) {
    return;
  }

  // Ensure that the entire selection sits within the same node.
  final baseNode = document.getNodeById(composer.selection!.base.nodeId)!;
  final extentNode = document.getNodeById(composer.selection!.extent.nodeId)!;
  if (baseNode.id != extentNode.id) {
    return;
  }

  if (!composer.selection!.isCollapsed) {
    // The selection is not collapsed. Delete the selected content first,
    // then continue the process.
    _deleteExpandedSelection(
      context: context,
      executor: executor,
      document: document,
      composer: composer,
    );
  }

  final newNodeId = Editor.createNodeId();

  if (extentNode is ListItemNode) {
    if (extentNode.text.text.isEmpty) {
      // The list item is empty. Convert it to a paragraph.
      _convertToParagraph(
        context: context,
        executor: executor,
        document: document,
        composer: composer,
      );
      return;
    }

    // Split the list item into two.
    executor.executeCommand(
      SplitListItemCommand(
        nodeId: extentNode.id,
        splitPosition: composer.selection!.extent.nodePosition as TextNodePosition,
        newNodeId: newNodeId,
      ),
    );
  } else if (extentNode is ParagraphNode) {
    // Split the paragraph into two. This includes headers, blockquotes, and
    // any other block-level paragraph.
    final currentExtentPosition = composer.selection!.extent.nodePosition as TextNodePosition;
    final endOfParagraph = extentNode.endPosition;

    executor.executeCommand(
      SplitParagraphCommand(
        nodeId: extentNode.id,
        splitPosition: currentExtentPosition,
        newNodeId: newNodeId,
        replicateExistingMetadata: currentExtentPosition.offset != endOfParagraph.offset,
      ),
    );
  } else if (composer.selection!.extent.nodePosition is UpstreamDownstreamNodePosition) {
    final extentPosition = composer.selection!.extent.nodePosition as UpstreamDownstreamNodePosition;
    if (extentPosition.affinity == TextAffinity.downstream) {
      // The caret sits on the downstream edge of block-level content. Insert
      // a new paragraph after this node.
      executor.executeCommand(
        InsertNodeAfterNodeCommand(
          existingNodeId: extentNode.id,
          newNode: ParagraphNode(
            id: newNodeId,
            text: AttributedText(''),
          ),
        ),
      );
    } else {
      // The caret sits on the upstream edge of block-level content. Insert
      // a new paragraph before this node.
      executor.executeCommand(
        InsertNodeAfterNodeCommand(
          existingNodeId: extentNode.id,
          newNode: ParagraphNode(
            id: newNodeId,
            text: AttributedText(''),
          ),
        ),
      );
    }
  } else {
    // We don't know how to handle this type of node position. Do nothing.
    return;
  }

  // Place the caret at the beginning of the new node.
  executor.executeCommand(
    ChangeSelectionCommand(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newNodeId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ),
  );
}

void _insertCharacterInTextComposable(
  String character, {
  required EditContext context,
  required Document document,
  required DocumentComposer composer,
  bool ignoreComposerAttributions = false,
  required CommandExecutor executor,
}) {
  if (composer.selection == null) {
    return;
  }
  if (!composer.selection!.isCollapsed) {
    return;
  }
  if (!_isTextEntryNode(document: document, selection: composer.selection!)) {
    return;
  }

  executor.executeCommand(
    InsertTextCommand(
      documentPosition: composer.selection!.extent,
      textToInsert: character,
      attributions: ignoreComposerAttributions ? {} : composer.preferences.currentAttributions,
    ),
  );
}

/// Converts the [TextNode] with the current [DocumentComposer] selection
/// extent to a [Paragraph], or does nothing if the current node is not
/// a [TextNode], or if the current selection spans more than one node.
void _convertToParagraph({
  required EditContext context,
  required CommandExecutor executor,
  required Document document,
  required DocumentComposer composer,
  Map<String, Attribution>? newMetadata,
}) {
  if (composer.selection == null) {
    return;
  }

  final baseNode = document.getNodeById(composer.selection!.base.nodeId)!;
  final extentNode = document.getNodeById(composer.selection!.extent.nodeId)!;
  if (baseNode.id != extentNode.id) {
    return;
  }
  if (extentNode is! TextNode) {
    return;
  }
  if (extentNode is ParagraphNode && extentNode.hasMetadataValue('blockType')) {
    // This content is already a regular paragraph.
    return;
  }

  executor.executeCommand(
    ConvertTextNodeToParagraphCommand(nodeId: extentNode.id, newMetadata: newMetadata),
  );
}

ExecutionInstruction deleteCharacterWhenBackspaceIsPressed({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(
    document: editContext.document,
    selection: editContext.composer.selection!,
  )) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if ((editContext.composer.selection!.extent.nodePosition as TextPosition).offset <= 0) {
    return ExecutionInstruction.continueExecution;
  }

  final didDelete = editContext.commonOps.deleteUpstream();

  return didDelete ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction deleteDownstreamContentWithDelete({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  final didDelete = editContext.commonOps.deleteDownstream();

  return didDelete ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction shiftEnterToInsertNewlineInBlock({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }
  if (!HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final didInsertNewline = editContext.commonOps.insertPlainText('\n');

  return didInsertNewline ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

bool _isTextEntryNode({
  required Document document,
  required DocumentSelection selection,
}) {
  final extentPosition = selection.extent;
  final extentNode = document.getNodeById(extentPosition.nodeId);
  return extentNode is TextNode;
}
