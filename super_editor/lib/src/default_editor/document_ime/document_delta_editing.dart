import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_serialization.dart';

/// Applies software keyboard text deltas to a document.
class TextDeltasDocumentEditor {
  TextDeltasDocumentEditor({
    required this.editor,
    required this.selection,
    required this.composingRegion,
    required this.commonOps,
    required this.onPerformAction,
  });

  final DocumentEditor editor;
  final ValueNotifier<DocumentSelection?> selection;
  final ValueNotifier<DocumentRange?> composingRegion;
  final CommonEditorOperations commonOps;

  /// The composing region in the IME.
  ///
  /// Typically, this will be the same composing region we get from the
  /// last [TextEditingDelta] received.
  ///
  /// However, in the cases where we receive a non-text delta in the same
  /// batch where we receive a text delta, this range might be adjusted
  /// to match our new content after the text delta is applied. This
  /// can happen, for example, in a paragraph split or a paragraph merge,
  /// where our changes to the document causes our editing text
  /// to be different from what the OS thinks it is.
  ///
  /// The composing region is adjusted only when we get non-text deltas.
  TextRange _imeComposingRegion = const TextRange(start: -1, end: -1);

  /// Callback invoked when the client should handle a given [TextInputAction].
  ///
  /// Typically, [TextInputAction]s are reported through a different part of Flutter's IME
  /// API. However, some actions, on some platforms, are converted into text editing
  /// deltas, rather than reported as explicit actions. For example, on Android, the `newline`
  /// action is reported as a text insertion with a `\n` character. That change is intercepted
  /// by this editor and reported as a [TextInputAction.newline] instead.
  final void Function(TextInputAction action) onPerformAction;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    // Apply deltas to the document.
    late DocumentImeSerializer serializedDocBeforeDelta;
    for (final delta in textEditingDeltas) {
      editorImeLog.info("---------------------------------------------------");
      editorImeLog.fine("Serializing document to perform IME operations");
      serializedDocBeforeDelta = DocumentImeSerializer(
        editor.document,
        selection.value!,
        composingRegion.value,
      );

      editorImeLog.info("Applying delta: $delta");
      if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta, serializedDocBeforeDelta);
      } else if (delta is TextEditingDeltaReplacement) {
        _applyReplacement(delta, serializedDocBeforeDelta);
      } else if (delta is TextEditingDeltaDeletion) {
        _applyDeletion(delta, serializedDocBeforeDelta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _applyNonTextChange(delta, serializedDocBeforeDelta);
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
    editorImeLog
        .fine("Serializing the latest document and selection to use to compute final document composing region.");
    final finalSerializedDoc = DocumentImeSerializer(
      editor.document,
      selection.value!,
      null,
      serializedDocBeforeDelta.didPrependPlaceholder //
          ? PrependedCharacterPolicy.include
          : PrependedCharacterPolicy.exclude,
    );
    editorImeLog.fine("Raw IME delta composing region: $_imeComposingRegion");
    composingRegion.value = finalSerializedDoc.imeToDocumentRange(_imeComposingRegion);
    editorImeLog.fine("Document composing region: ${composingRegion.value}");
  }

  void _applyInsertion(TextEditingDeltaInsertion delta, DocumentImeSerializer docSerializer) {
    _imeComposingRegion = delta.composing;

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

    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = docSerializer.imeToDocumentSelection(
      TextSelection.fromPosition(TextPosition(
        offset: delta.insertionOffset,
        affinity: delta.selection.affinity,
      )),
    )!;

    insert(
      insertionSelection,
      delta.textInserted,
    );
  }

  void _applyReplacement(TextEditingDeltaReplacement delta, DocumentImeSerializer docSerializer) {
    _imeComposingRegion = delta.composing;

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

    replace(delta.replacedRange, delta.replacementText, docSerializer);
  }

  void _applyDeletion(TextEditingDeltaDeletion delta, DocumentImeSerializer docSerializer) {
    _imeComposingRegion = delta.composing;

    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange, docSerializer);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta, DocumentImeSerializer docSerializer) {
    editorImeLog.fine("Non-text change:");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");

    final diff = computeDiff(delta.oldText, docSerializer.toTextEditingValue().text);

    final newSelectionRange = _transformTextRange(delta.selection, diff);
    final newComposingRange = _transformTextRange(delta.composing, diff);

    // TODO: handle upstream selections.
    final docSelection = docSerializer.imeToDocumentSelection(
      delta.selection.copyWith(
        baseOffset: newSelectionRange.start,
        extentOffset: newSelectionRange.end,
      ),
    );

    _imeComposingRegion = newComposingRange;

    if (docSelection != null) {
      // We got a selection from the platform.
      // This could happen in some software keyboards, like GBoard,
      // where the user can swipe over the spacebar to change the selection.
      selection.value = docSelection;
    }
  }

  /// Transforms a text [range] given a list of [diff] operations that happened.
  ///
  /// For example, if text was deleted before the [range], the result subtracts
  /// the deleted length from the [range].
  TextRange _transformTextRange(TextRange range, List<TextDiffOperation> diff) {
    TextRange transformedSelection = range;

    for (final op in diff) {
      if (op.range.start > range.end) {
        // The operation happened after the range we care about.
        // No transformation is needed.
        continue;
      }

      // Some characters were added or removed before our range.
      final diffLength = (op.range.end - op.range.start).abs();
      final adjustment = op.operation == TextDiffOperationKind.insertion //
          ? diffLength
          : -diffLength;

      transformedSelection = TextRange(
        start: transformedSelection.start + adjustment,
        end: transformedSelection.end + adjustment,
      );

      // TODO: handle expanded selections.
      // TODO: handle upstream selections.
    }

    return transformedSelection;
  }

  void insert(DocumentSelection insertionSelection, String textInserted) {
    editorImeLog.fine('Inserting "$textInserted" at position "$insertionSelection"');
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

  void replace(TextRange replacedRange, String replacementText, DocumentImeSerializer docSerializer) {
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
      onPerformAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);

    commonOps.convertParagraphByPatternMatching(
      selection.value!.extent.nodeId,
    );
  }

  void delete(TextRange deletedRange, DocumentImeSerializer docSerializer) {
    final rangeToDelete = deletedRange;
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

  void insertNewline() {
    if (!selection.value!.isCollapsed) {
      commonOps.deleteSelection();
    }
    commonOps.insertBlockLevelNewline();
  }
}

/// Computes the difference between [oldText] and [newText].
///
/// The result can contain a single insertion, a single deletion,
/// or a deletion followed by an insertion.
///
/// Results in an empty list if the two strings are equal.
@visibleForTesting
List<TextDiffOperation> computeDiff(String oldText, String newText) {
  if (oldText == newText) {
    return <TextDiffOperation>[];
  }

  final oldTextLength = oldText.length;
  final newTextLength = newText.length;
  final shortestTextLength = min(oldTextLength, newTextLength);

  // The number of characters that are present at the start of both oldText and newText.
  int? commonPrefixLength;

  // The number of characters that are present at the end of both oldText and newText.
  int? commonSuffixLength;

  // Compute the common prefix.
  for (int i = 0; i < shortestTextLength; i++) {
    if (oldText[i] != newText[i]) {
      commonPrefixLength = i;
      break;
    }
  }

  // When commonPrefixLength is null, it means we don't have any character in the shortest
  // text that isn't present in the longest text.
  // Therefore, the whole shortest text is considered the prefix.
  commonPrefixLength ??= shortestTextLength;

  // Compute the common suffix.
  for (int i = 1; i <= shortestTextLength; i++) {
    if (oldText[oldTextLength - i] != newText[newTextLength - i]) {
      commonSuffixLength = i - 1;
      break;
    }
  }

  // When commonSuffixLength is null, it means we don't have any character in the shortest
  // text that isn't present in the longest text.
  // Therefore, the whole shortest text is considered the suffix.
  commonSuffixLength ??= shortestTextLength;

  if (commonSuffixLength + commonPrefixLength > shortestTextLength) {
    // We have a common prefix which intersects with the common suffix.
    //
    // For example, consider the following sentences:
    // "Before a new line is found in a new document" and "Before a new document".
    //
    // We have a prefix of "Before a new " and a suffix of " a new document".
    // This would consider the new text as "Before a new  a new document".
    //
    // We keep the longest sequence and adjust the other.
    if (commonPrefixLength > commonSuffixLength) {
      commonSuffixLength = shortestTextLength - commonPrefixLength;
    } else {
      commonPrefixLength = shortestTextLength - commonSuffixLength;
    }
  }

  final changes = <TextDiffOperation>[];

  if (commonPrefixLength + commonSuffixLength < oldTextLength) {
    // Some content was removed.
    changes.add(
      TextDiffOperation(
        operation: TextDiffOperationKind.deletion,
        range: TextRange(
          start: commonPrefixLength,
          end: oldTextLength - commonSuffixLength,
        ),
      ),
    );
  }

  if (commonPrefixLength + commonSuffixLength < newTextLength) {
    // Some content was inserted.
    changes.add(
      TextDiffOperation(
        operation: TextDiffOperationKind.insertion,
        range: TextRange(
          start: commonPrefixLength,
          end: newTextLength - commonSuffixLength,
        ),
      ),
    );
  }

  return changes;
}

/// An [operation] that changes a text in the given [range].
@visibleForTesting
class TextDiffOperation {
  TextDiffOperation({
    required this.operation,
    required this.range,
  });

  /// An operation which modified the content at the [range].
  final TextDiffOperationKind operation;

  /// The range where the [operation] happened.
  final TextRange range;

  @override
  String toString() {
    return '[TextDiffOperation] - operation=$operation, range=$range';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextDiffOperation && //
          runtimeType == other.runtimeType &&
          operation == other.operation &&
          range == other.range;

  @override
  int get hashCode => operation.hashCode ^ range.hashCode;
}

@visibleForTesting
enum TextDiffOperationKind {
  insertion,
  deletion,
}
