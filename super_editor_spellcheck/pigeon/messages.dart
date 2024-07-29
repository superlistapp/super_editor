import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut: 'macos/Classes/messages.g.swift',
))
@HostApi()
abstract class SpellCheckApi {
  /// Checks the given [text] for spelling errors with the given [language].
  ///
  /// Returns a list of [TextSuggestion]s, where each spans represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the [language]
  /// isn't supported by the spell checker.
  List<TextSuggestion> fetchSuggestions(String language, String text);
}

/// A range containing a misspelled word and its suggestions.
///
/// The [end] index is exclusive.
class TextSuggestion {
  TextSuggestion({
    required this.start,
    required this.end,
    required this.suggestions,
  });

  final int start;
  final int end;
  final List<String?> suggestions;
}
