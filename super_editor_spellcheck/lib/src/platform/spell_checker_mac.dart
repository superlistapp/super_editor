import 'dart:ui';

import 'package:super_editor_spellcheck/src/platform/messages.g.dart';

/// Plugin to check spelling errors in text using the native macOS spell checker.
class SuperEditorSpellCheckerMacPlugin {
  final SpellCheckMac _spellCheckApi = SpellCheckMac();

  /// {@macro mac_spell_checker_available_languages}
  Future<List<String>> availableLanguages() async {
    final languages = await _spellCheckApi.availableLanguages();

    return languages //
        .where((e) => e != null)
        .cast<String>()
        .toList();
  }

  /// {@macro mac_spell_checker_unique_spell_document_tag}
  Future<int> uniqueSpellDocumentTag() async {
    return await _spellCheckApi.uniqueSpellDocumentTag();
  }

  /// {@macro mac_spell_checker_close_spell_document}
  Future<void> closeSpellDocumentWithTag(int tag) async {
    await _spellCheckApi.closeSpellDocument(tag);
  }

  /// {@macro mac_spell_checker_check_spelling}
  Future<TextRange> checkSpelling({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.checkSpelling(
      stringToCheck: stringToCheck,
      startingOffset: startingOffset,
      language: language,
      wrap: wrap,
      inSpellDocumentWithTag: inSpellDocumentWithTag,
    );

    return TextRange(
      start: result.start,
      end: result.end,
    );
  }

  /// {@macro mac_spell_checker_guesses}
  Future<List<String>> guesses({
    required TextRange range,
    required String text,
    String? language,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.guesses(
      range: PigeonRange(start: range.start, end: range.end),
      text: text,
      language: language,
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

  /// {@macro mac_spell_checker_correction}
  Future<String?> correction({
    required String text,
    required TextRange range,
    required String language,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.correction(
      text: text,
      range: PigeonRange(start: range.start, end: range.end),
      language: language,
      inSpellDocumentWithTag: inSpellDocumentWithTag,
    );

    return result;
  }

  /// {@macro mac_spell_checker_check_grammar}
  Future<CheckGrammarResult> checkGrammar({
    required String stringToCheck,
    required int startingOffset,
    String? language,
    bool wrap = false,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.checkGrammar(
      stringToCheck: stringToCheck,
      startingOffset: startingOffset,
      language: language,
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

  /// {@macro mac_spell_checker_completions}
  Future<List<String>> completions({
    required TextRange partialWordRange,
    required String text,
    required String language,
    int inSpellDocumentWithTag = 0,
  }) async {
    final result = await _spellCheckApi.completions(
      partialWordRange: PigeonRange(start: partialWordRange.start, end: partialWordRange.end),
      text: text,
      language: language,
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

  /// {@macro mac_spell_checker_count_words}
  Future<int> countWords({required String text, required String language}) async {
    return await _spellCheckApi.countWords(
      text: text,
      language: language,
    );
  }

  /// {@macro mac_spell_checker_learn_word}
  Future<void> learnWord(String word) async {
    await _spellCheckApi.learnWord(word);
  }

  /// {@macro mac_spell_checker_has_learned_word}
  Future<bool> hasLearnedWord(String word) async {
    return await _spellCheckApi.hasLearnedWord(word);
  }

  /// {@macro mac_spell_checker_unlearn_word}
  Future<void> unlearnWord(String word) async {
    await _spellCheckApi.unlearnWord(word);
  }

  /// {@macro mac_spell_checker_ignore_word}
  Future<void> ignoreWord({required String word, required int documentTag}) async {
    await _spellCheckApi.ignoreWord(word: word, documentTag: documentTag);
  }

  /// {@macro mac_spell_checker_ignored_words}
  Future<List<String>> ignoredWords({required int documentTag}) async {
    final words = await _spellCheckApi.ignoredWords(documentTag);
    if (words == null) {
      return <String>[];
    }

    return words //
        .where((e) => e != null)
        .cast<String>()
        .toList();
  }

  /// {@macro mac_spell_checker_set_ignored_words}
  Future<void> setIgnoredWords({required List<String> words, required int documentTag}) async {
    await _spellCheckApi.setIgnoredWords(words: words, documentTag: documentTag);
  }

  /// {@macro mac_spell_checker_user_replacements_dictionary}
  Future<Map<String, String>> userReplacementsDictionary() async {
    final dict = await _spellCheckApi.userReplacementsDictionary();
    dict.removeWhere((k, v) => k == null || v == null);

    return dict.cast<String, String>();
  }

  /// Converts the dart locale to macOS language code.
  ///
  /// For example, converts "pt-BR" to "pt_BR".
  ///
  /// Returns `null` if the [locale] is `null`.
  String? convertDartLocaleToMacLanguageCode(Locale? locale) {
    if (locale == null) {
      return null;
    }

    return locale.toLanguageTag().replaceAll("-", "_");
  }
}

class CheckGrammarResult {
  CheckGrammarResult({
    this.firstError,
    required this.details,
  });

  final TextRange? firstError;
  final List<GrammaticalAnalysisDetail> details;
}

class GrammaticalAnalysisDetail {
  GrammaticalAnalysisDetail({
    required this.range,
    required this.userDescription,
  });

  final TextRange range;

  /// The description of the grammatical error that should be displayed to the user.
  final String userDescription;
}

/// A range containing a misspelled word and its suggestions.
class TextSuggestion {
  TextSuggestion({
    required this.range,
    required this.suggestions,
  });

  final TextRange range;
  final List<String?> suggestions;
}
