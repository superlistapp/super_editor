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
/// To add this plugin to a [SuperEditor] widget, provide a [MarkdownFullParagraphInlineStylePlugin] in
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
class MarkdownFullParagraphInlineStylePlugin extends SuperEditorPlugin {
  MarkdownFullParagraphInlineStylePlugin() {
    _markdownInlineStyleReaction = MarkdownFullParagraphInlineStyleReaction();
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

class MarkdownFullParagraphInlineStyleReaction implements EditReaction {
  MarkdownFullParagraphInlineStyleReaction();

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      // No edits means no Markdown insertions. Nothing for this plugin to do.
      return;
    }
    if (changeList.where((edit) => edit is DocumentEdit && edit.change is TextInsertionEvent).isEmpty) {
      // TODO: account for paste behaviors.
      // No text insertions. Nothing for this plugin to do.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);

    final editedTextNodeIds = _findEditedTextNodes(document, changeList);
    final changeRequests = _applyInlineMarkdown(document, editedTextNodeIds, composer.selection);

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

  List<EditRequest> _applyInlineMarkdown(
      Document document, List<String> editedNodes, DocumentSelection? currentSelection) {
    print("Replacing markdown with attributions.");
    print(" - current selection: $currentSelection");
    final changeRequests = <EditRequest>[];

    for (final nodeId in editedNodes) {
      final node = document.getNodeById(nodeId);
      if (node is! TextNode) {
        continue;
      }

      changeRequests.addAll(
        _applyInlineMarkdownToTextNode(node, currentSelection),
      );
      print("--------");
    }

    return changeRequests;
  }

  List<EditRequest> _applyInlineMarkdownToTextNode(TextNode node, DocumentSelection? currentSelection) {
    final String nodeId = node.id;
    print("Checking edited node for Markdown changes: $nodeId");
    print("");

    final deltas = <EditRequest>[];

    final nodeText = node.text.text;

    // Take the current node text, which might contain a number of existing attributions and
    // some new Markdown text, and turn the whole thing into Markdown.
    final serializedMarkdownText = node.text.toMarkdown();

    // Take the full Markdown version of text and deserialize it back to AttributedText.
    // This process will re-create any pre-existing attributions (that are supported by Markdown),
    // but it will also create new attributions if the user inserted Markdown syntax.
    //
    // This re-ification process is especially important to facilitate the user's ability
    // to enter ambiguous Markdown syntax: "**token" -> "**token*" (italics) -> "**token**" (bold).
    final afterMarkdownText = (deserializeMarkdownToDocument(serializedMarkdownText).nodes.first as TextNode).text;

    if (nodeText.trim() == afterMarkdownText.text.trim()) {
      // No markdown was parsed in this paragraph. Nothing for us to do.
      return [];
    }

    if (afterMarkdownText.text.trim().isEmpty) {
      // The parsed text is empty. This means that parsing went from some content to
      // no content. This can happen when Markdown syntax appears at the beginning of
      // a text blob, e.g., "*", "**", etc. To prevent that syntax from immediately
      // disappearing, we filter out that case here.
      return [];
    }

    // Some kind of change was made to the text via Markdown syntax. Calculate the text and
    // attribution differences that came from parsing the Markdown and then create change
    // requests that will change the existing text into text with inline Markdown applied.
    final diffs = diff(nodeText, afterMarkdownText.text);

    // The following properties track a moving offset within the text BEFORE and AFTER
    // the inline Markdown was applied.
    //
    // Example:
    //
    //    "Hello *|italics*" (original text offset - 7)
    //    "Hello |italics" (parsed text offset - 6)
    int beforeMarkdownTextOffset = 0;
    int afterMarkdownTextOffset = 0;

    // If the selection base or extent sit in this node, those selection offsets might be
    // impacted by insertions and deletions caused by this reaction. Track any necessary
    // selection offset changes along the way.
    int? adjustedBaseSelectionOffset = node.containsPosition(currentSelection?.base)
        ? (currentSelection!.base.nodePosition as TextNodePosition).offset
        : null;
    int? adjustedExtentSelectionOffset = node.containsPosition(currentSelection?.extent)
        ? (currentSelection!.extent.nodePosition as TextNodePosition).offset
        : null;

    print("");
    print("Processing inline Markdown diffs:");
    for (final diff in diffs) {
      switch (diff.operation) {
        case DIFF_EQUAL:
          print("COPY: '${diff.text}'");

          final beforeMarkdownDiffRange =
              SpanRange(beforeMarkdownTextOffset, beforeMarkdownTextOffset + diff.text.length - 1);
          print("Before-Markdown diff range: ${beforeMarkdownDiffRange.start} -> ${beforeMarkdownDiffRange.end}");
          final beforeMarkdownAttributions = node.text.getAttributionSpansInRange(
            attributionFilter: (a) => true,
            range: beforeMarkdownDiffRange,
          );

          final afterMarkdownDiffRange =
              SpanRange(afterMarkdownTextOffset, afterMarkdownTextOffset + diff.text.length - 1);
          print("After-Markdown diff range: ${afterMarkdownDiffRange.start} -> ${afterMarkdownDiffRange.end}");
          final afterMarkdownAttributions = afterMarkdownText.getAttributionSpansInRange(
            attributionFilter: (a) => true,
            range: afterMarkdownDiffRange,
          );

          for (final existingAttribution in beforeMarkdownAttributions) {
            if (afterMarkdownAttributions.contains(existingAttribution)) {
              // This attribution existing before and after parsing Markdown. We don't need to
              // do anything.
              continue;
            }

            if (!_isInlineMarkdownAttribution(existingAttribution.attribution)) {
              // This attribution isn't a Markdown attribution, e.g., text color, therefore we don't
              // want to remove it.
              continue;
            }

            // This is an inline Markdown attribution that existed before parsing inline Markdown,
            // but doesn't exist after parsing inline Markdown. Remove it.
            print(
                "Removing an attribution: ${existingAttribution.attribution} - ${afterMarkdownDiffRange.start} -> ${afterMarkdownDiffRange.end}");
            deltas.add(
              RemoveTextAttributionsRequest(
                documentRange: DocumentRange(
                  start: DocumentPosition(
                    nodeId: nodeId,
                    nodePosition: TextNodePosition(offset: afterMarkdownDiffRange.start),
                  ),
                  end: DocumentPosition(
                    nodeId: nodeId,
                    nodePosition: TextNodePosition(offset: afterMarkdownDiffRange.end + 1),
                  ),
                ),
                attributions: {existingAttribution.attribution},
              ),
            );
          }

          for (final newAttribution in afterMarkdownAttributions) {
            if (!beforeMarkdownAttributions.contains(newAttribution)) {
              print(
                  "Adding an attribution: ${newAttribution.attribution} - ${afterMarkdownDiffRange.start} -> ${afterMarkdownDiffRange.end}");
              deltas.add(
                AddTextAttributionsRequest(
                  documentRange: DocumentRange(
                    start: DocumentPosition(
                      nodeId: nodeId,
                      nodePosition: TextNodePosition(offset: afterMarkdownDiffRange.start),
                    ),
                    end: DocumentPosition(
                      nodeId: nodeId,
                      nodePosition: TextNodePosition(offset: afterMarkdownDiffRange.end + 1),
                    ),
                  ),
                  attributions: {newAttribution.attribution},
                ),
              );
            }
          }

          beforeMarkdownTextOffset += diff.text.length;
          afterMarkdownTextOffset += diff.text.length;
        case DIFF_DELETE:
          print("DELETE: ${diff.text}");
          print(
              "Creating delete request from $beforeMarkdownTextOffset to ${beforeMarkdownTextOffset + diff.text.length}");
          deltas.add(
            DeleteContentRequest(
              documentRange: DocumentRange(
                start: DocumentPosition(
                  nodeId: node.id,
                  nodePosition: TextNodePosition(offset: afterMarkdownTextOffset),
                ),
                end: DocumentPosition(
                  nodeId: node.id,
                  nodePosition: TextNodePosition(offset: afterMarkdownTextOffset + diff.text.length),
                ),
              ),
            ),
          );

          beforeMarkdownTextOffset += diff.text.length;
        case DIFF_INSERT:
          print("INSERT: '${diff.text}'");

          deltas.add(
            InsertAttributedTextRequest(
              DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: beforeMarkdownTextOffset)),
              afterMarkdownText.copyText(afterMarkdownTextOffset, afterMarkdownTextOffset + diff.text.length),
            ),
          );

          afterMarkdownTextOffset += diff.text.length;
      }

      final contentMovement = afterMarkdownTextOffset - beforeMarkdownTextOffset;
      if (adjustedBaseSelectionOffset != null &&
          adjustedBaseSelectionOffset >= beforeMarkdownTextOffset - diff.text.length &&
          adjustedBaseSelectionOffset <= beforeMarkdownTextOffset) {
        // The selection base falls somewhere within this text span that's being processed.
        // Finalize the offset of the base selection.
        adjustedBaseSelectionOffset += contentMovement;
      }
      if (adjustedExtentSelectionOffset != null &&
          adjustedExtentSelectionOffset >= beforeMarkdownTextOffset - diff.text.length &&
          adjustedExtentSelectionOffset <= beforeMarkdownTextOffset) {
        // The selection extent falls somewhere within this text span that's being processed.
        // Finalize the offset of the base selection.
        adjustedExtentSelectionOffset += contentMovement;
        print("Updated extent to $adjustedExtentSelectionOffset");
      }

      print("Original: '$nodeText'");
      print("Parsed: '${afterMarkdownText.text}'");
      print("");
    }
    print("");

    print("Delta change requests:");
    print("Will be applied to: '$nodeText'");
    print("Insertions and deletions:");
    for (final change in deltas) {
      if (change is AddTextAttributionsRequest) {
        print(" - add attributions: ${change.attributions} - range: ${change.documentRange}");
      }
      if (change is RemoveTextAttributionsRequest) {
        print(" - remove attributions: ${change.attributions} - range: ${change.documentRange}");
      }
      if (change is InsertAttributedTextRequest) {
        print(" - insert '${change.textToInsert.text}' ${change.documentPosition}");
      }
      if (change is DeleteContentRequest) {
        print(" - delete ${change.documentRange}");
      }
    }
    print("");

    // The parser changed something in the node. Replace the old text with new text.
    return [
      ...deltas,
      if (adjustedBaseSelectionOffset != null || adjustedExtentSelectionOffset != null) //
        ChangeSelectionRequest(
          DocumentSelection(
            base: adjustedBaseSelectionOffset != null
                ? DocumentPosition(
                    nodeId: node.id,
                    nodePosition: TextNodePosition(offset: adjustedBaseSelectionOffset),
                  )
                : currentSelection!.base,
            extent: adjustedExtentSelectionOffset != null
                ? DocumentPosition(
                    nodeId: node.id,
                    nodePosition: TextNodePosition(offset: adjustedExtentSelectionOffset),
                  )
                : currentSelection!.extent,
          ),
          SelectionChangeType.pushExtent,
          SelectionReason.contentChange,
        ),
    ];
  }

  bool _isInlineMarkdownAttribution(Attribution attribution) {
    if (attribution == boldAttribution) {
      return true;
    }
    if (attribution == italicsAttribution) {
      return true;
    }
    if (attribution == strikethroughAttribution) {
      return true;
    }
    if (attribution is LinkAttribution) {
      return true;
    }

    return false;
  }
}

// TODO: move this into TextNode or maybe DocumentNode
extension on TextNode {
  bool containsPosition(DocumentPosition? position) {
    if (position == null) {
      return false;
    }

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
