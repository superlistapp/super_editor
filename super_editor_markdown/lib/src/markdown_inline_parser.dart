import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/image_syntax.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

/// Parses inline markdown content.
///
/// Supports strikethrough, underline, bold, italics, code and links.
///
/// The given [syntax] controls how the [text] is parsed, e.g., [MarkdownSyntax.normal]
/// for strict Markdown parsing, or [MarkdownSyntax.superEditor] to use Super Editor's
/// extended syntax.
///
/// If [encodeHtml] is `true`, it escapes HTML symbols like &, <, and >. For example,
/// `&` becomes `&amp;`, `<` becomes `&lt;`, and `>` becomes `&gt;`.
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
  final inlineVisitor = _InlineMarkdownToDocument();
  final inlineNodes = inlineParser.parse();
  for (final inlineNode in inlineNodes) {
    inlineNode.accept(inlineVisitor);
  }
  return inlineVisitor.attributedText;
}

/// Parses inline markdown content.
///
/// Apply [_InlineMarkdownToDocument] to a text [md.Element] to
/// obtain an [AttributedText] that represents the inline
/// styles within the given text.
///
/// [_InlineMarkdownToDocument] does not support parsing text
/// that contains image tags. If any non-image text is found,
/// the content is treated as styled text.
class _InlineMarkdownToDocument implements md.NodeVisitor {
  _InlineMarkdownToDocument();

  AttributedText get attributedText => _textStack.first;

  final List<AttributedText> _textStack = [AttributedText()];

  @override
  bool visitElementBefore(md.Element element) {
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
