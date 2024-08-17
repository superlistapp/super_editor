import 'dart:ui';

import 'package:super_editor_spellcheck/src/platform/spell_checker_mac.dart';

class SuperEditorSpellCheckerPlugin {
  /// Exposes the macOS spell checker methods.
  final SuperEditorSpellCheckerMacPlugin macSpellChecker = SuperEditorSpellCheckerMacPlugin();

  /// Checks the given [text] for spelling errors with the given [locale].
  ///
  /// Returns a list of [TextSuggestion]s, where each span represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the [locale]
  /// isn't supported by the spell checker.
  ///
  /// If the same misspelled word is found multiple times in the text, it will be
  /// included in the list multiple times, since each range is different.
  Future<List<TextSuggestion>> fetchSuggestions(
    Locale locale,
    String text, {
    int inSpellDocumentWithTag = 0,
  }) async {
    final language = macSpellChecker.convertDartLocaleToMacLanguageCode(locale);
    if (language?.isNotEmpty != true) {
      throw Exception("The argument 'language' must not be empty");
    }

    final result = <TextSuggestion>[];
    if (text.isEmpty) {
      // We can't look for misspelled words without a text.
      return result;
    }

    final availableLanguages = await macSpellChecker.availableLanguages();

    String languageCode = language!.replaceFirst("-", "_");
    if (!availableLanguages.contains(languageCode)) {
      // The given language isn't supported by the spell checker. It might be the case that
      // the user has a language configured with an incompatible region. For example,
      // a user might have "en-BR" configured, which means that the language is English,
      // but the region is Brazil. In this case, we should try to use only the language.
      languageCode = language.split("_").first;
      if (!availableLanguages.contains(languageCode)) {
        // The given language isn't supported by the spell checker. Fizzle.
        return result;
      }
    }

    // The start of the substring we are looking at.
    int currentOffset = 0;
    while (currentOffset < text.length) {
      final misspelledRange = await macSpellChecker.checkSpelling(
        stringToCheck: text,
        startingOffset: currentOffset,
        language: languageCode,
        wrap: false,
        inSpellDocumentWithTag: 0,
      );

      if (misspelledRange.start == -1) {
        // There are no more misspelled words in the text.
        break;
      }

      // We found a misspeled word. Check for suggestions.
      final guesses = await macSpellChecker.guesses(
        text: text,
        range: misspelledRange,
        language: languageCode,
        inSpellDocumentWithTag: inSpellDocumentWithTag,
      );

      // Only append the suggestion span if we have suggestions.
      // It wouldn't help to return a misspelled word without suggestions.
      if (guesses.isEmpty == false) {
        result.add(
          TextSuggestion(
            range: TextRange(start: misspelledRange.start, end: misspelledRange.end),
            suggestions: guesses,
          ),
        );
      }

      // Place the offset after the current word to continue the search.
      currentOffset += misspelledRange.end;
    }

    return result;
  }
}
