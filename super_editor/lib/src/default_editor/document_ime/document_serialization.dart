import 'dart:math';

import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Serializes a [Document] and [DocumentSelection] into a form that's understood by
/// the Input Method Engine (IME), and vis-a-versa.
///
/// The IME only understands strings of plain text. Therefore, to make [Document] content
/// available for IME editing, the [Document] structure needs to be serialized into a run of text.
///
/// When the IME alters the given content, that plain text needs to be deserialized back into
/// a [Document] structure.
///
/// This class implements both [Document] serialization and deserialization for the IME.
class DocumentImeSerializer {
  static const _leadingCharacter = '. ';

  DocumentImeSerializer(
    this._doc,
    this._selection,
    this._composingRegion, [
    this._prependedCharacterPolicy = PrependedCharacterPolicy.automatic,
  ]) {
    _serialize();
  }

  final Document _doc;
  final DocumentSelection _selection;
  final DocumentRange? _composingRegion;
  final _imeRangesToDocTextNodes = <TextRange, String>{};
  final _docTextNodesToImeRanges = <String, TextRange>{};
  final _selectedNodes = <DocumentNode>[];
  late String _imeText;
  final PrependedCharacterPolicy _prependedCharacterPolicy;
  String _prependedPlaceholder = '';

  void _serialize() {
    editorImeLog.fine("Creating an IME model from document, selection, and composing region");
    final buffer = StringBuffer();
    int characterCount = 0;

    if (_shouldPrependPlaceholder()) {
      // Put an arbitrary character at the front of the text so that
      // the IME will report backspace buttons when the caret sits at
      // the beginning of the node. For example, the caret is at the
      // beginning of some text and we want to combine this text with
      // the text above it when the user presses backspace.
      //
      //     Text above...
      //     |The selected text node.
      _prependedPlaceholder = _leadingCharacter;
      buffer.write(_prependedPlaceholder);
      characterCount = _prependedPlaceholder.length;
    } else {
      _prependedPlaceholder = '';
    }

    _selectedNodes.clear();
    _selectedNodes.addAll(_doc.getNodesInContentOrder(_selection));
    for (int i = 0; i < _selectedNodes.length; i += 1) {
      // Append a newline character before appending another node's text.
      //
      // The choice to separate each node with a newline was a judgement call.
      // There is no OS-level expectation for how structured content should
      // collapse down to IME content.
      if (i != 0) {
        buffer.write('\n');
        characterCount += 1;
      }

      final node = _selectedNodes[i];
      if (node is! TextNode) {
        buffer.write('~');
        characterCount += 1;

        final imeRange = TextRange(start: characterCount - 1, end: characterCount);
        _imeRangesToDocTextNodes[imeRange] = node.id;
        _docTextNodesToImeRanges[node.id] = imeRange;

        continue;
      }

      // Cache mappings between the IME text range and the document position
      // so that we can easily convert between the two, when requested.
      final imeRange = TextRange(start: characterCount, end: characterCount + node.text.text.length);
      _imeRangesToDocTextNodes[imeRange] = node.id;
      _docTextNodesToImeRanges[node.id] = imeRange;

      // Concatenate this node's text with the previous nodes.
      buffer.write(node.text.text);
      characterCount += node.text.text.length;
    }

    _imeText = buffer.toString();
    editorImeLog.fine("IME serialization:\n'$_imeText'");
  }

  bool _shouldPrependPlaceholder() {
    if (_prependedCharacterPolicy == PrependedCharacterPolicy.include) {
      // The client explicitly requested prepended characters. This is
      // useful, for example, when a client has an existing serialization that
      // includes prepended characters and wants to compare that serialization
      // to a new serialization. The client wants to ensure that the new
      // serialization has prepended characters, too.
      return true;
    } else if (_prependedCharacterPolicy == PrependedCharacterPolicy.exclude) {
      return false;
    }

    // We want to prepend an arbitrary placeholder character whenever the
    // user's selection is collapsed at the beginning of a node, and there's
    // another node above the selected node. Without the arbitrary character,
    // the IME would assume that there's no content before the current node and
    // therefore it wouldn't report the backspace button.
    final selectedNode = _doc.getNode(_selection.extent)!;
    final selectedNodeIndex = _doc.getNodeIndexById(selectedNode.id);
    return selectedNodeIndex > 0 &&
        _selection.isCollapsed &&
        _selection.extent.nodePosition == selectedNode.beginningPosition;
  }

  bool get didPrependPlaceholder => _prependedPlaceholder.isNotEmpty;

  DocumentSelection? imeToDocumentSelection(TextSelection imeSelection) {
    editorImeLog.fine("Creating doc selection from IME selection: $imeSelection");
    if (!imeSelection.isValid) {
      editorImeLog.fine("The IME selection is empty. Returning a null document selection.");
      return null;
    }

    if (didPrependPlaceholder) {
      // The IME might be trying to select our invisible prepended characters.
      // If so, we need to adjust the IME selection bounds.
      if ((imeSelection.isCollapsed && imeSelection.extentOffset < _prependedPlaceholder.length) ||
          (imeSelection.start < _prependedPlaceholder.length && imeSelection.end == _prependedPlaceholder.length)) {
        // The IME is only trying to select our invisible characters. Return null
        // for an empty document selection.
        editorImeLog.fine("The IME only selected invisible characters. Returning a null document selection.");
        return null;
      } else if (imeSelection.start < _prependedPlaceholder.length){
        // The IME is trying to select some invisible characters and some real
        // characters. Remove the invisible characters from the IME selection before
        // converting it to a document selection.
        editorImeLog.fine("Removing invisible characters from IME selection.");
        imeSelection = imeSelection.copyWith(
          baseOffset: max(imeSelection.baseOffset, _prependedPlaceholder.length),
          extentOffset: max(imeSelection.extentOffset, _prependedPlaceholder.length),
        );
        editorImeLog.fine("Adjusted IME selection is: $imeSelection");
      } else {
        editorImeLog.fine("The IME only selected visible characters. No adjustment necessary.");
      }
    } else {
      editorImeLog.fine("The serialization doesn't have any invisible characters. No adjustment necessary.");
    }

    return DocumentSelection(
      base: _imeToDocumentPosition(
        imeSelection.base,
        isUpstream: imeSelection.base.affinity == TextAffinity.upstream,
      ),
      extent: _imeToDocumentPosition(
        imeSelection.extent,
        isUpstream: imeSelection.extent.affinity == TextAffinity.upstream,
      ),
    );
  }

  DocumentRange? imeToDocumentRange(TextRange imeRange) {
    editorImeLog.fine("Creating doc range from IME range: $imeRange");
    if (!imeRange.isValid) {
      editorImeLog.fine("The IME range is empty. Returning null document range.");
      // The range is empty. Return null.
      return null;
    }

    if (didPrependPlaceholder) {
      // The IME might be trying to select our invisible prepended characters.
      // If so, we need to adjust the IME selection bounds.
      if ((imeRange.isCollapsed && imeRange.end < _prependedPlaceholder.length) ||
          (imeRange.start < _prependedPlaceholder.length && imeRange.end == _prependedPlaceholder.length)) {
        // The IME is only trying to select our invisible characters. Return null
        // for an empty document range.
        editorImeLog
            .fine("The IME tried to create a range around invisible characters. Returning null document range.");
        return null;
      } else {
        // The IME is trying to select some invisible characters and some real
        // characters. Remove the invisible characters from the IME range before
        // converting it to a document range.
        editorImeLog.fine("Removing arbitrary character from IME range.");
        editorImeLog.fine("Before adjustment, range: $imeRange");
        editorImeLog.fine("Prepended characters length: ${_prependedPlaceholder.length}");
        imeRange = TextRange(
          start: max(imeRange.start, _prependedPlaceholder.length),
          end: max(imeRange.end, _prependedPlaceholder.length),
        );
        editorImeLog.fine("Adjusted IME range to: $imeRange");
      }
    } else {
      editorImeLog.fine("The IME is only composing visible characters. No adjustment necessary.");
    }

    return DocumentRange(
      start: _imeToDocumentPosition(
        TextPosition(offset: imeRange.start),
        isUpstream: false,
      ),
      end: _imeToDocumentPosition(
        TextPosition(offset: imeRange.end),
        isUpstream: false,
      ),
    );
  }

  DocumentPosition _imeToDocumentPosition(TextPosition imePosition, {required bool isUpstream}) {
    for (final range in _imeRangesToDocTextNodes.keys) {
      if (range.start <= imePosition.offset && imePosition.offset <= range.end) {
        final node = _doc.getNodeById(_imeRangesToDocTextNodes[range]!)!;

        if (node is TextNode) {
          return DocumentPosition(
            nodeId: _imeRangesToDocTextNodes[range]!,
            nodePosition: TextNodePosition(offset: imePosition.offset - range.start),
          );
        } else {
          if (imePosition.offset <= range.start) {
            // Return a position at the start of the node.
            return DocumentPosition(
              nodeId: node.id,
              nodePosition: node.beginningPosition,
            );
          } else {
            // Return a position at the end of the node.
            return DocumentPosition(
              nodeId: node.id,
              nodePosition: node.endPosition,
            );
          }
        }
      }
    }

    editorImeLog
        .shout("Couldn't map an IME position to a document position. IME position: $imePosition. Available ranges:");
    for (final range in _imeRangesToDocTextNodes.keys) {
      editorImeLog.shout("Range: ${range.start} -> ${range.end}");
    }
    throw Exception("Couldn't map an IME position to a document position. IME position: $imePosition");
  }

  TextSelection documentToImeSelection(DocumentSelection docSelection) {
    editorImeLog.fine("Converting doc selection to ime selection: $docSelection");
    final selectionAffinity = _doc.getAffinityForSelection(docSelection);
    final startImePosition = _documentToImePosition(docSelection.base);
    final endImePosition = _documentToImePosition(docSelection.extent);

    editorImeLog.fine("Start IME position: $startImePosition");
    editorImeLog.fine("End IME position: $endImePosition");
    return TextSelection(
      baseOffset: startImePosition.offset,
      extentOffset: endImePosition.offset,
      affinity: selectionAffinity,
    );
  }

  TextRange documentToImeRange(DocumentRange? documentRange) {
    editorImeLog.fine("Converting doc range to ime range: $documentRange");
    if (documentRange == null) {
      editorImeLog.fine("The document range is null. Returning an empty IME range.");
      return const TextRange(start: -1, end: -1);
    }

    final startImePosition = _documentToImePosition(documentRange.start);
    final endImePosition = _documentToImePosition(documentRange.end);

    editorImeLog.fine("After converting DocumentRange to TextRange:");
    editorImeLog.fine("Start IME position: $startImePosition");
    editorImeLog.fine("End IME position: $endImePosition");
    return TextRange(
      start: startImePosition.offset,
      end: endImePosition.offset,
    );
  }

  TextPosition _documentToImePosition(DocumentPosition docPosition) {
    editorImeLog.fine("Converting DocumentPosition to IME TextPosition: $docPosition");
    final imeRange = _docTextNodesToImeRanges[docPosition.nodeId];
    if (imeRange == null) {
      throw Exception("No such document position in the IME content: $docPosition");
    }

    final nodePosition = docPosition.nodePosition;

    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        editorImeLog.fine("The doc position is an upstream position on a block.");
        // Return the text position before the special character,
        // e.g., "|~".
        return TextPosition(offset: imeRange.start);
      } else {
        editorImeLog.fine("The doc position is a downstream position on a block.");
        // Return the text position after the special character,
        // e.g., "~|".
        return TextPosition(offset: imeRange.start + 1);
      }
    }

    if (nodePosition is TextNodePosition) {
      return TextPosition(offset: imeRange.start + (docPosition.nodePosition as TextNodePosition).offset);
    }

    throw Exception("Super Editor doesn't know how to convert a $nodePosition into an IME-compatible selection");
  }

  TextEditingValue toTextEditingValue() {
    editorImeLog.fine("Creating TextEditingValue from document. Selection: $_selection");
    editorImeLog.fine("Text:\n'$_imeText'");
    final imeSelection = documentToImeSelection(_selection);
    editorImeLog.fine("Selection: $imeSelection");
    final imeComposingRegion = documentToImeRange(_composingRegion);
    editorImeLog.fine("Composing region: $imeComposingRegion");

    return TextEditingValue(
      text: _imeText,
      selection: imeSelection,
      composing: imeComposingRegion,
    );
  }

  /// Narrows the given [selection] until the base and extent both point to
  /// `TextNode`s.
  ///
  /// If the given [selection] base and/or extent already point to a `TextNode`
  /// then those same end-caps are retained in the returned `DocumentSelection`.
  ///
  /// If there is no text content within the [selection], `null` is returned.
  DocumentSelection? _constrictToTextSelectionEndCaps(DocumentSelection selection) {
    final baseNode = _doc.getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = _doc.getNodeIndexById(baseNode.id);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndexById(extentNode.id);

    final startNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final startNodeIndex = _doc.getNodeIndexById(startNode.id);
    final startPosition =
        baseNodeIndex <= extentNodeIndex ? selection.base.nodePosition : selection.extent.nodePosition;
    final endNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final endNodeIndex = _doc.getNodeIndexById(endNode.id);
    final endPosition = baseNodeIndex <= extentNodeIndex ? selection.extent.nodePosition : selection.base.nodePosition;

    if (startNodeIndex == endNodeIndex) {
      // The document selection is all in one node.
      if (startNode is! TextNode) {
        // The only content selected is non-text. Return null.
        return null;
      }

      // Part of a single TextNode is selected, therefore, the given selection
      // is already restricted to text end caps.
      return selection;
    }

    DocumentNode? restrictedStartNode;
    TextNodePosition? restrictedStartPosition;
    if (startNode is TextNode) {
      restrictedStartNode = startNode;
      restrictedStartPosition = startPosition as TextNodePosition;
    } else {
      int restrictedStartNodeIndex = startNodeIndex + 1;
      while (_doc.getNodeAt(restrictedStartNodeIndex) is! TextNode && restrictedStartNodeIndex <= endNodeIndex) {
        restrictedStartNodeIndex += 1;
      }

      if (_doc.getNodeAt(restrictedStartNodeIndex) is TextNode) {
        restrictedStartNode = _doc.getNodeAt(restrictedStartNodeIndex);
        restrictedStartPosition = const TextNodePosition(offset: 0);
      }
    }

    DocumentNode? restrictedEndNode;
    TextNodePosition? restrictedEndPosition;
    if (endNode is TextNode) {
      restrictedEndNode = endNode;
      restrictedEndPosition = endPosition as TextNodePosition;
    } else {
      int restrictedEndNodeIndex = endNodeIndex - 1;
      while (_doc.getNodeAt(restrictedEndNodeIndex) is! TextNode && restrictedEndNodeIndex >= startNodeIndex) {
        restrictedEndNodeIndex -= 1;
      }

      if (_doc.getNodeAt(restrictedEndNodeIndex) is TextNode) {
        restrictedEndNode = _doc.getNodeAt(restrictedEndNodeIndex);
        restrictedEndPosition = TextNodePosition(offset: (restrictedEndNode as TextNode).text.text.length);
      }
    }

    // If there was no text between the selection end-caps, return null.
    if (restrictedStartPosition == null || restrictedEndPosition == null) {
      return null;
    }

    return DocumentSelection(
      base: DocumentPosition(
        nodeId: restrictedStartNode!.id,
        nodePosition: restrictedStartPosition,
      ),
      extent: DocumentPosition(
        nodeId: restrictedEndNode!.id,
        nodePosition: restrictedEndPosition,
      ),
    );
  }

  /// Serializes just enough document text to serve the needs of the IME.
  ///
  /// The serialized text includes all the content of all partially selected
  /// nodes, plus one node on either side to allow for upstream and downstream
  /// deletions. For example, the user press backspace at the beginning of a
  /// paragraph. We need to tell the IME that there's content before the paragraph
  /// so that the IME sends us the delete delta.
  String _getMinimumTextForIME(DocumentSelection selection) {
    final baseNode = _doc.getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = _doc.getNodeIndexById(baseNode.id);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndexById(extentNode.id);

    final selectionStartNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final selectionStartNodeIndex = _doc.getNodeIndexById(selectionStartNode.id);
    final startNodeIndex = max(selectionStartNodeIndex - 1, 0);

    final selectionEndNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final selectionEndNodeIndex = _doc.getNodeIndexById(selectionEndNode.id);
    final endNodeIndex = min(selectionEndNodeIndex + 1, _doc.nodes.length - 1);

    final buffer = StringBuffer();
    for (int i = startNodeIndex; i <= endNodeIndex; i += 1) {
      final node = _doc.getNodeAt(i);
      if (node is! TextNode) {
        continue;
      }

      if (buffer.length > 0) {
        buffer.write('\n');
      }

      buffer.write(node.text.text);
    }

    return buffer.toString();
  }
}

enum PrependedCharacterPolicy {
  automatic,
  include,
  exclude,
}
