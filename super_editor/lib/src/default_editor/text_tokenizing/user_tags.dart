import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '../../core/document_composer.dart';
import '../../core/document_selection.dart';
import '../../core/editor.dart';
import '../text.dart';
import 'tag_tokenizer.dart';

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

class UserTagPlugin {
  UserTagPlugin() {
    _tagUserReaction = TagUserReaction(
      onUpdateComposingUserTag: _onComposingUserTagFound,
    );
  }

  ValueListenable<ComposingUserTag?> get composingUserTag => _composingUserTag;
  final _composingUserTag = ValueNotifier<ComposingUserTag?>(null);

  void _onComposingUserTagFound(ComposingUserTag? tag) {
    print("_onComposingUserTagFound: ${tag?.token}");
    _composingUserTag.value = tag;
  }

  List<EditRequestHandler> get requestHandlers => [
        (request) => request is FillInComposingUserTagRequest
            ? FillInComposingUserTagCommand(request.userTag, trigger: request.trigger)
            : null,
      ];

  List<EditReaction> get reactions => [_tagUserReaction, _moveSelectionAroundUserTagReaction];
  late final TagUserReaction _tagUserReaction;
  final _moveSelectionAroundUserTagReaction = const AdjustSelectionAroundTagReaction();
}

/// An [EditRequest] that replaces a composing user tag with the given [userTag]
/// and commits it.
///
/// For example, the user types "@da|", and then selects "dash" from a list of
/// matching users. This request replaces "@da|" with "@dash |" and converts the tag
/// from a composing user tag to a committed user tag.
///
/// For this request to have an effect, the user's selection must sit somewhere within
/// the composing user tag.
class FillInComposingUserTagRequest implements EditRequest {
  const FillInComposingUserTagRequest(
    this.userTag, {
    this.trigger = "@",
  });

  final String userTag;
  final String trigger;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FillInComposingUserTagRequest &&
          runtimeType == other.runtimeType &&
          userTag == other.userTag &&
          trigger == other.trigger;

  @override
  int get hashCode => userTag.hashCode ^ trigger.hashCode;
}

class FillInComposingUserTagCommand implements EditCommand {
  const FillInComposingUserTagCommand(
    this.userTag, {
    this.trigger = "@",
  });

  final String userTag;
  final String trigger;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    final selection = composer.selection;
    if (selection == null) {
      // There shouldn't be a composing user tag without a selection. Either way,
      // we can't find the desired composing user tag without a selection position
      // to guide us. Fizzle.
      editorUserTagsLog.warning("Tried to fill in a composing user tag, but there's no user selection.");
      return;
    }

    if (selection.isCollapsed) {
      final caret = selection.extent.nodePosition;
      if (caret is! TextNodePosition) {
        // The caret isn't sitting in a user tag. Fizzle.
        editorUserTagsLog.warning("Tried to fill in a composing user tag, but the user's caret isn't in a text node.");
        return;
      }

      final textNode = document.getNodeById(selection.extent.nodeId) as TextNode;

      final composingToken = TagTokenizer.findAttributedTokenAroundPosition(
        trigger,
        textNode.text,
        caret,
        (tokenAttributions) => tokenAttributions.contains(userTagComposingAttribution),
      );
      if (composingToken == null) {
        // There's no composing token near the caret. Fizzle.
        editorUserTagsLog
            .warning("Tried to fill in a composing user tag, but there's no composing token near the caret.");
        return;
      }

      // TODO:
      print("TODO: Replace the token text");
    } else {
      // TODO:
      print("TODO: Handle expanded selection");
    }
  }
}

/// An [EditReaction] that creates, updates, and removes composing user tags, and commits those
/// composing tags to stable user tags.
class TagUserReaction implements EditReaction {
  const TagUserReaction({
    String trigger = "@",
    this.onUpdateComposingUserTag,
  }) : _trigger = trigger;

  final String _trigger;
  final OnUpdateComposingUserTag? onUpdateComposingUserTag;

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

  /// Find any text that was previously attributed as a composing tag, which no longer meets
  /// the pattern for a user tag, and remove the tag attribution.
  void _removeInvalidTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorUserTagsLog.info("Removing invalid tags.");
    final document = editContext.find<MutableDocument>(Editor.documentKey);
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
      if (document.getNodeById(change.nodeId) == null) {
        // This node was deleted sometime later. No need to consider it.
        continue;
      }

      // We only care about deleted text when the deleted text contains at least one tag.
      final tagsInDeletedText = change.deletedText.getAttributionSpansInRange(
        attributionFilter: (attribution) =>
            attribution == userTagComposingAttribution || attribution is UserTagAttribution,
        range: SpanRange(start: 0, end: change.deletedText.text.length),
      );
      if (tagsInDeletedText.isEmpty) {
        continue;
      }

      nodesToInspect.add(change.nodeId);
    }
    editorUserTagsLog.fine("Found ${nodesToInspect.length} impacted nodes with tags that might be invalid");

    // Inspect every TextNode where a text deletion impacted a tag.
    final removeTagRequests = <EditRequest>{};
    // FIXME: this won't actually work for multiple deletions in the same text node because
    //        one deletion will screw up the indices of the next deletion.
    final deleteTagRequests = <EditRequest>{};
    for (final nodeId in nodesToInspect) {
      final textNode = document.getNodeById(nodeId) as TextNode;

      // If a composing tag no longer contains an "@", remove the attribution.
      final allComposingTags = textNode.text.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution == userTagComposingAttribution,
        range: SpanRange(start: 0, end: textNode.text.text.length - 1),
      );

      for (final tag in allComposingTags) {
        final tagText = textNode.text.text.substring(tag.start, tag.end + 1);

        if (!tagText.startsWith(_trigger)) {
          editorUserTagsLog.info("Removing tag with value: '$tagText'");

          onUpdateComposingUserTag?.call(null);

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

      // If a user tag's content no longer matches its attribution value, then
      // assume that the user tried to delete part of it. Delete the whole thing,
      // because we don't allow partial committed user tags.

      // Collect all the user tags in this node. The list is sorted such that
      // later tags appear before earlier tags. This way, as we delete tags, each
      // deleted tag won't impact the character offsets of the following tags
      // that we delete.
      final allUserTags = textNode.text
          .getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution is UserTagAttribution,
            range: SpanRange(start: 0, end: textNode.text.text.length - 1),
          )
          .sorted((tag1, tag2) => tag2.start - tag1.start);

      // Track the impact of deletions on selection bounds, then update the selection
      // to reflect the deletions.
      final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);

      final baseBeforeDeletions = composer.selection!.base;
      int baseOffsetAfterDeletions = baseBeforeDeletions.nodePosition is TextNodePosition
          ? (baseBeforeDeletions.nodePosition as TextNodePosition).offset
          : -1;

      final extentBeforeDeletions = composer.selection!.extent;
      int extentOffsetAfterDeletions = extentBeforeDeletions.nodePosition is TextNodePosition
          ? (extentBeforeDeletions.nodePosition as TextNodePosition).offset
          : -1;

      for (final tag in allUserTags) {
        final tagText = textNode.text.text.substring(tag.start, tag.end + 1);
        final attribution = tag.attribution as UserTagAttribution;
        final containsTrigger = textNode.text.text[tag.start] == _trigger;

        if (tagText != "$_trigger${attribution.userId}" || !containsTrigger) {
          // The tag was partially deleted it. Delete the whole thing.
          final deleteFrom = tag.start;
          final deleteTo = tag.end + 1; // +1 because SpanRange is inclusive and text position is exclusive
          editorUserTagsLog.info("Deleting partial tag '$tagText': $deleteFrom -> $deleteTo");

          if (baseBeforeDeletions.nodeId == textNode.id) {
            if (baseOffsetAfterDeletions >= deleteTo) {
              // The base sits beyond the entire deletion region. Push the base up by the
              // length of the deletion region.
              baseOffsetAfterDeletions -= deleteTo - deleteFrom;
            } else if (baseOffsetAfterDeletions > deleteFrom) {
              // The base sits somewhere within the deletion region. Move it to the beginning
              // of the deletion region.
              baseOffsetAfterDeletions = deleteFrom;
            }
          }

          if (extentBeforeDeletions.nodeId == textNode.id) {
            if (extentOffsetAfterDeletions >= deleteTo) {
              // The extent sits beyond the entire deletion region. Push the extent up by the
              // length of the deletion region.
              extentOffsetAfterDeletions -= deleteTo - deleteFrom;
            } else if (extentOffsetAfterDeletions > deleteFrom) {
              // The extent sits somewhere within the deletion region. Move it to the beginning
              // of the deletion region.
              extentOffsetAfterDeletions = deleteFrom;
            }
          }

          deleteTagRequests.add(
            DeleteSelectionRequest(
              documentSelection: DocumentSelection(
                base: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: deleteFrom),
                ),
                extent: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: deleteTo),
                ),
              ),
            ),
          );
        }
      }

      if (deleteTagRequests.isNotEmpty) {
        deleteTagRequests.add(
          ChangeSelectionRequest(
            DocumentSelection(
              base: baseOffsetAfterDeletions >= 0
                  ? DocumentPosition(
                      nodeId: textNode.id,
                      nodePosition: TextNodePosition(offset: baseOffsetAfterDeletions),
                    )
                  : baseBeforeDeletions,
              extent: extentOffsetAfterDeletions >= 0
                  ? DocumentPosition(
                      nodeId: textNode.id,
                      nodePosition: TextNodePosition(offset: extentOffsetAfterDeletions),
                    )
                  : extentBeforeDeletions,
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.contentChange,
          ),
        );
      }
    }

    // Run all the tag attribution removal requests, and tag deletion requests,
    // that we queued up.
    requestDispatcher.execute([
      ...removeTagRequests,
      ...deleteTagRequests,
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
      onUpdateComposingUserTag?.call(null);
      return;
    }
    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      onUpdateComposingUserTag?.call(null);
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      onUpdateComposingUserTag?.call(null);
      return;
    }

    // TODO: De-dup the following two uses of "findUntaggedTokenAroundCaret". I added the
    //       existingComposingTag version so we could report an existing composing tag. The
    //       other call only looks for non-tagged text, which makes it seem as if our existing
    //       composing tag doesn't exist.
    final existingComposingTag = TagTokenizer.findUntaggedTokenAroundCaret(
      triggerSymbol: _trigger,
      text: selectedNode.text,
      caretPosition: caretPosition,
      tagFilter: (tokenAttributions) => tokenAttributions.contains(userTagComposingAttribution),
    );
    if (existingComposingTag != null) {
      onUpdateComposingUserTag?.call(
        ComposingUserTag(
          DocumentRange(
            start: DocumentPosition(
              nodeId: selectedNode.id,
              // +1 to remove trigger symbol
              nodePosition: TextNodePosition(offset: existingComposingTag.token.startOffset + 1),
            ),
            end: DocumentPosition(
              nodeId: selectedNode.id,
              nodePosition: TextNodePosition(offset: existingComposingTag.token.endOffset),
            ),
          ),
          // Remove the trigger symbol from the value.
          existingComposingTag.token.value.substring(1),
        ),
      );
      return;
    }

    final tokenAroundCaret = TagTokenizer.findUntaggedTokenAroundCaret(
      triggerSymbol: _trigger,
      text: selectedNode.text,
      caretPosition: caretPosition,
      tagFilter: (tokenAttributions) =>
          !tokenAttributions.contains(userTagComposingAttribution) &&
          !tokenAttributions.any((attribution) => attribution is UserTagAttribution),
    );
    if (tokenAroundCaret == null) {
      // There's no tag around the caret.
      editorUserTagsLog.fine("There's no tag around the caret, fizzling");
      onUpdateComposingUserTag?.call(null);
      return;
    }
    if (!tokenAroundCaret.token.value.startsWith(_trigger)) {
      // Tags must start with an "@" but the preceding word doesn't. Return.
      editorUserTagsLog.fine("Token doesn't start with '$_trigger', fizzling");
      onUpdateComposingUserTag?.call(null);
      return;
    }

    editorImeLog.fine("Found a user token around caret: ${tokenAroundCaret.token.value}");

    onUpdateComposingUserTag?.call(
      ComposingUserTag(
        DocumentRange(
          start: DocumentPosition(
            nodeId: selectedNode.id,
            // +1 to remove trigger symbol
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.startOffset + 1),
          ),
          end: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: tokenAroundCaret.token.endOffset),
          ),
        ),
        // Remove the trigger symbol from the value.
        tokenAroundCaret.token.value.substring(1),
      ),
    );

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

  Set<TagToken> _findAllComposingTagsInTextNode(TextNode textNode) {
    return textNode.text
        // Find all the composing tag attributions.
        .getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == userTagComposingAttribution,
          range: SpanRange(start: 0, end: textNode.text.text.length - 1),
        )
        // Convert the attributions into TagToken's
        .map(
          (attributionSpan) => TagToken(
            textNode.text.text.substring(attributionSpan.start, attributionSpan.end + 1),
            attributionSpan.start,
            attributionSpan.end + 1,
          ),
        )
        .toSet();
  }

  void _commitTag(RequestDispatcher requestDispatcher, TextNode textNode, TagToken tag) {
    onUpdateComposingUserTag?.call(null);

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
}

typedef OnUpdateComposingUserTag = void Function(ComposingUserTag? composingUserTag);

class ComposingUserTag {
  const ComposingUserTag(this.contentBounds, this.token);

  final DocumentRange contentBounds;
  final String token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposingUserTag &&
          runtimeType == other.runtimeType &&
          contentBounds == other.contentBounds &&
          token == other.token;

  @override
  int get hashCode => contentBounds.hashCode ^ token.hashCode;
}

/// An [EditReaction] that prevents partial selection of a stable user tag.
class AdjustSelectionAroundTagReaction implements EditReaction {
  const AdjustSelectionAroundTagReaction({
    String trigger = "@",
  }) : _trigger = trigger;

  final String _trigger;

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
      editorUserTagsLog.fine(" - there's no caret/extent. Fizzling.");
      return;
    }

    if (selectionChangeEvent.newSelection!.isCollapsed) {
      final textNode = document.getNodeById(newCaret.nodeId);
      if (textNode == null || textNode is! TextNode) {
        // The selected content isn't text. We don't need to worry about it.
        editorUserTagsLog.fine(" - selected content isn't text. Fizzling.");
        return;
      }

      _adjustCaretPosition(
        editContext: editContext,
        requestDispatcher: requestDispatcher,
        textNode: textNode,
        selectionChangeEvent: selectionChangeEvent,
        newCaret: newCaret,
      );
    } else {
      _adjustExpandedSelection(
        editContext: editContext,
        requestDispatcher: requestDispatcher,
        selectionChangeEvent: selectionChangeEvent,
        newCaret: newCaret,
      );
    }
  }

  void _adjustCaretPosition({
    required EditContext editContext,
    required RequestDispatcher requestDispatcher,
    required TextNode textNode,
    required SelectionChangeEvent selectionChangeEvent,
    required DocumentPosition newCaret,
  }) {
    editorUserTagsLog.fine("Adjusting the caret position to avoid user tags.");

    final tagAroundCaret = _findTagAroundPosition(
      textNode.text,
      newCaret.nodePosition as TextNodePosition,
      (attribution) => attribution is UserTagAttribution,
    );
    if (tagAroundCaret == null) {
      // The caret isn't in a tag. We don't need to adjust anything.
      editorUserTagsLog.fine(" - the caret isn't in a tag. Fizzling. Selection:\n${selectionChangeEvent.newSelection}");
      return;
    }
    editorUserTagsLog.fine("Found tag around caret - $tagAroundCaret");

    // The new caret position sits inside of a tag. We need to move it outside the tag.
    editorUserTagsLog.fine("Selection change type: ${selectionChangeEvent.changeType}");
    switch (selectionChangeEvent.changeType) {
      case SelectionChangeType.insertContent:
        // It's not obvious how this would happen when inserting content. We'll play it
        // safe and do nothing in this case.
        return;
      case SelectionChangeType.placeCaret:
      case SelectionChangeType.collapseSelection:
      case SelectionChangeType.deleteContent:
        // Move the caret to the nearest edge of the tag.
        _moveCaretToNearestTagEdge(requestDispatcher, selectionChangeEvent, textNode.id, tagAroundCaret);
        break;
      case SelectionChangeType.pushCaret:
        // Move the caret to the side of the tag in the direction of push motion.
        _pushCaretToOppositeTagEdge(editContext, requestDispatcher, selectionChangeEvent, textNode.id, tagAroundCaret);
        break;
      case SelectionChangeType.placeExtent:
      case SelectionChangeType.pushExtent:
      case SelectionChangeType.expandSelection:
        throw AssertionError(
            "A collapsed selection reported a SelectionChangeType for an expanded selection: ${selectionChangeEvent.changeType}\n${selectionChangeEvent.newSelection}");
      case SelectionChangeType.clearSelection:
        throw AssertionError("Expected a collapsed selection but there was no selection.");
    }
  }

  void _adjustExpandedSelection({
    required EditContext editContext,
    required RequestDispatcher requestDispatcher,
    required SelectionChangeEvent selectionChangeEvent,
    required DocumentPosition newCaret,
  }) {
    editorUserTagsLog.fine("Adjusting an expanded selection to avoid a partial user tag selection.");

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final extentNode = document.getNodeById(newCaret.nodeId);
    if (extentNode is! TextNode) {
      // The caret isn't sitting in text. Fizzle.
      return;
    }

    final tagAroundCaret = _findTagAroundPosition(
      extentNode.text,
      newCaret.nodePosition as TextNodePosition,
      (attribution) => attribution is UserTagAttribution,
    );

    // The new caret position sits inside of a tag. We need to move it outside the tag.
    editorUserTagsLog.fine("Selection change type: ${selectionChangeEvent.changeType}");
    switch (selectionChangeEvent.changeType) {
      case SelectionChangeType.insertContent:
        // It's not obvious how this would happen when inserting content. We'll play it
        // safe and do nothing in this case.
        return;
      case SelectionChangeType.placeExtent:
      case SelectionChangeType.deleteContent:
        if (tagAroundCaret == null) {
          return;
        }

        // Move the caret to the nearest edge of the tag.
        _moveCaretToNearestTagEdge(requestDispatcher, selectionChangeEvent, extentNode.id, tagAroundCaret);
        break;
      case SelectionChangeType.pushExtent:
        if (tagAroundCaret == null) {
          return;
        }

        // Expand the selection by pushing the caret to the side of the tag in the direction of push motion.
        _pushCaretToOppositeTagEdge(
          editContext,
          requestDispatcher,
          selectionChangeEvent,
          extentNode.id,
          tagAroundCaret,
          expand: true,
        );
        break;
      case SelectionChangeType.expandSelection:
        // Move the base or extent to the side of the tag in the direction of push motion.
        TextNode? baseNode;
        final basePosition = selectionChangeEvent.newSelection!.base;
        if (basePosition.nodePosition is TextNodePosition) {
          baseNode = document.getNodeById(basePosition.nodeId) as TextNode;
        }

        _pushExpandedSelectionAroundTags(
          editContext,
          requestDispatcher,
          selectionChangeEvent,
          baseNode: baseNode,
          extentNode: extentNode,
        );
        break;
      case SelectionChangeType.placeCaret:
      case SelectionChangeType.pushCaret:
      case SelectionChangeType.collapseSelection:
        throw AssertionError(
            "An expanded selection reported a SelectionChangeType for a collapsed selection: ${selectionChangeEvent.changeType}\n${selectionChangeEvent.newSelection}");
      case SelectionChangeType.clearSelection:
        throw AssertionError("Expected a collapsed selection but there was no selection.");
    }
  }

  TagTokenAroundCaret? _findTagAroundPosition(
      AttributedText paragraphText, TextNodePosition position, bool Function(Attribution) attributionSelector) {
    // TODO: This reaction only matters when we have committed user tags. Use a standard attribution
    //       query instead of running a text character search to obtain wordAroundCaret.
    final wordAroundCaret = TagTokenizer.findAttributedTokenAroundPosition(
      _trigger,
      paragraphText,
      position,
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
    TagTokenAroundCaret tagAroundCaret,
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

  void _pushCaretToOppositeTagEdge(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent,
    String textNodeId,
    TagTokenAroundCaret tagAroundCaret, {
    bool expand = false,
  }) {
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

    final newSelection = expand
        ? DocumentSelection(
            base: selectionChangeEvent.newSelection!.base,
            extent: DocumentPosition(
              nodeId: selectionChangeEvent.newSelection!.extent.nodeId,
              nodePosition: TextNodePosition(
                offset: textOffset,
              ),
            ),
          )
        : DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: selectionChangeEvent.newSelection!.extent.nodeId,
              nodePosition: TextNodePosition(
                offset: textOffset,
              ),
            ),
          );

    requestDispatcher.execute([
      ChangeSelectionRequest(
        newSelection,
        SelectionChangeType.pushCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }

  void _pushExpandedSelectionAroundTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent, {
    required TextNode? baseNode,
    required TextNode? extentNode,
  }) {
    editorUserTagsLog.info("Pushing expanded selection to other side(s) of token(s)");

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selection = selectionChangeEvent.newSelection!;
    final selectionAffinity = document.getAffinityForSelection(selection);

    final tagAroundBase = baseNode != null
        ? _findTagAroundPosition(
            baseNode.text,
            selectionChangeEvent.newSelection!.base.nodePosition as TextNodePosition,
            (attribution) => attribution is UserTagAttribution,
          )
        : null;

    DocumentPosition? newBasePosition;
    if (tagAroundBase != null) {
      newBasePosition = DocumentPosition(
        nodeId: selection.base.nodeId,
        nodePosition: selectionAffinity == TextAffinity.downstream //
            ? TextNodePosition(offset: tagAroundBase.token.startOffset)
            : TextNodePosition(offset: tagAroundBase.token.endOffset),
      );
    }

    final tagAroundExtent = extentNode != null
        ? _findTagAroundPosition(
            extentNode.text,
            selectionChangeEvent.newSelection!.extent.nodePosition as TextNodePosition,
            (attribution) => attribution is UserTagAttribution,
          )
        : null;

    DocumentPosition? newExtentPosition;
    if (tagAroundExtent != null) {
      newExtentPosition = DocumentPosition(
        nodeId: selection.extent.nodeId,
        nodePosition: selectionAffinity == TextAffinity.downstream //
            ? TextNodePosition(offset: tagAroundExtent.token.endOffset)
            : TextNodePosition(offset: tagAroundExtent.token.startOffset),
      );
    }

    if (newBasePosition == null && newExtentPosition == null) {
      // No adjustment is needed.
      editorUserTagsLog.info("No selection adjustment is needed.");
      return;
    }

    requestDispatcher.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: newBasePosition ?? selectionChangeEvent.newSelection!.base,
          extent: newExtentPosition ?? selectionChangeEvent.newSelection!.extent,
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.contentChange,
      ),
    ]);
  }
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
