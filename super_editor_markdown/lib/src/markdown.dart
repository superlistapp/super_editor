import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';

// TODO: return a regular Document instead of a MutableDocument.
//       For now, we return MutableDocument because DocumentEditor
//       requires one. When the editing system matures, there should
//       be a way to return something here that is not concrete.

/// The given [syntax] controls how the [markdown] is parsed, e.g., [MarkdownSyntax.normal] for strict
/// Markdown parsing, or [MarkdownSyntax.superEditor] to use Super Editor's extended syntax.
MutableDocument deserializeMarkdownToDocument(
  String markdown, {
  MarkdownSyntax syntax = MarkdownSyntax.superEditor,
}) {
  final markdownLines = const LineSplitter().convert(markdown);

  final markdownDoc = md.Document(
    blockSyntaxes: [
      if (syntax == MarkdownSyntax.superEditor) _ParagraphWithAlignmentSyntax(),
    ],
  );
  final blockParser = md.BlockParser(markdownLines, markdownDoc);

  // Parse markdown string to structured markdown.
  final markdownNodes = blockParser.parseLines();

  // Convert structured markdown to a Document.
  final nodeVisitor = _MarkdownToDocument();
  for (final node in markdownNodes) {
    node.accept(nodeVisitor);
  }

  return MutableDocument(nodes: nodeVisitor.content);
}

/// The given [syntax] controls how the [doc] is serialized, e.g., [MarkdownSyntax.normal] for standard
/// Markdown syntax, or [MarkdownSyntax.superEditor] to use Super Editor's extended syntax.
String serializeDocumentToMarkdown(
  Document doc, {
  MarkdownSyntax syntax = MarkdownSyntax.superEditor,
}) {
  StringBuffer buffer = StringBuffer();

  bool isFirstLine = true;
  for (int i = 0; i < doc.nodes.length; ++i) {
    final node = doc.nodes[i];

    if (!isFirstLine) {
      // Create a new line to encode the given node.
      buffer.writeln("");
    } else {
      isFirstLine = false;
    }

    if (node is ImageNode) {
      buffer.write('![${node.altText}](${node.imageUrl})');
    } else if (node is HorizontalRuleNode) {
      buffer.write('---');
    } else if (node is ListItemNode) {
      final indent = List.generate(node.indent + 1, (index) => '  ').join('');
      final symbol = node.type == ListItemType.unordered ? '*' : '1.';

      buffer.write('$indent$symbol ${node.text.toMarkdown()}');

      final nodeBelow = i < doc.nodes.length - 1 ? doc.nodes[i + 1] : null;
      if (nodeBelow != null && (nodeBelow is! ListItemNode || nodeBelow.type != node.type)) {
        // This list item is the last item in the list. Add an extra
        // blank line after it.
        buffer.writeln('');
      }
    } else if (node is ParagraphNode) {
      final Attribution? blockType = node.getMetadataValue('blockType');

      if (blockType == header1Attribution) {
        buffer.write('# ${node.text.toMarkdown()}');
      } else if (blockType == header2Attribution) {
        buffer.write('## ${node.text.toMarkdown()}');
      } else if (blockType == header3Attribution) {
        buffer.write('### ${node.text.toMarkdown()}');
      } else if (blockType == header4Attribution) {
        buffer.write('#### ${node.text.toMarkdown()}');
      } else if (blockType == header5Attribution) {
        buffer.write('##### ${node.text.toMarkdown()}');
      } else if (blockType == header6Attribution) {
        buffer.write('###### ${node.text.toMarkdown()}');
      } else if (blockType == blockquoteAttribution) {
        // TODO: handle multiline
        buffer.write('> ${node.text.toMarkdown()}');
      } else if (blockType == codeAttribution) {
        buffer //
          ..writeln('```') //
          ..writeln(node.text.toMarkdown()) //
          ..write('```');
      } else {
        final String? textAlign = node.getMetadataValue('textAlign');
        // Left alignment is the default, so there is no need to add the alignment token.
        if (syntax == MarkdownSyntax.superEditor && textAlign != null && textAlign != 'left') {
          final alignmentToken = _convertAlignmentToMarkdown(textAlign);
          if (alignmentToken != null) {
            buffer.writeln(alignmentToken);
          }
        }
        buffer.write(node.text.toMarkdown());
      }
    }
  }

  return buffer.toString();
}

String? _convertAlignmentToMarkdown(String alignment) {
  switch (alignment) {
    case 'left':
      return ':---';
    case 'center':
      return ':---:';
    case 'right':
      return '---:';
    default:
      return null;
  }
}

/// Converts structured markdown to a list of [DocumentNode]s.
///
/// To use [_MarkdownToDocument], obtain a series of markdown
/// nodes from a [BlockParser] (from the markdown package) and
/// then visit each of the nodes with a [_MarkdownToDocument].
/// After visiting all markdown nodes, [_MarkdownToDocument]
/// contains [DocumentNode]s that correspond to the visited
/// markdown content.
class _MarkdownToDocument implements md.NodeVisitor {
  _MarkdownToDocument();

  final _content = <DocumentNode>[];
  List<DocumentNode> get content => _content;

  final _listItemTypeStack = <ListItemType>[];

  @override
  bool visitElementBefore(md.Element element) {
    // TODO: re-organize parsing such that visitElementBefore collects
    //       the block type info and then visitText and visitElementAfter
    //       take the action to create the node (#153)
    switch (element.tag) {
      case 'h1':
        _addHeader(element, level: 1);
        break;
      case 'h2':
        _addHeader(element, level: 2);
        break;
      case 'h3':
        _addHeader(element, level: 3);
        break;
      case 'h4':
        _addHeader(element, level: 4);
        break;
      case 'h5':
        _addHeader(element, level: 5);
        break;
      case 'h6':
        _addHeader(element, level: 6);
        break;
      case 'p':
        final inlineVisitor = _parseInline(element);

        if (inlineVisitor.isImage) {
          _addImage(
            // TODO: handle null image URL
            imageUrl: inlineVisitor.imageUrl!,
            altText: inlineVisitor.imageAltText!,
          );
        } else {
          _addParagraph(inlineVisitor.attributedText, element.attributes);
        }
        break;
      case 'blockquote':
        _addBlockquote(element);

        // Skip child elements within a blockquote so that we don't
        // add another node for the paragraph that comprises the blockquote
        return false;
      case 'code':
        _addCodeBlock(element);
        break;
      case 'ul':
        // A list just started. Push that list type on top of the list type stack.
        _listItemTypeStack.add(ListItemType.unordered);
        break;
      case 'ol':
        // A list just started. Push that list type on top of the list type stack.
        _listItemTypeStack.add(ListItemType.ordered);
        break;
      case 'li':
        if (_listItemTypeStack.isEmpty) {
          throw Exception('Tried to parse a markdown list item but the list item type was null');
        }

        _addListItem(
          element,
          listItemType: _listItemTypeStack.last,
          indent: _listItemTypeStack.length - 1,
        );
        break;
      case 'hr':
        _addHorizontalRule();
        break;
    }

    return true;
  }

  @override
  void visitElementAfter(md.Element element) {
    switch (element.tag) {
      // A list has ended. Pop the most recent list type from the stack.
      case 'ul':
      case 'ol':
        _listItemTypeStack.removeLast();
        break;
    }
  }

  @override
  void visitText(md.Text text) {
    // no-op: this visitor is block-level only
  }

  void _addHeader(md.Element element, {required int level}) {
    Attribution? headerAttribution;
    switch (level) {
      case 1:
        headerAttribution = header1Attribution;
        break;
      case 2:
        headerAttribution = header2Attribution;
        break;
      case 3:
        headerAttribution = header3Attribution;
        break;
      case 4:
        headerAttribution = header4Attribution;
        break;
      case 5:
        headerAttribution = header5Attribution;
        break;
      case 6:
        headerAttribution = header6Attribution;
        break;
    }

    _content.add(
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: _parseInlineText(element),
        metadata: {
          'blockType': headerAttribution,
        },
      ),
    );
  }

  void _addParagraph(AttributedText attributedText, Map<String, String> attributes) {
    final textAlign = attributes['textAlign'];

    _content.add(
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: attributedText,
        metadata: {
          'textAlign': textAlign != null ? textAlign : null,
        },
      ),
    );
  }

  void _addBlockquote(md.Element element) {
    _content.add(
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: _parseInlineText(element),
        metadata: {
          'blockType': blockquoteAttribution,
        },
      ),
    );
  }

  void _addCodeBlock(md.Element element) {
    // TODO: we may need to replace escape characters with literals here
    // CodeSampleNode(
    //   code: element.textContent //
    //       .replaceAll('&lt;', '<') //
    //       .replaceAll('&gt;', '>') //
    //       .trim(),
    // ),

    _content.add(
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: element.textContent,
        ),
        metadata: {
          'blockType': codeAttribution,
        },
      ),
    );
  }

  void _addImage({
    required String imageUrl,
    required String altText,
  }) {
    _content.add(
      ImageNode(
        id: DocumentEditor.createNodeId(),
        imageUrl: imageUrl,
        altText: altText,
      ),
    );
  }

  void _addHorizontalRule() {
    _content.add(HorizontalRuleNode(
      id: DocumentEditor.createNodeId(),
    ));
  }

  void _addListItem(
    md.Element element, {
    required ListItemType listItemType,
    required int indent,
  }) {
    _content.add(
      ListItemNode(
        id: DocumentEditor.createNodeId(),
        itemType: listItemType,
        indent: indent,
        text: _parseInlineText(element),
      ),
    );
  }

  AttributedText _parseInlineText(md.Element element) {
    final inlineVisitor = _parseInline(element);
    return inlineVisitor.attributedText;
  }

  _InlineMarkdownToDocument _parseInline(md.Element element) {
    final inlineParser = md.InlineParser(
      element.textContent,
      md.Document(
        inlineSyntaxes: [
          md.StrikethroughSyntax(),
          UnderlineSyntax(),
        ],
      ),
    );
    final inlineVisitor = _InlineMarkdownToDocument();
    final inlineNodes = inlineParser.parse();
    for (final inlineNode in inlineNodes) {
      inlineNode.accept(inlineVisitor);
    }
    return inlineVisitor;
  }
}

/// Parses inline markdown content.
///
/// Apply [_InlineMarkdownToDocument] to a text [Element] to
/// obtain an [AttributedText] that represents the inline
/// styles within the given text.
///
/// Apply [_InlineMarkdownToDocument] to an [Element] whose
/// content is an image tag to obtain image data.
///
/// [_InlineMarkdownToDocument] does not support parsing text
/// that contains image tags. If any non-image text is found,
/// the content is treated as styled text.
class _InlineMarkdownToDocument implements md.NodeVisitor {
  _InlineMarkdownToDocument();

  // For our purposes, we only support block-level images. Therefore,
  // if we find an image without any text, we're parsing an image.
  // Otherwise, if there is any text, then we're parsing a paragraph
  // and we ignore the image.
  bool get isImage => _imageUrl != null && attributedText.text.isEmpty;

  String? _imageUrl;
  String? get imageUrl => _imageUrl;

  String? _imageAltText;
  String? get imageAltText => _imageAltText;

  AttributedText get attributedText => _textStack.first;

  final List<AttributedText> _textStack = [AttributedText()];

  @override
  bool visitElementBefore(md.Element element) {
    if (element.tag == 'img') {
      // TODO: handle missing "src" attribute
      _imageUrl = element.attributes['src']!;
      _imageAltText = element.attributes['alt'] ?? '';
      return true;
    }

    _textStack.add(AttributedText());

    return true;
  }

  @override
  void visitText(md.Text text) {
    final attributedText = _textStack.removeLast();
    _textStack.add(attributedText.copyAndAppend(AttributedText(text: text.text)));
  }

  @override
  void visitElementAfter(md.Element element) {
    // Reset to normal text style because a plain text element does
    // not receive a call to visitElementBefore().
    final styledText = _textStack.removeLast();

    if (element.tag == 'strong') {
      styledText.addAttribution(
        boldAttribution,
        SpanRange(
          start: 0,
          end: styledText.text.length - 1,
        ),
      );
    } else if (element.tag == 'em') {
      styledText.addAttribution(
        italicsAttribution,
        SpanRange(
          start: 0,
          end: styledText.text.length - 1,
        ),
      );
    } else if (element.tag == "del") {
      styledText.addAttribution(
        strikethroughAttribution,
        SpanRange(
          start: 0,
          end: styledText.text.length - 1,
        ),
      );
    } else if (element.tag == "u") {
      styledText.addAttribution(
        underlineAttribution,
        SpanRange(
          start: 0,
          end: styledText.text.length - 1,
        ),
      );
    } else if (element.tag == 'a') {
      styledText.addAttribution(
        LinkAttribution(url: Uri.parse(element.attributes['href']!)),
        SpanRange(
          start: 0,
          end: styledText.text.length - 1,
        ),
      );
    }

    if (_textStack.isNotEmpty) {
      final surroundingText = _textStack.removeLast();
      _textStack.add(surroundingText.copyAndAppend(styledText));
    } else {
      _textStack.add(styledText);
    }
  }
}

extension Markdown on AttributedText {
  String toMarkdown() {
    final serializer = AttributedTextMarkdownSerializer();
    return serializer.serialize(this);
  }
}

/// Serializes an [AttributedText] into markdown format
class AttributedTextMarkdownSerializer extends AttributionVisitor {
  late String _fullText;
  late StringBuffer _buffer;
  late int _bufferCursor;

  String serialize(AttributedText attributedText) {
    _fullText = attributedText.text;
    _buffer = StringBuffer();
    _bufferCursor = 0;
    attributedText.visitAttributions(this);
    return _buffer.toString();
  }

  @override
  void visitAttributions(
    AttributedText fullText,
    int index,
    Set<Attribution> startingAttributions,
    Set<Attribution> endingAttributions,
  ) {
    // Write out the text between the end of the last markers, and these new markers.
    _buffer.write(
      fullText.text.substring(_bufferCursor, index),
    );

    // Add start markers.
    if (startingAttributions.isNotEmpty) {
      final markdownStyles = _sortAndSerializeAttributions(startingAttributions, AttributionVisitEvent.start);
      // Links are different from the plain styles since they are both not NamedAttributions (and therefore
      // can't be checked using equality comparison) and asymmetrical in markdown.
      final linkMarker = _encodeLinkMarker(startingAttributions, AttributionVisitEvent.start);

      _buffer
        ..write(linkMarker)
        ..write(markdownStyles);
    }

    // Write out the character at this index.
    _buffer.write(_fullText[index]);
    _bufferCursor = index + 1;

    // Add end markers.
    if (endingAttributions.isNotEmpty) {
      final markdownStyles = _sortAndSerializeAttributions(endingAttributions, AttributionVisitEvent.end);
      // Links are different from the plain styles since they are both not NamedAttributions (and therefore
      // can't be checked using equality comparison) and asymmetrical in markdown.
      final linkMarker = _encodeLinkMarker(endingAttributions, AttributionVisitEvent.end);

      // +1 on end index because this visitor has inclusive indices
      // whereas substring() expects an exclusive ending index.
      _buffer
        ..write(markdownStyles)
        ..write(linkMarker);
    }
  }

  @override
  void onVisitEnd() {
    // When the last span has no attributions, we still have text that wasn't added to the buffer yet.
    if (_bufferCursor <= _fullText.length - 1) {
      _buffer.write(_fullText.substring(_bufferCursor));
    }
  }

  /// Serializes style attributions into markdown syntax in a repeatable
  /// order such that opening and closing styles match each other on
  /// the opening and closing ends of a span.
  static String _sortAndSerializeAttributions(Set<Attribution> attributions, AttributionVisitEvent event) {
    const startOrder = [
      codeAttribution,
      boldAttribution,
      italicsAttribution,
      strikethroughAttribution,
      underlineAttribution,
    ];

    final buffer = StringBuffer();
    final encodingOrder = event == AttributionVisitEvent.start ? startOrder : startOrder.reversed;

    for (final markdownStyleAttribution in encodingOrder) {
      if (attributions.contains(markdownStyleAttribution)) {
        buffer.write(_encodeMarkdownStyle(markdownStyleAttribution));
      }
    }

    return buffer.toString();
  }

  static String _encodeMarkdownStyle(Attribution attribution) {
    if (attribution == codeAttribution) {
      return '`';
    } else if (attribution == boldAttribution) {
      return '**';
    } else if (attribution == italicsAttribution) {
      return '*';
    } else if (attribution == strikethroughAttribution) {
      return '~';
    } else if (attribution == underlineAttribution) {
      return '¬';
    } else {
      return '';
    }
  }

  /// Checks for the presence of a link in the attributions and returns the characters necessary to represent it
  /// at the open or closing boundary of the attribution, depending on the event.
  static String _encodeLinkMarker(Set<Attribution> attributions, AttributionVisitEvent event) {
    final linkAttributions = attributions.where((element) => element is LinkAttribution?);
    if (linkAttributions.isNotEmpty) {
      final linkAttribution = linkAttributions.first as LinkAttribution;

      if (event == AttributionVisitEvent.start) {
        return '[';
      } else {
        return '](${linkAttribution.url.toString()})';
      }
    }
    return "";
  }
}

/// Parses a paragraph preceded by an alignment token.
class _ParagraphWithAlignmentSyntax extends md.ParagraphSyntax {
  /// This pattern matches the text aligment notation.
  ///
  /// Possible values are `:---`, `:---:` and `---:`
  static final _alignmentNotationPattern = RegExp(r'^:-{3}|:-{3}:|-{3}:$');

  static const List<md.BlockSyntax> _standardNonParagraphBlockSyntaxes = [
    md.HeaderSyntax(),
    md.CodeBlockSyntax(),
    md.BlockquoteSyntax(),
    md.HorizontalRuleSyntax(),
    md.UnorderedListSyntax(),
    md.OrderedListSyntax(),
  ];

  const _ParagraphWithAlignmentSyntax();

  @override
  bool canParse(md.BlockParser parser) {
    if (!_alignmentNotationPattern.hasMatch(parser.current)) {
      return false;
    }

    final nextLine = parser.peek(1);

    // We found a match for a paragraph alignment token. However, the alignment token is the last
    // line of content in the document. Therefore, it's not really a paragraph alignment token, and we
    // should treat it as regular content.
    if (nextLine == null) {
      return false;
    }

    /// We found a paragraph alignment token, but the block after the alignment token isn't a paragraph.
    /// Therefore, the paragraph alignment token is actually regular content. This parser doesn't need to
    /// take any action.
    if (_standardNonParagraphBlockSyntaxes.any((syntax) => syntax.pattern.hasMatch(nextLine))) {
      return false;
    }

    // We found a paragraph alignment token, followed by a paragraph. Therefore, this parser should
    // parse the given content.
    return true;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final match = _alignmentNotationPattern.firstMatch(parser.current);

    // We've parsed the alignment token on the current line. We know a paragraph starts on the
    // next line. Move the parser to the next line so that we can parse the paragraph.
    parser.advance();

    // Parse the paragraph using the standard Markdown paragraph parser.
    final paragraph = super.parse(parser);

    if (paragraph is md.Element) {
      paragraph.attributes.addAll({'textAlign': _convertMarkdownAlignmentTokenToSuperEditorAlignment(match!.input)});
    }

    return paragraph;
  }

  /// Converts a markdown alignment token to the textAlign metadata used to configure
  /// the [ParagraphNode] alignment.
  String _convertMarkdownAlignmentTokenToSuperEditorAlignment(String alignmentToken) {
    switch (alignmentToken) {
      case ':---':
        return 'left';
      case ':---:':
        return 'center';
      case '---:':
        return 'right';
      // As we already check that the input matches the notation,
      // we shouldn't reach this point.
      default:
        return 'left';
    }
  }
}

/// A Markdown [TagSyntax] that matches underline spans of text, which are represented in
/// Markdown with surrounding `¬` tags, e.g., "this is ¬underline¬ text".
///
/// This [TagSyntax] produces `Element`s with a `u` tag.
class UnderlineSyntax extends md.TagSyntax {
  UnderlineSyntax() : super('¬', requiresDelimiterRun: true, allowIntraWord: true);

  @override
  md.Node close(md.InlineParser parser, md.Delimiter opener, md.Delimiter closer,
      {required List<md.Node> Function() getChildren}) {
    return md.Element('u', getChildren());
  }
}

enum MarkdownSyntax {
  /// Standard markdown syntax.
  normal,

  /// Extended syntax which supports serialization of text alignment, strikethrough and underline.
  ///
  /// Underline text is serialized between a pair of `¬`.
  ///
  /// Text alignment is serialized using an alignment notation at the
  /// line preceding the paragraph:
  ///
  /// `:---` represents left alignment. (The default)
  ///
  /// `:---:` represents center alignment.
  ///
  /// `---:` represents right alignment.
  superEditor,
}
