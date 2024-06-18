import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/parsing/block_formats.dart';
import 'package:super_editor_quill/src/parsing/inline_formats.dart';

/// Parses a fully formed Quill Delta document into a [MutableDocument].
///
/// The format of a Delta document looks like:
///
///     {
///       "ops": [
///         ...
///       ]
///     }
MutableDocument parseQuillDeltaDocument(
  Map<String, dynamic> deltaDocument, {
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
}) {
  return parseQuillDeltaOps(deltaDocument["ops"], inlineFormats: inlineFormats);
}

/// Runs a list of Quill Delta operations to construct a [MutableDocument],
/// beginning with an empty document.
MutableDocument parseQuillDeltaOps(
  List<dynamic> deltaOps, {
  List<BlockDeltaFormat> blockFormats = defaultBlockFormats,
  List<InlineDeltaFormat> inlineFormats = defaultInlineFormats,
}) {
  final deltaDocument = Delta.fromJson(deltaOps);

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

  for (final delta in deltaDocument.operations) {
    delta.applyToDocument(editor, blockFormats: blockFormats, inlineFormats: inlineFormats);
  }

  return document;
}

const defaultBlockFormats = [
  HeaderDeltaFormat(),
  BlockquoteDeltaFormat(),
  CodeBlockDeltaFormat(),
  ListDeltaFormat(),
  AlignDeltaFormat(),
];

const defaultInlineFormats = [
  // Named inline attributes (no parsing).
  NamedInlineDeltaFormat("bold", boldAttribution),
  NamedInlineDeltaFormat("italic", italicsAttribution),
  NamedInlineDeltaFormat("underline", underlineAttribution),
  NamedInlineDeltaFormat("strike", strikethroughAttribution),
  // TODO: superscript/subscript (needs a superscript attribution in Super Editor)
  NamedInlineDeltaFormat("code", codeAttribution),

  // Inline attributes with parsed values.
  ColorDeltaFormat(),
  BackgroundColorDeltaFormat(),
  // TODO: font format "font" (needs a font attribution in Super Editor)
  SizeDeltaFormat(),
  LinkDeltaFormat(),
];

/// An extension on Quill Delta [Operation]s that adds the ability for an operation to
/// apply itself to a Super Editor document through an [Editor].
extension OperationParser on Operation {
  static const _formula = "formula"; // requires KaTeX
  static const _image = "image";
  static const _video = "video";

  void applyToDocument(
    Editor editor, {
    required List<BlockDeltaFormat> blockFormats,
    required List<InlineDeltaFormat> inlineFormats,
  }) {
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    switch (type) {
      case _OperationType.insert:
        print("Running an insert operation...");
        if (data is String) {
          // This is a text insertion delta.
          _doInsertText(editor, composer, blockFormats, inlineFormats);
        }
        if (data is Object) {
          // This is an embed insertion delta.
          _doInsertMedia(editor, composer);
        }

        print("After insert:");
        final document = editor.context.find<MutableDocument>(Editor.documentKey);
        for (final node in document.nodes) {
          print(" - ${node.id} -> ${node.runtimeType}: ${node is TextNode ? node.text.text : ""}");
        }
        print("");
      case _OperationType.retain:
        final count = data as int;
        final newPosition = _findPositionDownstream(document, composer, count);
        editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: newPosition),
            SelectionChangeType.pushCaret,
            SelectionReason.contentChange,
          ),
        ]);
      case _OperationType.delete:
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
    print("Processing insertion delta '${(data as String).replaceAll("\n", "^")}'. Attributes: $attributes");
    final changeRequests = <EditRequest>[];

    // Apply block attributes *before* inserting the new delta text.
    for (final blockFormat in blockFormats) {
      final blockChanges = blockFormat.applyTo(this, editor);
      if (blockChanges != null) {
        changeRequests.addAll(blockChanges);
      }
    }

    // Insert new delta text and apply inline attributes.
    var text = data as String;
    var currentNodeId = composer.selection!.extent.nodeId;
    var currentTextPosition = composer.selection!.extent.nodePosition as TextNodePosition;

    // // Strip leading and trailing newlines from the inserted text and explicitly
    // // insert paragraphs in their place.
    // final leadingNewlineMatch = RegExp(r'^\n+').firstMatch(text);
    // final int leadingNewlineCount =
    //     leadingNewlineMatch != null ? leadingNewlineMatch.end - leadingNewlineMatch.start : 0;
    //
    // // Note: we need to be careful that when a string is nothing but newlines, we don't
    // // match them as both leading and trailing. We choose to handle those as leading and
    // // then avoid trailing newlines in that case.
    // final trailingNewlineMatch = RegExp(r'\n+$').firstMatch(text);
    // final trailingNewlineCount = leadingNewlineCount != text.length && trailingNewlineMatch != null
    //     ? trailingNewlineMatch.end - trailingNewlineMatch.start
    //     : 0;
    //
    // text = text.substring(leadingNewlineCount, text.length - trailingNewlineCount);
    //
    // print("Inserting $leadingNewlineCount leading newlines, and $trailingNewlineCount trailing newlines");

    final inlineAttributions = <Attribution>{};
    for (final inlineFormat in inlineFormats) {
      final attribution = inlineFormat.from(this);
      if (attribution != null) {
        inlineAttributions.add(attribution);
      }
    }

    final textPerLine = text.split("\n");
    print("Lines (${textPerLine.length}): $textPerLine");
    for (int i = 0; i < textPerLine.length; i += 1) {
      final line = textPerLine[i];
      final newNodeId = Editor.createNodeId();

      print("Inserting text in node $currentNodeId: '$line'");

      changeRequests.addAll([
        // Insert text.
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
        if (i < textPerLine.length - 1)
          InsertNodeAfterNodeRequest(
            existingNodeId: currentNodeId,
            newNode: ParagraphNode(
              id: newNodeId,
              text: AttributedText(""),
            ),
          ),
      ]);

      if (i < textPerLine.length - 1) {
        // We added a new paragraph. Update the node ID.
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

    // Check if the selected node is an empty text node. If it, we want to replace it
    // with the media that we're inserting.
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final selectedNodeId = composer.selection!.extent.nodeId;
    final selectedNode = document.getNodeById(selectedNodeId);
    final shouldReplaceSelectedNode = selectedNode is TextNode && selectedNode.text.text.isEmpty;

    if (content.containsKey("image")) {
      // This insertion is for an image.
      final imageNodeId = Editor.createNodeId();
      final imageUrl = content["image"] as String;
      final imageNode = ImageNode(
        id: imageNodeId,
        imageUrl: imageUrl,
      );
      print("Inserting image: $imageUrl");

      final newParagraphId = Editor.createNodeId();

      editor.execute([
        shouldReplaceSelectedNode
            ? ReplaceNodeRequest(
                existingNodeId: selectedNodeId,
                newNode: imageNode,
              )
            : InsertNodeAfterNodeRequest(
                existingNodeId: composer.selection!.extent.nodeId,
                newNode: imageNode,
              ),
        InsertNodeAfterNodeRequest(
          existingNodeId: imageNodeId,
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

    // TODO: video
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

  _OperationType get type {
    if (isInsert) {
      return _OperationType.insert;
    } else if (isRetain) {
      return _OperationType.retain;
    } else if (isDelete) {
      return _OperationType.delete;
    } else {
      throw Exception("Unknown operation type: $this");
    }
  }
}

enum _OperationType {
  insert,
  retain,
  delete,
}
