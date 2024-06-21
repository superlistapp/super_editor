import 'package:collection/collection.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/content/formatting.dart';
import 'package:super_editor_quill/src/content/multimedia.dart';

extension QuillDelta on MutableDocument {
  Delta toQuillDeltas() {
    final deltaDocument = Delta();

    for (final node in nodes) {
      if (node is ParagraphNode) {
        print("Serializing paragraph (${node.id}): ${node.text.text}");
        _serializeParagraph(node, deltaDocument);

        print(
          "After serializing paragraph, latest delta: '${(deltaDocument.operations[deltaDocument.operations.length - 1].value as String).toNewlineString()}'",
        );
        print("");
      } else if (node is ListItemNode) {
        print("Serializing list item (${node.id}): ${node.text.text}");
        // TODO:
        print("");
      } else if (node is TaskNode) {
        print("Serializing task (${node.id}): ${node.text.text}");
        // TODO:
        print("");
      } else if (node is ImageNode) {
        _serializeImage(node, deltaDocument);
      } else if (node is VideoNode) {
        _serializeVideo(node, deltaDocument);
      } else if (node is AudioNode) {
        _serializeAudio(node, deltaDocument);
      } else if (node is FileNode) {
        _serializeFile(node, deltaDocument);
      }
    }

    return deltaDocument;
  }

  void _serializeParagraph(ParagraphNode paragraph, Delta deltas) {
    print("Inserting text: '${paragraph.text.text.toNewlineString()}'");
    final blockFormat = _serializeBlockFormat(paragraph);

    var spans = paragraph.text.computeAttributionSpans().toList();
    if (spans.isEmpty) {
      // The text is empty. Inject a span so that our standard delta generation
      // behavior below still works.
      spans = [const MultiAttributionSpan(attributions: {}, start: 0, end: 0)];
    }

    for (int i = 0; i < spans.length; i += 1) {
      final span = spans[i];
      final text = paragraph.text.text.substring(span.start, paragraph.text.text.isNotEmpty ? span.end + 1 : span.end);
      print(" - span: '${text.toNewlineString()}'");

      // When we reach the end of the paragraph text, we want to insert a newline
      // as long as we don't need to apply any block format. Applying a block
      // format requires adding the newline in a different insert operation.
      final isNewlineNeeded = i == spans.length - 1 && blockFormat == null;

      final previousDelta = deltas.operations.lastOrNull;
      final newDelta = Operation.insert(
        text,
        // "$text${isNewlineNeeded ? "\n" : ""}",
        _serializeInlineAttributes(span.attributions),
      );
      if (previousDelta != null && newDelta.canMergeWith(previousDelta)) {
        print(
            " - Merging '${(previousDelta.value as String).toNewlineString()}' + '${(newDelta.value as String).toNewlineString()}'");
        deltas.operations[deltas.operations.length - 1] = newDelta.mergeWith(previousDelta);
        print(
            " - Merged with previous delta: '${(deltas.operations[deltas.operations.length - 1].value as String).toNewlineString()}'");
        continue;
      }

      print(" - Adding a new delta to the document list");
      deltas.operations.addAll([
        Operation.insert(
          text,
          // "$text${isNewlineNeeded ? "\n" : ""}",
          _serializeInlineAttributes(span.attributions),
        ),
      ]);
    }

    // if (blockFormat != null && blockFormat.isNotEmpty) {
    //   // Block formats are achieved by following the text with an insert
    //   // that contains a single newline and a block format that applies
    //   // to the previous insert.
    //   print(" - Adding a standalone newline delta because we need to apply a block format");
    final newlineDelta = Operation.insert("\n", blockFormat);
    final previousDelta = deltas.operations[deltas.operations.length - 1];
    if (newlineDelta.canMergeWith(previousDelta)) {
      print(
          "Merging a post-paragraph newline with previous delta: '${(previousDelta.value as String).toNewlineString()}'");
      deltas.operations[deltas.operations.length - 1] = newlineDelta.mergeWith(previousDelta);
    } else {
      print("Adding a standalone post-paragraph newline delta: ${(newlineDelta.value as String).toNewlineString()}");
      deltas.operations.add(newlineDelta);
    }
    // }
  }

  void _serializeListItem(ListItemNode listItem, Delta deltas) {
    //
  }

  void _serializeTask(TaskNode task, Delta deltas) {
    //
  }

  Map<String, dynamic>? _serializeBlockFormat(ParagraphNode paragraph) {
    final blockAttributes = <String, dynamic>{};

    // Add all the block-level formats that aren't mutually exclusive.
    if (paragraph.metadata["textAlign"] != null) {
      blockAttributes["align"] = paragraph.metadata["textAlign"];
    }
    if (paragraph.indent != 0) {
      blockAttributes["indent"] = paragraph.indent;
    }

    final blockType = paragraph.metadata["blockType"] as Attribution?;
    if (blockType == null) {
      return blockAttributes.isNotEmpty ? blockAttributes : null;
    }

    // Add the mutually exclusive block format.
    switch (blockType) {
      case header1Attribution:
        blockAttributes["header"] = 1;
      case header2Attribution:
        blockAttributes["header"] = 2;
      case header3Attribution:
        blockAttributes["header"] = 3;
      case header4Attribution:
        blockAttributes["header"] = 4;
      case header5Attribution:
        blockAttributes["header"] = 5;
      case header6Attribution:
        blockAttributes["header"] = 6;
      case blockquoteAttribution:
        blockAttributes["blockquote"] = true;
      case codeAttribution:
        blockAttributes["code-block"] = "plain";
    }

    return blockAttributes.isNotEmpty ? blockAttributes : null;
  }

  /// Given a set of [AttributedText] [attributions], serializes those into Quill Delta
  /// inline text attributes, returning all attributes in a map that should be set as
  /// the "attributes" in an insertion delta.
  Map<String, dynamic>? _serializeInlineAttributes(Set<Attribution> attributions) {
    final attributes = <String, dynamic>{};

    for (final attribution in attributions) {
      if (attribution == boldAttribution) {
        attributes["bold"] = true;
      }
      if (attribution == italicsAttribution) {
        attributes["italic"] = true;
      }
      if (attribution == strikethroughAttribution) {
        attributes["strike"] = true;
      }
      if (attribution == underlineAttribution) {
        attributes["underline"] = true;
      }
      if (attribution == superscriptAttribution) {
        attributes["script"] = "super";
      }
      if (attribution == subscriptAttribution) {
        attributes["script"] = "sub";
      }
      if (attribution is ColorAttribution) {
        attributes["color"] = "#${attribution.color.value.toRadixString(16).substring(2)}";
      }
      if (attribution is BackgroundColorAttribution) {
        attributes["background"] = "#${attribution.color.value.toRadixString(16).substring(2)}";
      }
      if (attribution is FontFamilyAttribution) {
        attributes["font"] = attribution.fontFamily;
      }
      if (attribution is NamedFontSizeAttribution) {
        attributes["size"] = attribution.fontSizeName;
      }
      if (attribution is FontSizeAttribution) {
        attributes["size"] = attribution.fontSize;
      }
      if (attribution is LinkAttribution) {
        attributes["link"] = attribution.url;
      }
    }

    return attributes.isEmpty ? null : attributes;
  }

  void _serializeImage(ImageNode image, Delta deltas) {
    deltas.operations.add(
      Operation.insert({
        "image": image.imageUrl,
      }),
    );
  }

  void _serializeVideo(VideoNode video, Delta deltas) {
    deltas.operations.add(
      Operation.insert({
        "video": video.url,
      }),
    );
  }

  void _serializeAudio(AudioNode audio, Delta deltas) {
    deltas.operations.add(
      Operation.insert({
        "audio": audio.url,
      }),
    );
  }

  void _serializeFile(FileNode file, Delta deltas) {
    deltas.operations.add(
      Operation.insert({
        "file": file.url,
      }),
    );
  }
}

extension DeltaSerialization on Operation {
  bool canMergeWith(Operation previousDelta) {
    if (!isInsert) {
      // We've only implement this for insertions, for now.
      // TODO: Add support for retain/delete.
      return false;
    }

    if (value is! String || previousDelta.value is! String) {
      // One or both of the deltas aren't text. Only text can be merged.
      return false;
    }

    // If the attributes are equivalent then we can merge the text deltas.
    if (const DeepCollectionEquality().equals(previousDelta.attributes, attributes)) {
      return true;
    }
    if (previousDelta.attributes == null && attributes!.isEmpty) {
      return true;
    }
    if (attributes == null && previousDelta.attributes!.isEmpty) {
      return true;
    }

    // There's a difference in the attributes. We need separate deltas.
    return false;
  }

  Operation mergeWith(Operation previousDelta) {
    if (!canMergeWith(previousDelta)) {
      throw Exception(
          "Tried to merge two deltas that can't be merged. Previous delta: $previousDelta. Next delta: $this");
    }

    return Operation.insert(
      "${previousDelta.value as String}${value as String}",
      previousDelta.attributes,
    );
  }
}

extension Newlines on String {
  String toNewlineString() => toString().replaceAll("\n", "⏎");
}
