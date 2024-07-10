import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/document_hardware_keyboard/document_physical_keyboard.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tokenizing/tags.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

/// A plugin that adds support for action tags, which are tags that represent
/// a user's desire for an action, and then disappear after entry.
///
/// Examples:
///
///   A user types "/task" to convert the current paragraph node to a task node, and
///   then the "/task" text disappears.
///
///   A user types "@john" to assign a task to the user "john", and then the "@john"
///   text disappears.
///
/// Typically, when the user initiates an action tag, the app displays a popover
/// with available actions. Then, the user selects an action from the popover.
/// This plugin doesn't include any popover behavior - that's left for each app
/// to handle as desired.
///
/// When an action tag is submitted, either by the user selecting a desired
/// action from the app's popover, or by some other app-specific means, the
/// tag text is deleted. This is because an action tag is a textual representation
/// of a user's desire to take an action. It's not a persistent reference, like
/// a user tag, or a hash tag.
class ActionTagsPlugin extends SuperEditorPlugin {
  ActionTagsPlugin({
    TagRule tagRule = defaultActionTagRule,
  }) : _tagRule = tagRule {
    _requestHandlers = <EditRequestHandler>[
      (request) => request is SubmitComposingActionTagRequest //
          ? SubmitComposingActionTagCommand()
          : null,
      (request) => request is CancelComposingActionTagRequest //
          ? CancelComposingActionTagCommand(request.tagRule)
          : null,
    ];

    _reactions = [
      ActionTagComposingReaction(
        tagRule: tagRule,
        onUpdateComposingActionTag: (composingTag) {
          _composingActionTag.value = composingTag;
        },
      ),
    ];
  }

  final TagRule _tagRule;

  /// The action tag that the user is currently composing.
  ValueListenable<IndexedTag?> get composingActionTag => _composingActionTag;
  final _composingActionTag = ValueNotifier<IndexedTag?>(null);

  @override
  void attach(Editor editor) {
    editor
      ..context.put(_composingActionTagKey, ComposingActionTag())
      ..requestHandlers.insertAll(0, _requestHandlers)
      ..reactionPipeline.insertAll(0, _reactions);
  }

  @override
  void detach(Editor editor) {
    editor
      ..context.remove(_composingActionTagKey)
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

    editContext.editor.execute([
      CancelComposingActionTagRequest(_tagRule),
    ]);

    return ExecutionInstruction.haltExecution;
  }
}

const defaultActionTagRule = TagRule(trigger: "/", excludedCharacters: {" "});

class SubmitComposingActionTagRequest implements EditRequest {
  const SubmitComposingActionTagRequest();
}

class SubmitComposingActionTagCommand extends EditCommand {
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null) {
      return;
    }

    final extent = composer.selection!.extent;
    final extentPosition = extent.nodePosition;
    if (extentPosition is! TextNodePosition) {
      return;
    }

    final textNode = document.getNodeById(extent.nodeId) as TextNode;

    final tagAroundPosition = TagFinder.findTagAroundPosition(
      // TODO: deal with these tag rules in requests and commands, should the user really pass them?
      tagRule: defaultActionTagRule,
      nodeId: composer.selection!.extent.nodeId,
      text: textNode.text,
      expansionPosition: extentPosition,
      isTokenCandidate: (attributions) => !attributions.contains(actionTagCancelledAttribution),
    );

    if (tagAroundPosition == null) {
      return;
    }

    context.composingActionTag.value = null;

    executor.executeCommand(
      DeleteContentCommand(
        documentRange: DocumentSelection(
          base: tagAroundPosition.indexedTag.start,
          extent: tagAroundPosition.indexedTag.end,
        ),
      ),
    );
    executor.executeCommand(
      ChangeSelectionCommand(
        DocumentSelection.collapsed(position: tagAroundPosition.indexedTag.start),
        SelectionChangeType.deleteContent,
        SelectionReason.userInteraction,
      ),
    );
  }
}

/// An [EditRequest] that cancels an on-going action tag composition near the user's selection.
///
/// When a user is in the process of composing an action tag, that tag is given an attribution
/// to identify it. After this request is processed, that attribution will be removed from
/// the text, which will also remove any related UI, such as a suggested user popover.
///
/// This request doesn't change the user's selection.
class CancelComposingActionTagRequest implements EditRequest {
  const CancelComposingActionTagRequest(this.tagRule);

  final TagRule tagRule;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelComposingActionTagRequest && runtimeType == other.runtimeType && tagRule == other.tagRule;

  @override
  int get hashCode => tagRule.hashCode;
}

class CancelComposingActionTagCommand extends EditCommand {
  const CancelComposingActionTagCommand(this._tagRule);

  final TagRule _tagRule;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    final selection = composer.selection;
    if (selection == null) {
      // There shouldn't be a composing action tag without a selection. Either way,
      // we can't find the desired composing action tag without a selection position
      // to guide us. Fizzle.
      editorActionTagsLog.warning("Tried to cancel a composing action tag, but there's no user selection.");
      return;
    }

    // Look for a composing tag at the extent, or the base.
    final base = selection.base;
    final extent = selection.extent;
    TagAroundPosition? composingToken;
    TextNode? textNode;

    if (base.nodePosition is TextNodePosition) {
      textNode = document.getNodeById(selection.base.nodeId) as TextNode;
      composingToken = TagFinder.findTagAroundPosition(
        tagRule: _tagRule,
        nodeId: textNode.id,
        text: textNode.text,
        expansionPosition: base.nodePosition as TextNodePosition,
        isTokenCandidate: (tokenAttributions) => tokenAttributions.contains(actionTagComposingAttribution),
      );
    }
    if (composingToken == null && extent.nodePosition is TextNodePosition) {
      textNode = document.getNodeById(selection.extent.nodeId) as TextNode;
      composingToken = TagFinder.findTagAroundPosition(
        tagRule: _tagRule,
        nodeId: textNode.id,
        text: textNode.text,
        expansionPosition: base.nodePosition as TextNodePosition,
        isTokenCandidate: (tokenAttributions) => tokenAttributions.contains(actionTagComposingAttribution),
      );
    }

    if (composingToken == null) {
      // There's no composing tag near either side of the user's selection. Fizzle.
      editorActionTagsLog.warning(
          "Tried to cancel a composing action tag, but there's no composing action tag near the user's selection.");
      return;
    }

    // Remove the composing attribution.
    executor.executeCommand(
      RemoveTextAttributionsCommand(
        documentRange: textNode!.selectionBetween(
          composingToken.indexedTag.startOffset,
          composingToken.indexedTag.endOffset,
        ),
        attributions: {actionTagComposingAttribution},
      ),
    );
    executor.executeCommand(
      AddTextAttributionsCommand(
        documentRange: textNode.selectionBetween(
          composingToken.indexedTag.startOffset,
          composingToken.indexedTag.endOffset,
        ),
        attributions: {actionTagCancelledAttribution},
      ),
    );
  }
}

class ActionTagComposingReaction extends EditReaction {
  ActionTagComposingReaction({
    required TagRule tagRule,
    required OnUpdateComposingActionTag onUpdateComposingActionTag,
  })  : _tagRule = tagRule,
        _onUpdateComposingActionTag = onUpdateComposingActionTag;

  final TagRule _tagRule;
  final OnUpdateComposingActionTag _onUpdateComposingActionTag;

  IndexedTag? _composingTag;

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editorContext.document;
    final composer = editorContext.find<MutableDocumentComposer>(Editor.composerKey);

    _composingTag = editorContext.composingActionTag.value;

    _healCancelledTags(requestDispatcher, document, changeList);

    if (composer.selection == null) {
      _cancelComposingTag(requestDispatcher);
      editorContext.composingActionTag.value = null;
      _onUpdateComposingActionTag(null);
      return;
    }

    final selection = composer.selection!;

    // Look for a composing tag at the extent, or the base.
    final base = selection.base;
    final extent = selection.extent;
    TagAroundPosition? tagAroundPosition;
    TextNode? textNode;

    if (base.nodePosition is TextNodePosition) {
      textNode = document.getNodeById(selection.base.nodeId) as TextNode;
      tagAroundPosition = TagFinder.findTagAroundPosition(
        tagRule: _tagRule,
        nodeId: textNode.id,
        text: textNode.text,
        expansionPosition: base.nodePosition as TextNodePosition,
        isTokenCandidate: (attributions) => !attributions.contains(actionTagCancelledAttribution),
      );
    }
    if (tagAroundPosition == null && extent.nodePosition is TextNodePosition) {
      textNode = document.getNodeById(selection.extent.nodeId) as TextNode;
      tagAroundPosition = TagFinder.findTagAroundPosition(
        tagRule: _tagRule,
        nodeId: textNode.id,
        text: textNode.text,
        expansionPosition: base.nodePosition as TextNodePosition,
        isTokenCandidate: (attributions) => !attributions.contains(actionTagCancelledAttribution),
      );
    }

    if (tagAroundPosition == null) {
      _cancelComposingTag(requestDispatcher);
      editorContext.composingActionTag.value = null;
      _onUpdateComposingActionTag(null);
      return;
    }

    _updateComposingTag(requestDispatcher, tagAroundPosition.indexedTag);
    editorContext.composingActionTag.value = tagAroundPosition.indexedTag;
    _onUpdateComposingActionTag(tagAroundPosition.indexedTag);
  }

  /// Finds all cancelled action tags across all changed text nodes in [changeList] and corrects
  /// any invalid attribution bounds that may have been introduced by edits.
  void _healCancelledTags(RequestDispatcher requestDispatcher, MutableDocument document, List<EditEvent> changeList) {
    final healChangeRequests = <EditRequest>[];

    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeChangeEvent) {
        continue;
      }

      final node = document.getNodeById(change.nodeId);
      if (node is! TextNode) {
        continue;
      }

      // The content in a TextNode changed. Check for the existence of any
      // out-of-sync cancelled tags and fix them.
      healChangeRequests.addAll(
        _healCancelledTagsInTextNode(requestDispatcher, node),
      );
    }

    // Run all the requests to heal the various cancelled tags.
    requestDispatcher.execute(healChangeRequests);
  }

  List<EditRequest> _healCancelledTagsInTextNode(RequestDispatcher requestDispatcher, TextNode node) {
    final cancelledTagRanges = node.text.getAttributionSpansInRange(
      attributionFilter: (a) => a == actionTagCancelledAttribution,
      range: SpanRange(0, node.text.length - 1),
    );

    final changeRequests = <EditRequest>[];

    for (final range in cancelledTagRanges) {
      final cancelledText = node.text.substring(range.start, range.end + 1); // +1 because substring is exclusive
      if (cancelledText == _tagRule.trigger) {
        // This is a legitimate cancellation attribution.
        continue;
      }

      DocumentSelection? addedRange;
      if (cancelledText.contains(_tagRule.trigger)) {
        // This cancelled range includes more than just a trigger. Reduce it back
        // down to the trigger.
        final triggerIndex = cancelledText.indexOf(_tagRule.trigger);
        addedRange = node.selectionBetween(triggerIndex, triggerIndex);
      }

      changeRequests.addAll([
        RemoveTextAttributionsRequest(
          documentRange: node.selectionBetween(range.start, range.end),
          attributions: {actionTagCancelledAttribution},
        ),
        if (addedRange != null) //
          AddTextAttributionsRequest(
            documentRange: addedRange,
            attributions: {actionTagCancelledAttribution},
          ),
      ]);
    }

    return changeRequests;
  }

  void _updateComposingTag(RequestDispatcher requestDispatcher, IndexedTag newTag) {
    final oldComposingTag = _composingTag;
    _composingTag = newTag;

    requestDispatcher.execute([
      if (oldComposingTag != null)
        RemoveTextAttributionsRequest(
          documentRange: DocumentSelection(
            base: oldComposingTag.start,
            extent: oldComposingTag.end,
          ),
          attributions: {actionTagComposingAttribution},
        ),
      AddTextAttributionsRequest(
        documentRange: DocumentSelection(
          base: newTag.start,
          extent: newTag.end,
        ),
        attributions: {actionTagComposingAttribution},
      ),
    ]);
  }

  void _cancelComposingTag(RequestDispatcher requestDispatcher) {
    if (_composingTag == null) {
      return;
    }

    final composingTag = _composingTag!;
    _composingTag = null;

    requestDispatcher.execute([
      RemoveTextAttributionsRequest(
        documentRange: DocumentSelection(
          base: composingTag.start,
          extent: composingTag.end,
        ),
        attributions: {actionTagComposingAttribution},
      ),
      AddTextAttributionsRequest(
        documentRange: DocumentSelection(
          base: composingTag.start,
          extent: composingTag.start.copyWith(
            nodePosition: TextNodePosition(offset: composingTag.startOffset + 1),
          ),
        ),
        attributions: {actionTagCancelledAttribution},
      ),
    ]);
  }
}

const _composingActionTagKey = "composing_action_tag";

extension on EditContext {
  ComposingActionTag get composingActionTag => find<ComposingActionTag>(_composingActionTagKey);
}

class ComposingActionTag with Editable {
  IndexedTag? value;
}

typedef OnUpdateComposingActionTag = void Function(IndexedTag? composingActionTag);

/// An attribution for an action tag that's currently being composed.
const actionTagComposingAttribution = NamedAttribution("action-tag-composing");

/// An attribution for an action tag that was being composed and then was cancelled.
///
/// This attribution is used to prevent automatically converting a cancelled composition
/// back to a composing tag.
const actionTagCancelledAttribution = NamedAttribution("action-tag-cancelled");
