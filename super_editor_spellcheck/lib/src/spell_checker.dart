import 'dart:ui';

import 'package:super_editor_spellcheck/src/messages.g.dart';

/// Plugin to check spelling errors in text using the native macOS spell checker.
class SuperEditorSpellCheckerPlugin {
  final SpellCheckApi _spellCheckApi = SpellCheckApi();

  /// Returns a unique tag to identified this spell checked object.
  ///
  /// Use this method to generate tags to avoid collisions with other objects that can be spell checked.
  Future<int> uniqueSpellDocumentTag() async {
    return await _spellCheckApi.uniqueSpellDocumentTag();
  }

  /// Notifies the receiver that the user has finished with the tagged document.
  ///
  /// The spell checker will release any resources associated with the document,
  /// including but not necessarily limited to, ignored words.
  Future<void> closeSpellDocumentWithTag(int tag) async {
    await _spellCheckApi.closeSpellDocument(tag);
  }

  /// Checks the given [text] for spelling errors with the given [locale].
  ///
  /// Returns a list of [TextSuggestion]s, where each spans represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the [locale]
  /// isn't supported by the spell checker.
  Future<List<TextSuggestion>> fetchSuggestions(Locale locale, String text) async {
    final results = await _spellCheckApi.fetchSuggestions(
      text: text,
      language: locale.toLanguageTag(),
    );

    return results
        .where((e) => e != null) //
        .cast<TextSuggestion>()
        .toList();
  }

  /// Starts the search for a misspelled word in [stringToCheck] starting at [startingOffset]
  /// within the string object.
  ///
  /// - [stringToCheck]: The string object containing the words to spellcheck.
  /// - [startingOffset]: The offset within the string object at which to start the spellchecking.
  /// - [wrap]: `true` to indicate that spell checking should continue at the beginning of the string
  ///   when the end of the string is reached; `false` to indicate that spellchecking should stop
  ///   at the end of the document.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the range of the first misspelled word.
  Future<TextRange> checkSpelling({
    required String stringToCheck,
    required int startingOffset,
    Locale? locale,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.checkSpelling(
      stringToCheck: stringToCheck,
      startingOffset: startingOffset,
      language: locale?.toLanguageTag(),
      wrap: wrap,
      inSpellDocumentWithTag: inSpellDocumentWithTag,
    );

    return TextRange(
      start: result.start,
      end: result.end,
    );
  }

  /// Returns an array of possible substitutions for the specified string.
  ///
  /// - [range]: The range of the string to check.
  /// - [text]: The string to guess.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns an array of strings containing possible replacement words.
  Future<List<String>> guesses({
    required TextRange range,
    required String text,
    Locale? locale,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.guesses(
      range: Range(start: range.start, end: range.end),
      text: text,
      language: locale?.toLanguageTag(),
      inSpellDocumentWithTag: inSpellDocumentWithTag,
    );

    if (result == null) {
      return <String>[];
    }

    return result //
        .where((e) => e != null)
        .cast<String>()
        .toList();
  }

  /// Initiates a grammatical analysis of a given string.
  ///
  /// - [stringToCheck]: The string to analyze.
  /// - [startingOffset]: Location within string at which to start the analysis.
  /// - [wrap]: `true` to specify that the analysis continue to the beginning of string when
  ///   the end is reached. `false` to have the analysis stop at the end of string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  Future<CheckGrammarResult> checkGrammar({
    required String stringToCheck,
    required int startingOffset,
    Locale? locale,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.checkGrammar(
      stringToCheck: stringToCheck,
      startingOffset: startingOffset,
      language: locale?.toLanguageTag(),
      inSpellDocumentWithTag: inSpellDocumentWithTag,
      wrap: wrap,
    );

    return CheckGrammarResult(
      firstError: result.firstError != null
          ? TextRange(
              start: result.firstError!.start,
              end: result.firstError!.end,
            )
          : null,
      details: result.details
              ?.map(
                (e) => GrammaticalAnalysisDetail(
                  range: TextRange(start: e!.range.start, end: e.range.end),
                  userDescription: e.userDescription,
                ),
              )
              .toList() ??
          [],
    );
  }

  /// Provides a list of complete words that the user might be trying to type based on a
  /// partial word in a given string.
  ///
  /// - [partialWordRange] - Range that identifies a partial word in string.
  /// - [text] - String with the partial word from which to generate the result.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the list of complete words from the spell checker dictionary in the order
  /// they should be presented to the user.
  Future<List<String>> completions({
    required TextRange partialWordRange,
    required String text,
    required Locale locale,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.completions(
      partialWordRange: Range(start: partialWordRange.start, end: partialWordRange.end),
      text: text,
      language: locale.toLanguageTag(),
      inSpellDocumentWithTag: inSpellDocumentWithTag,
    );

    if (result == null) {
      return <String>[];
    }

    return result //
        .where((e) => e != null)
        .cast<String>()
        .toList();
  }

  /// Returns the number of words in the specified string.
  Future<int> countWords({required String text, required Locale locale}) async {
    return await _spellCheckApi.countWords(
      text: text,
      language: locale.toLanguageTag(),
    );
  }

  /// Adds the [word] to the spell checker dictionary.
  Future<void> learnWord(String word) async {
    await _spellCheckApi.learnWord(word);
  }

  /// Indicates whether the spell checker has learned a given word.
  Future<bool> hasLearnedWord(String word) async {
    return await _spellCheckApi.hasLearnedWord(word);
  }

  /// Tells the spell checker to unlearn a given word.
  Future<void> unlearnWord(String word) async {
    await _spellCheckApi.unlearnWord(word);
  }

  /// Instructs the spell checker to ignore all future occurrences of [word] in the document
  /// identified by [documentTag].
  Future<void> ignoreWord({required String word, required int documentTag}) async {
    await _spellCheckApi.ignoreWord(word: word, documentTag: documentTag);
  }

  /// Returns the array of ignored words for a document identified by [documentTag].
  Future<List<String>> ignoredWords({required int documentTag}) async {
    final words = await _spellCheckApi.ignoredWords(documentTag: documentTag);
    if (words == null) {
      return <String>[];
    }

    return words //
        .where((e) => e != null)
        .cast<String>()
        .toList();
  }

  /// Initializes the ignored-words document (a dictionary identified by [documentTag] with [words]),
  /// an array of words to ignore.
  Future<void> setIgnoredWords({required List<String> words, required int documentTag}) async {
    await _spellCheckApi.setIgnoredWords(words: words, documentTag: documentTag);
  }

  /// Returns the dictionary used when replacing words.
  Future<Map<String, String>> userReplacementsDictionary() async {
    final dict = await _spellCheckApi.userReplacementsDictionary();
    dict.removeWhere((k, v) => k == null || v == null);

    return dict.cast<String, String>();
  }
}

class CheckGrammarResult {
  final TextRange? firstError;
  final List<GrammaticalAnalysisDetail> details;

  CheckGrammarResult({
    this.firstError,
    required this.details,
  });
}

class GrammaticalAnalysisDetail {
  GrammaticalAnalysisDetail({
    required this.range,
    required this.userDescription,
  });

  final TextRange range;
  final String userDescription;
}
