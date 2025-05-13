import 'dart:async';
import 'dart:math';

import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

class AiFadeInFeatureDemo extends StatefulWidget {
  const AiFadeInFeatureDemo({super.key});

  @override
  State<AiFadeInFeatureDemo> createState() => _AiFadeInFeatureDemoState();
}

class _AiFadeInFeatureDemoState extends State<AiFadeInFeatureDemo> with SingleTickerProviderStateMixin {
  // late final MutableDocument _document;
  // late final MutableDocumentComposer _composer;
  // late final Editor _editor;
  //
  // late final FocusNode _editorFocusNode;
  //
  // late final FadeInTextStyler _fadeInStylePhase;
  //
  // late final _FakeAiWithEditor _fakeAiWithEditor;

  late final _FakeAiWithMarkdown _fakeAiWithMarkdown;
  final _gptFeed = MarkdownGptReaderFeed();

  @override
  void initState() {
    print("Initializing AI demo");
    super.initState();

    // _document = MutableDocument(
    //   nodes: [
    //     ParagraphNode(id: "1", text: AttributedText()),
    //   ],
    // );
    // _composer = MutableDocumentComposer(
    //   initialSelection: DocumentSelection.collapsed(
    //     position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
    //   ),
    // );
    // _editor = Editor(
    //   editables: {
    //     Editor.documentKey: _document,
    //     Editor.composerKey: _composer,
    //   },
    //   requestHandlers: [
    //     ...defaultRequestHandlers,
    //   ],
    // );
    //
    // _editorFocusNode = FocusNode();
    //
    // _fadeInStylePhase = FadeInTextStyler(this);
    //
    // _fakeAiWithEditor = _FakeAiWithEditor(_editor);

    _fakeAiWithMarkdown = _FakeAiWithMarkdown(_gptFeed);
  }

  @override
  void dispose() {
    _fakeAiWithMarkdown.dispose();

    // _fadeInStylePhase.dispose();
    //
    // _fakeAiWithEditor.dispose();
    //
    // _editorFocusNode.dispose();
    //
    // _composer.dispose();
    // _editor.dispose();
    // _document.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Building AI demo");
    return InTheLabScaffold(
      content: GptReader(
        gptFeed: _gptFeed,
        stylesheet: defaultStylesheet.copyWith(
          selectedTextColorStrategy: ({
            required Color originalTextColor,
            required Color selectionHighlightColor,
          }) {
            return Colors.black;
          },
          addRulesAfter: [
            ...darkModeStyles,
          ],
        ),
        reactions: [
          MarkdownInlineUpstreamSyntaxReaction(
            defaultUpstreamInlineMarkdownParsers,
          ),
        ],
      ),
      supplemental: Column(
        spacing: 16,
        children: [
          ElevatedButton(
            onPressed: () => _fakeAiWithMarkdown.startSimulatedTextEntry(),
            child: Text("Restart Simulation"),
          ),
          ElevatedButton(
            onPressed: () => _fakeAiWithMarkdown.stopSimulatedTextEntry(),
            child: Text("Pause Simulation"),
          ),
        ],
      ),
    );
  }
}

class _FakeAiWithEditor {
  _FakeAiWithEditor(this._editor) {
    _preCannedDocument = _createFakeAiDocument();
  }

  void dispose() {
    _contentEntryTimer?.cancel();

    _isSimulatingTextEntry = false;
    _simulatedEntryTextIndex = 0;
    _nextTextEntrySnippet = null;
    _contentEntryTimer = null;
  }

  final Editor _editor;
  late final MutableDocument _preCannedDocument;

  bool _isRunningFadeIn = false;

  String? _fadingNodeId;

  AttributedText? _textToInsert;
  bool _isSimulatingTextEntry = false;
  int _simulatedEntryTextIndex = 0;
  AttributedText? _nextTextEntrySnippet;

  Timer? _contentEntryTimer;

  void startSimulatedTextEntry() {
    stopSimulatedTextEntry();
    _editor.execute([
      ClearDocumentRequest(),
    ]);

    _isRunningFadeIn = true;
    _doInsertContent();
    _contentEntryTimer = Timer(_randomAiTextInsertionInterval, _doInsertContent);
  }

  void _doInsertContent() {
    if (!_isRunningFadeIn) {
      return;
    }

    print("_doInsertContent() - node ID: $_fadingNodeId");
    if (_fadingNodeId == null) {
      // This is the start of the content insertion process.
      final firstNode = _preCannedDocument.first;
      _fadingNodeId = firstNode.id;

      _editor.execute([
        DeleteNodeRequest(nodeId: _editor.document.first.id),
      ]);
    } else if (!_isSimulatingTextEntry) {
      print(" - selecting next node");
      _selectNextNode();
      if (_fadingNodeId == null) {
        // We're done running the document fade-in.
        _isRunningFadeIn = false;
        return;
      }
    }

    bool isInsertingText = false;
    if (_isSimulatingTextEntry) {
      // We're in the process of inserting text.
      _selectNextTextSnippet();
      _doInsertText();

      isInsertingText = true;
    } else {
      final nextNode = _preCannedDocument.getNodeById(_fadingNodeId!)!;
      if (nextNode is TextNode) {
        // Start a new text node.
        print("Inserting new text node. Pre-canned text: ${nextNode.text.toPlainText()}");
        _editor.execute([
          InsertNodeAtIndexRequest(
            nodeIndex: _editor.document.length,
            newNode: nextNode.copyTextNodeWith(
              text: AttributedText(),
            ),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: nextNode.id,
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        ]);

        if (nextNode.text.isNotEmpty) {
          _isSimulatingTextEntry = true;
          _textToInsert = nextNode.text;
          _simulatedEntryTextIndex = 0;
        }

        isInsertingText = true;
      } else {
        // Insert the next non-text node.
        print("Inserting new non-text node");
        _editor.execute([
          InsertNodeAtIndexRequest(
            nodeIndex: _editor.document.length,
            newNode: nextNode.copyWithAddedMetadata({
              'createdAt': DateTime.now(),
            }),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: nextNode.id,
                nodePosition: nextNode.endPosition,
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
        ]);
      }
    }

    if (_fadingNodeId != null) {
      _contentEntryTimer = Timer(
        isInsertingText ? _randomAiTextInsertionInterval : _randomAiNodeInsertionInterval,
        _doInsertContent,
      );
    }
  }

  void _selectNextNode() {
    final previousNodeId = _fadingNodeId;
    final nextNode = previousNodeId != null //
        ? _preCannedDocument.getNodeAfterById(previousNodeId)
        : _preCannedDocument.first;
    _fadingNodeId = nextNode?.id;
    if (nextNode == null) {
      return;
    }
  }

  void _selectNextTextSnippet() {
    const minLength = 3;
    const maxLength = 30;

    final remaining = _textToInsert!.length - _simulatedEntryTextIndex;
    if (remaining <= 0) {
      // There's no text left. Fizzle.
      _nextTextEntrySnippet = null;
      return;
    }
    if (remaining <= minLength) {
      // There's not enough text left to satisfy the minimum per-entry amount.
      // Add whatever characters remain in the text.
      _nextTextEntrySnippet = _textToInsert!.copyText(_simulatedEntryTextIndex);
      _simulatedEntryTextIndex = _textToInsert!.length;
      return;
    }

    // Pick a random amount of the remaining characters, based on a minimum and
    // maximum number of characters that we want to insert per cycle.
    final randomMax = min(maxLength, remaining) - minLength;
    final length = Random().nextInt(randomMax) + minLength;
    final endIndex = _simulatedEntryTextIndex + length;

    _nextTextEntrySnippet = _textToInsert!.copyText(_simulatedEntryTextIndex, endIndex);
    _simulatedEntryTextIndex = endIndex;
  }

  void _doInsertText() {
    print("Inserting new text snippet");
    _editor.execute([
      InsertStyledTextAtCaretRequest(
        _nextTextEntrySnippet!,
        createdAt: DateTime.now(),
      ),
    ]);

    print(" - text entry index: $_simulatedEntryTextIndex, text length: ${_textToInsert!.length}");
    if (_simulatedEntryTextIndex >= _textToInsert!.length) {
      print(" - reached the end of a node. Turning off _isSimulatingTextEntry.");
      _isSimulatingTextEntry = false;
      _textToInsert = null;
      _simulatedEntryTextIndex = 0;
      _nextTextEntrySnippet = null;
    }
  }

  void stopSimulatedTextEntry() {
    print("STOPPING !!!!! - timer: $_contentEntryTimer");
    if (!_isRunningFadeIn) {
      return;
    }

    _isRunningFadeIn = false;
    _fadingNodeId = null;
    _isSimulatingTextEntry = false;
    _textToInsert = null;
    _contentEntryTimer?.cancel();
    _contentEntryTimer = null;
  }

  Duration get _randomAiNodeInsertionInterval => Duration(milliseconds: Random().nextInt(600) + 400);

  Duration get _randomAiTextInsertionInterval => Duration(milliseconds: Random().nextInt(400) + 100);
}

class _FakeAiWithMarkdown {
  _FakeAiWithMarkdown(this._gptFeed) {
    _chopDocumentIntoMarkdownInsertions();
  }

  void dispose() {
    _contentEntryTimer?.cancel();
    _contentEntryTimer = null;
  }

  final MarkdownGptReaderFeed _gptFeed;

  final _choppedInsertions = <String>[];

  bool _isRunningFadeIn = false;

  Timer? _contentEntryTimer;

  void _chopDocumentIntoMarkdownInsertions() {
    print("Chopping document into snippets");
    const minLength = 5;
    const maxLength = 25;

    int start = 0;
    while (start < _markdownDocument.length) {
      final end = _markdownDocument.length - start <= minLength //
          ? _markdownDocument.length
          : min(Random().nextInt(maxLength - minLength) + minLength + start, _markdownDocument.length);
      print("Chopping from $start to $end (of ${_markdownDocument.length})");

      _choppedInsertions.add(
        _markdownDocument.substring(start, end),
      );

      start = end;
    }
    print("Done chopping document");
  }

  void startSimulatedTextEntry() {
    print("Starting simulated text entry");
    stopSimulatedTextEntry();

    _isRunningFadeIn = true;

    print("Calling _doInsertContent()");
    _doInsertContent();
  }

  void _doInsertContent() {
    if (!_isRunningFadeIn) {
      print("Not running fade-in. Returning.");
      return;
    }

    final snippet = _choppedInsertions.removeAt(0);
    print("_doInsertContent() - snippet: '$snippet'");
    _gptFeed.submit(snippet);
    print("Done with insertion");

    if (_choppedInsertions.isNotEmpty) {
      print("Scheduling another timer");
      _contentEntryTimer = Timer(_randomAiTextInsertionInterval, _doInsertContent);
    }
  }

  void stopSimulatedTextEntry() {
    print("STOPPING !!!!! - timer: $_contentEntryTimer");
    if (!_isRunningFadeIn) {
      return;
    }

    _isRunningFadeIn = false;
    _contentEntryTimer?.cancel();
    _contentEntryTimer = null;
  }

  Duration get _randomAiTextInsertionInterval => Duration(milliseconds: Random().nextInt(400) + 100);
}

MutableDocument _createFakeAiDocument() => deserializeMarkdownToDocument(_markdownDocument);

const _markdownDocument = '''
# AI-Style Fade-In
It's common for chat GPT AI systems to fade in text and content as its generated by the AI model. Super Editor supports this.

Super Editor can fade-in text, as it's inserted.

Super Editor can also fade-in block nodes when inserted, too.

---
![This is an image](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTBlCAeZTtCKu3AgBfAodstpMeroo905pj5og&s)
---

To use this behavior, apps need to opt in to the following:
 * Configure text insertion requests to inject creation metadata, which includes the time.
 * Configure Super Editor's style phases to include the `FadeInStyler`.


''';

class MarkdownGptReaderFeed extends GptReaderFeed {
  void submit(String markdown) {
    print("Ensuring editor is attached.");
    ensureEditorIsAttached();
    print("Executing markdown insertion: '$markdown'");

    final now = DateTime.now();
    for (final character in markdown.characters) {
      if (character == "\n") {
        final newNodeId = Editor.createNodeId();
        editor!.execute([
          InsertNodeAtIndexRequest(
            nodeIndex: editor!.document.length,
            newNode: ParagraphNode(id: newNodeId, text: AttributedText()),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: newNodeId, nodePosition: TextNodePosition(offset: 0)),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.contentChange,
          ),
        ]);
        continue;
      }

      editor!.execute([
        InsertPlainTextAtCaretRequest(character, createdAt: now),
      ]);
    }

    print("Document after inserting '$markdown':");
    for (final node in editor!.document) {
      print(" - ${node.id}: $node");
    }
    print("---");
  }
}
