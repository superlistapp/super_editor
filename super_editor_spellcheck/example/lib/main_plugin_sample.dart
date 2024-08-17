import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _superEditorSpellcheckPlugin = SuperEditorSpellCheckerPlugin();
  final _textController = TextEditingController(text: 'She go to the store everys day.');

  List<TextSuggestion> _suggestions = [];

  TextRange _firstMispelledWord = TextRange.empty;
  List<String> _firstMispelledWordSuggestions = [];
  CheckGrammarResult? _grammarAnalysis;
  int? _wordCount;
  int? _documentTag;
  Map<String, String> _userReplacementsDictionary = <String, String>{};
  List<String> _completionsForLastWord = [];
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();

    _textController.addListener(_onTextChanged);
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    if (_documentTag != null) {
      _superEditorSpellcheckPlugin.macSpellChecker.closeSpellDocumentWithTag(_documentTag!);
    }
    super.dispose();
  }

  void _onTextChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 300),
      _fetchSuggestions,
    );
  }

  Future<void> _fetchSuggestions() async {
    final textToSearch = _textController.text;
    final locale = PlatformDispatcher.instance.locale;

    int? tag = _documentTag;
    tag ??= await _superEditorSpellcheckPlugin.macSpellChecker.uniqueSpellDocumentTag();

    final language = _superEditorSpellcheckPlugin.macSpellChecker.convertDartLocaleToMacLanguageCode(locale)!;

    final suggestions = await _superEditorSpellcheckPlugin.fetchSuggestions(
      locale,
      textToSearch,
    );

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final firstMisspelled = await _superEditorSpellcheckPlugin.macSpellChecker.checkSpelling(
      stringToCheck: textToSearch,
      startingOffset: 0,
      language: language,
    );

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final firstSuggestions = firstMisspelled.isValid
        ? await _superEditorSpellcheckPlugin.macSpellChecker.guesses(
            range: firstMisspelled,
            text: textToSearch,
            language: language,
          )
        : <String>[];

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final grammarAnalysis = await _superEditorSpellcheckPlugin.macSpellChecker.checkGrammar(
      stringToCheck: textToSearch,
      startingOffset: 0,
      language: language,
    );

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final wordCount = await _superEditorSpellcheckPlugin.macSpellChecker.countWords(
      text: textToSearch,
      language: language,
    );

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final replacements = await _superEditorSpellcheckPlugin.macSpellChecker.userReplacementsDictionary();

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    final completionOffset = max(textToSearch.lastIndexOf(' '), 0);

    final completions = await _superEditorSpellcheckPlugin.macSpellChecker.completions(
      partialWordRange: TextRange(start: completionOffset, end: textToSearch.length),
      text: textToSearch,
      language: language,
    );

    if (_shouldAbortCurrentSearch(textToSearch)) {
      return;
    }

    setState(() {
      _documentTag = tag;
      _suggestions = suggestions;
      _firstMispelledWord = firstMisspelled;
      _firstMispelledWordSuggestions = firstSuggestions;
      _grammarAnalysis = grammarAnalysis;
      _wordCount = wordCount;
      _userReplacementsDictionary = replacements;
      _completionsForLastWord = completions;
    });
  }

  bool _shouldAbortCurrentSearch(String textToSearch) {
    if (!mounted) {
      return true;
    }

    if (textToSearch != _textController.text) {
      // The user changed the text while the search was happening. Ignore the results,
      // because a new search will happen.
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                controller: _textController,
              ),
              if (_documentTag != null) //
                Text('Document tag: $_documentTag'),
              if (_wordCount != null) //
                Text('Word count: $_wordCount'),
              if (_firstMispelledWord.isValid)
                Text('First misspelled word: ${_textController.text.substring(
                  _firstMispelledWord.start,
                  _firstMispelledWord.end,
                )}'),
              if (_firstMispelledWordSuggestions.isNotEmpty)
                Text('Suggestions for first misspelled word: ${_firstMispelledWordSuggestions.join(', ')}'),
              const SizedBox(height: 10),
              _suggestions.isEmpty
                  ? const Text('No spelling errors found.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _suggestions.map(_buildSuggestions).toList(),
                    ),
              if (_grammarAnalysis != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _grammarAnalysis!.details.map(_buildGrammarAnalysis).toList(),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _userReplacementsDictionary.entries.map(_buildReplacement).toList(),
              ),
              if (_completionsForLastWord.isNotEmpty)
                Text('Completions for last word: ${_completionsForLastWord.join(', ')}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(TextSuggestion span) {
    return Text(
      '${_textController.text.substring(span.range.start, span.range.end)}: ${span.suggestions.join(', ')}',
    );
  }

  Widget _buildGrammarAnalysis(GrammaticalAnalysisDetail? detail) {
    return Text(
      '${_textController.text.substring(detail!.range.start, detail.range.end)}: ${detail.userDescription}',
    );
  }

  Widget _buildReplacement(MapEntry<String, String> entry) {
    return Text(
      'Replace ${entry.key} with ${entry.value}',
    );
  }
}
