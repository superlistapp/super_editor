import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tokenizing/tag_tokenizer.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// An [EditReaction] that creates, updates, and removes hash tags.
///
/// A hash tag is a token that begins with "#" (or some other trigger), and is
/// followed by one or more characters. A hash tag is terminated by the end of
/// a text block, a space, another "#", or any given terminating character.
///
/// Examples of hash tags:
///
///     #flutter
///     #flutter #dart    (2 tags)
///     #flutter#dart     (2 tags)
///     I love #flutter.  (the period is excluded from the hash tag)
///
/// Examples of strings that aren't hash tags:
///
///     #
///     #.
///     ##
///
class HashTagReaction implements EditReaction {
  HashTagReaction({
    String triggerSymbol = "#",
    Set<String> excludeCharacters = const {"."},
  })  : assert(triggerSymbol.length == 1,
            "The trigger symbol must be exactly one character long. Tried to use symbol: '$triggerSymbol'"),
        _triggerSymbol = triggerSymbol,
        _terminatingCharacters = excludeCharacters;

  /// The character that causes a hash tag to begin, defaults to "#".
  final String _triggerSymbol;

  /// Characters that cause a hash tag to end.
  ///
  /// By default, a hash tag will stop when it hits a ".", because a hash
  /// tag might appear at the end of a sentence, and the period shouldn't
  /// be included.
  ///
  /// Spaces are always enforced as terminating characters. A space does
  /// not need to be included in this set.
  final Set<String> _terminatingCharacters;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      // If there are no document edits then there can't possibly be a change to
      // hash tags. This is a quick escape to avoid unnecessary logging and inspections.
      return;
    }

    editorHashTagsLog.info("Reacting to possible hash tagging");
    editorHashTagsLog.info("Incoming change list:");
    editorHashTagsLog.info(changeList.map((event) => event.runtimeType).toList());
    editorHashTagsLog.info(
        "Caret position: ${editContext.find<MutableDocumentComposer>(Editor.composerKey).selection?.extent.nodePosition}");

    _findAndCreateNewTags(editContext, requestDispatcher, changeList);

    _splitBackToBackTags(editContext, requestDispatcher, changeList);

    _removeInvalidTags(editContext, requestDispatcher, changeList);
  }

  /// Find any text near the caret that fits the pattern of a hash tag, and surround
  /// it with a hash tag attribution.
  void _findAndCreateNewTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorHashTagsLog.fine("Looking for a hash tag around the caret.");

    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null || !composer.selection!.isCollapsed) {
      // We only tag when the selection is collapsed. Our selection is null or expanded. Return.
      return;
    }

    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return;
    }

    final hashTagAroundCaret = TagTokenizer.findUntaggedTokenAroundCaret(
      triggerSymbol: _triggerSymbol,
      nodeId: selectedNode.id,
      text: selectedNode.text,
      caretPosition: caretPosition,
      tagFilter: (tokenAttributions) => !tokenAttributions.any((attribution) => attribution is HashTagAttribution),
      excludeCharacters: _terminatingCharacters,
    );
    if (hashTagAroundCaret == null) {
      // There's no tag around the caret.
      editorHashTagsLog.fine("There's no tag around the caret, fizzling");
      return;
    }
    if (!hashTagAroundCaret.token.value.startsWith(_triggerSymbol)) {
      // Tags must start with a "#" (or other trigger symbol) but the preceding word doesn't. Return.
      editorHashTagsLog.fine("Token doesn't start with $_triggerSymbol, fizzling");
      return;
    }
    if (hashTagAroundCaret.token.value.length <= 1) {
      // The token only contains a "#". We require at least one valid character after
      // the "#" to consider it a hash tag.
      editorHashTagsLog.fine("Token has no content after $_triggerSymbol, fizzling");
      return;
    }

    editorHashTagsLog.fine(
        "Found a hash tag around caret: '${hashTagAroundCaret.token.value}' - surrounding it with an attribution: ${hashTagAroundCaret.token.startOffset} -> ${hashTagAroundCaret.token.endOffset}");

    requestDispatcher.execute([
      // Remove the old hash tag attribution(s).
      RemoveTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.token.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.token.endOffset),
          ),
        ),
        attributions: {
          ...selectedNode.text
              .getAllAttributionsAt(hashTagAroundCaret.token.startOffset)
              .whereType<HashTagAttribution>(),
        },
      ),
      // Add the new/updated hash tag attribution.
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.token.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.token.endOffset),
          ),
        ),
        attributions: {
          const HashTagAttribution(),
        },
      ),
    ]);
  }

  /// Finds any attributed hash tag that spans multiple hash tags, and breaks them up.
  ///
  /// For example, it's possible that we've gotten into a situation where two back-to-back
  /// hash tags are currently attributed as one:
  ///
  ///     [#flutter#dart]
  ///
  /// This method breaks that one attribution into two:
  ///
  ///     [#flutter][#dart]
  ///
  void _splitBackToBackTags(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);

    final textEdits = changeList
        .whereType<DocumentEdit>()
        .where((docEdit) => docEdit.change is NodeChangeEvent)
        .map((docEdit) => docEdit.change as NodeChangeEvent)
        .where((nodeChange) => document.getNodeById(nodeChange.nodeId) != null)
        .toList(growable: false);
    if (textEdits.isEmpty) {
      return;
    }

    editorHashTagsLog.info("Checking edited text nodes for back-to-back hash tags that need to be split apart");
    for (final textEdit in textEdits) {
      final node = document.getNodeById(textEdit.nodeId) as TextNode;
      _splitBackToBackTagsInTextNode(requestDispatcher, node);
    }
  }

  void _splitBackToBackTagsInTextNode(RequestDispatcher requestDispatcher, TextNode node) {
    final hashTags = node.text.getAttributionSpansInRange(
      attributionFilter: (attribution) => attribution is HashTagAttribution,
      range: SpanRange(start: 0, end: node.text.text.length),
    );
    if (hashTags.isEmpty) {
      return;
    }

    final spanRemovals = <SpanRange>{};
    final spanCreations = <SpanRange>{};

    editorHashTagsLog.finer("Found ${hashTags.length} hash tag attributions in text node '${node.id}'");
    for (final hashTag in hashTags) {
      final tagContent = node.text.text.substring(hashTag.start, hashTag.end + 1);
      editorHashTagsLog.finer("Inspecting $tagContent at ${hashTag.start} -> ${hashTag.end}");

      if (tagContent.lastIndexOf(_triggerSymbol) == 0) {
        // There's only one # in this tag, and it's at the beginning. No need
        // to split the tag.
        editorHashTagsLog.finer("No need to split this tag. Moving to next one.");
        continue;
      }

      // This tag has multiple #'s in it. We need to split this tag into multiple
      // pieces.
      editorHashTagsLog.finer("There are multiple hashes in this tag. Splitting.");

      // Remove the existing attribution, which covers multiple hash tags.
      spanRemovals.add(SpanRange(start: hashTag.start, end: hashTag.end));
      editorHashTagsLog.finer(
          "Removing multi-tag span: ${hashTag.start} -> ${hashTag.end}, '${node.text.text.substring(hashTag.start, hashTag.end + 1)}'");

      // Add a new attribution for each individual hash tag.
      int triggerSymbolIndex = tagContent.indexOf(_triggerSymbol);
      while (triggerSymbolIndex >= 0) {
        final nextTriggerSymbolIndex = tagContent.indexOf(_triggerSymbol, triggerSymbolIndex + 1);
        final tagEnd = nextTriggerSymbolIndex > 0 ? nextTriggerSymbolIndex - 1 : tagContent.length - 1;

        if (tagEnd - triggerSymbolIndex > 0) {
          // There's a hash, followed by at least one non-hash character. Therefore, this
          // is a legitimate hash tag. Give it an attribution.
          editorHashTagsLog.finer(
              "Adding a split tag span: ${hashTag.start + triggerSymbolIndex} -> ${hashTag.start + tagEnd}, '${node.text.text.substring(hashTag.start + triggerSymbolIndex, hashTag.start + tagEnd + 1)}'");
          spanCreations.add(SpanRange(
            start: hashTag.start + triggerSymbolIndex,
            end: hashTag.start + tagEnd,
          ));
        }

        triggerSymbolIndex = nextTriggerSymbolIndex;
      }
    }

    // Execute the attribution removals and additions.
    requestDispatcher.execute([
      // Remove the original multi-tag attribution spans.
      for (final removal in spanRemovals)
        RemoveTextAttributionsRequest(
          documentSelection: DocumentSelection(
            base: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: removal.start),
            ),
            extent: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: removal.end + 1),
            ),
          ),
          attributions: {const HashTagAttribution()},
        ),

      // Add the new, narrowed attribution spans.
      for (final creation in spanCreations)
        AddTextAttributionsRequest(
          documentSelection: DocumentSelection(
            base: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: creation.start),
            ),
            extent: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: creation.end + 1),
            ),
          ),
          attributions: {const HashTagAttribution()},
          autoMerge: false,
        ),
    ]);
  }

  /// Removes hash tags that have become invalid, e.g., a hash tag that had content but
  /// the content was deleted, and now it's just a dangling "#".
  void _removeInvalidTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    editorHashTagsLog.fine("Removing invalid tags.");
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

      // We only care about deleted text when the deleted text contains at least one tag.
      final tagsInDeletedText = change.deletedText.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution is HashTagAttribution,
        range: SpanRange(start: 0, end: change.deletedText.text.length),
      );
      if (tagsInDeletedText.isEmpty) {
        continue;
      }

      nodesToInspect.add(change.nodeId);
    }
    editorHashTagsLog.fine("Found ${nodesToInspect.length} impacted nodes with tags that might be invalid");

    // Inspect every TextNode where a text deletion impacted a tag. If a tag no longer contains
    // a "#", or only contains a "#", remove the attribution.
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final removeTagRequests = <EditRequest>{};
    for (final nodeId in nodesToInspect) {
      final textNode = document.getNodeById(nodeId) as TextNode;
      final allTags = textNode.text.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution is HashTagAttribution,
        range: SpanRange(start: 0, end: textNode.text.text.length - 1),
      );

      for (final tag in allTags) {
        final tagText = textNode.text.text.substring(tag.start, tag.end + 1);
        if (!tagText.startsWith(_triggerSymbol) || tagText == _triggerSymbol) {
          editorHashTagsLog.info("Removing tag with value: '$tagText'");
          removeTagRequests.add(
            RemoveTextAttributionsRequest(
              documentSelection: DocumentSelection(
                base: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.start),
                ),
                extent: DocumentPosition(
                  nodeId: textNode.id,
                  nodePosition: TextNodePosition(offset: tag.end + 1),
                ),
              ),
              attributions: {const HashTagAttribution()},
            ),
          );
        }
      }
    }

    // Run all the tag attribution removal requests that we queue'd up.
    for (final request in removeTagRequests) {
      requestDispatcher.execute([request]);
    }
  }
}

/// An attribution for a hash tag..
class HashTagAttribution extends NamedAttribution {
  const HashTagAttribution() : super("hashtag");

  @override
  bool canMergeWith(Attribution other) => other is HashTagAttribution;

  @override
  String toString() {
    return '[HashTagAttribution]';
  }
}
