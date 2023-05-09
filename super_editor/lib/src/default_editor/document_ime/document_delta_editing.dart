import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_serialization.dart';

/// Applies software keyboard text deltas to a document.
class TextDeltasDocumentEditor {
  TextDeltasDocumentEditor({
    required this.editor,
    required this.documentLayoutResolver,
    required this.selection,
    required this.composerPreferences,
    required this.composingRegion,
    required this.commonOps,
    required this.onPerformAction,
  });

  final DocumentEditor editor;
  final DocumentLayoutResolver documentLayoutResolver;
  final ValueNotifier<DocumentSelection?> selection;
  final ComposerPreferences composerPreferences;
  final ValueNotifier<DocumentRange?> composingRegion;
  final CommonEditorOperations commonOps;

  /// Handles newlines that are inserted as text, e.g., "\n" in deltas.
  final void Function(TextInputAction) onPerformAction;

  late DocumentImeSerializer _serializedDoc;
  late TextEditingValue _previousImeValue;
  TextEditingValue? _nextImeValue;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    // Apply deltas to the document.
    editorImeLog.fine("Serializing document to perform IME operations");
    _serializedDoc = DocumentImeSerializer(
      editor.document,
      selection.value!,
      composingRegion.value,
    );

    _previousImeValue = TextEditingValue(
      text: _serializedDoc.imeText,
      selection: selection.value != null
          ? _serializedDoc.documentToImeSelection(selection.value!)
          : const TextSelection.collapsed(offset: -1),
    );

    for (final delta in textEditingDeltas) {
      editorImeLog.info("---------------------------------------------------");

      print("Delta: \n$delta\n");

      editorImeLog.info("Applying delta: $delta");

      _nextImeValue = delta.apply(_previousImeValue);
      if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta);
      } else if (delta is TextEditingDeltaReplacement) {
        _applyReplacement(delta);
      } else if (delta is TextEditingDeltaDeletion) {
        _applyDeletion(delta);
        print("Selection after _applyDeletion()\n${selection.value}");
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
    composingRegion.value = _serializedDoc.imeToDocumentRange(textEditingDeltas.last.composing);
    editorImeLog.fine("Document composing region: ${composingRegion.value}");

    print("Selection at the end of all deltas: ${selection.value}");

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
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
        onPerformAction(TextInputAction.newline);
        return;
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }

      // Update the local IME value that changes with each delta
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();

      // Update the local IME value that changes with each delta
      _previousImeValue = delta.apply(_previousImeValue);

      return;
    }

    editorImeLog.fine(
        "Inserting text: '${delta.textInserted}', at insertion offset: ${delta.insertionOffset}, with ime selection: ${delta.selection}");

    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = _serializedDoc.imeToDocumentSelection(
      TextSelection.fromPosition(TextPosition(
        offset: delta.insertionOffset,
        affinity: delta.selection.affinity,
      )),
    )!;

    insert(insertionSelection, delta.textInserted);

    // Update the local IME value that changes with each delta
    _previousImeValue = delta.apply(_previousImeValue);

    // Update the IME to document serialization based on the insertion changes.
    _serializedDoc = DocumentImeSerializer(
      editor.document,
      selection.value!,
      composingRegion.value,
    )..imeText = _previousImeValue.text;

    editorOpsLog.fine("Updating Document Composer selection after text insertion.");
    final newSelection = _serializedDoc.imeToDocumentSelection(delta.selection)!;
    selection.value = newSelection;
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
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
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

    // Update the local IME value that changes with each delta
    _previousImeValue = delta.apply(_previousImeValue);
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    // Update the local IME value that changes with each delta
    _previousImeValue = delta.apply(_previousImeValue);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");

    print("");
    print("Non-text change:");
    print("IME selection: \n${delta.selection}\n");
    print("Existing composer selection: \n${selection.value}\n");

    // final docSelection = DocumentImeSerializer(
    //   editor.document,
    //   selection.value!,
    //   null,
    // ).imeToDocumentSelection(delta.selection);
    final docSelection = _serializedDoc.imeToDocumentSelection(delta.selection);
    print("New composer selection: \n$docSelection\n");

    if (docSelection != null) {
      // We got a selection from the platform.
      // This could happen in some software keyboards, like GBoard,
      // where the user can swipe over the spacebar to change the selection.
      selection.value = docSelection;
    }

    // Update the local IME value that changes with each delta
    _previousImeValue = delta.apply(_previousImeValue);
  }

  void insert(DocumentSelection insertionSelection, String textInserted) {
    editorImeLog.fine('Inserting "$textInserted" at position "$insertionSelection"');
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = selection.value;
    selection.value = insertionSelection;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = _insertPlainText(
      insertionSelection.extent,
      textInserted,
    );
    editorImeLog.fine("Insertion successful? $didInsert");
    print("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      selection.value = selectionBeforeInsertion;
    }

    commonOps.convertParagraphByPatternMatching(
      selection.value!.extent.nodeId,
    );
  }

  bool _insertPlainText(
    DocumentPosition insertionPosition,
    String text,
  ) {
    editorOpsLog.fine('Attempting to insert "$text" at position: $insertionPosition');

    final extentNodePosition = insertionPosition.nodePosition;
    if (extentNodePosition is UpstreamDownstreamNodePosition) {
      editorOpsLog.fine("The selected position is an UpstreamDownstreamPosition. Inserting new paragraph first.");
      commonOps.insertBlockLevelNewline();
    }

    final extentNode = editor.document.getNodeById(insertionPosition.nodeId)!;
    if (extentNode is! TextNode || extentNodePosition is! TextNodePosition) {
      editorOpsLog.fine(
          "Couldn't insert text because Super Editor doesn't know how to handle a node of type: $extentNode, with position: $extentNodePosition");
      return false;
    }

    final textNode = editor.document.getNodeById(insertionPosition.nodeId) as TextNode;

    editorOpsLog.fine("Executing text insertion command.");
    editorOpsLog.finer("Text before insertion: '${textNode.text.text}'");
    editor.executeCommand(
      InsertTextCommand(
        documentPosition: insertionPosition,
        textToInsert: text,
        attributions: composerPreferences.currentAttributions,
      ),
    );
    editorOpsLog.finer("Text after insertion: '${textNode.text.text}'");
    print("Text after insertion: '${textNode.text.text}'");

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
      selection.value = replacementSelection;
    }
    editorImeLog.fine("Replacing selection: $replacementSelection");
    editorImeLog.fine('With text: "$replacementText"');

    if (replacementText == "\n") {
      onPerformAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);

    commonOps.convertParagraphByPatternMatching(
      selection.value!.extent.nodeId,
    );
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSelectionToDelete = _serializedDoc.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");
    print("Doc selection to delete: $docSelectionToDelete");

    if (docSelectionToDelete == null) {
      final selectedNodeIndex = editor.document.getNodeIndexById(
        selection.value!.extent.nodeId,
      );
      if (selectedNodeIndex > 0) {
        // The user is trying to delete upstream at the start of a node.
        // This action requires intervention because the IME doesn't know
        // that there's more content before this node. Instruct the editor
        // to run a delete action upstream, which will take the desired
        // "backspace" behavior at the start of this node.
        print("Running delete upstream");
        final node = editor.document.getNodeAt(selectedNodeIndex)!;
        _deleteUpstream(DocumentPosition(nodeId: node.id, nodePosition: node.beginningPosition));
        editorImeLog.fine("Deleted upstream. New selection: ${selection.value}");
        return;
      }
    }

    editorImeLog.fine("Running selection deletion operation");
    print("Running standard deletion");
    selection.value = docSelectionToDelete;
    commonOps.deleteSelection();
  }

  /// Deletes a unit of content that comes before the [DocumentComposer]'s
  /// selection extent, or deletes all selected content if the selection
  /// is not collapsed.
  ///
  /// In the case of text editing, deletes the character that appears before
  /// the caret.
  ///
  /// If the caret sits at the beginning of a content block, such as the
  /// beginning of a text node, and the upstream node is not visually selectable,
  /// then the upstream node is deleted and the caret is kept where it is.
  ///
  /// Returns [true] if content was deleted, or [false] if no upstream
  /// content exists.
  bool _deleteUpstream(DocumentPosition deletionPosition) {
    print("_deleteUpstream at position: $deletionPosition");
    final node = editor.document.getNodeById(deletionPosition.nodeId)!;

    // If the caret is at the beginning of a list item, unindent the list item.
    // if (node is ListItemNode && (composer.selection!.extent.nodePosition as TextNodePosition).offset == 0) {
    //   return unindentListItem();
    // }

    if (deletionPosition.nodePosition is UpstreamDownstreamNodePosition) {
      final nodePosition = deletionPosition.nodePosition as UpstreamDownstreamNodePosition;
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The caret is sitting on the downstream edge of block-level content. Delete the
        // whole block by replacing it with an empty paragraph.
        commonOps.replaceBlockNodeWithEmptyParagraphAndCollapsedSelection(deletionPosition.nodeId);

        return true;
      } else {
        // The caret is sitting on the upstream edge of block-level content and
        // the user is trying to delete upstream.
        //  * If the node above is an empty paragraph, delete it.
        //  * If the node above is non-selectable, delete it.
        //  * Otherwise, move the caret up to the node above.
        final nodeBefore = editor.document.getNodeBefore(node);
        if (nodeBefore == null) {
          return false;
        }

        final componentBefore = documentLayoutResolver().getComponentByNodeId(nodeBefore.id)!;

        if (nodeBefore is TextNode && nodeBefore.text.text.isEmpty) {
          editor.executeCommand(EditorCommandFunction((doc, transaction) {
            transaction.deleteNode(nodeBefore);
          }));
          return true;
        }

        if (!componentBefore.isVisualSelectionSupported()) {
          // The node/component above is not selectable. Delete it.
          commonOps.deleteNonSelectedNode(nodeBefore);
          return true;
        }

        return commonOps.moveSelectionToEndOfPrecedingNode();
      }
    }

    if (deletionPosition.nodePosition is TextNodePosition) {
      final textPosition = deletionPosition.nodePosition as TextNodePosition;
      print("Deleting upstream from a TextNodePosition: $textPosition");
      if (textPosition.offset == 0) {
        final nodeBefore = editor.document.getNodeBefore(node);
        if (nodeBefore == null) {
          return false;
        }

        print("YOLO");
        final componentBefore = documentLayoutResolver().getComponentByNodeId(nodeBefore.id)!;

        if (nodeBefore is TextNode) {
          // The caret is at the beginning of one TextNode and is preceded by
          // another TextNode. Merge the two TextNodes.
          print("Merging text node with upstream text node");
          return commonOps.mergeTextNodeWithUpstreamTextNode();
        } else if (!componentBefore.isVisualSelectionSupported()) {
          // The node/component above is not selectable. Delete it.
          commonOps.deleteNonSelectedNode(nodeBefore);
          return true;
        } else if ((node as TextNode).text.text.isEmpty) {
          // The caret is at the beginning of an empty TextNode and the preceding
          // node is not a TextNode. Delete the current TextNode and move the
          // selection up to the preceding node if exist.
          if (commonOps.moveSelectionToEndOfPrecedingNode()) {
            editor.executeCommand(EditorCommandFunction((doc, transaction) {
              transaction.deleteNode(node);
            }));
          }
          return true;
        } else {
          // The caret is at the beginning of a non-empty TextNode, and the
          // preceding node is not a TextNode. Move the document selection to the
          // preceding node.
          return commonOps.moveSelectionToEndOfPrecedingNode();
        }
      } else {
        return commonOps.deleteUpstreamCharacter();
      }
    }

    return false;
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
    final extentNode = editor.document.getNodeById(caretPosition.nodeId)!;

    final newNodeId = DocumentEditor.createNodeId();

    if (extentNode is ParagraphNode) {
      // Split the paragraph into two. This includes headers, blockquotes, and
      // any other block-level paragraph.
      final currentExtentPosition = caretPosition.nodePosition as TextNodePosition;
      final endOfParagraph = extentNode.endPosition;

      editorOpsLog.finer("Splitting paragraph in two.");
      editor.executeCommand(
        SplitParagraphCommand(
          nodeId: extentNode.id,
          splitPosition: currentExtentPosition,
          newNodeId: newNodeId,
          replicateExistingMetadata: currentExtentPosition.offset != endOfParagraph.offset,
        ),
      );

      final newTextNode = editor.document.getNodeById(newNodeId)!;
      selection.value = DocumentSelection.collapsed(
          position: DocumentPosition(
        nodeId: newTextNode.id,
        nodePosition: newTextNode.beginningPosition,
      ));

      final newImeValue = _nextImeValue!;
      final imeNewlineIndex = newImeValue.text.indexOf("\n");
      final topImeToDocTextRange = TextRange(start: 0, end: imeNewlineIndex);
      final bottomImeToDocTextRange = TextRange(start: imeNewlineIndex + 1, end: newImeValue.text.length);
      print("Breaking paragraph at newline insertion");
      print(
          " - text before newline: '${newImeValue.text.substring(topImeToDocTextRange.start, topImeToDocTextRange.end)}'");
      print(
          " - text after newline: '${newImeValue.text.substring(bottomImeToDocTextRange.start, bottomImeToDocTextRange.end)}'");
      print(" - new selection: ${newImeValue.selection}");

      // Update mapping from Document nodes to IME ranges.
      _serializedDoc.docTextNodesToImeRanges[extentNode.id] = topImeToDocTextRange;
      _serializedDoc.docTextNodesToImeRanges[newTextNode.id] = bottomImeToDocTextRange;

      // Remove old mapping from IME TextRange to Document node.
      late final MapEntry<TextRange, String> oldImeToDoc;
      for (final entry in _serializedDoc.imeRangesToDocTextNodes.entries) {
        if (entry.value != extentNode.id) {
          continue;
        }

        oldImeToDoc = entry;
        break;
      }
      _serializedDoc.imeRangesToDocTextNodes.remove(oldImeToDoc.key);

      // Update and add mapping from IME TextRanges to Document nodes.
      _serializedDoc.imeRangesToDocTextNodes[topImeToDocTextRange] = extentNode.id;
      _serializedDoc.imeRangesToDocTextNodes[bottomImeToDocTextRange] = newTextNode.id;
    } else if (caretPosition.nodePosition is UpstreamDownstreamNodePosition) {
      final extentPosition = caretPosition.nodePosition as UpstreamDownstreamNodePosition;
      if (extentPosition.affinity == TextAffinity.downstream) {
        // The caret sits on the downstream edge of block-level content. Insert
        // a new paragraph after this node.
        editorOpsLog.finer("Inserting paragraph after block-level node.");
        editor.executeCommand(EditorCommandFunction((doc, transaction) {
          transaction.insertNodeAfter(
            existingNode: extentNode,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(text: ''),
            ),
          );
        }));
      } else {
        // The caret sits on the upstream edge of block-level content. Insert
        // a new paragraph before this node.
        editorOpsLog.finer("Inserting paragraph before block-level node.");
        editor.executeCommand(EditorCommandFunction((doc, transaction) {
          transaction.insertNodeBefore(
            existingNode: extentNode,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(text: ''),
            ),
          );
        }));
      }
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
}
