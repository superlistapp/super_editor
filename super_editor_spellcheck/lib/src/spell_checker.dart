import 'dart:ui';

import 'package:super_editor_spellcheck/src/messages.g.dart';

/// Plugin to check spelling errors in text using the native macOS spell checker.
class SuperEditorSpellCheckerPlugin {
  final SpellCheckApi _spellCheckApi = SpellCheckApi();

  /// Checks the given [text] for spelling errors with the given [locale].
  ///
  /// Returns a list of [TextSuggestion]s, where each spans represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the [locale]
  /// isn't supported by the spell checker.
  Future<List<TextSuggestion>> fetchSuggestions(Locale locale, String text) async {
    final results = await _spellCheckApi.fetchSuggestions(locale.toLanguageTag(), text);

    return results
        .where((e) => e != null) //
        .cast<TextSuggestion>()
        .toList();
  }
}
