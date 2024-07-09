import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blocks/indentation.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

import '../core/document.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';

final _log = Logger(scope: 'list_items.dart');

class ListItemNode extends TextNode {
  ListItemNode.ordered({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = ListItemType.ordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        ) {
    putMetadataValue("blockType", listItemAttribution);
  }

  ListItemNode.unordered({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = ListItemType.unordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        ) {
    putMetadataValue("blockType", listItemAttribution);
  }

  ListItemNode({
    required String id,
    required ListItemType itemType,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = itemType,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata ?? {},
        ) {
    if (!hasMetadataValue("blockType")) {
      putMetadataValue("blockType", listItemAttribution);
    }
  }

  final ListItemType type;

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent != _indent) {
      _indent = newIndent;
      notifyListeners();
    }
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is ListItemNode && type == other.type && indent == other.indent && text == other.text;
  }

  @override
  ListItemNode copy() {
    return ListItemNode(
      id: id,
      text: text.copyText(0),
      itemType: type,
      indent: indent,
      metadata: Map.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ListItemNode &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _indent == other._indent;

  @override
  int get hashCode => super.hashCode ^ type.hashCode ^ _indent.hashCode;
}

const listItemAttribution = NamedAttribution("listItem");

enum ListItemType {
  ordered,
  unordered,
}

class ListItemComponentBuilder implements ComponentBuilder {
  const ListItemComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ListItemNode) {
      return null;
    }

    int? ordinalValue;
    if (node.type == ListItemType.ordered) {
      ordinalValue = computeListItemOrdinalValue(node, document);
    }

    return switch (node.type) {
      ListItemType.unordered => UnorderedListItemComponentViewModel(
          nodeId: node.id,
          indent: node.indent,
          text: node.text,
          textStyleBuilder: noStyleBuilder,
          selectionColor: const Color(0x00000000),
        ),
      ListItemType.ordered => OrderedListItemComponentViewModel(
          nodeId: node.id,
          indent: node.indent,
          ordinalValue: ordinalValue,
          text: node.text,
          textStyleBuilder: noStyleBuilder,
          selectionColor: const Color(0x00000000),
        ),
    };
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! UnorderedListItemComponentViewModel &&
        componentViewModel is! OrderedListItemComponentViewModel) {
      return null;
    }

    if (componentViewModel is UnorderedListItemComponentViewModel) {
      return UnorderedListItemComponent(
        componentKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        indent: componentViewModel.indent,
        dotStyle: componentViewModel.dotStyle,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        composingRegion: componentViewModel.composingRegion,
        showComposingUnderline: componentViewModel.showComposingUnderline,
      );
    } else if (componentViewModel is OrderedListItemComponentViewModel) {
      return OrderedListItemComponent(
        componentKey: componentContext.componentKey,
        indent: componentViewModel.indent,
        listIndex: componentViewModel.ordinalValue!,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        numeralStyle: componentViewModel.numeralStyle,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        composingRegion: componentViewModel.composingRegion,
        showComposingUnderline: componentViewModel.showComposingUnderline,
      );
    }

    editorLayoutLog
        .warning("Tried to build a component for a list item view model without a list item type: $componentViewModel");
    return null;
  }
}

abstract class ListItemComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  ListItemComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.indent,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  int indent;

  @override
  AttributedText text;
  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;
  @override
  TextRange? composingRegion;
  @override
  bool showComposingUnderline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ListItemComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          indent == other.indent &&
          text == other.text &&
          textDirection == other.textDirection &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          composingRegion == other.composingRegion &&
          showComposingUnderline == other.showComposingUnderline;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      indent.hashCode ^
      text.hashCode ^
      textDirection.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      composingRegion.hashCode;
}

class UnorderedListItemComponentViewModel extends ListItemComponentViewModel {
  UnorderedListItemComponentViewModel({
    required super.nodeId,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    required super.indent,
    required super.text,
    required super.textStyleBuilder,
    this.dotStyle = const ListItemDotStyle(),
    super.textDirection = TextDirection.ltr,
    super.textAlignment = TextAlign.left,
    super.selection,
    required super.selectionColor,
    super.highlightWhenEmpty = false,
    super.composingRegion,
    super.showComposingUnderline = false,
  });

  ListItemDotStyle dotStyle = const ListItemDotStyle();

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    dotStyle = ListItemDotStyle(
      color: styles[Styles.dotColor],
      shape: styles[Styles.dotShape] ?? BoxShape.circle,
      size: styles[Styles.dotSize] ?? const Size(4, 4),
    );
  }

  @override
  UnorderedListItemComponentViewModel copy() {
    return UnorderedListItemComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      indent: indent,
      text: text,
      textStyleBuilder: textStyleBuilder,
      dotStyle: dotStyle,
      textDirection: textDirection,
      selection: selection,
      selectionColor: selectionColor,
      composingRegion: composingRegion,
      showComposingUnderline: showComposingUnderline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is UnorderedListItemComponentViewModel &&
          runtimeType == other.runtimeType &&
          dotStyle == other.dotStyle;

  @override
  int get hashCode => super.hashCode ^ dotStyle.hashCode;
}

class OrderedListItemComponentViewModel extends ListItemComponentViewModel {
  OrderedListItemComponentViewModel({
    required super.nodeId,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    required super.indent,
    this.ordinalValue,
    this.numeralStyle = OrderedListNumeralStyle.arabic,
    required super.text,
    required super.textStyleBuilder,
    super.textDirection = TextDirection.ltr,
    super.textAlignment = TextAlign.left,
    super.selection,
    required super.selectionColor,
    super.highlightWhenEmpty = false,
    super.composingRegion,
    super.showComposingUnderline = false,
  });

  final int? ordinalValue;
  OrderedListNumeralStyle numeralStyle;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    numeralStyle = styles[Styles.listNumeralStyle] ?? OrderedListNumeralStyle.arabic;
  }

  @override
  OrderedListItemComponentViewModel copy() {
    return OrderedListItemComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      indent: indent,
      ordinalValue: ordinalValue,
      numeralStyle: numeralStyle,
      text: text,
      textStyleBuilder: textStyleBuilder,
      textDirection: textDirection,
      selection: selection,
      selectionColor: selectionColor,
      composingRegion: composingRegion,
      showComposingUnderline: showComposingUnderline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is OrderedListItemComponentViewModel &&
          runtimeType == other.runtimeType &&
          ordinalValue == other.ordinalValue &&
          numeralStyle == other.numeralStyle;

  @override
  int get hashCode => super.hashCode ^ ordinalValue.hashCode ^ numeralStyle.hashCode;
}

class ListItemDotStyle {
  const ListItemDotStyle({
    this.color,
    this.shape = BoxShape.circle,
    this.size = const Size(4, 4),
  });

  final Color? color;
  final BoxShape shape;
  final Size size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItemDotStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          shape == other.shape &&
          size == other.size;

  @override
  int get hashCode => super.hashCode ^ color.hashCode ^ shape.hashCode ^ size.hashCode;
}

/// Displays a un-ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class UnorderedListItemComponent extends StatefulWidget {
  const UnorderedListItemComponent({
    Key? key,
    required this.componentKey,
    required this.text,
    required this.styleBuilder,
    this.dotBuilder = _defaultUnorderedListItemDotBuilder,
    this.dotStyle,
    this.indent = 0,
    this.indentCalculator = defaultListItemIndentCalculator,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final UnorderedListItemDotBuilder dotBuilder;
  final ListItemDotStyle? dotStyle;
  final int indent;
  final double Function(TextStyle, int indent) indentCalculator;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final TextRange? composingRegion;
  final bool showComposingUnderline;
  final bool showDebugPaint;

  @override
  State<UnorderedListItemComponent> createState() => _UnorderedListItemComponentState();
}

class _UnorderedListItemComponentState extends State<UnorderedListItemComponent> {
  /// A [GlobalKey] that connects a [ProxyTextDocumentComponent] to its
  /// descendant [TextComponent].
  ///
  /// The [ProxyTextDocumentComponent] doesn't know where the [TextComponent] sits
  /// in its subtree, but the proxy needs access to the [TextComponent] to provide
  /// access to text layout details.
  ///
  /// This key doesn't need to be public because the given [widget.componentKey]
  /// provides clients with direct access to text layout queries, as well as
  /// standard [DocumentComponent] queries.
  final GlobalKey _innerTextComponentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Usually, the font size is obtained via the stylesheet. But the attributions might
    // also contain a FontSizeAttribution, which overrides the stylesheet. Use the attributions
    // of the first character to determine the text style.
    final attributions = widget.text.getAllAttributionsAt(0).toSet();
    final textStyle = widget.styleBuilder(attributions);

    final indentSpace = widget.indentCalculator(textStyle, widget.indent);
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = textScaler.scale(textStyle.fontSize! * (textStyle.height ?? 1.25));

    return ProxyTextDocumentComponent(
      key: widget.componentKey,
      textComponentKey: _innerTextComponentKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: indentSpace,
            decoration: BoxDecoration(
              border: widget.showDebugPaint ? Border.all(width: 1, color: Colors.grey) : null,
            ),
            child: SizedBox(
              height: lineHeight,
              child: widget.dotBuilder(context, widget),
            ),
          ),
          Expanded(
            child: TextComponent(
              key: _innerTextComponentKey,
              text: widget.text,
              textStyleBuilder: widget.styleBuilder,
              textSelection: widget.textSelection,
              textScaler: textScaler,
              selectionColor: widget.selectionColor,
              highlightWhenEmpty: widget.highlightWhenEmpty,
              composingRegion: widget.composingRegion,
              showComposingUnderline: widget.showComposingUnderline,
              showDebugPaint: widget.showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The styling of an ordered list numberal.
enum OrderedListNumeralStyle {
  /// Arabic numeral style (e.g. 1, 2, 3, ...).
  arabic,

  /// Lowercase alphabetic numeral style (e.g. a, b, c, ...).
  lowerAlpha,

  /// Uppercase alphabetic numeral style (e.g. A, B, C, ...).
  upperAlpha,

  /// Lowercase Roman numeral style (e.g. i, ii, iii, ...).
  lowerRoman,

  /// Uppercase Roman numeral style (e.g. I, II, III, ...).
  upperRoman,
}

typedef UnorderedListItemDotBuilder = Widget Function(BuildContext, UnorderedListItemComponent);

Widget _defaultUnorderedListItemDotBuilder(BuildContext context, UnorderedListItemComponent component) {
  // Usually, the font size is obtained via the stylesheet. But the attributions might
  // also contain a FontSizeAttribution, which overrides the stylesheet. Use the attributions
  // of the first character to determine the text style.
  final attributions = component.text.getAllAttributionsAt(0).toSet();
  final textStyle = component.styleBuilder(attributions);

  final dotSize = component.dotStyle?.size ?? const Size(4, 4);

  return Align(
    alignment: Alignment.centerRight,
    child: Text.rich(
      TextSpan(
        // Place a zero-width joiner before the bullet point to make it properly aligned. Without this,
        // the bullet point is not vertically centered with the text, even when setting the textStyle
        // on the whole rich text or WidgetSpan.
        text: '\u200C',
        style: textStyle,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: dotSize.width,
              height: dotSize.height,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: component.dotStyle?.shape ?? BoxShape.circle,
                color: component.dotStyle?.color ?? textStyle.color,
              ),
            ),
          ),
        ],
      ),
      // Don't scale the dot.
      textScaler: const TextScaler.linear(1.0),
    ),
  );
}

/// Displays an ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class OrderedListItemComponent extends StatefulWidget {
  const OrderedListItemComponent({
    Key? key,
    required this.componentKey,
    required this.listIndex,
    required this.text,
    required this.styleBuilder,
    this.numeralBuilder = _defaultOrderedListItemNumeralBuilder,
    this.numeralStyle = OrderedListNumeralStyle.arabic,
    this.indent = 0,
    this.indentCalculator = defaultListItemIndentCalculator,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final int listIndex;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final OrderedListItemNumeralBuilder numeralBuilder;
  final OrderedListNumeralStyle numeralStyle;
  final int indent;
  final TextBlockIndentCalculator indentCalculator;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final TextRange? composingRegion;
  final bool showComposingUnderline;
  final bool showDebugPaint;

  @override
  State<OrderedListItemComponent> createState() => _OrderedListItemComponentState();
}

class _OrderedListItemComponentState extends State<OrderedListItemComponent> {
  /// A [GlobalKey] that connects a [ProxyTextDocumentComponent] to its
  /// descendant [TextComponent].
  ///
  /// The [ProxyTextDocumentComponent] doesn't know where the [TextComponent] sits
  /// in its subtree, but the proxy needs access to the [TextComponent] to provide
  /// access to text layout details.
  ///
  /// This key doesn't need to be public because the given [widget.componentKey]
  /// provides clients with direct access to text layout queries, as well as
  /// standard [DocumentComponent] queries.
  final GlobalKey _innerTextComponentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Usually, the font size is obtained via the stylesheet. But the attributions might
    // also contain a FontSizeAttribution, which overrides the stylesheet. Use the attributions
    // of the first character to determine the text style.
    final attributions = widget.text.getAllAttributionsAt(0).toSet();
    final textStyle = widget.styleBuilder(attributions);

    final indentSpace = widget.indentCalculator(textStyle, widget.indent);
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = textScaler.scale(textStyle.fontSize! * (textStyle.height ?? 1.0));

    return ProxyTextDocumentComponent(
      key: widget.componentKey,
      textComponentKey: _innerTextComponentKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: indentSpace,
            height: lineHeight,
            decoration: BoxDecoration(
              border: widget.showDebugPaint ? Border.all(width: 1, color: Colors.grey) : null,
            ),
            child: SizedBox(
              height: lineHeight,
              child: widget.numeralBuilder(context, widget),
            ),
          ),
          Expanded(
            child: TextComponent(
              key: _innerTextComponentKey,
              text: widget.text,
              textStyleBuilder: widget.styleBuilder,
              textSelection: widget.textSelection,
              textScaler: textScaler,
              selectionColor: widget.selectionColor,
              highlightWhenEmpty: widget.highlightWhenEmpty,
              composingRegion: widget.composingRegion,
              showComposingUnderline: widget.showComposingUnderline,
              showDebugPaint: widget.showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}

typedef OrderedListItemNumeralBuilder = Widget Function(BuildContext, OrderedListItemComponent);

/// The standard [TextBlockIndentCalculator] used by list items in `SuperEditor`.
double defaultListItemIndentCalculator(TextStyle textStyle, int indent) {
  return (textStyle.fontSize! * 0.60) * 4 * (indent + 1);
}

Widget _defaultOrderedListItemNumeralBuilder(BuildContext context, OrderedListItemComponent component) {
  // Usually, the font size is obtained via the stylesheet. But the attributions might
  // also contain a FontSizeAttribution, which overrides the stylesheet. Use the attributions
  // of the first character to determine the text style.
  final attributions = component.text.getAllAttributionsAt(0).toSet();
  final textStyle = component.styleBuilder(attributions);

  return OverflowBox(
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Text(
          '${_numeralForIndex(component.listIndex, component.numeralStyle)}.',
          textAlign: TextAlign.right,
          style: textStyle,
        ),
      ),
    ),
  );
}

/// Returns the text to be displayed for the given [numeral] and [numeralStyle].
String _numeralForIndex(int numeral, OrderedListNumeralStyle numeralStyle) {
  return switch (numeralStyle) {
    OrderedListNumeralStyle.arabic => '$numeral',
    OrderedListNumeralStyle.upperRoman => _intToRoman(numeral) ?? '$numeral',
    OrderedListNumeralStyle.lowerRoman => _intToRoman(numeral)?.toLowerCase() ?? '$numeral',
    OrderedListNumeralStyle.upperAlpha => _intToAlpha(numeral),
    OrderedListNumeralStyle.lowerAlpha => _intToAlpha(numeral).toLowerCase(),
  };
}

/// Converts a number to its Roman numeral representation.
///
/// Returns `null` if the number is greater than 3999, as we don't support the
/// vinculum notation. See more at https://en.wikipedia.org/wiki/Roman_numerals#cite_ref-Ifrah2000_52-1.
String? _intToRoman(int number) {
  if (number <= 0) {
    throw ArgumentError('Roman numerals are only defined for positive integers');
  }

  if (number > 3999) {
    // Starting from 4000, the Roman numeral representation uses a bar over the numeral to represent
    // a multiplication by 1000. We don't support this notation.
    return null;
  }

  const values = [1000, 500, 100, 50, 10, 5, 1];
  const symbols = ["M", "D", "C", "L", "X", "V", "I"];

  int remainingValueToConvert = number;

  final result = StringBuffer();

  for (int i = 0; i < values.length; i++) {
    final currentSymbol = symbols[i];
    final currentSymbolValue = values[i];

    final count = remainingValueToConvert ~/ currentSymbolValue;

    if (count > 0 && count < 4) {
      // The number is bigger than the current symbol's value. Add the appropriate
      // number of digits, respecting the maximum of three consecutive symbols.
      // For example, for 300 we would add "CCC", but for 400 we won't add "CCCC".
      result.write(currentSymbol * count);

      remainingValueToConvert %= currentSymbolValue;
    }

    if (remainingValueToConvert <= 0) {
      // The conversion is complete.
      break;
    }

    // We still have some value to convert. Check if we can use subtractive notation.
    if (i % 2 == 0 && i + 2 < values.length) {
      // Numbers in even positions (0, 2, 4) can be subtracted with other numbers
      // two positions to the right of them:
      //
      //  - 1000 (M) can be subtracted with 100 (C).
      //  - 100 (C) can be subtracted with 10 (X).
      //  - 10 (X) can be subtracted with 1 (I).
      //
      // Check if we can do this subtraction.
      final subtractiveValue = currentSymbolValue - values[i + 2];
      if (remainingValueToConvert >= subtractiveValue) {
        result.write(symbols[i + 2] + currentSymbol);
        remainingValueToConvert -= subtractiveValue;
      }
    } else if (i % 2 != 0 && i + 1 < values.length) {
      // Numbers in odd positions (1, 3, 5) can be subtracted with the number
      // immediately after it to the right:
      //
      // - 500 (D) can be subtracted with 100 (C).
      // - 50 (L) can be subtracted with 10 (X).
      // - 5 (V) can be subtracted with 1 (I).
      //
      // Check if we can do this subtraction.
      final subtractiveValue = currentSymbolValue - values[i + 1];
      if (remainingValueToConvert >= subtractiveValue) {
        result.write(symbols[i + 1] + currentSymbol);
        remainingValueToConvert -= subtractiveValue;
      }
    }
  }

  return result.toString();
}

/// Converts a number to a string composed of A-Z characters.
///
/// For example:
/// - 1 -> A
/// - 2 -> B
/// - ...
/// - 26 -> Z
/// - 27 -> AA
/// - 28 -> AB
String _intToAlpha(int num) {
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  const base = characters.length;

  String result = '';

  while (num > 0) {
    // Convert to 0-based index.
    num -= 1;

    // Find the next character to be added.
    result = characters[num % base] + result;

    // Move to the next digit.
    num = num ~/ base;
  }

  return result;
}

class IndentListItemRequest implements EditRequest {
  IndentListItemRequest({
    required this.nodeId,
  });

  final String nodeId;
}

class IndentListItemCommand extends EditCommand {
  IndentListItemCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent >= 6) {
      _log.log('IndentListItemCommand', 'WARNING: Editor does not support an indent level beyond 6.');
      return;
    }

    listItem.indent += 1;

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(nodeId),
      )
    ]);
  }
}

class UnIndentListItemRequest implements EditRequest {
  UnIndentListItemRequest({
    required this.nodeId,
  });

  final String nodeId;
}

class UnIndentListItemCommand extends EditCommand {
  UnIndentListItemCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent > 0) {
      // TODO: figure out how node changes should work in terms of
      //       a DocumentEditorTransaction (#67)
      listItem.indent -= 1;

      executor.logChanges([
        DocumentEdit(
          NodeChangeEvent(nodeId),
        )
      ]);
    } else {
      executor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: nodeId,
        ),
      );
    }
  }
}

class ConvertListItemToParagraphRequest implements EditRequest {
  ConvertListItemToParagraphRequest({
    required this.nodeId,
    this.paragraphMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? paragraphMetadata;
}

class ConvertListItemToParagraphCommand extends EditCommand {
  ConvertListItemToParagraphCommand({
    required this.nodeId,
    this.paragraphMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? paragraphMetadata;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    final newMetadata = Map<String, dynamic>.from(paragraphMetadata ?? {});
    if (newMetadata["blockType"] == listItemAttribution) {
      newMetadata["blockType"] = paragraphAttribution;
    }

    final newParagraphNode = ParagraphNode(
      id: listItem.id,
      text: listItem.text,
      metadata: newMetadata,
    );
    document.replaceNode(oldNode: listItem, newNode: newParagraphNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(listItem.id),
      )
    ]);
  }
}

class ConvertParagraphToListItemRequest implements EditRequest {
  ConvertParagraphToListItemRequest({
    required this.nodeId,
    required this.type,
  });

  final String nodeId;
  final ListItemType type;
}

class ConvertParagraphToListItemCommand extends EditCommand {
  ConvertParagraphToListItemCommand({
    required this.nodeId,
    required this.type,
  });

  final String nodeId;
  final ListItemType type;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final paragraphNode = node as ParagraphNode;

    final newListItemNode = ListItemNode(
      id: paragraphNode.id,
      itemType: type,
      text: paragraphNode.text,
    );
    document.replaceNode(oldNode: paragraphNode, newNode: newListItemNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(paragraphNode.id),
      )
    ]);
  }
}

class ChangeListItemTypeRequest implements EditRequest {
  ChangeListItemTypeRequest({
    required this.nodeId,
    required this.newType,
  });

  final String nodeId;
  final ListItemType newType;
}

class ChangeListItemTypeCommand extends EditCommand {
  ChangeListItemTypeCommand({
    required this.nodeId,
    required this.newType,
  });

  final String nodeId;
  final ListItemType newType;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final existingListItem = document.getNodeById(nodeId) as ListItemNode;

    final newListItemNode = ListItemNode(
      id: existingListItem.id,
      itemType: newType,
      text: existingListItem.text,
    );
    document.replaceNode(oldNode: existingListItem, newNode: newListItemNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(existingListItem.id),
      )
    ]);
  }
}

class SplitListItemRequest implements EditRequest {
  SplitListItemRequest({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;
}

class SplitListItemCommand extends EditCommand {
  SplitListItemCommand({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    final node = document.getNodeById(nodeId);
    final listItemNode = node as ListItemNode;
    final text = listItemNode.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = splitPosition.offset < text.length ? text.copyText(splitPosition.offset) : AttributedText();
    _log.log('SplitListItemCommand', 'Splitting list item:');
    _log.log('SplitListItemCommand', ' - start text: "$startText"');
    _log.log('SplitListItemCommand', ' - end text: "$endText"');

    // Change the current node's content to just the text before the caret.
    _log.log('SplitListItemCommand', ' - changing the original list item text due to split');
    // TODO: figure out how node changes should work in terms of
    //       a DocumentEditorTransaction (#67)
    listItemNode.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = listItemNode.type == ListItemType.ordered
        ? ListItemNode.ordered(
            id: newNodeId,
            text: endText,
            indent: listItemNode.indent,
          )
        : ListItemNode.unordered(
            id: newNodeId,
            text: endText,
            indent: listItemNode.indent,
          );

    // Insert the new node after the current node.
    _log.log('SplitListItemCommand', ' - inserting new node in document');
    document.insertNodeAfter(
      existingNode: node,
      newNode: newNode,
    );

    // Clear the composing region to avoid keeping a region pointing to the
    // node that was split.
    composer.setComposingRegion(null);

    _log.log('SplitListItemCommand', ' - inserted new node: ${newNode.id} after old one: ${node.id}');

    executor.logChanges([
      SplitListItemIntention.start(),
      DocumentEdit(
        NodeChangeEvent(nodeId),
      ),
      DocumentEdit(
        NodeInsertedEvent(newNodeId, document.getNodeIndexById(newNodeId)),
      ),
      SplitListItemIntention.end(),
    ]);
  }
}

class SplitListItemIntention extends Intention {
  SplitListItemIntention.start() : super.start();

  SplitListItemIntention.end() : super.end();
}

ExecutionInstruction tabToIndentListItem({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }
  if (HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.indentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction shiftTabToUnIndentListItem({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }
  if (!HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.unindentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction backspaceToUnIndentListItem({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }
  if ((editContext.composer.selection!.extent.nodePosition as TextPosition).offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.unindentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction splitListItemWhenEnterPressed({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  final didSplitListItem = editContext.commonOps.insertBlockLevelNewline();
  return didSplitListItem ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

/// Computes the ordinal value of an ordered list item.
///
/// Walks backwards counting the number of ordered list items above the [listItem] with the same indentation level.
///
/// The ordinal value starts at 1.
int computeListItemOrdinalValue(ListItemNode listItem, Document document) {
  if (listItem.type != ListItemType.ordered) {
    // Unordered list items do not have an ordinal value.
    return 0;
  }

  int ordinalValue = 1;
  DocumentNode? nodeAbove = document.getNodeBefore(listItem);
  while (nodeAbove != null && nodeAbove is ListItemNode && nodeAbove.indent >= listItem.indent) {
    if (nodeAbove.indent == listItem.indent) {
      if (nodeAbove.type != ListItemType.ordered) {
        // We found an unordered list item with the same indentation level as the ordered list item.
        // Other ordered list items above this one do not belong to the same list.
        break;
      }
      ordinalValue = ordinalValue + 1;
    }
    nodeAbove = document.getNodeBefore(nodeAbove);
  }

  return ordinalValue;
}
