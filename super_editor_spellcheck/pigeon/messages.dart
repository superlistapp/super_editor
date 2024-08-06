import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut: 'macos/Classes/messages.g.swift',
))
@HostApi()
abstract class SpellCheckMac {
  /// {@template mac_spell_checker_available_languages}
  /// A list containing all the available spell checking languages.
  ///
  /// The languages are ordered in the user’s preferred order as set in the
  /// system preferences.
  /// {@endtemplate}
  List<String?> availableLanguages();

  /// {@template mac_spell_checker_unique_spell_document_tag}
  /// Returns a unique tag to partition stateful operations in the spell checking system.
  ///
  /// Use the tag returned by this method in the spell checking methods when there are different
  /// texts being spell checked.
  ///
  /// For example, if there are two texts being spell checked, with tags `1` and `2`,
  /// the spell checker will keep the state of the ignored words separate for each one. If an
  /// ignored word is added to the tag `1`, it won't be seen as misspelled for tag `1`, but it
  /// will be for the tag `2`.
  ///
  /// Call [closeSpellDocument] when you are done with the tag to release resources.
  /// {@endtemplate}
  int uniqueSpellDocumentTag();

  /// {@template mac_spell_checker_close_spell_document}
  /// Notifies the spell checking system that the user has finished with the tagged document.
  ///
  /// The spell checker will release any resources associated with the document,
  /// including but not necessarily limited to, ignored words.
  /// {@endtemplate}
  void closeSpellDocument(int tag);

  /// {@template mac_spell_checker_check_spelling}
  /// Searches for a misspelled word in [stringToCheck], starting at [startingOffset], and returns the
  /// [TextRange] surrounding the misspelled word.
  ///
  /// If no misspelled word is found, a [TextRange] is returned with bounds of `-1`, which can also be
  /// queried more conveniently with [TextRange.isValid].
  ///
  /// To find all (or multiple) misspelled words in a given string, call this
  /// method repeatedly, passing in different values for [startingOffset].
  /// {@endtemplate}
  PigeonRange checkSpelling({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  });

  /// {@template mac_spell_checker_guesses}
  /// Returns possible substitutions for the specified misspelled word at [range] inside the [text].
  ///
  /// - [range]: The range, within the [text], for which possible substitutions should be generated.
  /// - [text]: The string containing the word/text for which substitutions should be generated.
  /// - [inSpellDocumentWithTag]: The (optional) ID of the loaded document that contains the given [text],
  ///   which is used to provide additional context to the substitution guesses. A value of '0' instructs
  ///   the guessing system to consider the [text] in isolation, without connection to any given document.
  /// {@endtemplate}
  List<String?>? guesses({
    required String text,
    required PigeonRange range,
    String? language,
    int inSpellDocumentWithTag = 0,
  });

  /// {@template mac_spell_checker_check_grammar}
  /// Performs a grammatical analysis of [stringToCheck], starting at [startingOffset].
  ///
  /// - [stringToCheck]: The string containing the text to be analyzed.
  /// - [startingOffset]: Location within the text at which the analysis should start.
  /// - [wrap]: `true` to specify that the analysis continue to the beginning of the text when
  ///   the end is reached. `false` to have the analysis stop at the end of the text.
  /// - [inSpellDocumentWithTag]: The (optional) ID of the loaded document that contains the given [text],
  ///   which is used to provide additional context to the substitution guesses. A value of '0' instructs
  ///   the guessing system to consider the [stringToCheck] in isolation, without connection to any given document.
  /// {@endtemplate}
  PigeonCheckGrammarResult checkGrammar({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  });

  /// {@template mac_spell_checker_completions}
  /// Provides a list of complete words that the user might be trying to type based on a partial word
  /// at [partialWordRange] in the given [text].
  ///
  /// - [partialWordRange] - The range, within the [text], for which possible completions should be generated.
  /// - [text] - The string containing the partial word for which completions should be generated.
  /// - [inSpellDocumentWithTag]: The (optional) ID of the loaded document that contains the given [text],
  ///   which is used to provide additional context to the substitution guesses. A value of '0' instructs
  ///   the guessing system to consider the [text] in isolation, without connection to any given document.
  ///
  /// The items of the list are in the order they should be presented to the user.
  /// {@endtemplate}
  List<String>? completions({
    required PigeonRange partialWordRange,
    required String text,
    String? language,
    int inSpellDocumentWithTag = 0,
  });

  /// {@template mac_spell_checker_count_words}
  /// Returns the number of words in the specified string.
  /// {@endtemplate}
  int countWords({required String text, String? language});

  /// {@template mac_spell_checker_learn_word}
  /// Adds the [word] to the spell checker dictionary.
  /// {@endtemplate}
  void learnWord(String word);

  /// {@template mac_spell_checker_has_learned_word}
  /// Indicates whether the spell checker has learned a given word.
  /// {@endtemplate}
  bool hasLearnedWord(String word);

  /// {@template mac_spell_checker_unlearn_word}
  /// Tells the spell checker to unlearn a given word.
  /// {@endtemplate}
  void unlearnWord(String word);

  /// {@template mac_spell_checker_ignore_word}
  /// Instructs the spell checker to ignore all future occurrences of [word] in the document
  /// identified by [documentTag].
  /// {@endtemplate}
  void ignoreWord({required String word, required int documentTag});

  /// {@template mac_spell_checker_ignored_words}
  /// Returns the array of ignored words for a document identified by [documentTag].
  /// {@endtemplate}
  List<String>? ignoredWords(int documentTag);

  /// {@template mac_spell_checker_set_ignored_words}
  /// Updates the ignored-words document (a dictionary identified by [documentTag] with [words])
  /// with a list of [words] to ignore.
  /// {@endtemplate}
  void setIgnoredWords({required List<String> words, required int documentTag});

  /// {@template mac_spell_checker_user_replacements_dictionary}
  /// Returns the dictionary used when replacing words, as defined by the user in the system preferences.
  ///
  /// This can be used to create an UI with replacement options when the user types a certain
  /// combination of characters. For example, the user might want to automatically replace
  /// "omw" with "on my way". When the user types "omw", an UI should display "on my way" as
  /// a possible replacement.
  /// {@endtemplate}
  Map<String, String> userReplacementsDictionary();
}

/// A range of characters in a string of text.
///
/// The text included in the range includes the character at [start], but not
/// the one at [end].
///
/// This is used because we can't use `TextRange` in pigeon.
class PigeonRange {
  PigeonRange({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;
}

/// The result of a grammatical analysis.
class PigeonCheckGrammarResult {
  PigeonCheckGrammarResult({
    this.firstError,
    this.details,
  });

  /// The range of the first error found in the text or `null` if no errors were found.
  final PigeonRange? firstError;

  /// A list of details about the grammatical errors found in the text or `null`
  /// if no errors were found.
  final List<PigeonGrammaticalAnalysisDetail?>? details;
}

/// A detail about a grammatical error found in a text.
class PigeonGrammaticalAnalysisDetail {
  PigeonGrammaticalAnalysisDetail({
    required this.range,
    required this.userDescription,
  });

  /// The range of the grammatical error in the text.
  final PigeonRange range;

  /// A description of the grammatical error.
  final String userDescription;
}
