import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';

import 'document_serialization.dart';

/// Applies software keyboard text deltas to a document.
class TextDeltasDocumentEditor {
  TextDeltasDocumentEditor({
    required this.editor,
    required this.document,
    required this.documentLayoutResolver,
    required this.selection,
    required this.composerPreferences,
    required this.composingRegion,
    required this.commonOps,
    required this.onPerformAction,
  });

  final Editor editor;
  final Document document;
  final DocumentLayoutResolver documentLayoutResolver;
  final ValueListenable<DocumentSelection?> selection;
  final ValueListenable<DocumentRange?> composingRegion;
  final ComposerPreferences composerPreferences;
  final CommonEditorOperations commonOps;

  /// Handles newlines that are inserted as text, e.g., "\n" in deltas.
  final void Function(TextInputAction) onPerformAction;

  late DocumentImeSerializer _serializedDoc;
  late TextEditingValue _previousImeValue;
  TextEditingValue? _nextImeValue;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    editorImeDeltasLog.fine("Incoming deltas:");
    for (final delta in textEditingDeltas) {
      editorImeDeltasLog.fine(delta);
    }

    // Apply deltas to the document.
    editorImeLog.fine("Serializing document to perform IME operations");
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
    );

    _previousImeValue = TextEditingValue(
      text: _serializedDoc.imeText,
      selection: selection.value != null
          ? _serializedDoc.documentToImeSelection(selection.value!)
          : const TextSelection.collapsed(offset: -1),
      composing: _serializedDoc.documentToImeRange(_serializedDoc.composingRegion),
    );

    // Start an editor transaction so that all changes made during this delta
    // application is considered a single undo-able change.
    editor.startTransaction();

    for (final delta in textEditingDeltas) {
      editorImeLog.info("---------------------------------------------------");

      editorImeLog.info("Applying delta: $delta");

      _nextImeValue = delta.apply(_previousImeValue);
      if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta);
      } else if (delta is TextEditingDeltaReplacement) {
        _applyReplacement(delta);
      } else if (delta is TextEditingDeltaDeletion) {
        _applyDeletion(delta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _applyNonTextChange(delta);
      } else {
        editorImeLog.shout("Unknown IME delta type: ${delta.runtimeType}");
      }

      editorImeLog.info("---------------------------------------------------");
    }

    // Update the editor's IME composing region based on the composing region
    // for the last delta. If the version of our document serialized hidden
    // characters in the IME, adjust for those hidden characters before setting
    // the IME composing region.
    editorImeLog.fine("After applying all deltas, converting the final composing region to a document range.");
    editorImeLog.fine("Raw IME delta composing region: ${textEditingDeltas.last.composing}");

    DocumentRange? docComposingRegion = _calculateNewComposingRegion(textEditingDeltas);

    if (docComposingRegion != composingRegion.value) {
      editor.execute([
        ChangeComposingRegionRequest(
          docComposingRegion,
        ),
      ]);
    }
    editorImeLog.fine("Document composing region: ${composingRegion.value}");

    // End the editor transaction for all deltas in this call.
    editor.endTransaction();

    _nextImeValue = null;
  }

  void _applyInsertion(TextEditingDeltaInsertion delta) {
    editorImeLog.fine('Inserted text: "${delta.textInserted}"');
    editorImeLog.fine("Insertion offset: ${delta.insertionOffset}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.textInserted == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android, newlines are only reported here. So, on Android,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android) {
        editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
        onPerformAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }

      // Update the local IME value that changes with each delta.
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();

      // Update the local IME value that changes with each delta.
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    editorImeLog.fine(
        "Inserting text: '${delta.textInserted}', at insertion offset: ${delta.insertionOffset}, with ime selection: ${delta.selection}");

    final insertionPosition = TextPosition(
      offset: delta.insertionOffset,
      affinity: delta.selection.affinity,
    );

    if (delta.textInserted == ' ' && _serializedDoc.isPositionInsidePlaceholder(insertionPosition)) {
      // The IME is trying to insert a space inside the invisible range. This is a situation that happens
      // on iOS when the user is composing a character at the beginning of a node using a korean keyboard.
      // The IME deletes the first visible character and the space from the invisible characters,
      // them it inserts the space back. We already adjust the deletion to avoid deleting the invisible space,
      // so we should ignore this insertion.
      //
      // For more information, see #1828.
      return;
    }

    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = _serializedDoc.imeToDocumentSelection(
      TextSelection.fromPosition(insertionPosition),
    )!;

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    insert(insertionSelection, delta.textInserted);

    // Update the IME to document serialization based on the insertion changes.
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
      _serializedDoc.didPrependPlaceholder ? PrependedCharacterPolicy.include : PrependedCharacterPolicy.exclude,
    );
  }

  void _applyReplacement(TextEditingDeltaReplacement delta) {
    editorImeLog.fine("Text replaced: '${delta.textReplaced}'");
    editorImeLog.fine("Replacement text: '${delta.replacementText}'");
    editorImeLog.fine("Replaced range: ${delta.replacedRange}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.replacementText == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android, newlines are only reported here. So, on Android,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android) {
        editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
        onPerformAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping replacement delta because its a newline");
      }
      return;
    }

    if (delta.replacementText == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    replace(delta.replacedRange, delta.replacementText);

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    // Update the IME to document serialization based on the replacement changes.
    // It's possible that the replacement text have a different length from the replaced text.
    // Therefore, we need to update our mapping from the IME positions to document positions.
    _serializedDoc = DocumentImeSerializer(
      document,
      selection.value!,
      composingRegion.value,
      _serializedDoc.didPrependPlaceholder ? PrependedCharacterPolicy.include : PrependedCharacterPolicy.exclude,
    );
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");

    DocumentSelection? docSelection = _calculateNewDocumentSelection(delta);
    DocumentRange? docComposingRegion = _calculateNewComposingRegion([delta]);

    if (docSelection != null) {
      // We got a selection from the platform.
      // This could happen in some software keyboards, like GBoard,
      // where the user can swipe over the spacebar to change the selection.
      editor.execute([
        ChangeSelectionRequest(
          docSelection,
          docSelection.isCollapsed ? SelectionChangeType.placeCaret : SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(docComposingRegion),
      ]);
    }

    // Update the local IME value that changes with each delta.
    _previousImeValue = delta.apply(_previousImeValue);
  }

  void insert(DocumentSelection insertionSelection, String textInserted) {
    editorImeLog.fine('Inserting "$textInserted" at position "$insertionSelection"');
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = selection.value;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = _insertPlainText(
      insertionSelection.extent,
      textInserted,
    );
    editorImeLog.fine("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      editor.execute([
        ChangeSelectionRequest(
          selectionBeforeInsertion,
          SelectionChangeType.placeCaret,
          SelectionReason.contentChange,
        ),
      ]);
    }
  }

  bool _insertPlainText(
    DocumentPosition insertionPosition,
    String text,
  ) {
    editorOpsLog.fine('Attempting to insert "$text" at position: $insertionPosition');

    DocumentNode? insertionNode = document.getNodeById(insertionPosition.nodeId);
    if (insertionNode == null) {
      editorOpsLog.warning('Attempted to insert text using a non-existing node');
      return false;
    }

    if (insertionPosition.nodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      commonOps.insertBlockLevelNewline();

      // After inserting a block level new line, the selection changes to another node.
      // Therefore, we need to update the insertion position.
      insertionNode = document.getNodeById(selection.value!.extent.nodeId)!;
      insertionPosition = DocumentPosition(nodeId: insertionNode.id, nodePosition: insertionNode.endPosition);
    }

    if (insertionNode is! TextNode || insertionPosition.nodePosition is! TextNodePosition) {
      editorOpsLog.fine(
          "Couldn't insert text because Super Editor doesn't know how to handle a node of type: $insertionNode, with position: ${insertionPosition.nodePosition}");
      return false;
    }

    editorOpsLog.fine("Executing text insertion command.");
    editorOpsLog.finer("Text before insertion: '${insertionNode.text.text}'");
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: insertionPosition),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      InsertTextRequest(
        documentPosition: insertionPosition,
        textToInsert: text,
        attributions: composerPreferences.currentAttributions,
      ),
    ]);
    editorOpsLog.finer("Text after insertion: '${insertionNode.text.text}'");

    return true;
  }

  void replace(TextRange replacedRange, String replacementText) {
    final replacementSelection = _serializedDoc.imeToDocumentSelection(TextSelection(
      baseOffset: replacedRange.start,
      // TODO: the delta API is wrong for TextRange.end, it should be exclusive,
      //       but it's implemented as inclusive. Change this code when Flutter
      //       fixes the problem.
      extentOffset: replacedRange.end,
    ));

    if (replacementSelection != null) {
      editor.execute([
        ChangeSelectionRequest(
          replacementSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.contentChange,
        ),
      ]);
    }
    editorImeLog.fine("Replacing selection: $replacementSelection");
    editorImeLog.fine('With text: "$replacementText"');

    if (replacementText == "\n") {
      onPerformAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSelectionToDelete = _serializedDoc.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

    if (docSelectionToDelete == null) {
      final selectedNodeIndex = document.getNodeIndexById(
        selection.value!.extent.nodeId,
      );
      // The user is trying to delete upstream at the start of a node.
      // This action requires intervention because the IME doesn't know
      // that there's more content before this node. Instruct the editor
      // to run a delete action upstream, which will take the desired
      // "backspace" behavior at the start of this node.
      editor.execute([
        DeleteUpstreamAtBeginningOfNodeRequest(
          document.getNodeAt(selectedNodeIndex)!,
        ),
      ]);
      return;
    }

    editorImeLog.fine("Running selection deletion operation");
    editor.execute([
      ChangeSelectionRequest(
        docSelectionToDelete,
        docSelectionToDelete.isCollapsed ? SelectionChangeType.collapseSelection : SelectionChangeType.expandSelection,
        SelectionReason.contentChange,
      ),
    ]);
    commonOps.deleteSelection();
  }

  void insertNewline() {
    if (_nextImeValue != null) {
      _insertNewlineInDeltas();
    } else {
      _insertNewlineFromHardwareKey();
    }
  }

  void _insertNewlineInDeltas() {
    assert(selection.value != null && selection.value!.isCollapsed);

    editorOpsLog.fine("Inserting block-level newline");

    final caretPosition = selection.value!.extent;
    final extentNode = document.getNodeById(caretPosition.nodeId)!;

    final newNodeId = Editor.createNodeId();

    if (extentNode is ListItemNode) {
      if (extentNode.text.text.isEmpty) {
        // The list item is empty. Convert it to a paragraph.
        editorOpsLog.finer(
            "The current node is an empty list item. Converting it to a paragraph instead of inserting block-level newline.");
        editor.execute([
          ConvertTextNodeToParagraphRequest(nodeId: extentNode.id),
        ]);
        return;
      }

      // Split the list item into two.
      editorOpsLog.finer("Splitting list item in two.");
      editor.execute([
        SplitListItemRequest(
          nodeId: extentNode.id,
          splitPosition: caretPosition.nodePosition as TextNodePosition,
          newNodeId: newNodeId,
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      ]);
      final newListItemNode = document.getNodeById(newNodeId)!;

      _updateImeRangeMappingAfterNodeSplit(originNode: extentNode, newNode: newListItemNode);
    } else if (extentNode is ParagraphNode) {
      // Split the paragraph into two. This includes headers, blockquotes, and
      // any other block-level paragraph.
      final currentExtentPosition = caretPosition.nodePosition as TextNodePosition;
      final endOfParagraph = extentNode.endPosition;

      editorOpsLog.finer("Splitting paragraph in two.");
      editor.execute([
        SplitParagraphRequest(
          nodeId: extentNode.id,
          splitPosition: currentExtentPosition,
          newNodeId: newNodeId,
          replicateExistingMetadata: currentExtentPosition.offset != endOfParagraph.offset,
        ),
      ]);

      final newTextNode = document.getNodeById(newNodeId)!;
      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newTextNode.id,
              nodePosition: newTextNode.beginningPosition,
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      ]);

      _updateImeRangeMappingAfterNodeSplit(originNode: extentNode, newNode: newTextNode);
    } else if (caretPosition.nodePosition is UpstreamDownstreamNodePosition) {
      final extentPosition = caretPosition.nodePosition as UpstreamDownstreamNodePosition;
      if (extentPosition.affinity == TextAffinity.downstream) {
        // The caret sits on the downstream edge of block-level content. Insert
        // a new paragraph after this node.
        editorOpsLog.finer("Inserting paragraph after block-level node.");
        editor.execute([
          InsertNodeAfterNodeRequest(
            existingNodeId: extentNode.id,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(),
            ),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        ]);
      } else {
        // The caret sits on the upstream edge of block-level content. Insert
        // a new paragraph before this node.
        editorOpsLog.finer("Inserting paragraph before block-level node.");
        editor.execute([
          InsertNodeBeforeNodeRequest(
            existingNodeId: extentNode.id,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(),
            ),
          ),
        ]);
      }
    } else if (extentNode is TaskNode) {
      if (extentNode.text.text.isEmpty) {
        // The task is empty. Convert it to a paragraph.
        editor.execute([
          ConvertTextNodeToParagraphRequest(nodeId: extentNode.id),
        ]);
        return;
      }

      final splitOffset = (caretPosition.nodePosition as TextNodePosition).offset;

      editor.execute([
        SplitExistingTaskRequest(
          existingNodeId: extentNode.id,
          splitOffset: splitOffset,
          newNodeId: newNodeId,
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      ]);
      final newTaskNode = document.getNodeById(newNodeId)!;

      _updateImeRangeMappingAfterNodeSplit(originNode: extentNode, newNode: newTaskNode);
    } else {
      // We don't know how to handle this type of node position. Do nothing.
      editorOpsLog.fine("Can't insert new block-level inline because we don't recognize the selected content type.");
      return;
    }
  }

  void _insertNewlineFromHardwareKey() {
    if (!selection.value!.isCollapsed) {
      commonOps.deleteSelection();
    }
    commonOps.insertBlockLevelNewline();
  }

  /// Updates mappings from Document nodes to IME ranges and IME ranges to Document nodes.
  void _updateImeRangeMappingAfterNodeSplit({
    required DocumentNode originNode,
    required DocumentNode newNode,
  }) {
    final newImeValue = _nextImeValue!;
    final imeNewlineIndex = newImeValue.text.indexOf("\n");
    final topImeToDocTextRange = TextRange(start: 0, end: imeNewlineIndex);
    final bottomImeToDocTextRange = TextRange(start: imeNewlineIndex + 1, end: newImeValue.text.length);

    // Update mapping from Document nodes to IME ranges.
    _serializedDoc.docTextNodesToImeRanges[originNode.id] = topImeToDocTextRange;
    _serializedDoc.docTextNodesToImeRanges[newNode.id] = bottomImeToDocTextRange;

    // Remove old mapping from IME TextRange to Document node.
    late final MapEntry<TextRange, String> oldImeToDoc;
    for (final entry in _serializedDoc.imeRangesToDocTextNodes.entries) {
      if (entry.value != originNode.id) {
        continue;
      }

      oldImeToDoc = entry;
      break;
    }
    _serializedDoc.imeRangesToDocTextNodes.remove(oldImeToDoc.key);

    // Update and add mapping from IME TextRanges to Document nodes.
    _serializedDoc.imeRangesToDocTextNodes[topImeToDocTextRange] = originNode.id;
    _serializedDoc.imeRangesToDocTextNodes[bottomImeToDocTextRange] = newNode.id;
  }

  DocumentSelection? _calculateNewDocumentSelection(TextEditingDelta delta) {
    if (CurrentPlatform.isWeb &&
        delta.selection.isCollapsed &&
        _serializedDoc.isPositionInsidePlaceholder(delta.selection.extent)) {
      // On web, pressing CMD + LEFT ARROW generates a non-text delta moving
      // the selection to the first character. However, the first character is in a region
      // invisible to the user. Adjust the document selection to be the first visible character.
      // Expanded selection are already adjusted by the serializer.
      return _serializedDoc.imeToDocumentSelection(
        TextSelection.collapsed(
          offset: _serializedDoc.firstVisiblePosition.offset,
        ),
      );
    }
    return _serializedDoc.imeToDocumentSelection(delta.selection);
  }

  DocumentRange? _calculateNewComposingRegion(List<TextEditingDelta> deltas) {
    final lastDelta = deltas.last;
    if (CurrentPlatform.isWeb &&
        lastDelta.composing.isCollapsed &&
        _serializedDoc.isPositionInsidePlaceholder(TextPosition(offset: lastDelta.composing.end))) {
      // On web, pressing CMD + LEFT ARROW generates a non-text delta moving
      // the selection, and possibly the composing region to the first character. However, the first character
      // is in a region invisible to the user. Adjust the document composing region to be the first visible character.
      // Expanded regions are already adjusted by the serializer.
      return _serializedDoc.imeToDocumentRange(
        TextRange.collapsed(
          _serializedDoc.firstVisiblePosition.offset,
        ),
      );
    }

    if (_serializedDoc.imeText.length < lastDelta.composing.end) {
      // The IME is composing, but the composing region is out of our text bounds. This can happen if the delta
      // handling causes our text to be smaller than the IME's text.
      //
      // For example, when using the markdown plugin, typing "~b~" causes the text to be converted to "b"
      // with strikethrough. The ~ character triggers a composition start, but the IME's composing region is still
      // at the end of "~b~", which is out of our text bounds. This out of bounds index causes our IME range
      // mapping to fail.
      //
      // Clear the composing region.
      return null;
    }

    return _serializedDoc.imeToDocumentRange(lastDelta.composing);
  }
}
