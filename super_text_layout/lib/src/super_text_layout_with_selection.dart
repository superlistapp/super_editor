import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout_logging.dart';

import 'caret_layer.dart';
import 'super_text.dart';
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
    this.userSelections = const [],
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

class _SuperTextWithSelectionState extends ProseTextState<SuperTextWithSelection> {
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
  ProseTextLayout get textLayout => (_textLayoutKey.currentState as ProseTextBlock).textLayout;

  @override
  Widget build(BuildContext context) {
    buildsLog.info("Building SuperTextWithSelection ($hashCode)");
    // TODO: how do we prevent a full SuperText rebuild when the selection changes?
    // TODO: add a test that ensures the highlight painter doesn't paint anything when
    //       the selection is collapsed
    return _RebuildOptimizedSuperTextWithSelection(
      textLayoutKey: _textLayoutKey,
      richText: widget.richText,
      textAlign: widget.textAlign,
      userSelections: _userSelections,
    );
  }
}

class _RebuildOptimizedSuperTextWithSelection extends StatefulWidget {
  const _RebuildOptimizedSuperTextWithSelection({
    Key? key,
    this.textLayoutKey,
    required this.richText,
    this.textAlign = TextAlign.left,
    required this.userSelections,
  }) : super(key: key);

  final Key? textLayoutKey;
  final InlineSpan richText;
  final TextAlign textAlign;

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
    if (widget.textAlign != oldWidget.textAlign) {
      buildsLog.fine("Text align changed. Invalidating the cached SuperText widget.");

      // The text align changed, which means the text layout changed. Invalidate
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
      textAlign: widget.textAlign,
      layerBeneathBuilder: _buildLayerBeneath,
      layerAboveBuilder: _buildLayerAbove,
    );
    return _cachedSubtree!;
  }

  Widget _buildLayerBeneath(BuildContext context, TextLayout textLayout) {
    return ValueListenableBuilder<List<UserSelection>>(
      valueListenable: widget.userSelections,
      builder: (context, value, child) {
        buildsLog.info(
            "SuperTextWithSelection ($hashCode) user selection changed, building new selection highlights: ${widget.userSelections.value.isNotEmpty ? widget.userSelections.value.first.selection : "null"}");

        return Stack(
          children: [
            for (final userSelection in value)
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
    return ValueListenableBuilder<List<UserSelection>>(
      valueListenable: widget.userSelections,
      builder: (context, value, child) {
        buildsLog.info(
            "SuperTextWithSelection ($hashCode) user selection changed, building carets: ${widget.userSelections.value.isNotEmpty ? widget.userSelections.value.first.selection : "null"}");

        return Stack(
          children: [
            for (final userSelection in value)
              if (userSelection.hasCaret)
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: userSelection.caretStyle,
                  blinkCaret: userSelection.blinkCaret,
                  position: userSelection.selection.extent,
                  caretTracker: userSelection.caretFollower,
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
    required this.selection,
    this.highlightStyle = const SelectionHighlightStyle(),
    this.highlightWhenEmpty = false,
    this.highlightBoundsFollower,
    this.caretStyle = const CaretStyle(),
    this.blinkCaret = true,
    this.hasCaret = true,
    this.caretFollower,
  });

  /// The logical text selection boundaries.
  ///
  /// User selection of an empty text block should pass
  /// `TextSelection.collapsed(offset: 0)`.
  final TextSelection selection;

  /// Visual style used to paint a highlight for an expanded [selection].
  final SelectionHighlightStyle highlightStyle;

  /// Whether to paint a small selection highlight for an empty text block.
  ///
  /// For example, the user selects multiple blocks of text and some of those
  /// blocks are empty. If [highlightWhenEmpty] is `true`, those empty text
  /// blocks will paint a small selection highlight.
  final bool highlightWhenEmpty;

  /// [LayerLink] that connects to an invisible rectangle that surrounds
  /// the selection highlight, which is useful for positioning something
  /// like a toolbar near the user's selection.
  final LayerLink? highlightBoundsFollower;

  /// Visual style used to paint a caret at the [selection] extent.
  final CaretStyle caretStyle;

  /// Whether the caret should blink.
  final bool blinkCaret;

  /// Whether this selection includes the user's caret.
  ///
  /// Typically, there is only one caret per user within an entire
  /// document. At the same time, many different blocks of text may
  /// have selection highlights.
  final bool hasCaret;

  /// [LayerLink] that connects to an invisible rectangle that surrounds
  /// the user's caret, if the caret is displayed.
  ///
  /// Following the caret is useful when displaying something like a user
  /// name next to a caret, or a magnifier above the caret.
  final LayerLink? caretFollower;

  UserSelection copyWith({
    TextSelection? selection,
    SelectionHighlightStyle? highlightStyle,
    bool? highlightWhenEmpty,
    LayerLink? highlightBoundsFollower,
    CaretStyle? caretStyle,
    bool? blinkCaret,
    bool? hasCaret,
    LayerLink? caretFollower,
  }) {
    return UserSelection(
      selection: selection ?? this.selection,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      highlightWhenEmpty: highlightWhenEmpty ?? this.highlightWhenEmpty,
      highlightBoundsFollower: highlightBoundsFollower ?? this.highlightBoundsFollower,
      caretStyle: caretStyle ?? this.caretStyle,
      blinkCaret: blinkCaret ?? this.blinkCaret,
      hasCaret: hasCaret ?? this.hasCaret,
      caretFollower: caretFollower ?? this.caretFollower,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSelection &&
          runtimeType == other.runtimeType &&
          selection == other.selection &&
          highlightStyle == other.highlightStyle &&
          highlightWhenEmpty == other.highlightWhenEmpty &&
          highlightBoundsFollower == other.highlightBoundsFollower &&
          caretStyle == other.caretStyle &&
          blinkCaret == other.blinkCaret &&
          hasCaret == other.hasCaret &&
          caretFollower == other.caretFollower;

  @override
  int get hashCode =>
      selection.hashCode ^
      highlightStyle.hashCode ^
      highlightWhenEmpty.hashCode ^
      highlightBoundsFollower.hashCode ^
      caretStyle.hashCode ^
      blinkCaret.hashCode ^
      hasCaret.hashCode ^
      caretFollower.hashCode;
}
