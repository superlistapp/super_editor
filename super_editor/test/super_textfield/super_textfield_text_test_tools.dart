import 'package:attributed_text/attributed_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

/// [Matcher] that expects a target [AttributedText] to have content
/// and styles and match the given [markdown].
Matcher equalsMarkdown(String markdown) => TextEqualsMarkdownMatcher(markdown);

class TextEqualsMarkdownMatcher extends Matcher {
  const TextEqualsMarkdownMatcher(this._expectedMarkdown);

  final String _expectedMarkdown;

  @override
  Description describe(Description description) {
    return description.add("given text has equivalent content to the given markdown");
  }

  @override
  bool matches(covariant Object target, Map<dynamic, dynamic> matchState) {
    return _calculateMismatchReason(target, matchState) == null;
  }

  @override
  Description describeMismatch(
    covariant Object target,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final mismatchReason = _calculateMismatchReason(target, matchState);
    if (mismatchReason != null) {
      mismatchDescription.add(mismatchReason);
    }
    return mismatchDescription;
  }

  String? _calculateMismatchReason(
    Object target,
    Map<dynamic, dynamic> matchState,
  ) {
    late AttributedText actualText;
    if (target is! AttributedText) {
      return "the given target isn't an AttributedText: $target";
    }
    actualText = target;

    final actualMarkdown = actualText.toMarkdown();
    final stringMatcher = equals(_expectedMarkdown);
    final matcherState = {};
    final matches = stringMatcher.matches(actualMarkdown, matcherState);
    if (matches) {
      // The document matches the markdown. Our matcher matches.
      return null;
    }

    return stringMatcher.describeMismatch(actualMarkdown, StringDescription(), matchState, false).toString();
  }
}
