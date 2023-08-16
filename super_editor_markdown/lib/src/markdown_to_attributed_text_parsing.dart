import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/markdown_to_document_parsing.dart';

/// Parses [markdown] and returns it as [AttributedText].
///
/// The [markdown] is expected to represent a single paragraph of content. If
/// the [markdown] isn't text-based (e.g., an image), or if the [markdown] includes
/// more than one paragraph of content, an exception is thrown.
AttributedText attributedTextFromMarkdown(String markdown) {
  if (markdown.isEmpty) {
    return AttributedText();
  }

  final document = deserializeMarkdownToDocument(markdown);
  assert(document.nodes.length == 1,
      "Tried to parse Markdown to AttributedText. Expected one paragraph node but ended up with ${document.nodes.length} parsed nodes.");
  assert(document.nodes.first is ParagraphNode,
      "Tried to parse Markdown to AttributedText. Expected text but found content type: ${document.nodes.first.runtimeType}");
  return (document.nodes.first as ParagraphNode).text;
}
