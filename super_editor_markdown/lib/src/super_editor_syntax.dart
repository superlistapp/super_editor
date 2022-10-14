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
