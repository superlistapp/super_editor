import 'package:super_editor/super_editor.dart';

/// Tokenizes a term at the beginning of a paragraph, such as a "*" for a
/// list item, or "##" for an H2.
class TokenizeBeginningOfParagraph implements DocumentChangePostProcess {
  TokenizeBeginningOfParagraph(this._composer) {
    _composer.selectionNotifier.addListener(_onSelectionChange);
  }

  void dispose() {
    _composer.selectionNotifier.addListener(_onSelectionChange);
  }

  final DocumentComposer _composer;
  DocumentSelection? _latestSelection;
  String? _observedTextNodeId;
  AttributedText? _previousParagraphText;

  void _onSelectionChange() {
    _latestSelection = _composer.selection;
  }

  @override
  void onDocumentChange(DocumentEditor editor) {
    final currentSelection = _composer.selection;
    if (currentSelection == null) {
      return;
    }

    if (!currentSelection.isCollapsed) {
      // We only want to tokenize when the user types a space after
      // the token, so an expanded selection wouldn't qualify.
      return;
    }

    if (currentSelection.extent.nodePosition is! TextNodePosition) {
      // The user has selected a non-text node. We can't tokenize non-text.
      return;
    }

    final textNode = editor.document.getNode(currentSelection.extent) as TextNode;
    final textNodePosition = currentSelection.extent.nodePosition as TextNodePosition;
    final textBeforeCaret = textNode.text.text.substring(
        0, textNodePosition.offset < textNode.text.text.length ? textNodePosition.offset + 1 : textNodePosition.offset);
    print("Text before caret: '$textBeforeCaret'");

    if (textBeforeCaret == "# ") {
      print("H1 hash found");

      // The selection change needs to happen before the deletion so that
      // the selection is always valid.
      _composer.selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: textNode.id,
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      editor.executeCommand(DeleteSelectionCommand(
        documentSelection: DocumentSelection(
          base: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      ));

      textNode.putMetadataValue("blockType", header1Attribution);
    } else if (textBeforeCaret == "## ") {
      print("H2 hash found");
      textNode.putMetadataValue("blockType", header2Attribution);
    }
  }
}

/// Tokenizes the term at the caret, regardless of where that term appears
/// in a paragraph.
class TokenizeTermInParagraph implements DocumentChangePostProcess {
  @override
  void onDocumentChange(DocumentEditor editor) {
    // TODO: implement onTextChange
  }
}
