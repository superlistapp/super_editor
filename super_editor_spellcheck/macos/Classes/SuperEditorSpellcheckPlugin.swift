import FlutterMacOS
import Foundation
import AppKit

/// Plugin to check spelling errors in text using the native macOS spell checker.
public class SuperEditorSpellcheckPlugin: SpellCheckApi {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SuperEditorSpellcheckPlugin()
    SpellCheckApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
  }

  /// Checks the given `text` for spelling errors with the given `language`.
  ///
  /// Returns a list of `TextSuggestion`s, where each entry represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the `language`
  /// isn't supported by the spell checker.
  func fetchSuggestions(language: String, text: String) throws -> [TextSuggestion] {
    var result : [TextSuggestion] = [];

    if (language.isEmpty || text.isEmpty) {
      // We can't look for misspelled words without a language or text.
      return result;
    }

    let spellChecker = NSSpellChecker.shared;

    // Convert dart locale to macOS language code. For example, converts "pt-BR" to "pt_BR".
    var languageCode = language.replacingOccurrences(of: "-", with: "_")
    if (!spellChecker.availableLanguages.contains(languageCode)){
      // The given language isn't supported by the spell checker. It might be the case that
      // the user has a language configured with an incompatible region. For example,
      // a user might have "en-BR" configured, which means that the language is English,
      // but the region is Brazil. In this case, we should try to use only the language.
      let firstPart = languageCode.components(separatedBy: "_").first;
      if (firstPart == nil) {
        // The language code isn't in the format language_REGION. Fizzle.
        return result;
      }

      languageCode = firstPart!;
      if (!spellChecker.availableLanguages.contains(languageCode)){
        // The given language isn't supported by the spell checker. Fizzle.
        return result;
      }
    }

    // The start of the substring we are looking at.
    var currentOffset = 0;
    var shouldContinue = true;
    while (shouldContinue && currentOffset < text.count) {
      let misspelledRange = spellChecker.checkSpelling(
        of: text,
        startingAt: currentOffset,
        language: languageCode,
        wrap: false,
        inSpellDocumentWithTag: 0,
        wordCount: nil
      );

      if (misspelledRange.location != NSNotFound) {
        // We found a misspeled word. Check for suggestions.
        let guesses = spellChecker.guesses(
          forWordRange: misspelledRange,
          in: text,
          language: languageCode,
          inSpellDocumentWithTag: 0
        );

        // Only append the suggestion span if we have suggestions.
        // It wouldn't help to return a misspelled word without suggestions.
        if (guesses?.isEmpty == false) {
          result.append(TextSuggestion(
            start: Int64(misspelledRange.location),
            // Transform the end to be exclusive, to match the Dart TextRange.
            end: Int64(misspelledRange.location + misspelledRange.length),
            suggestions: guesses!
          ));
        }

        // Place the offset after the current word to continue the search.
        currentOffset += misspelledRange.location + misspelledRange.length;
      }

      // If we found a misspelled word, we should continue the search until
      // no more misspelled words are found.
      shouldContinue = misspelledRange.location != NSNotFound;
    };

    return result;
  }
}