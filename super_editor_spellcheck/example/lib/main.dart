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
  final _textController = TextEditingController(text: 'Helo, Worl!');

  List<TextSuggestion> _suggestions = [];

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
    super.dispose();
  }

  void _onTextChanged() {
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    final suggestions = await _superEditorSpellcheckPlugin.fetchSuggestions(
      PlatformDispatcher.instance.locale,
      _textController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _suggestions = suggestions;
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
              _suggestions.isEmpty
                  ? const Text('No spelling errors found.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _suggestions.map(_buildSuggestions).toList(),
                    ),
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
}
