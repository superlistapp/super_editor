import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/composer/composer_reactions.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/default_editor/text.dart';

import 'common_editor_operations.dart';
import 'default_document_editor_reactions.dart';

Editor createDefaultDocumentEditor({
  required MutableDocument document,
  required MutableDocumentComposer composer,
  HistoryGroupingPolicy historyGroupingPolicy = defaultMergePolicy,
}) {
  final editor = Editor(
    editables: {
      Editor.documentKey: document,
      Editor.composerKey: composer,
    },
    requestHandlers: List.from(defaultRequestHandlers),
    historyGroupingPolicy: historyGroupingPolicy,
    reactionPipeline: List.from(defaultEditorReactions),
  );

  return editor;
}

final defaultRequestHandlers = List.unmodifiable(<EditRequestHandler>[
  (request) => request is ChangeSelectionRequest
      ? ChangeSelectionCommand(
          request.newSelection,
          request.changeType,
          request.reason,
          notifyListeners: request.notifyListeners,
        )
      : null,
  (request) => request is ClearSelectionRequest
      ? const ChangeSelectionCommand(
          null,
          SelectionChangeType.clearSelection,
          SelectionReason.userInteraction,
        )
      : null,
  (request) => request is ChangeComposingRegionRequest //
      ? ChangeComposingRegionCommand(request.composingRegion)
      : null,
  (request) => request is ClearComposingRegionRequest //
      ? ChangeComposingRegionCommand(null)
      : null,
  (request) => request is ChangeInteractionModeRequest //
      ? ChangeInteractionModeCommand(isInteractionModeDesired: request.isInteractionModeDesired)
      : null,
  (request) => request is RemoveComposerPreferenceStylesRequest //
      ? RemoveComposerPreferenceStylesCommand(request.stylesToRemove)
      : null,
  (request) => request is InsertTextRequest
      ? InsertTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
          attributions: request.attributions,
        )
      : null,
  (request) => request is InsertAttributedTextRequest
      ? InsertAttributedTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
        )
      : null,
  (request) => request is PasteStructuredContentEditorRequest
      ? PasteStructuredContentEditorCommand(
          content: request.content,
          pastePosition: request.pastePosition,
        )
      : null,
  (request) => request is InsertNodeAtIndexRequest
      ? InsertNodeAtIndexCommand(nodeIndex: request.nodeIndex, newNode: request.newNode)
      : null,
  (request) => request is InsertNodeBeforeNodeRequest
      ? InsertNodeBeforeNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (request) => request is InsertNodeAfterNodeRequest
      ? InsertNodeAfterNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (request) => request is InsertNodeAtCaretRequest //
      ? InsertNodeAtCaretCommand(newNode: request.node)
      : null,
  (request) => request is MoveNodeRequest //
      ? MoveNodeCommand(nodeId: request.nodeId, newIndex: request.newIndex)
      : null,
  (request) => request is CombineParagraphsRequest
      ? CombineParagraphsCommand(firstNodeId: request.firstNodeId, secondNodeId: request.secondNodeId)
      : null,
  (request) => request is ReplaceNodeRequest
      ? ReplaceNodeCommand(existingNodeId: request.existingNodeId, newNode: request.newNode)
      : null,
  (request) => request is ReplaceNodeWithEmptyParagraphWithCaretRequest
      ? ReplaceNodeWithEmptyParagraphWithCaretCommand(nodeId: request.nodeId)
      : null,
  (request) => request is DeleteContentRequest //
      ? DeleteContentCommand(documentRange: request.documentRange)
      : null,
  (request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is ListItemNode
      ? ConvertListItemToParagraphCommand(nodeId: request.node.id, paragraphMetadata: request.node.metadata)
      : null,
  (request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is ParagraphNode
      ? DeleteUpstreamAtBeginningOfParagraphCommand(request.node)
      : null,
  (request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is BlockNode
      ? DeleteUpstreamAtBeginningOfBlockNodeCommand(request.node)
      : null,
  (request) => request is DeleteNodeRequest //
      ? DeleteNodeCommand(nodeId: request.nodeId)
      : null,
  (request) => request is DeleteUpstreamCharacterRequest //
      ? const DeleteUpstreamCharacterCommand()
      : null,
  (request) => request is DeleteDownstreamCharacterRequest //
      ? const DeleteDownstreamCharacterCommand()
      : null,
  (request) => request is InsertTextRequest
      ? InsertTextCommand(
          documentPosition: request.documentPosition,
          textToInsert: request.textToInsert,
          attributions: request.attributions)
      : null,
  (request) => request is InsertCharacterAtCaretRequest
      ? InsertCharacterAtCaretCommand(
          character: request.character,
          ignoreComposerAttributions: request.ignoreComposerAttributions,
        )
      : null,
  (request) => request is ChangeParagraphAlignmentRequest
      ? ChangeParagraphAlignmentCommand(
          nodeId: request.nodeId,
          alignment: request.alignment,
        )
      : null,
  (request) => request is IndentParagraphRequest
      ? IndentParagraphCommand(
          request.nodeId,
        )
      : null,
  (request) => request is UnIndentParagraphRequest
      ? UnIndentParagraphCommand(
          request.nodeId,
        )
      : null,
  (request) => request is SetParagraphIndentRequest
      ? SetParagraphIndentCommand(
          request.nodeId,
          level: request.level,
        )
      : null,
  (request) => request is ChangeParagraphBlockTypeRequest
      ? ChangeParagraphBlockTypeCommand(
          nodeId: request.nodeId,
          blockType: request.blockType,
        )
      : null,
  (request) => request is SplitParagraphRequest
      ? SplitParagraphCommand(
          nodeId: request.nodeId,
          splitPosition: request.splitPosition,
          newNodeId: request.newNodeId,
          replicateExistingMetadata: request.replicateExistingMetadata,
          attributionsToExtendToNewParagraph: request.attributionsToExtendToNewParagraph,
        )
      : null,
  (request) => request is ConvertParagraphToTaskRequest
      ? ConvertParagraphToTaskCommand(
          nodeId: request.nodeId,
          isComplete: request.isComplete,
        )
      : null,
  (request) => request is ConvertTaskToParagraphRequest
      ? ConvertTaskToParagraphCommand(
          nodeId: request.nodeId,
          paragraphMetadata: request.paragraphMetadata,
        )
      : null,
  (request) => request is DeleteUpstreamAtBeginningOfNodeRequest && request.node is TaskNode
      ? ConvertTaskToParagraphCommand(nodeId: request.node.id, paragraphMetadata: request.node.metadata)
      : null,
  (request) => request is ChangeTaskCompletionRequest
      ? ChangeTaskCompletionCommand(
          nodeId: request.nodeId,
          isComplete: request.isComplete,
        )
      : null,
  (request) => request is IndentTaskRequest //
      ? IndentTaskCommand(request.nodeId)
      : null,
  (request) => request is UnIndentTaskRequest //
      ? UnIndentTaskCommand(request.nodeId)
      : null,
  (request) => request is SetTaskIndentRequest //
      ? SetTaskIndentCommand(request.nodeId, request.indent)
      : null,
  (request) => request is SplitExistingTaskRequest
      ? SplitExistingTaskCommand(
          nodeId: request.existingNodeId,
          splitOffset: request.splitOffset,
          newNodeId: request.newNodeId,
        )
      : null,
  (request) => request is SplitListItemRequest
      ? SplitListItemCommand(
          nodeId: request.nodeId,
          splitPosition: request.splitPosition,
          newNodeId: request.newNodeId,
        )
      : null,
  (request) => request is IndentListItemRequest //
      ? IndentListItemCommand(nodeId: request.nodeId)
      : null,
  (request) => request is UnIndentListItemRequest //
      ? UnIndentListItemCommand(nodeId: request.nodeId)
      : null,
  (request) => request is ChangeListItemTypeRequest
      ? ChangeListItemTypeCommand(nodeId: request.nodeId, newType: request.newType)
      : null,
  (request) => request is ConvertListItemToParagraphRequest //
      ? ConvertListItemToParagraphCommand(nodeId: request.nodeId, paragraphMetadata: request.paragraphMetadata)
      : null,
  (request) => request is ConvertParagraphToListItemRequest
      ? ConvertParagraphToListItemCommand(nodeId: request.nodeId, type: request.type)
      : null,
  (request) => request is AddTextAttributionsRequest
      ? AddTextAttributionsCommand(
          documentRange: request.documentRange,
          attributions: request.attributions,
          autoMerge: request.autoMerge,
        )
      : null,
  (request) => request is ToggleTextAttributionsRequest
      ? ToggleTextAttributionsCommand(documentRange: request.documentRange, attributions: request.attributions)
      : null,
  (request) => request is RemoveTextAttributionsRequest
      ? RemoveTextAttributionsCommand(documentRange: request.documentRange, attributions: request.attributions)
      : null,
  (request) => request is ChangeSingleColumnLayoutComponentStylesRequest
      ? ChangeSingleColumnLayoutComponentStylesCommand(nodeId: request.nodeId, styles: request.styles) //
      : null,
  (request) => request is ConvertTextNodeToParagraphRequest
      ? ConvertTextNodeToParagraphCommand(nodeId: request.nodeId, newMetadata: request.newMetadata)
      : null,
  (request) => request is PasteEditorRequest
      ? PasteEditorCommand(
          content: request.content,
          pastePosition: request.pastePosition,
        )
      : null,
]);

final defaultEditorReactions = List.unmodifiable([
  UpdateComposerTextStylesReaction(),
  const LinkifyReaction(),

  //---- Start Content Conversions ----
  HeaderConversionReaction(),
  const UnorderedListItemConversionReaction(),
  const OrderedListItemConversionReaction(),
  const BlockquoteConversionReaction(),
  const HorizontalRuleConversionReaction(),
  const ImageUrlConversionReaction(),
  const DashConversionReaction(),
  //---- End Content Conversions ---

  UpdateSubTaskIndentAfterTaskDeletionReaction(),
]);
