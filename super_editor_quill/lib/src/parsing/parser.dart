import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/content/multimedia.dart';
import 'package:super_editor_quill/src/parsing/block_formats.dart';
import 'package:super_editor_quill/src/parsing/inline_formats.dart';

/// Parses a fully formed Quill Delta document (as JSON) into a [MutableDocument].
///
/// The format of a Delta document looks like:
///
///     {
///       "ops": [
///         ...
///       ]
///     }
///
/// For more information about the Quill Delta format, see the official
/// documentation: https://quilljs.com/docs/delta/
MutableDocument parseQuillDeltaDocument(
  Map<String, dynamic> deltaDocument, {
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
}) {
  return parseQuillDeltaOps(deltaDocument["ops"], inlineFormats: inlineFormats);
}

/// Parses a list Quill Delta operations (as JSON) into a [MutableDocument].
///
/// This parser is the same as [parseQuillDeltaDocument] except that this method
/// directly accepts the operations list instead of the whole document map. This
/// method is provided for convenience because in some situations only the
/// operations are exchanged, rather than the whole document object.
MutableDocument parseQuillDeltaOps(
  List<dynamic> deltaOps, {
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
}) {
  // Deserialize the delta operations JSON into a Dart data structure.
  final deltaDocument = Delta.fromJson(deltaOps);

  // Create a new, empty Super Editor document.
  final document = MutableDocument.empty();
  final composer = MutableDocumentComposer();
  final editor = Editor(
    editables: {
      Editor.documentKey: document,
      Editor.composerKey: composer,
    },
    requestHandlers: List.from(defaultRequestHandlers),
    // No reactions. Follow the delta operations exactly.
    reactionPipeline: [],
  );

  // Place the caret in the (only) empty paragraph so we can begin applying
  // deltas to the document.
  final firstParagraph = document.nodes.first as ParagraphNode;
  composer.setSelectionWithReason(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: firstParagraph.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ),
    SelectionReason.contentChange,
  );

  // Run every Quill Delta operation on the empty document. At the end of this
  // process the Super Editor document will reflect the desired Quill Delta
  // document state.
  for (final delta in deltaDocument.operations) {
    delta.applyToDocument(editor, blockFormats: blockFormats, inlineFormats: inlineFormats);
  }

  return document;
}

/// The standard block-level text formats that are parsed from Quill Deltas,
/// e.g., headers, blockquotes, list items.
const defaultBlockFormats = [
  HeaderDeltaFormat(),
  BlockquoteDeltaFormat(),
  CodeBlockDeltaFormat(),
  ListDeltaFormat(),
  AlignDeltaFormat(),
  IndentParagraphDeltaFormat(),
];

/// The standard inline text formats that are parsed from Quill Deltas, e.g.,
/// bold, italics, underline, links.
const defaultInlineFormats = [
  // Named inline attributes (no parsing).
  NamedInlineDeltaFormat("bold", boldAttribution),
  NamedInlineDeltaFormat("italic", italicsAttribution),
  NamedInlineDeltaFormat("underline", underlineAttribution),
  NamedInlineDeltaFormat("strike", strikethroughAttribution),
  NamedInlineDeltaFormat("code", codeAttribution),

  // Inline attributes with parsed values.
  ColorDeltaFormat(),
  BackgroundColorDeltaFormat(),
  ScriptDeltaFormat(),
  FontFamilyDeltaFormat(),
  SizeDeltaFormat(),
  LinkDeltaFormat(),
];

/// An extension on Quill Delta [Operation]s that adds the ability for an operation to
/// apply itself to a Super Editor document through an [Editor].
extension OperationParser on Operation {
  /// Applies this operation to a Super Editor document by sending requests
  /// through the given [editor].
  ///
  /// To configure how a given Quill Delta attribute impacts text blocks and text spans,
  /// provide the desired [blockFormats] and [inlineFormats]. For example, the recognition
  /// of an attribute called "bold", and the application of a [boldAttribution] to the
  /// Super Editor document, is implemented by the [BlockDeltaFormat], which should be
  /// included in [inlineFormats].
  void applyToDocument(
    Editor editor, {
    required List<BlockDeltaFormat> blockFormats,
    required List<InlineDeltaFormat> inlineFormats,
  }) {
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    switch (type) {
      case DeltaOperationType.insert:
        if (data is String) {
          // This is a text insertion delta.
          _doInsertText(editor, composer, blockFormats, inlineFormats);
        }
        if (data is Object) {
          // This is an embed insertion delta.
          _doInsertMedia(editor, composer);
        }

        // Deduplicate all back-to-back code blocks.
        final document = editor.context.find<MutableDocument>(Editor.documentKey);
        if (document.nodes.length < 3) {
          // Minimum of 3 nodes: code, code, newline.
          break;
        }

        var codeBlocks = <ParagraphNode>[];
        for (int i = document.nodes.length - 2; i >= 0; i -= 1) {
          final node = document.nodes[i];
          if (node is! ParagraphNode) {
            break;
          }
          if (node.getMetadataValue("blockType") != codeAttribution) {
            break;
          }

          codeBlocks.add(node);
        }

        if (codeBlocks.length < 2) {
          break;
        }

        codeBlocks = codeBlocks.reversed.toList();
        final mergeNode = codeBlocks.first;
        var codeToMove = codeBlocks[1].text.insertString(textToInsert: "\n", startOffset: 0);
        for (int i = 2; i < codeBlocks.length; i += 1) {
          codeToMove = codeToMove.copyAndAppend(codeBlocks[i].text.insertString(textToInsert: "\n", startOffset: 0));
        }

        editor.execute([
          InsertAttributedTextRequest(
            DocumentPosition(nodeId: mergeNode.id, nodePosition: mergeNode.endPosition),
            codeToMove,
          ),
          for (int i = 1; i < codeBlocks.length; i += 1) //
            DeleteNodeRequest(nodeId: codeBlocks[i].id),
        ]);

      case DeltaOperationType.retain:
        final count = data as int;
        final newPosition = _findPositionDownstream(document, composer, count);
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: newPosition),
            SelectionChangeType.pushCaret,
            SelectionReason.contentChange,
          ),
        ]);

      case DeltaOperationType.delete:
        final count = data as int;
        final newPosition = _findPositionDownstream(document, composer, count);
        editor.execute([
          DeleteContentRequest(
            documentRange: DocumentRange(
              start: composer.selection!.extent,
              end: newPosition,
            ),
          ),
        ]);
    }
  }

  void _doInsertText(
    Editor editor,
    DocumentComposer composer,
    List<BlockDeltaFormat> blockFormats,
    List<InlineDeltaFormat> inlineFormats,
  ) {
    final changeRequests = <EditRequest>[];

    // Apply block attributes *before* inserting the new delta text.
    //
    // For example, consider the following deltas:
    //
    //     ops: [
    //       { insert: 'Welcome Header' },
    //       { insert: '\n', attributes: { "header": 1 } },
    //       { insert: 'This is the content' }
    //     ]
    //
    // Notice that the "header" attribute is included in the delta that follows
    // the actual header text. That's the behavior we're implementing by applying
    // block formats here *before* inserting any new text.
    for (final blockFormat in blockFormats) {
      final blockChanges = blockFormat.applyTo(this, editor);
      if (blockChanges != null) {
        changeRequests.addAll(blockChanges);
      }
    }

    // Insert new delta text and apply inline attributes.
    //
    // The process of inserting text also requires that we handle newline characters.
    // Each newline needs to add a new paragraph. Newlines can appear at the beginning,
    // the end, and in the middle of a single text insertion.
    var text = data as String;
    var currentNodeId = composer.selection!.extent.nodeId;
    var currentTextPosition = composer.selection!.extent.nodePosition as TextNodePosition;

    // The included inline attributes apply to all text within this insert operation.
    final inlineAttributions = <Attribution>{};
    for (final inlineFormat in inlineFormats) {
      final attribution = inlineFormat.from(this);
      if (attribution != null) {
        inlineAttributions.add(attribution);
      }
    }

    // Break the insertion text at every newline so we can insert paragraphs.
    final textPerLine = text.split("\n");
    for (int i = 0; i < textPerLine.length; i += 1) {
      final line = textPerLine[i];
      final newNodeId = Editor.createNodeId();

      changeRequests.addAll([
        // Insert a line of text.
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: currentNodeId,
            nodePosition: currentTextPosition,
          ),
          textToInsert: line,
          attributions: line.isNotEmpty ? inlineAttributions : {},
        ),
        // Every line of text is followed by a newline, except the last
        // line. If this isn't the last line, add a new paragraph.
        if (i < textPerLine.length - 1) ...[
          InsertNodeAfterNodeRequest(
            existingNodeId: currentNodeId,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(""),
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
            SelectionReason.contentChange,
          ),
        ],
      ]);

      if (i < textPerLine.length - 1) {
        // This isn't the last line, so we added a new paragraph. Update the node ID.
        currentNodeId = newNodeId;
        currentTextPosition = const TextNodePosition(offset: 0);
      }
    }

    // Execute the block changes and inline text insertions.
    editor.execute(changeRequests);
  }

  void _doInsertMedia(Editor editor, DocumentComposer composer) {
    final content = data;
    if (content is! Map<String, dynamic>) {
      // We don't know what this is.
      return;
    }

    // Check if the selected node is an empty text node. If it is, we want to replace it
    // with the media that we're inserting.
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final selectedNodeId = composer.selection!.extent.nodeId;
    final selectedNode = document.getNodeById(selectedNodeId);
    final shouldReplaceSelectedNode = selectedNode is TextNode && selectedNode.text.text.isEmpty;

    String? newNodeId;
    String? mediaUrl;
    DocumentNode? newNode;

    if (content.containsKey("image")) {
      // This insertion is for an image.
      newNodeId = Editor.createNodeId();
      mediaUrl = content["image"] as String;
      newNode = ImageNode(
        id: newNodeId,
        imageUrl: mediaUrl,
      );
    }

    if (content.containsKey("video")) {
      // This insertion is for a video.
      newNodeId = Editor.createNodeId();
      mediaUrl = content["video"] as String;
      newNode = VideoNode(
        id: newNodeId,
        url: mediaUrl,
      );
    }

    if (content.containsKey("audio")) {
      // This insertion is for a video.
      newNodeId = Editor.createNodeId();
      mediaUrl = content["audio"] as String;
      newNode = AudioNode(
        id: newNodeId,
        url: mediaUrl,
      );
    }

    if (content.containsKey("file")) {
      // This insertion is for a video.
      newNodeId = Editor.createNodeId();
      mediaUrl = content["file"] as String;
      newNode = FileNode(
        id: newNodeId,
        url: mediaUrl,
      );
    }

    if (newNode == null) {
      // We didn't find any media to insert.
      return;
    }

    // Insert the media in the document.
    final newParagraphId = Editor.createNodeId();
    editor.execute([
      shouldReplaceSelectedNode
          ? ReplaceNodeRequest(
              existingNodeId: selectedNodeId,
              newNode: newNode,
            )
          : InsertNodeAfterNodeRequest(
              existingNodeId: composer.selection!.extent.nodeId,
              newNode: newNode,
            ),
      InsertNodeAfterNodeRequest(
        existingNodeId: newNodeId!,
        newNode: ParagraphNode(
          id: newParagraphId,
          text: AttributedText(""),
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newParagraphId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.contentChange,
      ),
    ]);
  }

  /// Moves [count] units downstream from the current caret position.
  ///
  /// The distance of each unit in [count] is defined by the Delta spec. In text, a unit
  /// is a character. In media, such as videos or images, a unit is the whole media item.
  DocumentPosition _findPositionDownstream(Document document, DocumentComposer composer, int count) {
    var caretPosition = composer.selection!.extent;
    var selectedNode = document.getNodeById(caretPosition.nodeId)!;
    int unitsToMove = count;

    while (unitsToMove > 0) {
      if (selectedNode is TextNode) {
        final currentPosition = caretPosition.nodePosition as TextNodePosition;

        if (selectedNode.text.length - currentPosition.offset >= unitsToMove) {
          // The caret wants to move somewhere in this paragraph. Return that position.
          return DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: TextNodePosition(offset: currentPosition.offset + unitsToMove),
          );
        }

        // The caret wants to move beyond this paragraph.
        unitsToMove -= selectedNode.text.length - currentPosition.offset;
        selectedNode = document.getNodeAfter(selectedNode)!;
        caretPosition = DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: selectedNode.beginningPosition,
        );
      } else {
        // This is a block node. The caret either sits on the upstream side or
        // the downstream side.
        if (unitsToMove == 1) {
          // The deltas want to move across this block to the downstream side.
          // Return that position.
          return DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: selectedNode.endPosition,
          );
        }

        // The deltas want to retain more beyond this node.
        unitsToMove -= 1;
        selectedNode = document.getNodeAfter(selectedNode)!;
        caretPosition = DocumentPosition(
          nodeId: selectedNode.id,
          nodePosition: selectedNode.beginningPosition,
        );
      }
    }

    return caretPosition;
  }

  /// Returns the [DeltaOperationType] of this operation.
  ///
  /// The [DeltaOperationType] is provided so that developers can use a `switch`
  /// statement to handle all operation types, rather than repeated if-statements
  /// on [isInsert], [isRetain], and [isDelete].
  DeltaOperationType get type {
    if (isInsert) {
      return DeltaOperationType.insert;
    } else if (isRetain) {
      return DeltaOperationType.retain;
    } else if (isDelete) {
      return DeltaOperationType.delete;
    } else {
      throw Exception("Unknown operation type: $this");
    }
  }
}

enum DeltaOperationType {
  insert,
  retain,
  delete,
}
