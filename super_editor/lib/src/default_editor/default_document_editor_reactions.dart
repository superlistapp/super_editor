import 'dart:io';

import 'package:attributed_text/attributed_text.dart';
import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:linkify/linkify.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'multi_node_editing.dart';

/// Converts a [ParagraphNode] to an [UnorderedListItemNode] when the
/// user types "* " (or similar) at the start of the paragraph.
class UnorderedListItemConversionReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final didTypeSpaceAtEnd = EditInspector.didTypeSpace(document, changeList);
    if (!didTypeSpaceAtEnd) {
      return;
    }

    final edit = changeList[changeList.length - 2] as DocumentEdit;
    final textInsertionEvent = edit.change as TextInsertionEvent;
    final paragraph = document.getNodeById(textInsertionEvent.nodeId) as ParagraphNode;
    final unorderedListItemMatch = RegExp(r'^\s*[*-]\s+$');
    if (!paragraph.text.text.startsWith(unorderedListItemMatch)) {
      return;
    }

    // The user started a paragraph with an unordered list item pattern.
    // Convert the paragraph to an unordered list item.
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ListItemNode.unordered(id: paragraph.id, text: AttributedText(text: "")),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: textInsertionEvent.nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.place,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// Converts a [ParagraphNode] to an [OrderedListItemNode] when the
/// user types " 1. " (or similar) at the start of the paragraph.
class OrderedListItemConversionReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final didTypeSpaceAtEnd = EditInspector.didTypeSpace(document, changeList);
    if (!didTypeSpaceAtEnd) {
      return;
    }

    final edit = changeList[changeList.length - 2] as DocumentEdit;
    final textInsertionEvent = edit.change as TextInsertionEvent;
    final paragraph = document.getNodeById(textInsertionEvent.nodeId) as ParagraphNode;
    // We want to match "1. ", " 1. ", "1) ", " 1) ".
    final orderedListItemMatch = RegExp(r'^\s*1[.)]\s+$');
    if (!paragraph.text.text.startsWith(orderedListItemMatch)) {
      return;
    }

    // The user started a paragraph with an ordered list item pattern.
    // Convert the paragraph to an unordered list item.
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ListItemNode.ordered(id: paragraph.id, text: AttributedText(text: "")),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: textInsertionEvent.nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.place,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// Adjusts a [ParagraphNode] to use a blockquote block attribution when a
/// user types " > " (or similar) at the start of the paragraph.
class BlockquoteConversionReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final didTypeSpaceAtEnd = EditInspector.didTypeSpace(document, changeList);
    if (!didTypeSpaceAtEnd) {
      return;
    }

    final edit = changeList[changeList.length - 2] as DocumentEdit;
    final textInsertionEvent = edit.change as TextInsertionEvent;
    final paragraph = document.getNodeById(textInsertionEvent.nodeId) as ParagraphNode;
    final blockquoteMatch = RegExp(r'^>\s$');
    if (!paragraph.text.text.startsWith(blockquoteMatch)) {
      return;
    }

    // The user started a paragraph with blockquote pattern.
    // Convert the paragraph to a blockquote.
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ParagraphNode(
          id: paragraph.id,
          text: AttributedText(text: ""),
          metadata: {
            "blockType": blockquoteAttribution,
          },
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: textInsertionEvent.nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.place,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// Converts full node content that looks like "--- " into a horizontal rule.
class HorizontalRuleConversionReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final didTypeSpaceAtEnd = EditInspector.didTypeSpace(document, changeList);
    if (!didTypeSpaceAtEnd) {
      return;
    }

    final edit = changeList[changeList.length - 2] as DocumentEdit;
    final textInsertionEvent = edit.change as TextInsertionEvent;
    final paragraph = document.getNodeById(textInsertionEvent.nodeId) as ParagraphNode;
    final hrMatch = RegExp(r'^---*\s$');
    if (!paragraph.text.text.startsWith(hrMatch)) {
      return;
    }

    // The user started a paragraph with a horizontal rule pattern.
    // Convert the paragraph to a horizontal rule.
    requestDispatcher.execute([
      InsertNodeAtIndexRequest(
        nodeIndex: document.getNodeIndexById(paragraph.id),
        newNode: HorizontalRuleNode(
          id: Editor.createNodeId(),
        ),
      ),
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ParagraphNode(
          id: paragraph.id,
          text: AttributedText(text: ""),
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.place,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// When the user creates a new node, and the previous node is just a URL
/// to an image, the replaces the previous node with the referenced image.
class ImageUrlConversionReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.isEmpty) {
      return;
    }
    if (changeList.last is! SubmitParagraphIntention) {
      return;
    }

    editorOpsLog.finer("Checking for image URL after paragraph submission");

    // The user pressed "enter" at the end of a paragraph. Check if the
    // paragraph is comprised of a URL.
    final selectionChange =
        changeList.reversed.firstWhereOrNull((item) => item is SelectionChangeEvent) as SelectionChangeEvent?;
    if (selectionChange == null || selectionChange.oldSelection == null) {
      // There was no selection change. There should be a selection change when
      // a paragraph is inserted. We don't know what's going on. Bail out.
      editorOpsLog.finer("There was no selection change. Not an image URL.");
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final previousNode = document.getNodeById(selectionChange.oldSelection!.extent.nodeId);
    if (previousNode is! ParagraphNode) {
      // The intention indicated that the user pressed "enter" from a paragraph
      // but the previously selected node isn't a paragraph. We don't know why.
      // Bail out.
      editorOpsLog.finer("Previous node wasn't a paragraph. Bailing.");
      return;
    }

    // Check if the submitted paragraph is comprised of a single URL.
    final extractedLinks = linkify(
      previousNode.text.text,
      options: const LinkifyOptions(
        humanize: false,
      ),
    );
    final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
    if (linkCount != 1) {
      // Either there aren't any URLs, or there are multiple. This reaction
      // doesn't apply.
      editorOpsLog.finer("Didn't find exactly 1 link. Found: $linkCount");
      return;
    }

    final url = extractedLinks.firstWhere((element) => element is UrlElement).text;
    if (url != previousNode.text.text.trim()) {
      // There's more in the paragraph than just a URL. This reaction
      // doesn't apply.
      editorOpsLog.finer("Paragraph had more than just a URL");
      return;
    }

    // The submitted paragraph consists of a single URL. Check if that
    // URL is an image. If it is, replace the submitted paragraph with
    // an image.
    // TODO: move the URL lookup into a behavior within the node. We don't want async reaction behaviors.
    final originalText = previousNode.text.text;
    _isImageUrl(url).then((isImage) {
      if (!isImage) {
        editorOpsLog.finer("Checked URL, but it's not an image");
        return;
      }

      // The URL is an image. Convert the node.
      editorOpsLog.finer('The URL is an image. Converting the ParagraphNode to an ImageNode.');
      final node = document.getNodeById(previousNode.id);
      if (node is! ParagraphNode) {
        editorOpsLog.finer('The node has become something other than a ParagraphNode ($node). Can\'t convert ndoe.');
        return;
      }
      final currentText = node.text.text;
      if (currentText.trim() != originalText.trim()) {
        editorOpsLog.finer('The node content changed in a non-trivial way. Aborting node conversion.');
        return;
      }

      final imageNode = ImageNode(
        id: node.id,
        imageUrl: url,
      );

      requestDispatcher.execute([
        ReplaceNodeRequest(
          existingNodeId: node.id,
          newNode: imageNode,
        ),
      ]);
    });
  }

  Future<bool> _isImageUrl(String url) async {
    late http.Response response;

    // This function throws [SocketException] when the [url] is not valid.
    // For instance, when typing for https://f|, it throws
    // Unhandled Exception: SocketException: Failed host lookup: 'f'
    //
    // It doesn't affect any functionality, but it throws exception and preventing
    // any related test to pass
    try {
      response = await http.get(Uri.parse(url));
    } on SocketException catch (e) {
      editorOpsLog.fine('Failed to load URL: ${e.message}');
      return false;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      editorOpsLog.fine('Failed to load URL: ${response.statusCode} - ${response.reasonPhrase}');
      return false;
    }

    final contentType = response.headers['content-type'];
    if (contentType == null) {
      editorOpsLog.fine('Failed to determine URL content type.');
      return false;
    }
    if (!contentType.startsWith('image/')) {
      editorOpsLog.fine('URL is not an image. Ignoring');
      return false;
    }

    return true;
  }
}

class LinkifyReaction implements EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> edits) {
    final document = editContext.find<MutableDocument>(Editor.documentKey);
    TextInsertionEvent? linkifyCandidate;
    for (final edit in edits) {
      if (edit is DocumentEdit) {
        final change = edit.change;
        if (change is TextInsertionEvent && change.text == " ") {
          // Every space insertion might appear after a URL.
          linkifyCandidate = change;
        }
      } else if (edit is SelectionChangeEvent) {
        if (linkifyCandidate == null) {
          // There was no text insertion to linkify.
          continue;
        }

        if (edit.newSelection == null) {
          // The editor doesn't have a selection. Don't linkify.
          linkifyCandidate = null;
          continue;
        } else if (!edit.newSelection!.isCollapsed) {
          // The selection is expanded. Don't linkify.
          linkifyCandidate = null;
          continue;
        }

        final caretPosition = edit.newSelection!.extent;
        if (caretPosition.nodeId != linkifyCandidate.nodeId) {
          // The selection moved to some other node. Don't linkify.
          linkifyCandidate = null;
          continue;
        }
        // +1 for the inserted space
        if ((caretPosition.nodePosition as TextNodePosition).offset != linkifyCandidate.offset + 1) {
          // The caret isn't sitting directly after the space. Whatever
          // these events represent, it doesn't represent the user typing
          // a URL and then press SPACE. Don't linkify.
          linkifyCandidate = null;
          continue;
        }

        // The caret sits directly after an inserted space. Get the word before
        // the space from the document, and linkify, if it fits a schema.
        final textNode = document.getNodeById(linkifyCandidate.nodeId) as TextNode;
        final text = textNode.text.text;
        final wordStartOffset = _moveOffsetByWord(text, linkifyCandidate.offset, true) ?? 0;
        final word = text.substring(wordStartOffset, linkifyCandidate.offset);

        // Ensure that the preceding word doesn't already contain a full or partial
        // link attribution.
        if (textNode.text
            .getAttributionSpansInRange(
              attributionFilter: (attribution) => attribution is LinkAttribution,
              range: SpanRange(start: wordStartOffset, end: linkifyCandidate.offset),
            )
            .isNotEmpty) {
          // There are link attributions in the preceding word. We don't want to mess with them.
          continue;
        }

        final extractedLinks = linkify(
          word,
          options: const LinkifyOptions(
            humanize: false,
          ),
        );
        final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
        if (linkCount == 1) {
          // The word is a single URL. Linkify it.
          textNode.text.addAttribution(
            LinkAttribution(url: Uri.parse(word)),
            SpanRange(start: wordStartOffset, end: linkifyCandidate.offset - 1),
          );
        }
      }
    }
  }

  int? _moveOffsetByWord(String text, int textOffset, bool upstream) {
    if (textOffset < 0 || textOffset > text.length) {
      throw Exception("Index '$textOffset' is out of string range. Length: ${text.length}");
    }

    // Create a character range, initially with zero length
    // Note that the getter for this object is confusingly named: it is an iterator but includes lots of functionality
    // beyond that interface, most importantly for us a range over this string that can be manipulated in terms of
    // characters
    final range = text.characters.iterator;
    // Expand the range so it reaches from the start of the string to the initial text offset. The text offset is passed
    // to us in terms of code units but the iterator deals in grapheme clusters, so we need to manually count the length
    // of each cluster until we reach the desired offset
    var remainingOffset = textOffset;
    range.expandWhile((char) {
      remainingOffset -= char.length;
      return remainingOffset >= 0;
    });
    final moveWhile = upstream ? range.dropBackWhile : range.expandWhile;
    // Adjust the range in the requested direction as long it does not end in a word. This accounts for cases where the
    // text offset starts in between words. After this we know the range ends on a word character
    moveWhile((char) => char != " ");
    // Adjust the range in the requested direction until it reaches a non-word character. After this we know that the
    // range ends at the start of the next word upstream or end of the next word downstream from the initial text offset
    moveWhile((char) => char != " ");
    // The range now reaches from the start of the string to our new text offset. Calculate that offset using the
    // range's string length and return it
    return range.current.length;
  }
}

class EditInspector {
  /// Whether [edits] ends with the user typing a space, i.e., typing a " ".
  ///
  /// Typing a space means that a space was inserted, and the caret moved from
  /// just before the space, to just after the space.
  static bool didTypeSpace(Document document, List<EditEvent> edits) {
    if (edits.length < 2) {
      return false;
    }

    final selectionEvent = edits.last;
    if (selectionEvent is! SelectionChangeEvent) {
      return false;
    }

    final edit = edits[edits.length - 2];
    if (edit is! DocumentEdit) {
      return false;
    }
    final textInsertionEvent = edit.change;
    if (textInsertionEvent is! TextInsertionEvent) {
      return false;
    }
    if (textInsertionEvent.text != " ") {
      return false;
    }

    if (selectionEvent.oldSelection == null || selectionEvent.newSelection == null) {
      return false;
    }
    if (selectionEvent.newSelection!.extent.nodeId != textInsertionEvent.nodeId) {
      return false;
    }

    final editedNode = document.getNodeById(textInsertionEvent.nodeId)!;
    // TODO: decide whether this inspection should be just for paragraphs or any text node
    if (editedNode is! ParagraphNode) {
      return false;
    }

    final caretPosition = selectionEvent.newSelection!.extent.nodePosition as TextNodePosition;
    final editedText = editedNode.text.text;
    if (caretPosition.offset != editedText.length) {
      return false;
    }

    // The inserted text was a space, and the caret now sits at the end of
    // the edited text. We assume this means that the user just typed a space.
    return true;
  }

  EditInspector._();
}
