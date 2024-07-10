import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// [EditReaction] that synchronizes the active composer styles with the caret's
/// position, when the caret moves in relevant ways.
///
/// When the user places the caret at a new position in a document, the caret might
/// sit immediately before or after some text with existing styles, e.g., bold,
/// italics, underline. Based on the situation, the user expects these styles to
/// be automatically applied to newly typed text. This reaction identifies these
/// situations and activates the desired styles in the [DocumentComposer].
///
/// Only the given `stylesToExtend` are automatically activated.
///
/// Styles are activated when placing the caret at the beginning of a paragraph,
/// and the first character has a style:
///
///     **Hello, world**
///     |**Hello, world**
///     **F|Hello, world**
///
/// Styles are activated when placing the caret immediately after a style:
///
///     **Hello**, world
///     **Hello**|, world
///     **HelloF**|, world
///
/// The selection can change for many reasons. This reaction only activates
/// styles when it believes that the user explicitly moved the caret.
/// Conversely, if the caret moves due to the user typing a character, or
/// if the selection is expanded, then this reaction doesn't activate any
/// styles.
class UpdateComposerTextStylesReaction extends EditReaction {
  UpdateComposerTextStylesReaction({
    Set<Attribution>? stylesToExtend,
  }) : _stylesToExtend = stylesToExtend ?? defaultExtendableStyles;

  final Set<Attribution> _stylesToExtend;

  DocumentPosition? _previousSelectionExtent;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final lastSelectionChange =
        changeList.lastWhereOrNull((element) => element is SelectionChangeEvent) as SelectionChangeEvent?;
    if (lastSelectionChange == null) {
      // The selection didn't change in this transaction.
      return;
    }

    switch (lastSelectionChange.changeType) {
      case SelectionChangeType.placeCaret:
      case SelectionChangeType.pushCaret:
      case SelectionChangeType.collapseSelection:
      case SelectionChangeType.deleteContent:
        _updateComposerStylesAtCaret(editContext);
      default:
      // We don't want change the composer styles for the other types of selection changes.
    }

    // Update our internal accounting.
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    _previousSelectionExtent = composer.selection?.extent;
  }

  void _updateComposerStylesAtCaret(EditContext editContext) {
    final document = editContext.document;
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);

    if (composer.selection?.extent == _previousSelectionExtent) {
      return;
    }

    final selectionExtent = composer.selection?.extent;
    if (selectionExtent != null &&
        selectionExtent.nodePosition is TextNodePosition &&
        _previousSelectionExtent != null &&
        _previousSelectionExtent!.nodePosition is TextNodePosition) {
      // The current and previous selections are text positions. Check for the situation where the two
      // selections are functionally equivalent, but the affinity changed.
      final selectedNodePosition = selectionExtent.nodePosition as TextNodePosition;
      final previousSelectedNodePosition = _previousSelectionExtent!.nodePosition as TextNodePosition;

      if (selectionExtent.nodeId == _previousSelectionExtent!.nodeId &&
          selectedNodePosition.offset == previousSelectedNodePosition.offset) {
        // The text selection changed, but only the affinity is different. An affinity change doesn't alter
        // the selection from the user's perspective, so don't alter any preferences. Return.
        return;
      }
    }

    _previousSelectionExtent = composer.selection?.extent;

    composer.preferences.clearStyles();

    if (composer.selection == null || !composer.selection!.isCollapsed) {
      return;
    }

    final node = document.getNodeById(composer.selection!.extent.nodeId);
    if (node is! TextNode) {
      return;
    }

    final textPosition = composer.selection!.extent.nodePosition as TextPosition;

    if (textPosition.offset == 0 && node.text.text.isEmpty) {
      return;
    }

    late int offsetWithAttributionsToExtend;
    if (textPosition.offset == 0) {
      // The inserted text is at the very beginning of the text blob. Therefore, we should apply the
      // same attributions to the inserted text, as the text that immediately follows the inserted text.
      offsetWithAttributionsToExtend = textPosition.offset + 1;
    } else {
      // The inserted text is NOT at the very beginning of the text blob. Therefore, we should apply the
      // same attributions to the inserted text, as the text that immediately precedes the inserted text.
      offsetWithAttributionsToExtend = textPosition.offset - 1;
    }

    Set<Attribution> allAttributions = node.text.getAllAttributionsAt(offsetWithAttributionsToExtend);

    // Add desired expandable styles.
    final newStyles = allAttributions.where((attribution) => _stylesToExtend.contains(attribution)).toSet();

    // TODO: we shouldn't have such specific behavior in here. Figure out how to generalize this.
    // Add a link attribution only if the selection sits at the middle of the link.
    // As we are dealing with a collapsed selection, we shouldn't have more than one link.
    final linkAttribution = allAttributions.firstWhereOrNull((attribution) => attribution is LinkAttribution);
    if (linkAttribution != null) {
      final range = node.text.getAttributedRange({linkAttribution}, offsetWithAttributionsToExtend);

      if (textPosition.offset > 0 &&
          offsetWithAttributionsToExtend >= range.start &&
          offsetWithAttributionsToExtend < range.end) {
        newStyles.add(linkAttribution);
      }
    }

    composer.preferences.addStyles(newStyles);
  }
}

final defaultExtendableStyles = Set.unmodifiable({
  boldAttribution,
  italicsAttribution,
  underlineAttribution,
  strikethroughAttribution,
});
