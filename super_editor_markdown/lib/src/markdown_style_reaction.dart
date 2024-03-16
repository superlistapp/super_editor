import 'dart:math';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/document_to_markdown_serializer.dart';
import 'package:super_editor_markdown/src/markdown_to_document_parsing.dart';

/// A [SuperEditorPlugin] that finds inline Markdown syntax and converts it into
/// attributions.
///
/// Inline Markdown syntax includes things like `**token**` for bold, `*token*` for
/// italics, `~token~` for strikethrough, and `[token](url)` for hyperlinks.
///
/// When this plugin finds inline Markdown syntax, that syntax is removed when the corresponding
/// attribution is applied. For example, "**bold**" becomes "bold" with a bold attribution
/// applied to it.
///
/// This plugin only identifies spans of Markdown styles within individual [TextNode]s. Markdown
/// symbols that span [TextNode]s are not identified or applied. This is done for implementation
/// simplicity. If multi-node syntax recognition and application is needed, this plugin can
/// be updated for that purpose.
///
/// To add this plugin to a [SuperEditor] widget, provide a [MarkdownInlineStylePlugin] in
/// the `plugins` property.
///
///   SuperEditor(
///     //...
///     plugins: {
///       markdownInlineStylePlugin,
///     },
///   );
///
/// To add this plugin directly to an [Editor], without involving a [SuperEditor]
/// widget, call [attach] with the given [Editor]. When that [Editor] is no longer needed,
/// call [detach] to clean up all plugin references.
///
///   markdownInlineStylePlugin.attach(editor);
///
///
class MarkdownInlineStylePlugin extends SuperEditorPlugin {
  MarkdownInlineStylePlugin() {
    _markdownInlineStyleReaction = MarkdownInlineStyleReaction();
  }

  /// An [EditReaction] that finds and converts Markdown styling into attributed
  /// styles.
  late EditReaction _markdownInlineStyleReaction;

  @override
  void attach(Editor editor) {
    editor.reactionPipeline.insert(0, _markdownInlineStyleReaction);
  }

  @override
  void detach(Editor editor) {
    editor.reactionPipeline.remove(_markdownInlineStyleReaction);
  }
}

class MarkdownInlineStyleReaction implements EditReaction {
  MarkdownInlineStyleReaction();

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      // No edits means no Markdown insertions. Nothing for this plugin to do.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);

    final editedTextNodeIds = _findEditedTextNodes(document, changeList);
    final changeRequests = _replaceMarkdown(document, editedTextNodeIds, composer.selection);

    requestDispatcher.execute(changeRequests);
  }

  /// Finds and returns the node IDs for every [TextNode] that was altered during this
  /// transaction.
  List<String> _findEditedTextNodes(Document document, List<EditEvent> changeList) {
    final editedTextNodes = <String, String>{};
    for (final change in changeList) {
      if (change is! DocumentEdit || change.change is! NodeDocumentChange) {
        continue;
      }

      final nodeId = (change.change as NodeDocumentChange).nodeId;
      if (editedTextNodes.containsKey(nodeId)) {
        continue;
      }

      if (document.getNodeById(nodeId) is! TextNode) {
        continue;
      }

      editedTextNodes[nodeId] = document.getNodeById(nodeId)!.id;
    }

    return editedTextNodes.values.toList();
  }

  List<EditRequest> _replaceMarkdown(Document document, List<String> editedNodes, DocumentSelection? currentSelection) {
    print("Replacing markdown with attributions.");
    print(" - current selection: $currentSelection");
    final changeRequests = <EditRequest>[];

    for (final nodeId in editedNodes) {
      final node = document.getNodeById(nodeId);
      if (node is! TextNode) {
        continue;
      }

      print("Checking edited node for Markdown changes: $nodeId");
      print("");
      final nodeText = node.text.text;

      // Take the current node text, which might contain a number of attributions and some new
      // Markdown text, and turn the whole thing into Markdown.
      final serializedMarkdownText = node.text.toMarkdown();

      // Take the full Markdown version of text and deserialize it back to AttributedText.
      // This process will re-create any pre-existing attributions, but it will also create
      // new attributions if the user inserted Markdown syntax.
      //
      // This re-ification process is especially important to facilitate the user's ability
      // to enter ambiguous Markdown syntax: "**token" -> "**token*" (italics) -> "**token**" (bold).
      final reifiedMarkdownText = (deserializeMarkdownToDocument(serializedMarkdownText).nodes.first as TextNode).text;

      if (nodeText.trim() == reifiedMarkdownText.text.trim()) {
        // No markdown was parsed in this paragraph. Move to the next one.
        continue;
      }

      // Some kind of change was made to the text via Markdown syntax.
      final diffs = diff(nodeText, reifiedMarkdownText.text);
      AttributedText updatedText = AttributedText();
      int originalTextOffset = 0;
      int parsedTextOffset = 0;
      print("");
      print("Found diffs:");
      for (final diff in diffs) {
        switch (diff.operation) {
          case DIFF_EQUAL:
            print(" - COPY: '${diff.text}'");
            final copyRange = SpanRange(originalTextOffset, originalTextOffset + diff.text.length - 1);

            final newAttributions =
                reifiedMarkdownText.getAttributionSpansInRange(attributionFilter: (a) => true, range: copyRange);

            updatedText = updatedText.copyAndAppend(
              AttributedText(node.text.text.substring(copyRange.start, copyRange.end + 1)),
            );

            for (final span in newAttributions) {
              print("Adding a new attribution: ${span.attribution} - ${span.start} -> ${span.end}");
              updatedText.addAttribution(span.attribution, SpanRange(span.start, span.end));
            }

            originalTextOffset += diff.text.length;
            parsedTextOffset += diff.text.length;
          case DIFF_DELETE:
            originalTextOffset += diff.text.length;
          case DIFF_INSERT:
            print(" - INSERT: '${diff.text}'");
            updatedText = updatedText.copyAndAppend(
              reifiedMarkdownText.copyText(parsedTextOffset, originalTextOffset + diff.text.length),
            );
            parsedTextOffset += diff.text.length;
        }
        print("'${updatedText.text}'");
      }
      print("");

      print("New attributed text after adding up diffs:");
      print("'${updatedText.text}'");
      print("${updatedText.spans}");
      print("");

      print("Markdown found a change. Replacing node text.");
      // The parser changed something in the node. Replace the old text with new text.
      changeRequests.addAll([
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 0)),
            end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: node.text.text.length)),
          ),
        ),
        InsertAttributedTextRequest(
          DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 0)),
          updatedText,
        ),
      ]);

      // Adjust the current selection, if necessary, now that the content changed.
      if (currentSelection != null &&
          (node.containsPosition(currentSelection.base) || node.containsPosition(currentSelection.extent))) {
        final baseNodePosition = currentSelection.base.nodePosition;
        final initialBaseOffset = baseNodePosition is TextNodePosition ? baseNodePosition.offset : null;
        final extentNodePosition = currentSelection.extent.nodePosition;
        final initialExtentOffset = extentNodePosition is TextNodePosition ? extentNodePosition.offset : null;

        // One or both ends of the user's selection sits within this node. Therefore, we
        // need to move those selection endpoints based on where/how many Markdown characters
        // were removed in the parsing process.
        //
        // This process is fragile because we don't know exactly what was changed in the text.
        // We assume that the parsed version of the text matches the original text, minus
        // some number of characters. To figure out where the Markdown parser removed characters,
        // we move character-by-character and add up the difference:
        //
        //     Hello **bold** world
        //
        //     vs
        //
        //     Hello bold world
        parsedTextOffset = 0;
        originalTextOffset = 0;
        int? adjustedBaseOffset = baseNodePosition is TextNodePosition ? baseNodePosition.offset : null;
        int? adjustedExtentOffset = extentNodePosition is TextNodePosition ? extentNodePosition.offset : null;

        while (parsedTextOffset < reifiedMarkdownText.length) {
          final parsedCharacter = reifiedMarkdownText.text[parsedTextOffset];
          String originalCharacter = nodeText[originalTextOffset];

          while (originalCharacter != parsedCharacter) {
            originalTextOffset = nodeText.moveOffsetDownstreamByCharacter(originalTextOffset)!;
            originalCharacter = nodeText[originalTextOffset];

            // (Maybe) update selection positions by checking every original text location.
            adjustedBaseOffset = _maybeAdjustSelectionOffset(originalTextOffset, parsedTextOffset, adjustedBaseOffset);
            adjustedExtentOffset =
                _maybeAdjustSelectionOffset(originalTextOffset, parsedTextOffset, adjustedExtentOffset);
          }

          // (Maybe) update selection positions by checking every original text location.
          adjustedBaseOffset = _maybeAdjustSelectionOffset(originalTextOffset, parsedTextOffset, adjustedBaseOffset);
          adjustedExtentOffset =
              _maybeAdjustSelectionOffset(originalTextOffset, parsedTextOffset, adjustedExtentOffset);

          parsedTextOffset = reifiedMarkdownText.text.moveOffsetDownstreamByCharacter(parsedTextOffset)!;
          originalTextOffset = nodeText.moveOffsetDownstreamByCharacter(originalTextOffset)!;
        }

        adjustedBaseOffset = _maybeAdjustFinalSelectionOffset(reifiedMarkdownText.length, adjustedBaseOffset);
        adjustedExtentOffset = _maybeAdjustFinalSelectionOffset(reifiedMarkdownText.length, adjustedExtentOffset);

        if (initialBaseOffset != adjustedBaseOffset || initialExtentOffset != adjustedExtentOffset) {
          changeRequests.add(
            ChangeSelectionRequest(
              DocumentSelection(
                base: adjustedBaseOffset != null
                    ? DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: adjustedBaseOffset))
                    : currentSelection.base,
                extent: adjustedExtentOffset != null
                    ? DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: adjustedExtentOffset))
                    : currentSelection.extent,
              ),
              SelectionChangeType.pushExtent,
              SelectionReason.contentChange,
            ),
          );
        }
        print("");
        print("");
      }

      print("--------");
    }

    return changeRequests;
  }
}

/// Corrects and returns the [selectionOffset] so that it moves upstream by whatever the
/// difference between the original text length and the styled text length at this moment.
///
/// This method should be called for every character that's visited in the original text.
///
/// If the given [originalTextOffset] isn't the same as the [selectionOffset], then the
/// [selectionOffset] is returned as-is. This check is done inside of this method so that
/// callers can blindly call this method without needing to make that comparison themselves.
///
/// The [selectionOffset] is nullable so that callers can blindly pass a selection base or
/// extent, even when that base or extent might sit outside of the given [TextNode], and
/// therefore it's null. This is a convenience to let the client avoid filtering for that
/// condition ahead of time.
int? _maybeAdjustSelectionOffset(int originalTextOffset, int styledTextOffset, int? selectionOffset) {
  if (selectionOffset == null) {
    return null;
  }
  if (originalTextOffset != selectionOffset) {
    return selectionOffset;
  }

  // The `originalTextOffset` is the same as `selectionOffset`, which means this is the
  // location in the text that the selection currently sits. Whatever the difference in
  // text position between `originalTextOffset` and `styledTextOffset` exists at this
  // point, we want to apply it to the `selectionOffset`.
  return selectionOffset - (originalTextOffset - styledTextOffset);
}

int? _maybeAdjustFinalSelectionOffset(int styledTextLength, int? selectionOffset) {
  if (selectionOffset == null) {
    return null;
  }

  // If the `selectionOffset` sits beyond the `styledTextLength` then we're left to
  // assume that the selection position was sitting at the very end of the original
  // text and needs to be placed at the end of the styled text.
  return min(styledTextLength, selectionOffset);
}

// TODO: move this into TextNode or maybe DocumentNode
extension on TextNode {
  bool containsPosition(DocumentPosition position) {
    if (position.nodeId != id) {
      return false;
    }

    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return false;
    }

    if (nodePosition.offset < 0 || nodePosition.offset > text.length) {
      return false;
    }

    return true;
  }
}
