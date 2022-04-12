import 'package:flutter/widgets.dart';
import 'package:super_text/src/super_text.dart';
import 'package:super_text/super_text_logging.dart';

import 'caret_layer.dart';
import 'text_layout.dart';
import 'text_selection_layer.dart';

/// Displays rich text with traditional text carets and selection highlights.
///
/// [SuperTextWithSelection] supports single-user and multi-user selection
/// displays.
///
/// [SuperTextWithSelection] is intended to provide the most convenient API possible
/// for traditional selection rendering. To render unusual selection use-cases,
/// use [SuperText], directly. You can use the implementation of [SuperTextWithSelection]
/// as a guide for how to implement your own behaviors and visual effects.
class SuperTextWithSelection extends StatefulWidget {
  SuperTextWithSelection.single({
    Key? key,
    this.textLayoutKey,
    required this.richText,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    UserSelection? userSelection,
  })  : userSelections = userSelection != null ? [userSelection] : const [],
        super(key: key);

  const SuperTextWithSelection.multi({
    Key? key,
    this.textLayoutKey,
    required this.richText,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    required this.userSelections,
  }) : super(key: key);

  /// Key attached to the inner widget that implements [TextLayout].
  final GlobalKey? textLayoutKey;

  /// The blob of text that's displayed to the user.
  final InlineSpan richText;

  /// The alignment to use for [richText] display.
  final TextAlign textAlign;

  /// The text direction to use for [richText] display.
  final TextDirection textDirection;

  /// The user selections that are painted with the given [richText].
  ///
  /// A user selection includes a caret and a selection highlight.
  final List<UserSelection> userSelections;

  @override
  State<SuperTextWithSelection> createState() => _SuperTextWithSelectionState();
}

class _SuperTextWithSelectionState extends State<SuperTextWithSelection> implements ProseTextBlock {
  late GlobalKey _textLayoutKey;
  late final ValueNotifier<List<UserSelection>> _userSelections;

  @override
  void initState() {
    super.initState();
    _textLayoutKey = widget.textLayoutKey ?? GlobalKey(debugLabel: "text_layout");
    _userSelections = ValueNotifier(widget.userSelections);
  }

  @override
  void didUpdateWidget(SuperTextWithSelection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textLayoutKey != oldWidget.textLayoutKey) {
      _textLayoutKey = widget.textLayoutKey ?? GlobalKey(debugLabel: "text_layout");
    }

    // Notify the optimized rendering widget that the user selections
    // have changed. This is done with a ValueNotifier instead of a
    // regular widget rebuild so that we can tactically rebuild only
    // the parts of the subtree that are used for selection painting.
    if (widget.userSelections != oldWidget.userSelections) {
      buildsLog.finest("SuperTextWithSelection ($hashCode) user selections changed. Notifying optimized subtree");
      _userSelections.value = widget.userSelections;
    }
  }

  @override
  ProseTextLayout get textLayout => _textLayoutKey.currentState as ProseTextLayout;

  @override
  Widget build(BuildContext context) {
    buildsLog.info("Building SuperTextWithSelection ($hashCode)");
    // TODO: how do we prevent a full SuperText rebuild when the selection changes?
    // TODO: add a test that ensures the highlight painter doesn't paint anything when
    //       the selection is collapsed
    return _RebuildOptimizedSuperTextWithSelection(
      textLayoutKey: _textLayoutKey,
      richText: widget.richText,
      userSelections: _userSelections,
    );
  }
}

class _RebuildOptimizedSuperTextWithSelection extends StatefulWidget {
  const _RebuildOptimizedSuperTextWithSelection({
    Key? key,
    this.textLayoutKey,
    required this.richText,
    required this.userSelections,
  }) : super(key: key);

  final Key? textLayoutKey;
  final InlineSpan richText;

  final ValueNotifier<List<UserSelection>> userSelections;

  @override
  _RebuildOptimizedSuperTextWithSelectionState createState() => _RebuildOptimizedSuperTextWithSelectionState();
}

class _RebuildOptimizedSuperTextWithSelectionState extends State<_RebuildOptimizedSuperTextWithSelection> {
  Widget? _cachedSubtree;

  @override
  void initState() {
    super.initState();

    _updateTextLength();
  }

  @override
  void didUpdateWidget(_RebuildOptimizedSuperTextWithSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.richText != oldWidget.richText) {
      buildsLog.fine("Rich text changed. Invalidating the cached SuperText widget.");

      _updateTextLength();

      // The text changed, which means the text layout changed. Invalidate
      // the cache so that the full SuperText widget subtree is rebuilt.
      _cachedSubtree = null;
    }
  }

  // The current length of the text displayed by this widget. The value
  // is cached because computing the length of rich text may have
  // non-trivial performance implications.
  int get _textLength => _cachedTextLength;
  late int _cachedTextLength;
  void _updateTextLength() {
    _cachedTextLength = widget.richText.toPlainText().length;
  }

  bool get _isTextEmpty => _textLength == 0;

  @override
  Widget build(BuildContext context) {
    if (_cachedSubtree != null) {
      buildsLog.info(
          "Building SuperTextWithSelection ($hashCode), returning cached subtree for optimized super text with selection");
      return _cachedSubtree!;
    }

    buildsLog.info("Building SuperTextWithSelection ($hashCode), doing full build (no cached subtree is available)");
    _cachedSubtree = SuperText(
      key: widget.textLayoutKey,
      richText: widget.richText,
      layerBeneathBuilder: _buildLayerBeneath,
      layerAboveBuilder: _buildLayerAbove,
    );
    return _cachedSubtree!;
  }

  Widget _buildLayerBeneath(BuildContext context, TextLayout textLayout) {
    buildsLog.info("Building SuperTextWithSelection ($hashCode) selection highlight layer");
    return ValueListenableBuilder<List<UserSelection>>(
      valueListenable: widget.userSelections,
      builder: (context, value, child) {
        buildsLog.info(
            "SuperTextWithSelection ($hashCode) user selection changed, building selection highlights: ${widget.userSelections.value.isNotEmpty ? widget.userSelections.value.first.selection : "null"}");
        return Stack(
          children: [
            for (final userSelection in widget.userSelections.value)
              if (!_isTextEmpty)
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: userSelection.highlightStyle,
                  selection: userSelection.selection,
                )
              else if (userSelection.highlightWhenEmpty)
                TextLayoutEmptyHighlight(
                  textLayout: textLayout,
                  style: userSelection.highlightStyle,
                ),
          ],
        );
      },
    );
  }

  Widget _buildLayerAbove(BuildContext context, TextLayout textLayout) {
    buildsLog.info("Building SuperTextWithSelection ($hashCode) caret layer");
    return ValueListenableBuilder<List<UserSelection>>(
      valueListenable: widget.userSelections,
      builder: (context, value, child) {
        buildsLog.info(
            "SuperTextWithSelection ($hashCode) user selection changed, building carets: ${widget.userSelections.value.isNotEmpty ? widget.userSelections.value.first.selection : "null"}");
        return Stack(
          children: [
            for (final userSelection in widget.userSelections.value)
              if (userSelection.hasCaret)
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: userSelection.caretStyle,
                  blinkCaret: userSelection.blinkCaret,
                  position: userSelection.selection.extent,
                ),
          ],
        );
      },
    );
  }
}

/// A user's selection, including a highlight style, caret style, and the logical
/// [TextSelection].
class UserSelection {
  const UserSelection({
    this.highlightStyle = const SelectionHighlightStyle(),
    this.caretStyle = const CaretStyle(),
    this.blinkCaret = true,
    required this.selection,
    this.highlightWhenEmpty = false,
    this.hasCaret = true,
  });

  /// Visual style used to paint a highlight for an expanded [selection].
  final SelectionHighlightStyle highlightStyle;

  /// Visual style used to paint a caret at the [selection] extent.
  final CaretStyle caretStyle;

  /// Whether the caret should blink.
  final bool blinkCaret;

  /// The logical text selection boundaries.
  ///
  /// User selection of an empty text block should pass
  /// `TextSelection.collapsed(offset: 0)`.
  final TextSelection selection;

  /// Whether to paint a small selection highlight for an empty text block.
  ///
  /// For example, the user selects multiple blocks of text and some of those
  /// blocks are empty. If [highlightWhenEmpty] is `true`, those empty text
  /// blocks will paint a small selection highlight.
  final bool highlightWhenEmpty;

  /// Whether this selection includes the user's caret.
  ///
  /// Typically, there is only one caret per user within an entire
  /// document. At the same time, many different blocks of text may
  /// have selection highlights.
  final bool hasCaret;

  UserSelection copyWith({
    SelectionHighlightStyle? highlightStyle,
    CaretStyle? caretStyle,
    bool? blinkCaret,
    TextSelection? selection,
    bool? hasCaret,
  }) {
    return UserSelection(
      highlightStyle: highlightStyle ?? this.highlightStyle,
      caretStyle: caretStyle ?? this.caretStyle,
      blinkCaret: blinkCaret ?? this.blinkCaret,
      selection: selection ?? this.selection,
      hasCaret: hasCaret ?? this.hasCaret,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSelection &&
          runtimeType == other.runtimeType &&
          highlightStyle == other.highlightStyle &&
          caretStyle == other.caretStyle &&
          blinkCaret == other.blinkCaret &&
          selection == other.selection;

  @override
  int get hashCode => highlightStyle.hashCode ^ caretStyle.hashCode ^ blinkCaret.hashCode ^ selection.hashCode;
}
