import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_hardware_keyboard/document_input_keyboard.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tokenizing/tags.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/strings.dart';

/// A [SuperEditor] plugin that adds the ability to create Slack-style tags, such as
/// persistent user references, e.g., "@dash".
///
/// Slack tagging includes three modes:
///  * Composing: a tag is being assembled, i.e., typed.
///  * Committed: a tag is done being assembled - it's now uneditable.
///  * Unbound: a tag is doing being assembled, but it references an unknown entity - it's still editable.
///  * Cancelled: a tag was being composed, but the composition was cancelled.
class SlackTagPlugin extends SuperEditorPlugin {
  /// The key used to access the [SlackTagIndex] in an attached [Editor].
  static const slackTagIndexKey = "slackTagIndex";

  static const _trigger = "@";

  SlackTagPlugin({List<EditRequestHandler> customRequestHandlers = const []}) : tagIndex = SlackTagIndex() {
    _requestHandlers = <EditRequestHandler>[
      (request) =>
          request is FillInComposingSlackTagRequest ? FillInComposingSlackTagCommand(_trigger, request.tag) : null,
      (request) => request is CancelComposingSlackTagRequest //
          ? const CancelComposingSlackTagCommand()
          : null,
      ...customRequestHandlers,
    ];

    _reactions = [
      SlackTagReaction(
        trigger: _trigger,
        onUpdateComposingTag: tagIndex.setTag,
      ),
      const AdjustSelectionAroundSlackTagReaction(_trigger),
    ];
  }

  /// Index of all slack tags in the document, which changes as the user adds and removes tags.
  final SlackTagIndex tagIndex;

  @override
  void attach(Editor editor) {
    editor
      ..context.put(SlackTagPlugin.slackTagIndexKey, tagIndex)
      ..requestHandlers.insertAll(0, _requestHandlers)
      ..reactionPipeline.insertAll(0, _reactions);
  }

  @override
  void detach(Editor editor) {
    editor
      ..context.remove(SlackTagPlugin.slackTagIndexKey)
      ..requestHandlers.removeWhere((item) => _requestHandlers.contains(item))
      ..reactionPipeline.removeWhere((item) => _reactions.contains(item));
  }

  late final List<EditRequestHandler> _requestHandlers;

  late final List<EditReaction> _reactions;

  @override
  List<DocumentKeyboardAction> get keyboardActions => [_cancelOnEscape];
  ExecutionInstruction _cancelOnEscape({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is KeyDownEvent || keyEvent is KeyRepeatEvent) {
      return ExecutionInstruction.continueExecution;
    }

    if (keyEvent.logicalKey != LogicalKeyboardKey.escape) {
      return ExecutionInstruction.continueExecution;
    }

    final tagIndex = editContext.editor.context.find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey);
    if (!tagIndex.isComposing) {
      return ExecutionInstruction.continueExecution;
    }

    editContext.editor.execute([
      const CancelComposingSlackTagRequest(),
    ]);

    return ExecutionInstruction.haltExecution;
  }
}

/// An [EditRequest] that replaces a composing slack tag with the given [tag]
/// and commits it.
///
/// For example, the user types "@da|", and then selects "dash" from a list of
/// matching users. This request replaces "@da|" with "@dash |" and converts the tag
/// from a composing user tag to a committed user tag.
///
/// For this request to have an effect, the user's selection must sit somewhere within
/// the composing user tag.
class FillInComposingSlackTagRequest implements EditRequest {
  const FillInComposingSlackTagRequest(
    this.tag,
  );

  final String tag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FillInComposingSlackTagRequest && runtimeType == other.runtimeType && tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}

class FillInComposingSlackTagCommand implements EditCommand {
  const FillInComposingSlackTagCommand(
    this._trigger,
    this._tag,
  );

  final String _trigger;
  final String _tag;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final tagIndex = context.find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey);

    if (!tagIndex.isComposing) {
      return;
    }

    // Remove the composing attribution from the text.
    final removeComposingAttributionCommand = removeSlackComposingTokenAttribution(document, tagIndex);

    // Insert the final text and apply a stable tag attribution.
    final tag = tagIndex.composingSlackTag.value!;
    final textNode = document.getNodeById(tag.contentBounds.start.nodeId) as TextNode;
    final slackTagAttribution = CommittedSlackTagAttribution(_tag);

    // The text offset immediately after the trigger ("@").
    final startOfToken = (tag.contentBounds.start.nodePosition as TextNodePosition).offset;

    // Place the caret after the trigger so that the caret isn't temporarily beyond the
    // end of the text.
    executor.executeCommand(
      ChangeSelectionCommand(
        // +1 for trigger symbol
        textNode.selectionAt(startOfToken + 1),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    );

    // Delete the composing slack tag text.
    executor.executeCommand(
      DeleteContentCommand(
        documentRange: textNode.selectionBetween(
          startOfToken,
          (tag.contentBounds.end.nodePosition as TextNodePosition).offset,
        ),
      ),
    );

    // Insert a committed slack tag.
    executor.executeCommand(
      InsertAttributedTextCommand(
        documentPosition: textNode.positionAt(startOfToken),
        textToInsert: AttributedText(
          "$_trigger$_tag ",
          AttributedSpans(
            attributions: [
              SpanMarker(attribution: slackTagAttribution, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: slackTagAttribution, offset: _tag.length, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
    );

    // Place the caret at the end of the inserted text.
    executor.executeCommand(
      ChangeSelectionCommand(
        // +1 for trigger, +1 for space after the token
        textNode.selectionAt(startOfToken + _tag.length + 2),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    );

    // Remove the composing region after we apply the stable attribution to avoid a
    // reaction automatically re-applying the composing tag.
    // FIXME: Use a transaction to bundle these changes so order doesn't matter.
    if (removeComposingAttributionCommand != null) {
      executor.executeCommand(removeComposingAttributionCommand);
      print("Attributions immediately after removing composing attribution:");
      print("${textNode.text.getAttributionSpansByFilter((a) => true)}");
    }

    // Reset the tag index so that we're no longer composing a tag.
    tagIndex._composingSlackTag.value = null;
  }
}

/// An [EditRequest] that cancels an on-going slack tag composition near the user's selection.
///
/// When a user is in the process of composing a slack tag, that tag is given an attribution
/// to identify it. After this request is processed, that attribution will be removed from
/// the text, which will also remove any related UI, such as a suggested-value popover.
///
/// This request doesn't change the user's selection.
class CancelComposingSlackTagRequest implements EditRequest {
  const CancelComposingSlackTagRequest();
}

class CancelComposingSlackTagCommand implements EditCommand {
  const CancelComposingSlackTagCommand();

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final tagIndex = context.find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey);
    if (!tagIndex.isComposing) {
      return;
    }

    final document = context.find<MutableDocument>(Editor.documentKey);

    // Remove the composing attribution from the text.
    final removeComposingAttributionCommand = removeSlackComposingTokenAttribution(document, tagIndex);

    // Reset the tag index.
    final tag = tagIndex.composingSlackTag.value!;
    tagIndex._composingSlackTag.value = null;

    // Mark the trigger as cancelled, so we don't immediately convert it back to a tag.
    final nodeWithTag = document.getNodeById(tag.contentBounds.start.nodeId) as TextNode?;
    if (nodeWithTag == null) {
      // The node is gone. It may have been deleted. Nothing more for us to do.
      return;
    }

    // TODO: move this into a command. Don't directly mutate the document.
    final triggerOffset = (tag.contentBounds.start.nodePosition as TextNodePosition).offset;
    nodeWithTag.text.addAttribution(
      slackTagCancelledAttribution,
      SpanRange(triggerOffset, triggerOffset),
    );

    // Remove the composing region after we apply the cancelled attribution to avoid a
    // reaction automatically re-applying the composing tag.
    // FIXME: Use a transaction to bundle these changes so order doesn't matter.
    if (removeComposingAttributionCommand != null) {
      executor.executeCommand(removeComposingAttributionCommand);
    }
  }
}

EditCommand? removeSlackComposingTokenAttribution(Document document, SlackTagIndex tagIndex) {
  print("REMOVING COMPOSING ATTRIBUTION");
  // Remove any composing attribution for the previous state of the tag.
  // It's possible that the previous composing region disappeared, e.g., due to a deletion.
  final previousTag = tagIndex._composingSlackTag.value!;
  final previousTagNode =
      document.getNodeById(previousTag.contentBounds.start.nodeId); // We assume tags don't cross node boundaries.
  if (previousTagNode == null || previousTagNode is! TextNode) {
    print("Couldn't find composing attribution. Fizzling.");
    return null;
  }

  return RemoveTextAttributionsCommand(
    documentRange: DocumentRange(
      start: DocumentPosition(
        nodeId: previousTagNode.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
      end: DocumentPosition(
        nodeId: previousTagNode.id,
        nodePosition: TextNodePosition(offset: previousTagNode.text.length),
      ),
    ),
    attributions: {slackTagComposingAttribution},
  );
}

extension SlackTagIndexEditable on EditContext {
  /// Returns the [SlackTagIndex] that the [SlackTagPlugin] added to the attached [Editor].
  ///
  /// This accessor is provided as a convenience so that clients don't need to call `find()`
  /// on the [EditContext].
  SlackTagIndex get slackTagIndex => find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey);
}

/// An [EditReaction] that creates, updates, and removes composing slack tags, and commits those
/// composing tags, causing them to become uneditable.
class SlackTagReaction implements EditReaction {
  SlackTagReaction({
    required this.trigger,
    this.maxTriggerRange = 15,
    this.onUpdateComposingTag,
  });

  /// The character that triggers a tag, e.g., "@".
  final String trigger;

  /// The maximum distance the caret can sit from the trigger while causing a tag composition.
  final int maxTriggerRange;

  /// Callback that's notified of all changes to the current composing tag, including
  /// the start of composition, a change to the composing value, and the cancellation of
  /// composition.
  final OnUpdateComposingSlackTag? onUpdateComposingTag;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    final tagIndex = editContext.find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey);

    editorSlackTagsLog.info("------------------------------------------------------");
    editorSlackTagsLog.info("Reacting to possible slack tagging");
    editorSlackTagsLog.info("Incoming change list:");
    editorSlackTagsLog.info(changeList.map((event) => event.runtimeType).toList());
    editorSlackTagsLog.info(
        "Caret position: ${editContext.find<MutableDocumentComposer>(Editor.composerKey).selection?.extent.nodePosition}");
    editorSlackTagsLog.info("Is already composing a tag? ${tagIndex.isComposing}");

    if (changeList.length == 1 && changeList.first is SelectionChangeEvent) {
      print("Selection change event: ${(changeList.first as SelectionChangeEvent).changeType}");
    }

    // Update the current tag composition.
    final selection = composer.selection;
    _updateTagComposition(requestDispatcher, document, tagIndex, selection);

    // _healCancelledTags(requestDispatcher, document, changeList);

    // _adjustTagAttributionsAroundAlteredTags(editContext, requestDispatcher, changeList);

    _deleteCommittedTagsThatWerePartiallyDeleted(editContext, requestDispatcher, changeList);

    // _createNewComposingTag(editContext, requestDispatcher, changeList);

    // Run tag commits after updating tags, above, so that we don't commit an in-progress
    // tag when a new character is added to the end of the tag.
    // _commitCompletedComposingTag(editContext, requestDispatcher, changeList);

    // _updateTagIndex(editContext, changeList);

    editorSlackTagsLog.info("------------------------------------------------------");
  }

  void _updateTagComposition(
      RequestDispatcher requestDispatcher, Document document, SlackTagIndex tagIndex, DocumentSelection? selection) {
    // If, in tbe previous frame, we were composing a tag, check if we're still in range of
    // the tag. If not, cancel the composing process.
    if (tagIndex.isComposing) {
      if (selection == null || !selection.isCollapsed) {
        _stopComposing(requestDispatcher, document, tagIndex);
      } else {
        final tag = _findUpstreamTagWithinRange(document, selection.extent);

        if (tagIndex.composingSlackTag.value != tag && tag != null) {
          _updateComposing(requestDispatcher, document, tagIndex, tag);
        }

        if (tag == null) {
          _stopComposing(requestDispatcher, document, tagIndex);
        }
      }
    }

    // Check if caret is in range of an upstream trigger. If so, start composing.
    if (!tagIndex.isComposing && selection != null && selection.isCollapsed) {
      final tag = _findUpstreamTagWithinRange(document, selection.extent);
      if (tag != null) {
        _startComposing(requestDispatcher, tagIndex, tag);
      }
    }
  }

  void _startComposing(RequestDispatcher requestDispatcher, SlackTagIndex tagIndex, ComposingSlackTag tag) {
    if (tagIndex.isComposing) {
      return;
    }

    editorSlackTagsLog
        .info("Starting new tag composition at offset ${tag.contentBounds.start}, initial token: '${tag.token}'");
    tagIndex._composingSlackTag.value = tag;

    requestDispatcher.execute([
      AddTextAttributionsRequest(
        documentRange: tag.contentBounds,
        attributions: {slackTagComposingAttribution},
      ),
    ]);

    onUpdateComposingTag?.call(tag);
  }

  void _updateComposing(
      RequestDispatcher requestDispatcher, Document document, SlackTagIndex tagIndex, ComposingSlackTag newTag) {
    _removePreviousTagComposingAttribution(requestDispatcher, document, tagIndex);

    // Update the tag index for the new tag.
    tagIndex._composingSlackTag.value = newTag;
    onUpdateComposingTag?.call(newTag);

    // Add composing attribution for the updated tag bounds.
    print("Updating composing attribution with bounds: ${newTag.contentBounds}");
    requestDispatcher.execute([
      AddTextAttributionsRequest(
        documentRange: newTag.contentBounds,
        attributions: {slackTagComposingAttribution},
      ),
    ]);
  }

  void _stopComposing(RequestDispatcher requestDispatcher, Document document, SlackTagIndex tagIndex) {
    if (!tagIndex.isComposing) {
      return;
    }

    _removePreviousTagComposingAttribution(requestDispatcher, document, tagIndex);

    editorSlackTagsLog.info("Stopping tag composition");
    tagIndex._composingSlackTag.value = null;

    onUpdateComposingTag?.call(null);
  }

  void _removePreviousTagComposingAttribution(
      RequestDispatcher requestDispatcher, Document document, SlackTagIndex tagIndex) {
    // Remove any composing attribution for the previous state of the tag.
    // It's possible that the previous composing region disappeared, e.g., due to a deletion.
    final previousTag = tagIndex._composingSlackTag.value!;
    final previousTagNode =
        document.getNodeById(previousTag.contentBounds.start.nodeId); // We assume tags don't cross node boundaries.
    if (previousTagNode == null || previousTagNode is! TextNode || previousTagNode.text.text.isEmpty) {
      return;
    }

    requestDispatcher.execute([
      RemoveTextAttributionsRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: previousTagNode.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          end: DocumentPosition(
            nodeId: previousTagNode.id,
            nodePosition: TextNodePosition(offset: previousTagNode.text.length),
          ),
        ),
        attributions: {slackTagComposingAttribution},
      ),
    ]);
  }

  /// Searches for a trigger character upstream from the [caret] and, if one a trigger is
  /// found, returns a [ComposingSlackTag] with info about the text and bounds related to
  /// the tag.
  ///
  /// The search only looks as far upstream as the [maxTriggerRange].
  ///
  /// If no trigger character is found within [maxTriggerRange], `null` is returned.
  ///
  /// If a trigger character is found, but the trigger is attributed with [slackTagCancelledAttribution]
  /// then `null` is returned.
  ///
  /// If a trigger character is found, but the trigger is attributed with a [CommittedSlackTagAttribution]
  /// then `null` is returned.
  ComposingSlackTag? _findUpstreamTagWithinRange(Document document, DocumentPosition caret) {
    final textNode = document.getNodeById(caret.nodeId);
    if (textNode is! TextNode) {
      return null;
    }

    final caretTextPosition = caret.nodePosition;
    if (caretTextPosition is! TextNodePosition) {
      return null;
    }

    editorSlackTagsLog.fine(
        "Looking for trigger upstream from caret in node: '${textNode.id}' from caret index ${caretTextPosition.offset}");
    editorSlackTagsLog.fine("Current text is: '${textNode.text.text}'");
    int triggerOffset = caretTextPosition.offset;
    final textIterator = textNode.text.text.characters.iterator;
    textIterator
      ..moveNext(triggerOffset)
      ..collapseToEnd();
    while (!textIterator.startsWith(trigger.characters) &&
        triggerOffset > 0 &&
        (caretTextPosition.offset - triggerOffset) <= maxTriggerRange) {
      textIterator.moveBack();
      triggerOffset -= 1;
    }

    if (textNode.text.hasAttributionAt(triggerOffset, attribution: slackTagCancelledAttribution)) {
      // We found a trigger character but the user explicitly cancelled an earlier
      // tag composition at that trigger. Ignore it.
      editorSlackTagsLog.fine("Found an upstream trigger, but it was previously cancelled for composing. Ignoring it.");
      return null;
    }

    if (textNode.text.getAllAttributionsAt(triggerOffset).whereType<CommittedSlackTagAttribution>().isNotEmpty) {
      // We found a trigger character but it belongs to a committed tag. Ignore it.
      editorSlackTagsLog.fine("Found an upstream trigger, but it's already committed. Ignoring it.");
      return null;
    }

    if (textIterator.startsWith(trigger.characters)) {
      editorSlackTagsLog
          .fine("Found an upstream trigger at offset $triggerOffset, caret offset: ${caretTextPosition.offset}");

      final tagToken = triggerOffset != caretTextPosition.offset //
          ? textNode.text.text.substring(triggerOffset + 1, caretTextPosition.offset)
          : "";
      if (tagToken.startsWith(" ")) {
        // As a matter of policy, we don't activate tag composition if the first character
        // after the trigger is a space.
        return null;
      }

      return ComposingSlackTag(
        textNode.rangeBetween(
          triggerOffset,
          caretTextPosition.offset,
        ),
        tagToken,
      );
    }

    editorSlackTagsLog.fine("Didn't find any upstream trigger.");
    return null;
  }

  /// Removes composing or cancelled slack tag attributions from any tag that no longer
  /// matches the pattern of a slack tag.
  ///
  /// Example:
  ///
  ///  - |@john|  ->  |john|  -> john
  void _deleteCommittedTagsThatWerePartiallyDeleted(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorSlackTagsLog.info("Removing invalid tags.");
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
      final tagsInDeletedText = change.deletedText.getAttributionSpansByFilter(
        (attribution) => attribution == slackTagComposingAttribution || attribution is CommittedSlackTagAttribution,
      );
      if (tagsInDeletedText.isEmpty) {
        continue;
      }

      nodesToInspect.add(change.nodeId);
    }
    editorSlackTagsLog.fine("Found ${nodesToInspect.length} impacted nodes with tags that might be invalid");

    // Inspect every TextNode where a text deletion impacted a tag.
    // final removeTagRequests = <EditRequest>{};
    final deleteTagRequests = <EditRequest>{};
    for (final nodeId in nodesToInspect) {
      final textNode = document.getNodeById(nodeId) as TextNode;

      // // If a composing tag no longer contains a trigger ("@"), remove the attribution.
      // final allComposingTags = textNode.text.getAttributionSpansInRange(
      //   attributionFilter: (attribution) => attribution == slackTagComposingAttribution,
      //   range: SpanRange(0, textNode.text.length - 1),
      // );
      //
      // for (final tag in allComposingTags) {
      //   final tagText = textNode.text.substring(tag.start, tag.end + 1);
      //
      //   if (!tagText.startsWith(trigger)) {
      //     editorSlackTagsLog.info("Removing tag with value: '$tagText'");
      //
      //     onUpdateComposingTag?.call(null);
      //
      //     removeTagRequests.add(
      //       RemoveTextAttributionsRequest(
      //         documentRange: textNode.selectionBetween(tag.start, tag.end + 1),
      //         attributions: {slackTagComposingAttribution},
      //       ),
      //     );
      //   }
      // }

      // If a slack tag's content no longer matches its attribution value, then
      // assume that the user tried to delete part of it. Delete the whole thing,
      // because we don't allow partial committed user tags.

      // Collect all the slack tags in this node. The list is sorted such that
      // later tags appear before earlier tags. This way, as we delete tags, each
      // deleted tag won't impact the character offsets of the following tags
      // that we delete.
      final allSlackTags = textNode.text
          .getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution is CommittedSlackTagAttribution,
            range: SpanRange(0, textNode.text.length - 1),
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

      for (final tag in allSlackTags) {
        final tagText = textNode.text.substring(tag.start, tag.end + 1);
        final attribution = tag.attribution as CommittedSlackTagAttribution;
        final containsTrigger = textNode.text.text[tag.start] == trigger;

        if (tagText != "$trigger${attribution.tagValue}" || !containsTrigger) {
          // The tag was partially deleted it. Delete the whole thing.
          final deleteFrom = tag.start;
          final deleteTo = tag.end + 1; // +1 because SpanRange is inclusive and text position is exclusive
          editorSlackTagsLog.info("Deleting partial tag '$tagText': $deleteFrom -> $deleteTo");

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
            DeleteContentRequest(
              documentRange: textNode.selectionBetween(deleteFrom, deleteTo),
            ),
          );
        }
      }

      if (deleteTagRequests.isNotEmpty) {
        deleteTagRequests.add(
          ChangeSelectionRequest(
            DocumentSelection(
              base: baseOffsetAfterDeletions >= 0 ? textNode.positionAt(baseOffsetAfterDeletions) : baseBeforeDeletions,
              extent: extentOffsetAfterDeletions >= 0
                  ? textNode.positionAt(extentOffsetAfterDeletions)
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
      // ...removeTagRequests,
      ...deleteTagRequests,
    ]);
  }

  void _commitTag(RequestDispatcher requestDispatcher, TextNode textNode, IndexedTag tag) {
    onUpdateComposingTag?.call(null);

    final tagSelection = textNode.selectionBetween(tag.startOffset, tag.endOffset);

    requestDispatcher
      // Remove composing tag attribution.
      ..execute([
        RemoveTextAttributionsRequest(
          documentRange: tagSelection,
          attributions: {slackTagComposingAttribution},
        )
      ])
      // Add stable tag attribution.
      ..execute([
        AddTextAttributionsRequest(
          documentRange: tagSelection,
          attributions: {
            CommittedSlackTagAttribution(textNode.text.substring(
              tag.startOffset + 1, // +1 to remove the trigger ("@") from the value
              tag.endOffset,
            ))
          },
        )
      ]);
  }

  TagAroundPosition? _findComposingTagAtCaret(EditContext editContext) {
    return _findTagAtCaret(editContext, (attributions) => attributions.contains(slackTagComposingAttribution));
  }

  TagAroundPosition? _findTagAtCaret(
    EditContext editContext,
    bool Function(Set<Attribution> attributions) tagSelector,
  ) {
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null || !composer.selection!.isCollapsed) {
      // We only tag when the selection is collapsed. Our selection is null or expanded. Return.
      return null;
    }
    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return null;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return null;
    }

    return SlackTagFinder.findTagAroundPosition(
      nodeId: selectedNode.id,
      text: selectedNode.text,
      trigger: trigger,
      expansionPosition: caretPosition,
      isTokenCandidate: tagSelector,
    );
  }
}

typedef OnUpdateComposingSlackTag = void Function(ComposingSlackTag? composingSlackTag);

/// Collects references to all slack tags in a document for easy querying.
class SlackTagIndex with ChangeNotifier implements Editable {
  bool get isComposing => _composingSlackTag.value != null;

  /// Returns the active [ComposingSlackTag], if the user is currently composing a slack tag,
  /// or `null` if no slack tag is currently being composed.
  ValueListenable<ComposingSlackTag?> get composingSlackTag => _composingSlackTag;
  final _composingSlackTag = ValueNotifier<ComposingSlackTag?>(null);

  void setTag(ComposingSlackTag? tag) {
    _composingSlackTag.value = tag;
  }

  final _committedTags = <String, Set<IndexedTag>>{};

  Set<IndexedTag> getCommittedTagsInTextNode(String nodeId) => _committedTags[nodeId] ?? {};

  Set<IndexedTag> getAllCommittedTags() {
    final tags = <IndexedTag>{};
    for (final value in _committedTags.values) {
      tags.addAll(value);
    }
    return tags;
  }

  void _setCommittedTagsInNode(String nodeId, Set<IndexedTag> tags) {
    _committedTags[nodeId] ??= <IndexedTag>{};

    if (const DeepCollectionEquality().equals(_committedTags[nodeId], tags)) {
      return;
    }

    _committedTags[nodeId]!
      ..clear()
      ..addAll(tags);
    _onChange();
  }

  void _clearCommittedTagsInNode(String nodeId) {
    if (_committedTags[nodeId] == null || _committedTags[nodeId]!.isEmpty) {
      return;
    }

    _committedTags[nodeId]?.clear();
    _onChange();
  }

  final _cancelledTags = <String, Set<IndexedTag>>{};

  Set<IndexedTag> getCancelledTagsInTextNode(String nodeId) => _cancelledTags[nodeId] ?? {};

  Set<IndexedTag> getAllCancelledTags() {
    final tags = <IndexedTag>{};
    for (final value in _cancelledTags.values) {
      tags.addAll(value);
    }
    return tags;
  }

  void _setCancelledTagsInNode(String nodeId, Set<IndexedTag> tags) {
    _cancelledTags[nodeId] ??= <IndexedTag>{};

    if (const DeepCollectionEquality().equals(_cancelledTags[nodeId], tags)) {
      return;
    }

    _cancelledTags[nodeId]!
      ..clear()
      ..addAll(tags);
    _onChange();
  }

  void _clearCancelledTagsInNode(String nodeId) {
    if (_cancelledTags[nodeId] == null || _cancelledTags[nodeId]!.isEmpty) {
      return;
    }

    _cancelledTags[nodeId]?.clear();
    _onChange();
  }

  bool _isInATransaction = false;
  bool _didChange = false;

  @override
  void onTransactionStart() {
    _isInATransaction = true;
    _didChange = false;
  }

  void _onChange() {
    if (!_isInATransaction) {
      return;
    }

    _didChange = true;
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {
    _isInATransaction = false;
    if (_didChange) {
      _didChange = false;
      notifyListeners();
    }
  }
}

class ComposingSlackTag {
  const ComposingSlackTag(this.contentBounds, this.token);

  final DocumentRange contentBounds;
  final String token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposingSlackTag &&
          runtimeType == other.runtimeType &&
          contentBounds == other.contentBounds &&
          token == other.token;

  @override
  int get hashCode => contentBounds.hashCode ^ token.hashCode;
}

/// An [EditReaction] that prevents partial selection of a slack user tag.
class AdjustSelectionAroundSlackTagReaction implements EditReaction {
  const AdjustSelectionAroundSlackTagReaction(this.trigger);

  final String trigger;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    editorSlackTagsLog.info("KeepCaretOutOfTagReaction - react()");

    SelectionChangeEvent? selectionChangeEvent;
    bool hasNonSelectionOrComposingRegionChange = false;

    if (changeList.length >= 2) {
      // Check if we have any event that isn't a selection or composing region change.
      hasNonSelectionOrComposingRegionChange =
          changeList.any((e) => e is! SelectionChangeEvent && e is! ComposingRegionChangeEvent);
      selectionChangeEvent = changeList.firstWhereOrNull((e) => e is SelectionChangeEvent) as SelectionChangeEvent?;
    } else if (changeList.length == 1 && changeList.first is SelectionChangeEvent) {
      selectionChangeEvent = changeList.first as SelectionChangeEvent;
    }

    if (hasNonSelectionOrComposingRegionChange || selectionChangeEvent == null) {
      // We only want to move the caret when we're confident about what changed. Therefore,
      // we only react to changes that are solely a selection or composing region change,
      // i.e., we ignore situations like text entry, text deletion, etc.
      editorSlackTagsLog.info(" - change list isn't just a single SelectionChangeEvent: $changeList");
      return;
    }

    editorSlackTagsLog.info(" - we received just one selection change event. Checking for user tag.");

    final document = editContext.find<MutableDocument>(Editor.documentKey);

    final newCaret = selectionChangeEvent.newSelection?.extent;
    if (newCaret == null) {
      editorSlackTagsLog.fine(" - there's no caret/extent. Fizzling.");
      return;
    }

    if (selectionChangeEvent.newSelection!.isCollapsed) {
      final textNode = document.getNodeById(newCaret.nodeId);
      if (textNode == null || textNode is! TextNode) {
        // The selected content isn't text. We don't need to worry about it.
        editorSlackTagsLog.fine(" - selected content isn't text. Fizzling.");
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

    print(
        "Selection after adjusting for tag: ${editContext.find<MutableDocumentComposer>(Editor.composerKey).selection?.extent.nodePosition}");
  }

  void _adjustCaretPosition({
    required EditContext editContext,
    required RequestDispatcher requestDispatcher,
    required TextNode textNode,
    required SelectionChangeEvent selectionChangeEvent,
    required DocumentPosition newCaret,
  }) {
    editorSlackTagsLog.fine("Adjusting the caret position to avoid slack tags.");

    final tagAroundCaret = _findTagAroundPosition(
      textNode.id,
      textNode.text,
      newCaret.nodePosition as TextNodePosition,
      (attribution) => attribution is CommittedSlackTagAttribution,
    );
    if (tagAroundCaret == null) {
      // The caret isn't in a tag. We don't need to adjust anything.
      editorSlackTagsLog
          .fine(" - the caret isn't in a tag. Fizzling. Selection:\n${selectionChangeEvent.newSelection}");
      return;
    }
    editorSlackTagsLog.fine("Found tag around caret - $tagAroundCaret");

    // The new caret position sits inside of a tag. We need to move it outside the tag.
    editorSlackTagsLog.fine("Selection change type: ${selectionChangeEvent.changeType}");
    switch (selectionChangeEvent.changeType) {
      case SelectionChangeType.insertContent:
        // It's not obvious how this would happen when inserting content. We'll play it
        // safe and do nothing in this case.
        return;
      case SelectionChangeType.placeCaret:
      case SelectionChangeType.collapseSelection:
      case SelectionChangeType.alteredContent:
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
    editorSlackTagsLog.fine("Adjusting an expanded selection to avoid a partial slack tag selection.");

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final extentNode = document.getNodeById(newCaret.nodeId);
    if (extentNode is! TextNode) {
      // The caret isn't sitting in text. Fizzle.
      return;
    }

    final tagAroundCaret = _findTagAroundPosition(
      extentNode.id,
      extentNode.text,
      newCaret.nodePosition as TextNodePosition,
      (attribution) => attribution is CommittedSlackTagAttribution,
    );

    // The new caret position sits inside of a tag. We need to move it outside the tag.
    editorSlackTagsLog.fine("Selection change type: ${selectionChangeEvent.changeType}");
    switch (selectionChangeEvent.changeType) {
      case SelectionChangeType.insertContent:
        // It's not obvious how this would happen when inserting content. We'll play it
        // safe and do nothing in this case.
        return;
      case SelectionChangeType.placeExtent:
      case SelectionChangeType.alteredContent:
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
      // throw AssertionError(
      //     "An expanded selection reported a SelectionChangeType for a collapsed selection: ${selectionChangeEvent.changeType}\n${selectionChangeEvent.newSelection}");
      case SelectionChangeType.clearSelection:
      // throw AssertionError("Expected a collapsed selection but there was no selection.");
    }
  }

  TagAroundPosition? _findTagAroundPosition(
    String nodeId,
    AttributedText paragraphText,
    TextNodePosition position,
    bool Function(Attribution) attributionSelector,
  ) {
    final searchOffset = position.offset;
    final committedTags = paragraphText.getAllAttributionsAt(searchOffset).whereType<CommittedSlackTagAttribution>();
    if (committedTags.isEmpty) {
      // The caret isn't sitting within a committed tag. Return.
      return null;
    }

    final tagAttributionAroundCaret = committedTags.first;
    final tagAroundCaret = paragraphText.getAttributionSpans({tagAttributionAroundCaret}).first;

    if (tagAroundCaret.start == searchOffset) {
      // There's a tag, but it starts immediately after the search offset. We don't want to
      // report "hello |@user" as the tag sitting within "@user".
      return null;
    }

    return TagAroundPosition(
      indexedTag: IndexedTag(
        Tag(trigger, tagAttributionAroundCaret.tagValue),
        nodeId,
        tagAroundCaret.start,
      ),
      searchOffset: position.offset,
    );

    // final tagAroundCaret = SlackTagFinder.findTagAroundPosition(
    //   trigger: trigger,
    //   nodeId: nodeId,
    //   text: paragraphText,
    //   expansionPosition: position,
    //   isTokenCandidate: (tokenAttributions) => tokenAttributions.any(attributionSelector),
    // );
    // print("tagAroundCaret: $tagAroundCaret");
    // if (tagAroundCaret == null) {
    //   print("1");
    //   return null;
    // }
    // if (tagAroundCaret.searchOffsetInToken == 0 ||
    //     tagAroundCaret.searchOffsetInToken == tagAroundCaret.indexedTag.tag.raw.length) {
    //   // The token is either on the starting edge, e.g., "|@tag", or at the ending edge,
    //   // e.g., "@tag|". We don't care about those scenarios when looking for the caret
    //   // inside of the token.
    //   print("2");
    //   return null;
    // }
    //
    // final tokenAttributions = paragraphText.getAllAttributionsThroughout(
    //   SpanRange(
    //     tagAroundCaret.indexedTag.startOffset,
    //     tagAroundCaret.indexedTag.endOffset - 1,
    //   ),
    // );
    // if (tokenAttributions.any((attribution) => attribution is CommittedSlackTagAttribution)) {
    //   // This token is a user tag. Return it.
    //   print("3");
    //   return tagAroundCaret;
    // }
    //
    // print("4");
    // return null;
  }

  void _moveCaretToNearestTagEdge(
    RequestDispatcher requestDispatcher,
    SelectionChangeEvent selectionChangeEvent,
    String textNodeId,
    TagAroundPosition tagAroundCaret,
  ) {
    DocumentSelection? newSelection;
    editorSlackTagsLog.info("oldCaret is null. Pushing caret to end of tag.");
    // The caret was placed directly in the token without a previous selection. This might
    // be a user tap, or programmatic placement. Move the caret to the nearest edge of the
    // token.
    if ((tagAroundCaret.searchOffset - tagAroundCaret.indexedTag.startOffset).abs() <
        (tagAroundCaret.searchOffset - tagAroundCaret.indexedTag.endOffset).abs()) {
      // Move the caret to the start of the tag.
      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: textNodeId,
          nodePosition: TextNodePosition(offset: tagAroundCaret.indexedTag.startOffset),
        ),
      );
    } else {
      // Move the caret to the end of the tag.
      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: textNodeId,
          nodePosition: TextNodePosition(offset: tagAroundCaret.indexedTag.endOffset),
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
    TagAroundPosition tagAroundCaret, {
    bool expand = false,
  }) {
    editorSlackTagsLog.info("Pushing caret to other side of token - tag around caret: $tagAroundCaret");
    final Document document = editContext.find<MutableDocument>(Editor.documentKey);

    final pushDirection = document.getAffinityBetween(
      base: selectionChangeEvent.oldSelection!.extent,
      extent: selectionChangeEvent.newSelection!.extent,
    );

    late int textOffset;
    switch (pushDirection) {
      case TextAffinity.upstream:
        // Move to starting edge.
        textOffset = tagAroundCaret.indexedTag.startOffset;
        break;
      case TextAffinity.downstream:
        // Move to ending edge.
        textOffset = tagAroundCaret.indexedTag.endOffset;
        print("Pushing to text offset: $textOffset");
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

    print("Setting selection to: $newSelection");

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
    editorSlackTagsLog.info("Pushing expanded selection to other side(s) of token(s)");

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selection = selectionChangeEvent.newSelection!;
    final selectionAffinity = document.getAffinityForSelection(selection);

    final tagAroundBase = baseNode != null
        ? _findTagAroundPosition(
            baseNode.id,
            baseNode.text,
            selectionChangeEvent.newSelection!.base.nodePosition as TextNodePosition,
            (attribution) => attribution is CommittedSlackTagAttribution,
          )
        : null;

    DocumentPosition? newBasePosition;
    if (tagAroundBase != null) {
      newBasePosition = DocumentPosition(
        nodeId: selection.base.nodeId,
        nodePosition: selectionAffinity == TextAffinity.downstream //
            ? TextNodePosition(offset: tagAroundBase.indexedTag.startOffset)
            : TextNodePosition(offset: tagAroundBase.indexedTag.endOffset),
      );
    }

    final tagAroundExtent = extentNode != null
        ? _findTagAroundPosition(
            extentNode.id,
            extentNode.text,
            selectionChangeEvent.newSelection!.extent.nodePosition as TextNodePosition,
            (attribution) => attribution is CommittedSlackTagAttribution,
          )
        : null;

    DocumentPosition? newExtentPosition;
    if (tagAroundExtent != null) {
      newExtentPosition = DocumentPosition(
        nodeId: selection.extent.nodeId,
        nodePosition: selectionAffinity == TextAffinity.downstream //
            ? TextNodePosition(offset: tagAroundExtent.indexedTag.endOffset)
            : TextNodePosition(offset: tagAroundExtent.indexedTag.startOffset),
      );
    }

    if (newBasePosition == null && newExtentPosition == null) {
      // No adjustment is needed.
      editorSlackTagsLog.info("No selection adjustment is needed.");
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

class SlackTagFinder {
  /// Finds a tag that touches the given [expansionPosition] and returns that tag,
  /// indexed within the document, along with the [expansionPosition].
  static TagAroundPosition? findTagAroundPosition({
    required String trigger,
    required String nodeId,
    required AttributedText text,
    required TextNodePosition expansionPosition,
    required bool Function(Set<Attribution> tokenAttributions) isTokenCandidate,
  }) {
    final rawText = text.text;
    if (rawText.isEmpty) {
      return null;
    }

    int tokenStartOffset = min(expansionPosition.offset - 1, rawText.length - 1);
    tokenStartOffset = max(tokenStartOffset, 0);

    int tokenEndOffset = min(expansionPosition.offset - 1, rawText.length - 1);
    tokenEndOffset = max(tokenEndOffset, 0);

    if (rawText[tokenStartOffset] != trigger) {
      while (tokenStartOffset > 0) {
        final upstreamCharacterIndex = rawText.moveOffsetUpstreamByCharacter(tokenStartOffset)!;
        final upstreamCharacter = rawText[upstreamCharacterIndex];

        // Move the starting character index upstream.
        tokenStartOffset = upstreamCharacterIndex;

        if (upstreamCharacter == trigger) {
          // The character we just added to the token bounds is the trigger.
          // We don't want to move the start any further upstream.
          break;
        }
      }
    }

    while (tokenEndOffset < rawText.length - 1) {
      final downstreamCharacterIndex = rawText.moveOffsetDownstreamByCharacter(tokenEndOffset)!;
      final downstreamCharacter = rawText[downstreamCharacterIndex];
      if (downstreamCharacter != trigger) {
        break;
      }

      tokenEndOffset = downstreamCharacterIndex;
    }
    // Make end off exclusive.
    tokenEndOffset += 1;

    final tokenRange = SpanRange(tokenStartOffset, tokenEndOffset);
    if (tokenRange.end - tokenRange.start <= 0) {
      return null;
    }

    final tagText = text.substringInRange(tokenRange);
    if (!tagText.startsWith(trigger)) {
      return null;
    }

    final tokenAttributions = text.getAttributionSpansInRange(attributionFilter: (a) => true, range: tokenRange);
    if (!isTokenCandidate(tokenAttributions.map((span) => span.attribution).toSet())) {
      return null;
    }

    final tagAroundPosition = TagAroundPosition(
      indexedTag: IndexedTag(
        Tag(trigger, tagText.substring(1)),
        nodeId,
        tokenStartOffset,
      ),
      searchOffset: expansionPosition.offset,
    );

    return tagAroundPosition;
  }

  /// Finds and returns all tags in the given [textNode], which start with [trigger].
  static Set<IndexedTag> findAllTagsInTextNode(String trigger, TextNode textNode) {
    final plainText = textNode.text.text;
    final tags = <IndexedTag>{};

    int characterIndex = 0;
    int? tagStartIndex;
    late StringBuffer tagBuffer;
    for (final character in plainText.characters) {
      if (character == trigger) {
        if (tagStartIndex != null) {
          // We found a trigger, but we're still accumulating a tag from an earlier
          // trigger. End the tag we were accumulating.
          tags.add(IndexedTag(
            Tag.fromRaw(tagBuffer.toString()),
            textNode.id,
            tagStartIndex,
          ));
        }

        // Start accumulating a new tag, because we hit a trigger character.
        tagStartIndex = characterIndex;
        tagBuffer = StringBuffer();
      }

      if (tagStartIndex != null) {
        // We're accumulating a tag and we hit a character that isn't allowed to
        // appear in a tag. End the tag we were accumulating.
        tags.add(IndexedTag(
          Tag.fromRaw(tagBuffer.toString()),
          textNode.id,
          tagStartIndex,
        ));

        tagStartIndex = null;
      } else if (tagStartIndex != null) {
        // We're accumulating a tag. Add this character to the tag.
        tagBuffer.write(character);
      }

      characterIndex += 1;
    }

    if (tagStartIndex != null) {
      // We were assembling a tag and it went to the end of the text. End the tag.
      tags.add(IndexedTag(
        Tag.fromRaw(tagBuffer.toString()),
        textNode.id,
        tagStartIndex,
      ));
    }

    return tags;
  }

  const SlackTagFinder._();
}

/// An attribution for a slack tag that's currently being composed.
const slackTagComposingAttribution = NamedAttribution("slack-tag-composing");

/// An attribution for a slack tag that was previously being composed, but was then
/// abandoned (not cancelled) without committing it.
const slackTagUnboundAttribution = NamedAttribution("slack-tag-unbound");

/// An attribution for a slack tag that was being composed and then was cancelled.
///
/// This attribution is used to prevent automatically converting a cancelled composition
/// back to a composing tag.
const slackTagCancelledAttribution = NamedAttribution("slack-tag-cancelled");

/// An attribution for a committed tag, i.e., a slack tag that's done being composed and
/// shouldn't be partially selectable or editable.
class CommittedSlackTagAttribution implements Attribution {
  const CommittedSlackTagAttribution(this.tagValue);

  @override
  String get id => tagValue;

  final String tagValue;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommittedSlackTagAttribution && runtimeType == other.runtimeType && tagValue == other.tagValue;

  @override
  int get hashCode => tagValue.hashCode;

  @override
  String toString() {
    return '[CommittedSlackTagAttribution]: $tagValue';
  }
}
