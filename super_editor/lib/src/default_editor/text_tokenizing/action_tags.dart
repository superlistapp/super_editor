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
      ..requestHandlers.insertAll(0, _requestHandlers)
      ..reactionPipeline.insertAll(0, _reactions);
  }

  @override
  void detach(Editor editor) {
    editor
      ..requestHandlers.removeWhere((item) => _requestHandlers.contains(item))
      ..reactionPipeline.removeWhere((item) => _reactions.contains(item));
  }

  late final List<EditRequestHandler> _requestHandlers;

  late final List<EditReaction> _reactions;

  @override
  List<DocumentKeyboardAction> get keyboardActions => [_cancelOnEscape];
  ExecutionInstruction _cancelOnEscape({
    required SuperEditorContext editContext,
    required RawKeyEvent keyEvent,
  }) {
    if (keyEvent is RawKeyDownEvent) {
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
  // TODO:
}

class SubmitComposingActionTagCommand implements EditCommand {
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
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

    print("Submitting the composing tag by deleting its text: ${tagAroundPosition.indexedTag}");

    executor.executeCommand(
      DeleteSelectionCommand(
        documentSelection: DocumentSelection(
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

class CancelComposingActionTagCommand implements EditCommand {
  const CancelComposingActionTagCommand(this._tagRule);

  final TagRule _tagRule;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    print("Running CancelComposingActionTagCommand");
    final document = context.find<MutableDocument>(Editor.documentKey);
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

    final actionTagBasePosition = DocumentPosition(
      nodeId: textNode!.id,
      nodePosition: TextNodePosition(offset: composingToken.indexedTag.startOffset),
    );

    // Remove the composing attribution.
    print("Removing composing attribution from $actionTagBasePosition to ${composingToken.indexedTag.endOffset}");
    executor.executeCommand(
      RemoveTextAttributionsCommand(
        documentSelection: DocumentSelection(
          base: actionTagBasePosition,
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: composingToken.indexedTag.endOffset),
          ),
        ),
        attributions: {actionTagComposingAttribution},
      ),
    );
    executor.executeCommand(
      AddTextAttributionsCommand(
        documentSelection: DocumentSelection(
          base: actionTagBasePosition,
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: composingToken.indexedTag.endOffset),
          ),
        ),
        attributions: {actionTagCancelledAttribution},
      ),
    );
  }
}

class ActionTagComposingReaction implements EditReaction {
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
    final document = editorContext.find<MutableDocument>(Editor.documentKey);
    final composer = editorContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null) {
      // TODO: cancel any composing tag.
      _cancelComposingTag(requestDispatcher);
      _onUpdateComposingActionTag(null);
      return;
    }

    final extent = composer.selection!.extent;
    final extentPosition = extent.nodePosition;
    if (extentPosition is! TextNodePosition) {
      // TODO: cancel any composing tag.
      _cancelComposingTag(requestDispatcher);
      _onUpdateComposingActionTag(null);
      return;
    }

    final textNode = document.getNodeById(extent.nodeId) as TextNode;

    print("Before changing annotations, text is:");
    print("${textNode.text}");

    final tagAroundPosition = TagFinder.findTagAroundPosition(
      tagRule: _tagRule,
      nodeId: composer.selection!.extent.nodeId,
      text: textNode.text,
      expansionPosition: extentPosition,
      isTokenCandidate: (attributions) => !attributions.contains(actionTagCancelledAttribution),
    );

    if (tagAroundPosition == null) {
      _cancelComposingTag(requestDispatcher);
      _onUpdateComposingActionTag(null);
      return;
    }

    // TODO: don't activate cancelled tokens
    // TODO: remove cancellation attributions from tokens that don't fit our rule

    print("Found indexed tag:");
    print("$tagAroundPosition");
    _updateComposingTag(requestDispatcher, tagAroundPosition.indexedTag);
    _onUpdateComposingActionTag(tagAroundPosition.indexedTag);

    // Notion allows spaces:
    // "/ page link" matches one action in Notion, which is displayed in a popover

    // Notion continues to show a "No results" popup for 4 characters of non-matching
    // "/ text spa" <- still shows "No results", "/ text span" <- popup disappears and gives up

    // Once Notion gives up, either due to 4+ characters of "No results" or moving caret
    // away from the tag, the tag never re-activates.
  }

  void _updateComposingTag(RequestDispatcher requestDispatcher, IndexedTag newTag) {
    final oldComposingTag = _composingTag;
    _composingTag = newTag;

    print("Updating composing tag to: $_composingTag");
    requestDispatcher.execute([
      if (oldComposingTag != null)
        RemoveTextAttributionsRequest(
          documentSelection: DocumentSelection(
            base: oldComposingTag.start,
            extent: oldComposingTag.end,
          ),
          attributions: {actionTagComposingAttribution},
        ),
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
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

    print("Cancelling composing tag: $_composingTag");
    final composingTag = _composingTag!;
    _composingTag = null;

    requestDispatcher.execute([
      RemoveTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: composingTag.start,
          extent: composingTag.end,
        ),
        attributions: {actionTagComposingAttribution},
      ),
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: composingTag.start,
          extent: composingTag.end,
        ),
        attributions: {actionTagCancelledAttribution},
      ),
    ]);
  }
}

typedef OnUpdateComposingActionTag = void Function(IndexedTag? composingActionTag);

/// An attribution for an action tag that's currently being composed.
const actionTagComposingAttribution = NamedAttribution("action-tag-composing");

/// An attribution for an action tag that was being composed and then was cancelled.
///
/// This attribution is used to prevent automatically converting a cancelled composition
/// back to a composing tag.
const actionTagCancelledAttribution = NamedAttribution("action-tag-cancelled");
