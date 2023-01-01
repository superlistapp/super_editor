import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_serialization.dart';

/// Applies software keyboard text deltas to a document.
class TextDeltasDocumentEditor {
  const TextDeltasDocumentEditor({
    required this.editor,
    required this.selection,
    required this.imeComposingRegion,
    required this.commonOps,
  });

  final DocumentEditor editor;
  final ValueNotifier<DocumentSelection?> selection;
  final ValueNotifier<TextRange> imeComposingRegion;
  final CommonEditorOperations commonOps;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    // Make note of whether the version of the document before these
    // deltas included hidden characters.
    final didPrependPlaceholderInPreviousDocument = DocumentImeSerializer(
      editor.document,
      selection.value!,
    ).didPrependPlaceholder;

    // Apply deltas to the document.
    for (final delta in textEditingDeltas) {
      editorImeLog.info("Applying delta: $delta");
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
    }

    // Update the editor's IME composing region based on the composing region
    // for the last delta. If the version of our document serialized hidden
    // characters in the IME, adjust for those hidden characters before setting
    // the IME composing region.
    imeComposingRegion.value = didPrependPlaceholderInPreviousDocument
        ? TextRange(
            start: textEditingDeltas.last.composing.start - 2,
            end: textEditingDeltas.last.composing.end - 2,
          )
        : textEditingDeltas.last.composing;
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
        performAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }
      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    editorImeLog.fine(
        "Inserting text: '${delta.textInserted}', at insertion offset: ${delta.insertionOffset}, with ime selection: ${delta.selection}");

    insert(
      TextPosition(offset: delta.insertionOffset, affinity: delta.selection.affinity),
      delta.textInserted,
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
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
        performAction(TextInputAction.newline);
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
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    // editorImeLog.fine("App-side selection - ${currentTextEditingValue.selection}");
    // editorImeLog.fine("App-side composing - ${currentTextEditingValue.composing}");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");
    // currentTextEditingValue = _currentTextEditingValue.copyWith(composing: delta.composing);
  }

  void insert(TextPosition insertionPosition, String textInserted) {
    if (textInserted == "\n") {
      // Newlines are handled in performAction()
      return;
    }

    editorImeLog.fine('Inserting "$textInserted" at position "$insertionPosition"');
    editorImeLog.fine("Serializing document to perform IME operation");
    final docSerializer = DocumentImeSerializer(
      editor.document,
      selection.value!,
    );
    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = docSerializer.imeToDocumentSelection(
      TextSelection.fromPosition(insertionPosition),
    );
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = selection.value;
    selection.value = insertionSelection;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = commonOps.insertPlainText(textInserted);
    editorImeLog.fine("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      selection.value = selectionBeforeInsertion;
    }

    commonOps.convertParagraphByPatternMatching(
      selection.value!.extent.nodeId,
    );
  }

  void replace(TextRange replacedRange, String replacementText) {
    final docSerializer = DocumentImeSerializer(
      editor.document,
      selection.value!,
    );

    final replacementSelection = docSerializer.imeToDocumentSelection(TextSelection(
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
      performAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);

    commonOps.convertParagraphByPatternMatching(
      selection.value!.extent.nodeId,
    );
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSerializer = DocumentImeSerializer(
      editor.document,
      selection.value!,
    );
    final docSelectionToDelete = docSerializer.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

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
        commonOps.deleteUpstream();
        editorImeLog.fine("Deleted upstream. New selection: ${selection.value}");
        return;
      }
    }

    editorImeLog.fine("Running selection deletion operation");
    selection.value = docSelectionToDelete;
    commonOps.deleteSelection();
  }

  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        if (!selection.value!.isCollapsed) {
          commonOps.deleteSelection();
        }
        commonOps.insertBlockLevelNewline();
        break;
      case TextInputAction.none:
        // no-op
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
      case TextInputAction.next:
      case TextInputAction.previous:
      case TextInputAction.continueAction:
      case TextInputAction.join:
      case TextInputAction.route:
      case TextInputAction.emergencyCall:
      case TextInputAction.unspecified:
        editorImeLog.warning("User pressed unhandled action button: $action");
        break;
    }
  }
}
