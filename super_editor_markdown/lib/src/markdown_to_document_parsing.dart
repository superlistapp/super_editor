import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/image_syntax.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import 'super_editor_syntax.dart';

/// Parses the given [markdown] and deserializes it into a [MutableDocument].
///
/// The given [syntax] controls how the [markdown] is parsed, e.g., [MarkdownSyntax.normal]
/// for strict Markdown parsing, or [MarkdownSyntax.superEditor] to use Super Editor's
/// extended syntax.
///
/// To add support for parsing non-standard Markdown blocks, provide [customBlockSyntax]s
/// that parse Markdown text into [md.Element]s, and provide [customElementToNodeConverters] that
/// turn those [md.Element]s into [DocumentNode]s.
MutableDocument deserializeMarkdownToDocument(
  String markdown, {
  MarkdownSyntax syntax = MarkdownSyntax.superEditor,
  List<md.BlockSyntax> customBlockSyntax = const [],
  List<ElementToNodeConverter> customElementToNodeConverters = const [],
  bool encodeHtml = false,
}) {
  final markdownLines = const LineSplitter().convert(markdown);

  final markdownDoc = md.Document(
    blockSyntaxes: [
      ...customBlockSyntax,
      if (syntax == MarkdownSyntax.superEditor) ...[
        _HeaderWithAlignmentSyntax(),
        const _ParagraphWithAlignmentSyntax(),
      ],
      const _EmptyLinePreservingParagraphSyntax(),
      const _TaskSyntax(),
    ],
  );
  final blockParser = md.BlockParser(markdownLines, markdownDoc);

  // Parse markdown string to structured markdown.
  final markdownNodes = blockParser.parseLines();

  // Convert structured markdown to a Document.
  final nodeVisitor = _MarkdownToDocument(customElementToNodeConverters, encodeHtml, syntax);
  for (final node in markdownNodes) {
    node.accept(nodeVisitor);
  }

  final documentNodes = nodeVisitor.content;

  if (documentNodes.isEmpty) {
    // An empty markdown was parsed.
    // For the user to be able to interact with the editor, at least one
    // node is required, so we add an empty paragraph.
    documentNodes.add(
      ParagraphNode(id: Editor.createNodeId(), text: AttributedText()),
    );
  }

  return MutableDocument(nodes: documentNodes);
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
  _MarkdownToDocument([
    this._elementToNodeConverters = const [],
    this._encodeHtml = false,
    this.syntax = MarkdownSyntax.normal,
  ]);

  final MarkdownSyntax syntax;

  final List<ElementToNodeConverter> _elementToNodeConverters;

  final _content = <DocumentNode>[];
  List<DocumentNode> get content => _content;

  final _listItemTypeStack = <ListItemType>[];

  /// The count of the list items currently being visited.
  ///
  /// Being visited means that [visitElementBefore] was called for an element and
  /// [visitElementAfter] wasn't called yet.
  ///
  /// A list item might contain children with tags like `p` and `h2`. When it does,
  /// the list item text content is inside of its children and we only generate
  /// document nodes when we visit the list item's children.
  ///
  /// We track the item count because when there are sublists, [visitElementBefore] is
  /// called for the sublist item before [visitElementAfter] is called for the
  /// main list item.
  int _listItemVisitedCount = 0;

  /// If `true`, special HTML symbols are encoded with HTML escape codes, otherwise those
  /// symbols are left as-is.
  ///
  /// Example: "&" -> "&amp;", "<" -> "&lt;", ">" -> "&gt;"
  final bool _encodeHtml;

  @override
  bool visitElementBefore(md.Element element) {
    for (final converter in _elementToNodeConverters) {
      final node = converter.handleElement(element);
      if (node != null) {
        _content.add(node);
        return true;
      }
    }

    if (_listItemVisitedCount > 0 &&
        !const ['li', 'ul', 'ol'].contains(element.tag) &&
        (element.children == null || element.children!.isEmpty || element.children!.length == 1)) {
      // We are visiting the text content of a list item. Add a list item node to the document.
      _addListItem(
        element,
        listItemType: _listItemTypeStack.last,
        indent: _listItemTypeStack.length - 1,
      );
      return false;
    }

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
        final inlineVisitor = _parseInline(element.textContent);

        if (inlineVisitor.isImage) {
          _addImage(
            // TODO: handle null image URL
            imageUrl: inlineVisitor.imageUrl!,
            altText: inlineVisitor.imageAltText!,
            expectedBitmapSize: inlineVisitor.width != null || inlineVisitor.height != null
                ? ExpectedSize(
                    inlineVisitor.width != null ? int.tryParse(inlineVisitor.width!) : null,
                    inlineVisitor.height != null ? int.tryParse(inlineVisitor.height!) : null,
                  )
                : null,
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

        // Mark that we are visiting a list item.
        _listItemVisitedCount += 1;

        if (element.children != null &&
            element.children!.isNotEmpty &&
            element.children!.first is! md.UnparsedContent) {
          // The list item content is inside of its child's element. Wait until we visit
          // the list item's children to generate a list node.
          return true;
        }

        // We already have the content of the list item, generate a list node.
        _addListItem(
          element,
          listItemType: _listItemTypeStack.last,
          indent: _listItemTypeStack.length - 1,
        );
        break;

      case 'hr':
        _addHorizontalRule();
        break;
      case 'task':
        _addTask(element);
        break;
    }

    return true;
  }

  @override
  void visitElementAfter(md.Element element) {
    switch (element.tag) {
      case 'li':
        _listItemVisitedCount -= 1;
        break;
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

    final textAlign = element.attributes['textAlign'];
    _content.add(
      ParagraphNode(
        id: Editor.createNodeId(),
        text: _parseInlineText(element.textContent),
        metadata: {
          'blockType': headerAttribution,
          'textAlign': textAlign,
        },
      ),
    );
  }

  void _addParagraph(AttributedText attributedText, Map<String, String> attributes) {
    final textAlign = attributes['textAlign'];

    _content.add(
      ParagraphNode(
        id: Editor.createNodeId(),
        text: attributedText,
        metadata: {
          'textAlign': textAlign,
        },
      ),
    );
  }

  void _addBlockquote(md.Element element) {
    _content.add(
      ParagraphNode(
        id: Editor.createNodeId(),
        text: _parseInlineText(element.textContent),
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
        id: Editor.createNodeId(),
        text: AttributedText(
          element.textContent,
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
    ExpectedSize? expectedBitmapSize,
  }) {
    _content.add(
      ImageNode(
        id: Editor.createNodeId(),
        imageUrl: imageUrl,
        altText: altText,
        expectedBitmapSize: expectedBitmapSize,
      ),
    );
  }

  void _addHorizontalRule() {
    _content.add(HorizontalRuleNode(
      id: Editor.createNodeId(),
    ));
  }

  void _addListItem(
    md.Element element, {
    required ListItemType listItemType,
    required int indent,
  }) {
    late String content;

    if (element.children != null && element.children!.isNotEmpty && element.children!.first is md.UnparsedContent) {
      // The list item might contain another sub-list. In that case, the textContent
      // contains the text for the whole list instead of just the current list item.
      // Use the textContent for the first child, which contains only the text
      // of the current list item.
      content = element.children!.first.textContent;
    } else {
      content = element.textContent;
    }

    _content.add(
      ListItemNode(
        id: Editor.createNodeId(),
        itemType: listItemType,
        indent: indent,
        text: _parseInlineText(content),
      ),
    );
  }

  void _addTask(md.Element element) {
    _content.add(
      TaskNode(
        id: Editor.createNodeId(),
        text: _parseInlineText(element.textContent),
        isComplete: element.attributes['completed'] == 'true',
      ),
    );
  }

  AttributedText _parseInlineText(String text) {
    final inlineVisitor = _parseInline(text);
    return inlineVisitor.attributedText;
  }

  _InlineMarkdownToDocument _parseInline(String text) {
    final inlineParser = md.InlineParser(
      text,
      md.Document(
        inlineSyntaxes: [
          md.StrikethroughSyntax(),
          UnderlineSyntax(),
          if (syntax == MarkdownSyntax.superEditor) //
            SuperEditorImageSyntax(),
        ],
        encodeHtml: _encodeHtml,
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

  String? get width => _width;
  String? _width;

  String? get height => _height;
  String? _height;

  AttributedText get attributedText => _textStack.first;

  final List<AttributedText> _textStack = [AttributedText()];

  @override
  bool visitElementBefore(md.Element element) {
    if (element.tag == 'img') {
      // TODO: handle missing "src" attribute
      _imageUrl = element.attributes['src']!;
      _imageAltText = element.attributes['alt'] ?? '';
      _width = element.attributes['width'];
      _height = element.attributes['height'];
      return true;
    }

    _textStack.add(AttributedText());

    return true;
  }

  @override
  void visitText(md.Text text) {
    final attributedText = _textStack.removeLast();
    _textStack.add(attributedText.copyAndAppend(AttributedText(text.text)));
  }

  @override
  void visitElementAfter(md.Element element) {
    // Reset to normal text style because a plain text element does
    // not receive a call to visitElementBefore().
    final styledText = _textStack.removeLast();

    if (element.tag == 'strong') {
      styledText.addAttribution(
        boldAttribution,
        SpanRange(0, styledText.text.length - 1),
      );
    } else if (element.tag == 'em') {
      styledText.addAttribution(
        italicsAttribution,
        SpanRange(0, styledText.text.length - 1),
      );
    } else if (element.tag == "del") {
      styledText.addAttribution(
        strikethroughAttribution,
        SpanRange(0, styledText.text.length - 1),
      );
    } else if (element.tag == "u") {
      styledText.addAttribution(
        underlineAttribution,
        SpanRange(0, styledText.text.length - 1),
      );
    } else if (element.tag == 'a') {
      styledText.addAttribution(
        LinkAttribution(url: Uri.parse(element.attributes['href']!)),
        SpanRange(0, styledText.text.length - 1),
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

/// Converts a deserialized Markdown element into a [DocumentNode].
///
/// For example, the Markdown parser might identify an element called
/// "blockquote". A corresponding [ElementToNodeConverter] would receive
/// the "blockquote" element and create an appropriate [ParagraphNode] to
/// represent that blockquote in the deserialized [Document].
abstract class ElementToNodeConverter {
  DocumentNode? handleElement(md.Element element);
}

/// A Markdown [TagSyntax] that matches underline spans of text, which are represented in
/// Markdown with surrounding `¬` tags, e.g., "this is ¬underline¬ text".
///
/// This [TagSyntax] produces `Element`s with a `u` tag.
class UnderlineSyntax extends md.TagSyntax {
  UnderlineSyntax() : super('¬', requiresDelimiterRun: true, allowIntraWord: true);

  @override
  md.Node? close(
    md.InlineParser parser,
    md.Delimiter opener,
    md.Delimiter closer, {
    required List<md.Node> Function() getChildren,
  }) {
    return md.Element('u', getChildren());
  }
}

/// Parses a paragraph preceded by an alignment token.
class _ParagraphWithAlignmentSyntax extends _EmptyLinePreservingParagraphSyntax {
  /// This pattern matches the text aligment notation.
  ///
  /// Possible values are `:---`, `:---:`, `---:` and `-::-`.
  static final _alignmentNotationPattern = RegExp(r'^:-{3}|:-{3}:|-{3}:|-::-$');

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
  md.Node? parse(md.BlockParser parser) {
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
      case '-::-':
        return 'justify';
      // As we already check that the input matches the notation,
      // we shouldn't reach this point.
      default:
        return 'left';
    }
  }
}

/// A [BlockSyntax] that parses paragraphs.
///
/// Allows empty paragraphs and paragraphs containing blank lines.
class _EmptyLinePreservingParagraphSyntax extends md.BlockSyntax {
  const _EmptyLinePreservingParagraphSyntax();

  @override
  RegExp get pattern => RegExp('');

  @override
  bool canEndBlock(md.BlockParser parser) => false;

  @override
  bool canParse(md.BlockParser parser) {
    if (_standardNonParagraphBlockSyntaxes.any((e) => e.canParse(parser))) {
      // A standard non-paragraph parser wants to parse this input. Let the other parser run.
      return false;
    }

    if (parser.current.isEmpty) {
      // We consider this input to be a separator between blocks because
      // it started with an empty line. We want to parse this input.
      return true;
    }

    if (_isAtParagraphEnd(parser, ignoreEmptyBlocks: _endsWithHardLineBreak(parser.current))) {
      // Another parser wants to parse this input. Let the other parser run.
      return false;
    }

    // The input is a paragraph. We want to parse it.
    return true;
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final childLines = <String>[];
    final startsWithEmptyLine = parser.current.isEmpty;

    // A hard line break causes the next line to be treated
    // as part of the same paragraph, except if the next line is
    // the beginning of another block element.
    bool hasHardLineBreak = _endsWithHardLineBreak(parser.current);

    if (startsWithEmptyLine) {
      // The parser started at an empty line.
      // Consume the line as a separator between blocks.
      parser.advance();

      if (parser.isDone) {
        // The document ended with a single empty line, so we just ignore it.
        // To be considered as a paragraph starting with an empty line
        // we need at least two empty lines:
        // one to separate the paragraph from the previous block
        // and another one to be the content of the paragraph.
        return null;
      }

      if (!_blankLinePattern.hasMatch(parser.current)) {
        // We found an empty line, but the following line isn't blank.
        // As there is no hard line break, the first line is consumed
        // as a separator between blocks.
        // Therefore, we aren't looking at a paragraph with blank lines.
        return null;
      }

      // We found a paragraph, and the first line of that paragraph is empty. Add a
      // corresponding empty line to the parsed version of the paragraph.
      childLines.add('');

      // Check for a hard line break, so we consume the next line if we found one.
      hasHardLineBreak = _endsWithHardLineBreak(parser.current);
      parser.advance();
    }

    // Consume everything until another block element is found.
    // A line break will cause the parser to stop, unless the preceding line
    // ends with a hard line break.
    while (!_isAtParagraphEnd(parser, ignoreEmptyBlocks: hasHardLineBreak)) {
      final currentLine = parser.current;
      childLines.add(currentLine);

      hasHardLineBreak = _endsWithHardLineBreak(currentLine);

      parser.advance();
    }

    // We already started looking at a different block element.
    // Let another syntax parse it.
    if (childLines.isEmpty) {
      return null;
    }

    // Remove trailing whitespace from each line of the parsed paragraph
    // and join them into a single string, separated by a line breaks.
    final contents = md.UnparsedContent(childLines.map((e) => _removeTrailingSpaces(e)).join('\n'));
    return _LineBreakSeparatedElement('p', [contents]);
  }

  /// Checks if the current line ends a paragraph by verifying if another
  /// block syntax can parse the current input.
  ///
  /// An empty line ends the paragraph, unless [ignoreEmptyBlocks] is `true`.
  bool _isAtParagraphEnd(md.BlockParser parser, {required bool ignoreEmptyBlocks}) {
    if (parser.isDone) {
      return true;
    }
    for (final syntax in parser.blockSyntaxes) {
      if (syntax != this &&
          !(syntax is md.EmptyBlockSyntax && ignoreEmptyBlocks) &&
          syntax.canParse(parser) &&
          syntax.canEndBlock(parser)) {
        return true;
      }
    }
    return false;
  }

  /// Removes all whitespace characters except `"\n"`.
  String _removeTrailingSpaces(String text) {
    final pattern = RegExp(r'[\t ]+$');
    return text.replaceAll(pattern, '');
  }

  /// Returns `true` if [line] ends with a hard line break.
  ///
  /// As per the Markdown spec, a line ending with two or more spaces
  /// represents a hard line break.
  ///
  /// A hard line break causes the next line to be part of the
  /// same paragraph, except if it's the beginning of another block element.
  bool _endsWithHardLineBreak(String line) {
    return line.endsWith('  ');
  }
}

/// An [Element] that preserves line breaks.
///
/// The default [Element] implementation ignores all line breaks.
class _LineBreakSeparatedElement extends md.Element {
  _LineBreakSeparatedElement(String tag, List<md.Node>? children) : super(tag, children);

  @override
  String get textContent {
    return (children ?? []).map((md.Node? child) => child!.textContent).join('\n');
  }
}

/// A [md.BlockSyntax] that parses tasks.
///
/// A compled task starts with `- [x] ` followed by the task's content.
///
/// An incomplete task starts with `- [ ] ` followed by the task's content.
///
/// Tasks can have multiple lines of content.
class _TaskSyntax extends md.BlockSyntax {
  const _TaskSyntax();

  /// Parses the first line of a task.
  ///
  /// `- [x] ` or `- [ ]` followed by any text.
  @override
  RegExp get pattern => RegExp(r'^- \[( |x)\] (.*)');

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current);
    if (match == null) {
      return null;
    }

    final completionToken = match.group(1)!;
    final taskDescriptionFirstLine = match.group(2)!;

    final buffer = StringBuffer(taskDescriptionFirstLine);

    // Move to the second line.
    parser.advance();

    // Consume the following lines until we:
    // - reach the end of the input OR
    // - find a blank line OR
    // - find the start of another block element (including another task)
    while (!parser.isDone &&
        !_blankLinePattern.hasMatch(parser.current) &&
        !_standardNonParagraphBlockSyntaxes.any((syntax) => syntax.pattern.hasMatch(parser.current))) {
      buffer.write('\n');
      buffer.write(parser.current);

      parser.advance();
    }

    return md.Element(
      'task',
      [md.Text(buffer.toString())],
    )..attributes['completed'] = (completionToken == 'x').toString();
  }
}

/// Parses a header preceded by an alignment token.
///
/// Headers are represented by `_ParagraphWithAlignmentSyntax`s and therefore
/// this parser must run before a [_ParagraphWithAlignmentSyntax], so that this parser
/// can process header-specific details, such as header alignment.
class _HeaderWithAlignmentSyntax extends md.BlockSyntax {
  /// This pattern matches the text alignment notation.
  ///
  /// Possible values are `:---`, `:---:`, `---:` and `-::-`.
  static final _alignmentNotationPattern = RegExp(r'^:-{3}|:-{3}:|-{3}:|-::-$');

  /// Use internal HeaderSyntax.
  final _headerSyntax = const md.HeaderSyntax();

  @override
  RegExp get pattern => RegExp('');

  @override
  bool canEndBlock(md.BlockParser parser) => false;

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

    // Only parse if the next line is header.
    if (!_headerSyntax.pattern.hasMatch(nextLine)) {
      return false;
    }

    return true;
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = _alignmentNotationPattern.firstMatch(parser.current);

    // We've parsed the alignment token on the current line. We know a header starts on the
    // next line. Move the parser to the next line so that we can parse the header.
    parser.advance();

    final headerNode = _headerSyntax.parse(parser);

    if (headerNode is md.Element) {
      headerNode.attributes.addAll({'textAlign': _convertMarkdownAlignmentTokenToSuperEditorAlignment(match!.input)});
    }

    return headerNode;
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
      case '-::-':
        return 'justify';
      // As we already check that the input matches the notation,
      // we shouldn't reach this point.
      default:
        return 'left';
    }
  }
}

/// Matches empty lines or lines containing only whitespace.
final _blankLinePattern = RegExp(r'^(?:[ \t]*)$');

const List<md.BlockSyntax> _standardNonParagraphBlockSyntaxes = [
  md.HeaderSyntax(),
  md.CodeBlockSyntax(),
  md.FencedCodeBlockSyntax(),
  md.BlockquoteSyntax(),
  md.HorizontalRuleSyntax(),
  _TaskSyntax(),
  md.UnorderedListSyntax(),
  md.OrderedListSyntax(),
];
