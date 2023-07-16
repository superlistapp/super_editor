import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tokenizing/tags.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// A [SuperEditorPlugin] that finds and attributes hash tags in a document.
///
/// A hash tag is a text token that begins with a trigger character, such as "#", and
/// is followed by one or more non-space characters.
///
/// A [HashTagPlugin] finds and attributes hash tags as the user types them into an [Editor].
/// Clients that wish to react to changes to hash tags can use the [hashTagIndex] to query
/// existing hash tags.
///
/// To add hash tag behaviors to a [SuperEditor] widget, provide a [HashTagPlugin] in
/// the `plugins` property.
///
///   SuperEditor(
///     //...
///     plugins: {
///       hashTagPlugin,
///     },
///   );
///
/// To add hash tag behaviors directly to an [Editor], without involving a [SuperEditor]
/// widget, call [attach] with the given [Editor]. When that [Editor] is no longer needed,
/// call [detach] to clean up all plugin references.
///
///   hashTagPlugin.attach(editor);
///
///
class HashTagPlugin extends SuperEditorPlugin {
  /// The key used to access the [HashTagIndex] in an attached [Editor].
  static const hashTagIndexKey = "hashTagIndex";

  HashTagPlugin({
    TagRule tagRule = hashTagRule,
  })  : _tagRule = tagRule,
        hashTagIndex = HashTagIndex() {
    _hashTagReaction = HashTagReaction(
      tagRule: _tagRule,
    );
  }

  /// The rule for what this plugin considers to be a hash tag.
  final TagRule _tagRule;

  /// Index of all hash tags in the document.
  final HashTagIndex hashTagIndex;

  /// An [EditReaction] that finds and attributes all hash tags.
  late EditReaction _hashTagReaction;

  @override
  void attach(Editor editor) {
    editor
      ..context.put(hashTagIndexKey, hashTagIndex)
      ..reactionPipeline.insert(0, _hashTagReaction);

    _initializeHashTagIndex(editor);
  }

  void _initializeHashTagIndex(Editor editor) {
    final document = editor.context.find<MutableDocument>(Editor.documentKey);

    for (final node in document.nodes) {
      if (node is! TextNode) {
        continue;
      }

      final tagSpans = node.text.getAttributionSpansInRange(
        attributionFilter: (a) => a is HashTagAttribution,
        range: SpanRange(start: 0, end: node.text.text.length - 1),
      );

      final tags = <IndexedTag>{};
      for (final tagSpan in tagSpans) {
        IndexedTag(
          Tag.fromRaw(node.text.text.substring(tagSpan.start, tagSpan.end + 1)),
          node.id,
          tagSpan.start,
        );
      }
      hashTagIndex._setTagsInNode(node.id, tags);
    }
  }

  @override
  void detach(Editor editor) {
    editor
      ..context.remove(hashTagIndexKey)
      ..reactionPipeline.remove(_hashTagReaction);
  }
}

/// Default [TagRule] for hash tags.
const hashTagRule = TagRule(trigger: "#", excludedCharacters: {"."});

extension HashTagIndexEditable on EditContext {
  /// Returns the [HashTagIndex] that the [HashTagPlugin] added to the attached [Editor].
  ///
  /// This accessor is provided as a convenience so that clients don't need to call `find()`
  /// on the [EditContext].
  HashTagIndex get hashTagIndex => find<HashTagIndex>(HashTagPlugin.hashTagIndexKey);
}

/// Collects references to all hash tags in a document for easy querying.
class HashTagIndex with ChangeNotifier implements Editable {
  final _tags = <String, Set<IndexedTag>>{};

  Set<IndexedTag> getTagsInTextNode(String nodeId) => _tags[nodeId] ?? {};

  Set<IndexedTag> getAllTags() {
    final tags = <IndexedTag>{};
    for (final value in _tags.values) {
      tags.addAll(value);
    }
    return tags;
  }

  void _setTagsInNode(String nodeId, Set<IndexedTag> tags) {
    _tags[nodeId] ??= <IndexedTag>{};
    _tags[nodeId]!.addAll(tags);
    _onChange();
  }

  void _clearNode(String nodeId) {
    _tags[nodeId]?.clear();
    _onChange();
  }

  bool _isInATransaction = false;
  bool _didChange = false;

  @override
  void onTransactionStart() {
    _isInATransaction = true;
    _didChange = false;
  }

  void _onChange() {
    if (!_isInATransaction) {
      return;
    }

    _didChange = true;
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {
    _isInATransaction = false;
    if (_didChange) {
      _didChange = false;
      notifyListeners();
    }
  }
}

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
    TagRule tagRule = hashTagRule,
  }) : _tagRule = tagRule;

  final TagRule _tagRule;

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

    _adjustTagAttributionsAroundAlteredTags(editContext, requestDispatcher, changeList);

    _findAndCreateNewTags(editContext, requestDispatcher, changeList);

    _splitBackToBackTags(editContext, requestDispatcher, changeList);

    _removeInvalidTags(editContext, requestDispatcher, changeList);

    _updateTagIndex(editContext, changeList);
  }

  /// Finds a hash tag near the caret and adjusts the attribution bounds so that the
  /// tag content remains attributed.
  ///
  /// Examples:
  ///
  ///  - |#das|h      ->  |#dash|
  ///  - |#dash and|  ->  |#dash| and
  ///
  void _adjustTagAttributionsAroundAlteredTags(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);

    final hashTag = _findTagAtCaret(editContext, (attributions) => attributions.contains(const HashTagAttribution()));
    if (hashTag != null) {
      final tagRange = SpanRange(start: hashTag.indexedTag.startOffset, end: hashTag.indexedTag.endOffset);
      final hasTagAttributionThroughout =
          hashTag.indexedTag.computeLeadingSpanForAttribution(document, const HashTagAttribution()) == tagRange;
      if (hasTagAttributionThroughout) {
        // The tag is already fully attributed. No need to do anything.
        return;
      }

      // The token is only partially attributed. Expand the attribution around the token.
      requestDispatcher.execute([
        AddTextAttributionsRequest(
          documentSelection: DocumentSelection(
            base: hashTag.indexedTag.start,
            extent: hashTag.indexedTag.end,
          ),
          attributions: {const HashTagAttribution()},
        ),
      ]);

      return;
    }
  }

  TagAroundPosition? _findTagAtCaret(
      EditContext editContext, bool Function(Set<Attribution> attributions) tagSelector) {
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection == null || !composer.selection!.isCollapsed) {
      // We only tag when the selection is collapsed. Our selection is null or expanded. Return.
      return null;
    }
    final selectionPosition = composer.selection!.extent;
    final caretPosition = selectionPosition.nodePosition;
    if (caretPosition is! TextNodePosition) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return null;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final selectedNode = document.getNodeById(selectionPosition.nodeId);
    if (selectedNode is! TextNode) {
      // Tagging only happens in the middle of text. The selected content isn't text. Return.
      return null;
    }

    return TagFinder.findTagAroundPosition(
      tagRule: _tagRule,
      nodeId: selectedNode.id,
      text: selectedNode.text,
      expansionPosition: caretPosition,
      isTokenCandidate: tagSelector,
    );
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

    final hashTagAroundCaret = TagFinder.findTagAroundPosition(
      tagRule: _tagRule,
      nodeId: selectedNode.id,
      text: selectedNode.text,
      expansionPosition: caretPosition,
      isTokenCandidate: (tokenAttributions) =>
          !tokenAttributions.any((attribution) => attribution is HashTagAttribution),
    );
    if (hashTagAroundCaret == null) {
      // There's no tag around the caret.
      editorHashTagsLog.fine("There's no tag around the caret, fizzling");
      return;
    }
    if (!hashTagAroundCaret.indexedTag.tag.raw.startsWith(_tagRule.trigger)) {
      // Tags must start with a "#" (or other trigger symbol) but the preceding word doesn't. Return.
      editorHashTagsLog.fine("Token doesn't start with ${_tagRule.trigger}, fizzling");
      return;
    }
    if (hashTagAroundCaret.indexedTag.tag.raw.length <= 1) {
      // The token only contains a "#". We require at least one valid character after
      // the "#" to consider it a hash tag.
      editorHashTagsLog.fine("Token has no content after ${_tagRule.trigger}, fizzling");
      return;
    }

    editorHashTagsLog.fine(
        "Found a hash tag around caret: '${hashTagAroundCaret.indexedTag.tag}' - surrounding it with an attribution: ${hashTagAroundCaret.indexedTag.startOffset} -> ${hashTagAroundCaret.indexedTag.endOffset}");

    requestDispatcher.execute([
      // Remove the old hash tag attribution(s).
      RemoveTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.indexedTag.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.indexedTag.endOffset),
          ),
        ),
        attributions: {
          ...selectedNode.text
              .getAllAttributionsAt(hashTagAroundCaret.indexedTag.startOffset)
              .whereType<HashTagAttribution>(),
        },
      ),
      // Add the new/updated hash tag attribution.
      AddTextAttributionsRequest(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.indexedTag.startOffset),
          ),
          extent: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: hashTagAroundCaret.indexedTag.endOffset),
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

      if (tagContent.lastIndexOf(_tagRule.trigger) == 0) {
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
      int triggerSymbolIndex = tagContent.indexOf(_tagRule.trigger);
      while (triggerSymbolIndex >= 0) {
        final nextTriggerSymbolIndex = tagContent.indexOf(_tagRule.trigger, triggerSymbolIndex + 1);
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
        if (!tagText.startsWith(_tagRule.trigger) || tagText == _tagRule.trigger) {
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

    // Run all the tag attribution removal requests that we queued up.
    for (final request in removeTagRequests) {
      requestDispatcher.execute([request]);
    }
  }

  void _updateTagIndex(EditContext editContext, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final index = editContext.hashTagIndex;
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeDocumentChange) {
        return;
      }
      if (document.getNodeById(change.nodeId) is! TextNode) {
        return;
      }

      if (change is NodeRemovedEvent) {
        index._clearNode(change.nodeId);
      } else if (change is NodeInsertedEvent) {
        index._setTagsInNode(
          change.nodeId,
          _findAllTagsInNode(document, change.nodeId),
        );
      } else if (change is NodeChangeEvent) {
        index._clearNode(change.nodeId);
        index._setTagsInNode(
          change.nodeId,
          _findAllTagsInNode(document, change.nodeId),
        );
      }
    }
  }

  Set<IndexedTag> _findAllTagsInNode(Document document, String nodeId) {
    final textNode = document.getNodeById(nodeId) as TextNode;
    final allTags = textNode.text
        .getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution is HashTagAttribution,
          range: SpanRange(start: 0, end: textNode.text.text.length - 1),
        )
        .map(
          (span) => IndexedTag(
            Tag.fromRaw(textNode.text.text.substring(span.start, span.end + 1)),
            textNode.id,
            span.start,
          ),
        )
        .toSet();

    return allTags;
  }
}

/// An attribution for a hash tag.
class HashTagAttribution extends NamedAttribution {
  const HashTagAttribution() : super("hashtag");

  @override
  bool canMergeWith(Attribution other) => other is HashTagAttribution;

  @override
  String toString() {
    return '[HashTagAttribution]';
  }
}
