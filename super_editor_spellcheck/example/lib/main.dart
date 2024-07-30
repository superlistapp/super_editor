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
      _superEditorSpellcheckPlugin.closeSpellDocumentWithTag(_documentTag!);
    }
    super.dispose();
  }

  void _onTextChanged() {
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    int? tag = _documentTag;
    tag ??= await _superEditorSpellcheckPlugin.uniqueSpellDocumentTag();

    final suggestions = await _superEditorSpellcheckPlugin.fetchSuggestions(
      PlatformDispatcher.instance.locale,
      _textController.text,
    );

    final firstMisspelled = await _superEditorSpellcheckPlugin.checkSpelling(
      stringToCheck: _textController.text,
      startingOffset: 0,
      locale: PlatformDispatcher.instance.locale,
    );

    final firstSuggestions = firstMisspelled.isValid
        ? await _superEditorSpellcheckPlugin.guesses(
            range: firstMisspelled,
            text: _textController.text,
            locale: PlatformDispatcher.instance.locale,
          )
        : <String>[];

    final grammarAnalysis = await _superEditorSpellcheckPlugin.checkGrammar(
      stringToCheck: _textController.text,
      startingOffset: 0,
      locale: PlatformDispatcher.instance.locale,
    );

    final wordCount = await _superEditorSpellcheckPlugin.countWords(
      text: _textController.text,
      locale: PlatformDispatcher.instance.locale,
    );

    final replacements = await _superEditorSpellcheckPlugin.userReplacementsDictionary();

    final completionOffset = max(_textController.text.lastIndexOf(' '), 0);

    final completions = await _superEditorSpellcheckPlugin.completions(
      partialWordRange: TextRange(start: completionOffset, end: _textController.text.length),
      text: _textController.text,
      locale: PlatformDispatcher.instance.locale,
    );

    if (!mounted) {
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
      '${_textController.text.substring(span.start, span.end)}: ${span.suggestions.join(', ')}',
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
