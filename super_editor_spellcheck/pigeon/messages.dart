import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut: 'macos/Classes/messages.g.swift',
))
@HostApi()
abstract class SpellCheckMac {
  /// Checks the given [text] for spelling errors with the given [language].
  ///
  /// Returns a list of [TextSuggestion]s, where each span represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the [language]
  /// isn't supported by the spell checker.
  List<TextSuggestion> fetchSuggestions({
    required String text,
    required String language,
  });

  /// Returns a unique tag to identified this spell checked object.
  ///
  /// Use this method to generate tags to avoid collisions with other objects that can be spell checked.
  int uniqueSpellDocumentTag();

  /// Notifies the receiver that the user has finished with the tagged document.
  ///
  /// The spell checker will release any resources associated with the document,
  /// including but not necessarily limited to, ignored words.
  void closeSpellDocument(int tag);

  /// Searches for a misspelled word in [stringToCheck] starting at [startingOffset]
  /// within the string object.
  ///
  /// - [stringToCheck]: The string object containing the words to spellcheck.
  /// - [startingOffset]: The offset within the string object at which to start the spellchecking.
  /// - [language]: The language of the words in the string.
  /// - [wrap]: `true` to indicate that spell checking should continue at the beginning of the string
  ///   when the end of the string is reached; `false` to indicate that spellchecking should stop
  ///   at the end of the string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the range of the first misspelled word.
  Range checkSpelling({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  });

  /// Returns an array of possible substitutions for the specified string.
  ///
  /// - [range]: The range of the string to check.
  /// - [text]: The string to guess.
  /// - [language]: The language of the string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns an array of strings containing possible replacement words.
  List<String?>? guesses({
    required String text,
    required Range range,
    String? language,
    int inSpellDocumentWithTag = 0,
  });

  /// Performs a grammatical analysis of a given string.
  ///
  /// - [stringToCheck]: The string to analyze.
  /// - [startingOffset]: Location within string at which to start the analysis.
  /// - [language]: Language to use in string.
  /// - [wrap]: `true` to specify that the analysis continue to the beginning of string when
  ///   the end is reached. `false` to have the analysis stop at the end of string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  PlatformCheckGrammarResult checkGrammar({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  });

  /// Provides a list of complete words that the user might be trying to type based on a
  /// partial word in a given string.
  ///
  /// - [partialWordRange] - Range that identifies a partial word in string.
  /// - [text] - String with the partial word from which to generate the result.
  /// - [language]: Language to use in string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the list of complete words from the spell checker dictionary in the order
  /// they should be presented to the user.
  List<String>? completions({
    required Range partialWordRange,
    required String text,
    String? language,
    int inSpellDocumentWithTag = 0,
  });

  /// Returns the number of words in the specified string.
  int countWords({required String text, String? language});

  /// Adds the [word] to the spell checker dictionary.
  void learnWord(String word);

  /// Indicates whether the spell checker has learned a given word.
  bool hasLearnedWord(String word);

  /// Tells the spell checker to unlearn a given word.
  void unlearnWord(String word);

  /// Instructs the spell checker to ignore all future occurrences of [word] in the document
  /// identified by [documentTag].
  void ignoreWord({required String word, required int documentTag});

  /// Returns the array of ignored words for a document identified by [documentTag].
  List<String>? ignoredWords(int documentTag);

  /// Updates the ignored-words document (a dictionary identified by [documentTag] with [words])
  /// with a list of [words] to ignore.
  void setIgnoredWords({required List<String> words, required int documentTag});

  /// Returns the dictionary used when replacing words.
  Map<String, String> userReplacementsDictionary();
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

/// A range of characters in a string of text.
///
/// The text included in the range includes the character at [start], but not
/// the one at [end].
///
/// This is used because we can't use `TextRange` in pigeon.
class Range {
  Range({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;
}

/// The result of a grammatical analysis.
class PlatformCheckGrammarResult {
  PlatformCheckGrammarResult({
    this.firstError,
    this.details,
  });

  /// The range of the first error found in the text or `null` if no errors were found.
  final Range? firstError;

  /// A list of details about the grammatical errors found in the text or `null`
  /// if no errors were found.
  final List<PlatformGrammaticalAnalysisDetail?>? details;
}

/// A detail about a grammatical error found in a text.
class PlatformGrammaticalAnalysisDetail {
  PlatformGrammaticalAnalysisDetail({
    required this.range,
    required this.userDescription,
  });

  /// The range of the grammatical error in the text.
  final Range range;

  /// A description of the grammatical error.
  final String userDescription;
}
