import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/image_syntax.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

/// Parses inline markdown content.
///
/// Supports strikethrough, underline, bold, italics, code, links and images.
///
/// The given [syntax] controls how the [text] is parsed, e.g., [MarkdownSyntax.normal]
/// for strict Markdown parsing, or [MarkdownSyntax.superEditor] to use Super Editor's
/// extended syntax.
AttributedText parseInlineMarkdown(
  String text, {
  MarkdownSyntax syntax = MarkdownSyntax.superEditor,
  bool encodeHtml = false,
}) {
  final inlineParser = md.InlineParser(
    text,
    md.Document(
      inlineSyntaxes: [
        SingleStrikethroughSyntax(), // this needs to be before md.StrikethroughSyntax to be recognized
        md.StrikethroughSyntax(),
        UnderlineSyntax(),
        if (syntax == MarkdownSyntax.superEditor) //
          SuperEditorImageSyntax(),
      ],
      encodeHtml: encodeHtml,
    ),
  );
  final inlineVisitor = InlineMarkdownToDocument();
  final inlineNodes = inlineParser.parse();
  for (final inlineNode in inlineNodes) {
    inlineNode.accept(inlineVisitor);
  }
  return inlineVisitor.attributedText;
}

/// Parses inline markdown content.
///
/// Apply [InlineMarkdownToDocument] to a text [md.Element] to
/// obtain an [AttributedText] that represents the inline
/// styles within the given text.
///
/// Apply [InlineMarkdownToDocument] to an [md.Element] whose
/// content is an image tag to obtain image data.
///
/// [InlineMarkdownToDocument] does not support parsing text
/// that contains image tags. If any non-image text is found,
/// the content is treated as styled text.
class InlineMarkdownToDocument implements md.NodeVisitor {
  InlineMarkdownToDocument();

  // For our purposes, we only support block-level images. Therefore,
  // if we find an image without any text, we're parsing an image.
  // Otherwise, if there is any text, then we're parsing a paragraph
  // and we ignore the image.
  bool get isImage => _imageUrl != null && attributedText.isEmpty;

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
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == 'em') {
      styledText.addAttribution(
        italicsAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == "del") {
      styledText.addAttribution(
        strikethroughAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == "code") {
      styledText.addAttribution(
        codeAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == "u") {
      styledText.addAttribution(
        underlineAttribution,
        SpanRange(0, styledText.length - 1),
      );
    } else if (element.tag == 'a') {
      styledText.addAttribution(
        LinkAttribution.fromUri(Uri.parse(element.attributes['href']!)),
        SpanRange(0, styledText.length - 1),
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
