import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '../../core/document_composer.dart';
import '../../core/document_selection.dart';
import '../../core/editor.dart';
import '../text.dart';

// USER TAGGING FEATURE:
// A user can be tagged when typing a pattern that begins with "@".
//
// The feature works as follows.
//
//
// TRIGGERS - how to start tagging
//
// "some stuff |" -> "some stuff @|"
//
// "some | stuff" -> "some @| stuff"
//
//
// NO TRIGGER - things that don't start tagging
//
// "some stuff|" -> "some stuff@|"
//
// "some st|uff" -> "some st@|uff"
//
//
// VISUAL INDICATORS
//
// While user is typing token:
//  * is blue as long as token has match candidate, e.g. "M" has "Matt" and "Mike"
//  * is regular text color if no match candidates, e.g., "Mar" doesn't match "Matt" or "Mike"
//
// Blue when user finishes typing the token and it fully matches a candidate
//
// Red when a tag is "committed", i.e., the caret moves anywhere else.
//
//
// REMOVE TAG - when a composing tag loses its tag attribution
//
// "@|matt" -> "matt"
//
// "@matt|" -> "@mat|"
//
// "@ma|tt" -> "@mtt"
//
//
// COMPOSING to SUBMITTED/CANCELLED - when a tag goes from composing to stable
//
// "@ma|" -> "@mat|" - still composing
//
// "@mt|" -> "@m|t" -> "@ma|t" - still composing
//
// "@matt|" -> "@matt |" - submitted
//
// "@|matt" -> "|@matt" - submitted
//
// "@ma|tt" -> "@matt" (selection moved or nullified) - submitted
//
// Code deletes the attribution

/// An [EditReaction] that creates, updates, and removes composing user tags, and commits those
/// composing tags to stable user tags.
class TagUserReaction implements EditReaction {
  // FIXME: the changeList will be wrong if there's more than one reaction.
  //        The 2nd reaction to run won't be given the changes caused by the
  //        first reaction. This would likely lead to corrupt attempts to access
  //        and alter the document.

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    editorUserTagsLog.info("Reacting to possible user tagging");
    editorUserTagsLog.info("Incoming change list:");
    editorUserTagsLog.info(changeList.map((event) => event.runtimeType).toList());
    editorUserTagsLog.info(
        "Caret position: ${editContext.find<MutableDocumentComposer>(Editor.composerKey).selection?.extent.nodePosition}");

    _removeInvalidTags(editContext, requestDispatcher, changeList);

    _findAndCreateNewTags(editContext, requestDispatcher, changeList);

    // Run tag commits after updating tags, above, so that we don't commit an in-progress
    // tag when a new character is added to the end of the tag.
    _commitCompletedTags(editContext, requestDispatcher, changeList);
  }

  /// Find any composing tag that's no longer being composed, and commit it.
  void _commitCompletedTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorUserTagsLog.fine("Looking for completed tags to commit.");
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composingTagNodeCandidates = <String>{};
    for (final edit in changeList) {
      if (edit is DocumentEdit && (edit.change is TextInsertionEvent || edit.change is TextDeletedEvent)) {
        composingTagNodeCandidates.add((edit.change as NodeChangeEvent).nodeId);
      } else if (edit is SelectionChangeEvent) {
        final oldSelection = edit.oldSelection;
        if (oldSelection == null) {
          continue;
        }

        if (oldSelection.base.nodePosition is TextNodePosition) {
          // The old selection might belong to a node that was removed. Make sure
          // the old node exists. If it does, add the node ID as a candidate.
          final nodeId = oldSelection.base.nodeId;
          if (document.getNodeById(nodeId) != null) {
            composingTagNodeCandidates.add(nodeId);
          }
        }
        if (oldSelection.extent.nodePosition is TextNodePosition) {
          // The old selection might belong to a node that was removed. Make sure
          // the old node exists. If it does, add the node ID as a candidate.
          final nodeId = oldSelection.extent.nodeId;
          if (document.getNodeById(nodeId) != null) {
            composingTagNodeCandidates.add(nodeId);
          }
        }
      } else if (edit is DocumentEdit && edit.change is NodeRemovedEvent) {
        // Make sure we don't try to track a node where text was edited, if that
        // node was later removed.
        final change = (edit).change as NodeRemovedEvent;
        composingTagNodeCandidates.remove(change.nodeId);
      }
    }
    if (composingTagNodeCandidates.isEmpty) {
      return;
    }

    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    final selection = composer.selection;
    for (final textNodeId in composingTagNodeCandidates) {
      editorUserTagsLog.fine("Checking node $textNodeId for composing tags to commit");
      final textNode = document.getNodeById(textNodeId) as TextNode;
      final composingTags = _findAllComposingTagsInTextNode(textNode);
      editorUserTagsLog.fine("Composing tags in node: $composingTags");

      for (final composingTag in composingTags) {
        if (selection == null || selection.extent.nodeId != textNodeId || selection.base.nodeId != textNodeId) {
          editorUserTagsLog
              .info("Committing tag because selection is null, or selection moved to different node: '$composingTag'");
          _commitTag(requestDispatcher, textNode, composingTag);
          continue;
        }

        final extentPosition = selection.extent.nodePosition as TextNodePosition;
        if (selection.isCollapsed &&
            (extentPosition.offset <= composingTag.startOffset || extentPosition.offset > composingTag.endOffset)) {
          editorUserTagsLog
              .info("Committing tag because the caret is out of range: '$composingTag', extent: $extentPosition");
          _commitTag(requestDispatcher, textNode, composingTag);
          continue;
        }

        editorUserTagsLog.fine("Allowing tag '$composingTag' to continue composing without committing it.");
      }
    }
  }

  Set<_Token> _findAllComposingTagsInTextNode(TextNode textNode) {
    return textNode.text
        // Find all the composing tag attributions.
        .getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == userTagComposingAttribution,
          range: SpanRange(start: 0, end: textNode.text.text.length - 1),
        )
        // Convert the attributions into _Token's
        .map(
          (attributionSpan) => _Token(
            textNode.text.text.substring(attributionSpan.start, attributionSpan.end + 1),
            attributionSpan.start,
            attributionSpan.end + 1,
          ),
        )
        .toSet();
  }

  void _commitTag(RequestDispatcher requestDispatcher, TextNode textNode, _Token tag) {
    // TODO: batch all these requests into one transaction
    final tagSelection = DocumentSelection(
      base: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextNodePosition(offset: tag.startOffset),
      ),
      extent: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextNodePosition(offset: tag.endOffset),
      ),
    );

    // Remove composing tag attribution.
    requestDispatcher.execute([
      RemoveTextAttributionsRequest(
        documentSelection: tagSelection,
        attributions: {userTagComposingAttribution},
      )
    ]);

    // Add stable tag attribution.
    requestDispatcher.execute([
      AddTextAttributionsRequest(
        documentSelection: tagSelection,
        attributions: {
          UserTagAttribution(textNode.text.text.substring(
            tag.startOffset + 1, // +1 to remove the "@" from the value
            tag.endOffset,
          ))
        },
      )
    ]);
  }

  /// Find any text near the caret that fits the pattern of a user tag and convert it into a
  /// composing tag.
  void _findAndCreateNewTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorUserTagsLog.fine("Looking for a tag around the caret.");
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null || !composer.selection!.isCollapsed) {
      // We only tag when the selection is collapsed. Our selection is null or expanded. Return.
      return;
    }
    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    // TODO: we handle adding a tag attribution, but what about identifying the situation
    //       where we need to remove one?
    final tokenAroundCaret = _findUntaggedTokenAroundCaret(
      selectedNode.text,
      caretPosition,
      (tokenAttributions) =>
          !tokenAttributions.contains(userTagComposingAttribution) &&
          !tokenAttributions.any((attribution) => attribution is UserTagAttribution),
    );
    if (tokenAroundCaret == null) {
      // There's no tag around the caret.
      editorUserTagsLog.fine("There's no tag around the caret, fizzling");
      return;
    }
    if (!tokenAroundCaret.token.value.startsWith("@")) {
      // Tags must start with an "@" but the preceding word doesn't. Return.
      editorUserTagsLog.fine("Token doesn't start with @, fizzling");
      return;
    }

    // TODO: check candidates for partial match

    editorImeLog.fine("Found a user token around caret: ${tokenAroundCaret.token.value}");

    requestDispatcher.execute([
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.endOffset),
          ),
        ),
        attributions: {
          userTagComposingAttribution,
        },
      ),
    ]);
  }

  /// Find any text that was previously attributed as a composing tag, which no longer meets
  /// the pattern for a user tag, and remove the tag attribution.
  void _removeInvalidTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorUserTagsLog.fine("Removing invalid tags.");
    final nodesToInspect = <String>{};
    for (final edit in changeList) {
      // We only care about deleted text, in case the deletion made an existing tag invalid.
      if (edit is! DocumentEdit) {
        continue;
      }
      final change = edit.change;
      if (change is! TextDeletedEvent) {
        continue;
      }

      // We only care about deleted text when the deleted text contains at least one tag.
      final tagsInDeletedText = change.deletedText.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution == userTagComposingAttribution,
        range: SpanRange(start: 0, end: change.deletedText.text.length),
      );
      if (tagsInDeletedText.isEmpty) {
        continue;
      }

      nodesToInspect.add(change.nodeId);
    }
    editorUserTagsLog.fine("Found ${nodesToInspect.length} impacted nodes with tags that might be invalid");

    // Inspect every TextNode where a text deletion impacted a tag. If a tag no longer contains
    // an "@", remove the attribution.
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final removeTagRequests = <EditRequest>{};
    for (final nodeId in nodesToInspect) {
      final textNode = document.getNodeById(nodeId) as TextNode;
      final allTags = textNode.text.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution == userTagComposingAttribution,
        range: SpanRange(start: 0, end: textNode.text.text.length - 1),
      );

      for (final tag in allTags) {
        final tagText = textNode.text.text.substring(tag.start, tag.end + 1);
        if (!tagText.startsWith("@")) {
          editorUserTagsLog.info("Removing tag with value: '$tagText'");
          removeTagRequests.add(
            RemoveTextAttributionsRequest(
              documentSelection: DocumentSelection(
                base: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.start),
                ),
                extent: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.end + 1),
                ),
              ),
              attributions: {userTagComposingAttribution},
            ),
          );
        }
      }
    }

    // Run all the tag attribution removal requests that we queue'd up.
    for (final request in removeTagRequests) {
      requestDispatcher.execute([request]);
    }
  }
}

/// An [EditReaction] that creates, updates, and removes hash tags.
class HashTagReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    editorHashTagsLog.info("Reacting to possible hash tagging");
    editorHashTagsLog.info("Incoming change list:");
    editorHashTagsLog.info(changeList.map((event) => event.runtimeType).toList());
    editorHashTagsLog.info(
        "Caret position: ${editContext.find<MutableDocumentComposer>(Editor.composerKey).selection?.extent.nodePosition}");

    _splitBackToBackTags(editContext, requestDispatcher, changeList);

    _removeInvalidTags(editContext, requestDispatcher, changeList);

    _findAndCreateNewTags(editContext, requestDispatcher, changeList);
  }

  void _splitBackToBackTags(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    // TODO: split attributions around #john#sally
  }

  /// Find any text near the caret that fits the pattern of a user tag and convert it into a
  /// composing tag.
  void _findAndCreateNewTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorHashTagsLog.fine("Looking for a tag around the caret.");
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null || !composer.selection!.isCollapsed) {
      // We only tag when the selection is collapsed. Our selection is null or expanded. Return.
      return;
    }
    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    // TODO: we handle adding a tag attribution, but what about identifying the situation
    //       where we need to remove one?
    final tokenAroundCaret = _findUntaggedTokenAroundCaret(
      selectedNode.text,
      caretPosition,
      (tokenAttributions) => !tokenAttributions.any((attribution) => attribution is HashTagAttribution),
    );
    if (tokenAroundCaret == null) {
      // There's no tag around the caret.
      editorHashTagsLog.fine("There's no tag around the caret, fizzling");
      return;
    }
    if (!tokenAroundCaret.token.value.startsWith("#")) {
      // Tags must start with an "#" but the preceding word doesn't. Return.
      editorHashTagsLog.fine("Token doesn't start with #, fizzling");
      return;
    }

    editorHashTagsLog.fine(
        "Found a hash tag around caret: '${tokenAroundCaret.token.value}' - surrounding it with an attribution: ${tokenAroundCaret.token.startOffset} -> ${tokenAroundCaret.token.endOffset}");

    editorHashTagsLog.fine("Existing hash tags attributions near caret: ${selectedNode.text.getAllAttributionsAt(0)}");

    editorHashTagsLog.fine("All attribution markers in test: ${selectedNode.text.spans.markers}");

    requestDispatcher.execute([
      // Remove the old hash tag attribution(s).
      RemoveTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.endOffset),
          ),
        ),
        attributions: {
          ...selectedNode.text.getAllAttributionsAt(tokenAroundCaret.token.startOffset).whereType<HashTagAttribution>(),
        },
      ),
      // Add the new/updated hash tag attribution.
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.endOffset),
          ),
        ),
        attributions: {
          const HashTagAttribution(),
        },
      ),
    ]);
  }

  /// Find any text that was previously attributed as a composing tag, which no longer meets
  /// the pattern for a user tag, and remove the tag attribution.
  void _removeInvalidTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorHashTagsLog.fine("Removing invalid tags.");
    final nodesToInspect = <String>{};
    for (final edit in changeList) {
      // We only care about deleted text, in case the deletion made an existing tag invalid.
      if (edit is! DocumentEdit) {
        continue;
      }
      final change = edit.change;
      if (change is! TextDeletedEvent) {
        continue;
      }

      // We only care about deleted text when the deleted text contains at least one tag.
      final tagsInDeletedText = change.deletedText.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution is HashTagAttribution,
        range: SpanRange(start: 0, end: change.deletedText.text.length),
      );
      if (tagsInDeletedText.isEmpty) {
        continue;
      }

      nodesToInspect.add(change.nodeId);
    }
    editorHashTagsLog.fine("Found ${nodesToInspect.length} impacted nodes with tags that might be invalid");

    // Inspect every TextNode where a text deletion impacted a tag. If a tag no longer contains
    // a "#", remove the attribution.
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final removeTagRequests = <EditRequest>{};
    for (final nodeId in nodesToInspect) {
      final textNode = document.getNodeById(nodeId) as TextNode;
      final allTags = textNode.text.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution is HashTagAttribution,
        range: SpanRange(start: 0, end: textNode.text.text.length - 1),
      );

      for (final tag in allTags) {
        final tagText = textNode.text.text.substring(tag.start, tag.end + 1);
        if (!tagText.startsWith("#")) {
          editorHashTagsLog.info("Removing tag with value: '$tagText'");
          removeTagRequests.add(
            RemoveTextAttributionsRequest(
              documentSelection: DocumentSelection(
                base: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.start),
                ),
                extent: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.end + 1),
                ),
              ),
              attributions: {const HashTagAttribution()},
            ),
          );
        }
      }
    }

    // Run all the tag attribution removal requests that we queue'd up.
    for (final request in removeTagRequests) {
      requestDispatcher.execute([request]);
    }
  }
}

/// An [EditReaction] that prevents partial selection of a stable user tag.
class KeepCaretOutOfTagReaction implements EditReaction {
  const KeepCaretOutOfTagReaction();

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    editorUserTagsLog.info("KeepCaretOutOfTagReaction - react()");
    if (changeList.length > 1 || changeList.first is! SelectionChangeEvent) {
      // We only want to move the caret when we're confident about what changed. Therefore,
      // we only react to changes that are solely a selection change, i.e., we ignore
      // situations like text entry, text deletion, etc.
      editorUserTagsLog.info(" - change list isn't just a single SelectionChangeEvent: $changeList");
      return;
    }

    editorUserTagsLog.info(" - we received just one selection change event. Checking for user tag.");

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectionChangeEvent = changeList.first as SelectionChangeEvent;

    final newCaret = selectionChangeEvent.newSelection?.extent;
    if (newCaret == null) {
      return;
    }

    final textNode = document.getNodeById(newCaret.nodeId);
    if (textNode == null || textNode is! TextNode) {
      // The selected content isn't text. We don't need to worry about it.
      return;
    }

    final tagAroundCaret = _findTagAroundCaret(
      textNode.text,
      newCaret.nodePosition as TextNodePosition,
      (attribution) => attribution is UserTagAttribution,
    );
    if (tagAroundCaret == null) {
      // The caret isn't in a tag. We don't need to adjust anything.
      return;
    }
    editorUserTagsLog.info("Found tag around caret - $tagAroundCaret");

    // The new caret position sits inside of a tag. We need to move it outside the tag.
    switch (selectionChangeEvent.changeType) {
      case SelectionChangeType.insertContent:
        // It's not obvious how this would happen when inserting content. We'll play it
        // safe and do nothing in this case.
        return;
      case SelectionChangeType.clearSelection:
        // We already checked for a null selection. This should never happen.
        return;
      case SelectionChangeType.place:
      case SelectionChangeType.collapseSelection:
      case SelectionChangeType.deleteContent:
        // Move the caret to the nearest edge of the tag.
        _moveCaretToNearestTagEdge(requestDispatcher, selectionChangeEvent, textNode.id, tagAroundCaret);
        break;
      case SelectionChangeType.pushCaret:
        // Move the caret to the side of the tag in the direction of push motion.
        _pushCaretToNearestTagEdge(editContext, requestDispatcher, selectionChangeEvent, textNode.id, tagAroundCaret);
        break;
      case SelectionChangeType.expandSelection:
        // Move the base or extent to the side of the tag in the direction of push motion.
        _pushExpandedSelectionAroundTag(editContext, requestDispatcher, selectionChangeEvent, textNode);
        break;
    }
  }

  _TokenAroundCaret? _findTagAroundCaret(
      AttributedText paragraphText, TextNodePosition caretPosition, bool Function(Attribution) attributionSelector) {
    final wordAroundCaret = _findAttributedTokenAroundCaret(
      paragraphText,
      caretPosition,
      (tokenAttributions) => tokenAttributions.any(attributionSelector),
      // (tokenAttributions) => tokenAttributions.any((attribution) => attribution is UserTagAttribution),
    );
    if (wordAroundCaret == null) {
      return null;
    }
    if (wordAroundCaret.caretOffsetInToken == 0 ||
        wordAroundCaret.caretOffsetInToken == wordAroundCaret.token.value.length) {
      // The token is either on the starting edge, e.g., "|@tag", or at the ending edge,
      // e.g., "@tag|". We don't care about those scenarios when looking for the caret
      // inside of the token.
      return null;
    }

    final tokenAttributions = paragraphText.getAllAttributionsThroughout(
      SpanRange(
        start: wordAroundCaret.token.startOffset,
        end: wordAroundCaret.token.endOffset - 1,
      ),
    );
    if (tokenAttributions.any((attribution) => attribution is UserTagAttribution)) {
      // This token is a user tag. Return it.
      return wordAroundCaret;
    }

    return null;
  }

  void _moveCaretToNearestTagEdge(
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent,
    String textNodeId,
    _TokenAroundCaret tagAroundCaret,
  ) {
    DocumentSelection? newSelection;
    editorUserTagsLog.info("oldCaret is null. Pushing caret to end of tag.");
    // The caret was placed directly in the token without a previous selection. This might
    // be a user tap, or programmatic placement. Move the caret to the nearest edge of the
    // token.
    if ((tagAroundCaret.caretOffset - tagAroundCaret.token.startOffset).abs() <
        (tagAroundCaret.caretOffset - tagAroundCaret.token.endOffset).abs()) {
      // Move the caret to the start of the tag.
      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: textNodeId,
          nodePosition: TextNodePosition(offset: tagAroundCaret.token.startOffset),
        ),
      );
    } else {
      // Move the caret to the end of the tag.
      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: textNodeId,
          nodePosition: TextNodePosition(offset: tagAroundCaret.token.endOffset),
        ),
      );
    }

    requestDispatcher.execute([
      ChangeSelectionRequest(
        newSelection,
        newSelection.isCollapsed ? SelectionChangeType.pushCaret : SelectionChangeType.expandSelection,
        SelectionReason.contentChange,
      ),
    ]);
  }

  void _pushCaretToNearestTagEdge(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent,
    String textNodeId,
    _TokenAroundCaret tagAroundCaret,
  ) {
    editorUserTagsLog.info("Pushing caret to other side of token - tag around caret: $tagAroundCaret");
    final Document document = editContext.find<MutableDocument>(Editor.documentKey);

    final pushDirection = document.getAffinityBetween(
      base: selectionChangeEvent.oldSelection!.extent,
      extent: selectionChangeEvent.newSelection!.extent,
    );

    late int textOffset;
    switch (pushDirection) {
      case TextAffinity.upstream:
        // Move to starting edge.
        textOffset = tagAroundCaret.token.startOffset;
        break;
      case TextAffinity.downstream:
        // Move to ending edge.
        textOffset = tagAroundCaret.token.endOffset;
        break;
    }

    requestDispatcher.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: selectionChangeEvent.newSelection!.extent.nodeId,
            nodePosition: TextNodePosition(
              offset: textOffset,
            ),
          ),
        ),
        SelectionChangeType.pushCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }

  void _pushExpandedSelectionAroundTag(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent,
    TextNode textNode,
  ) {
    final previousBase = selectionChangeEvent.oldSelection!.base.nodePosition as TextNodePosition;
    final newBase = selectionChangeEvent.newSelection!.base.nodePosition as TextNodePosition;

    final previousExtent = selectionChangeEvent.oldSelection!.extent.nodePosition as TextNodePosition;
    final newExtent = selectionChangeEvent.newSelection!.extent.nodePosition as TextNodePosition;

    int baseOffset = newBase.offset;
    if (previousBase.offset != newBase.offset) {
      // The base of the selection moved.
      final tagAroundBase = _findTagAroundCaret(
        textNode.text,
        newBase,
        (attribution) => attribution is UserTagAttribution,
      );
      if (tagAroundBase != null &&
          tagAroundBase.caretOffsetInToken > 0 &&
          tagAroundBase.caretOffsetInToken < tagAroundBase.token.value.length) {
        if (newBase.offset - previousBase.offset < 0) {
          // The base moved upstream. Push it to the beginning side of the token.
          baseOffset = tagAroundBase.token.startOffset;
        } else {
          // The base moved downstream. Push it to the ending side of the token.
          baseOffset = tagAroundBase.token.endOffset;
        }
      }
    }

    int extentOffset = newExtent.offset;
    if (previousExtent.offset != newExtent.offset) {
      // The extent of the selection moved.
      final tagAroundExtent = _findTagAroundCaret(
        textNode.text,
        newExtent,
        (attribution) => attribution is UserTagAttribution,
      );
      if (tagAroundExtent != null &&
          tagAroundExtent.caretOffsetInToken > 0 &&
          tagAroundExtent.caretOffsetInToken < tagAroundExtent.token.value.length) {
        if (newExtent.offset - previousExtent.offset < 0) {
          // The extent moved upstream. Push it to the beginning side of the token.
          extentOffset = tagAroundExtent.token.startOffset;
        } else {
          // The extent moved downstream. Push it to the ending side of the token.
          extentOffset = tagAroundExtent.token.endOffset;
        }
      }
    }

    requestDispatcher.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(
              offset: baseOffset,
            ),
          ),
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(
              offset: extentOffset,
            ),
          ),
        ),
        SelectionChangeType.pushCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

class UserTagDelegate implements TagDelegate {
  @override
  String get symbol => "@";

  @override
  Attribution createComposingTag(String symbol, String token) {
    return userTagComposingAttribution;
  }

  @override
  Attribution? commitTag(String symbol, String token) {
    return UserTagAttribution(token);
  }
}

abstract class TagDelegate {
  /// The symbol that initiates a new tag, e.g., "@" for users, "#" for hash tags.
  String get symbol;

  /// Creates and returns an [Attribution] that should be applied to the given
  /// [token], which was initiated with the given [symbol].
  ///
  /// This method is called for every text entry change to a given token.
  ///
  /// For example:
  ///
  ///     @|
  ///     @m|
  ///     @ma|
  ///     @mat|
  ///     @matt|
  ///     @mat|
  ///     @ma|
  ///
  Attribution createComposingTag(String symbol, String token);

  /// Creates and returns an [Attribution] that should be applied to a completed
  /// tag with the given [token], which was initiated with the given [symbol]..
  ///
  /// Returns `null` if the given [token] shouldn't be represented as a tag, such
  /// as a user tag for a user that doesn't exist.
  Attribution? commitTag(String symbol, String token);
}

/// Finds the word that surrounds the [caretPosition] in the [paragraphText], or `null`
/// if the surrounding word is already tagged, or the caret isn't currently sitting in a word.
_TokenAroundCaret? _findUntaggedTokenAroundCaret(
  AttributedText paragraphText,
  TextNodePosition caretPosition,
  bool Function(Set<Attribution>) tagFilter,
) {
  return _findAttributedTokenAroundCaret(
    paragraphText,
    caretPosition,
    tagFilter,
  );
}

_TokenAroundCaret? _findAttributedTokenAroundCaret(
  AttributedText paragraphText,
  TextNodePosition caretPosition,
  bool Function(Set<Attribution> tokenAttributions) isTokenCandidate,
) {
  final text = paragraphText.text;
  int tokenStartOffset = caretPosition.offset;
  int tokenEndOffset = caretPosition.offset;
  // TODO: use characters package to move forward and backward
  while (tokenStartOffset > 0 && text[tokenStartOffset - 1] != " ") {
    tokenStartOffset -= 1;
  }
  while (tokenEndOffset < text.length && text[tokenEndOffset] != " ") {
    tokenEndOffset += 1;
  }

  final tokenRange = SpanRange(start: tokenStartOffset, end: tokenEndOffset - 1);
  final tokenAttributions = paragraphText.getAllAttributionsThroughout(tokenRange);
  if (!isTokenCandidate(tokenAttributions)) {
    return null;
  }

  final token = text.substring(tokenStartOffset, tokenEndOffset);
  editorUserTagsLog.fine("Token around caret: '$token'");
  editorHashTagsLog.fine("Token around caret: '$token'");

  return _TokenAroundCaret(
    token: _Token(
      token,
      tokenStartOffset,
      tokenEndOffset,
    ),
    caretOffset: caretPosition.offset,
  );
}

/// A [_Token], along with the current caret offset, which is expected to fall
/// somewhere within the bounds of the [_Token].
///
/// This data structure is useful for inspecting active typing into a token.
class _TokenAroundCaret {
  const _TokenAroundCaret({
    required this.token,
    required this.caretOffset,
  });

  final _Token token;

  final int caretOffset;

  int get caretOffsetInToken => caretOffset - token.startOffset;

  @override
  String toString() =>
      "[_TokenAroundCaret] - token: '${token.value}', start: ${token.startOffset}, end: ${token.endOffset}, caret offset in token: $caretOffsetInToken";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TokenAroundCaret &&
          runtimeType == other.runtimeType &&
          token.value == other.token.value &&
          caretOffsetInToken == other.caretOffsetInToken;

  @override
  int get hashCode => token.value.hashCode ^ caretOffsetInToken.hashCode;
}

/// A text [value], along with its text offsets within some [TextNode].
class _Token {
  const _Token(this.value, this.startOffset, this.endOffset);

  final String value;

  final int startOffset;

  // The final index, plus 1, to match normal String semantics, rather than matching AttributionSpan semantics.
  final int endOffset;

  @override
  String toString() => "[_Token] - '$value', $startOffset -> $endOffset";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Token &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset;

  @override
  int get hashCode => value.hashCode ^ startOffset.hashCode ^ endOffset.hashCode;
}

/// An attribution for a user tag that's currently being composed.
const userTagComposingAttribution = NamedAttribution("user-tag-composing");

/// An attribution for a stable user tag, i.e., a user tag that's done being composed and
/// shouldn't be partially selectable or editable.
class UserTagAttribution implements Attribution {
  const UserTagAttribution(this.userId);

  @override
  String get id => userId;

  final String userId;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserTagAttribution && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return '[UserTagAttribution]: $userId';
  }
}

/// An attribution for a hash tag..
class HashTagAttribution extends NamedAttribution {
  const HashTagAttribution() : super("hashtag");

  @override
  bool canMergeWith(Attribution other) => other is HashTagAttribution;

  @override
  String toString() {
    return '[HashTagAttribution]';
  }
}