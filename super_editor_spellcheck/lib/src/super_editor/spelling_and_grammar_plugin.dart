import 'dart:ui';

import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/platform/spell_checker.dart';

/// A [SuperEditorPlugin] that checks spelling and grammar across a [Document],
/// underlines spelling and grammar mistakes, and offers corrections.
class SpellingAndGrammarPlugin extends SuperEditorPlugin {
  final _reaction = SpellingAndGrammarReaction();

  // TODO: Move underlines to a styler so that we don't encode temporary stuff in the document.
  // TODO: Make it possible to add stylers via plugin
  // TODO: Have this plugin apply spelling error ranges to the styler

  @override
  void attach(Editor editor) {
    editor.reactionPipeline.add(_reaction);
  }

  @override
  void detach(Editor editor) {
    editor.reactionPipeline.remove(_reaction);
  }
}

/// An [EditReaction] that runs spelling and grammar checks on all [TextNode]s
/// in a given [Document].
class SpellingAndGrammarReaction implements EditReaction {
  @override
  void modifyContent(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final document = editorContext.document;

    final changedTextNodes = <String>{};
    for (final event in changeList) {
      if (event is! DocumentEdit) {
        continue;
      }

      final change = event.change;
      if (change is! NodeChangeEvent) {
        continue;
      }

      final node = document.getNodeById(change.nodeId);
      if (node is! TextNode) {
        continue;
      }

      // A TextNode was changed in some way. Queue it for spelling and grammar checks.
      changedTextNodes.add(node.id);
    }

    for (final textNodeId in changedTextNodes) {
      final textNode = document.getNodeById(textNodeId);
      if (textNode == null) {
        // TODO: log a warning.
        continue;
      }
      if (textNode is! TextNode) {
        // TODO: log a warning.
        continue;
      }

      _doSpellingAndGrammarTest(textNode);
    }
  }

  Future<void> _doSpellingAndGrammarTest(TextNode textNode) async {
    final spellChecker = SuperEditorSpellCheckerPlugin().macSpellChecker;

    final spellingErrors = <TextRange>[];
    int startingOffset = 0;
    TextRange prevSpellingError = TextRange.empty;
    do {
      prevSpellingError = await spellChecker.checkSpelling(
        stringToCheck: textNode.text.text,
        startingOffset: startingOffset,
      );

      if (prevSpellingError.isValid) {
        spellingErrors.add(prevSpellingError);
        startingOffset = prevSpellingError.end;

        final word = textNode.text.text.substring(prevSpellingError.start, prevSpellingError.end);
        print("Misspelled word: '$word'");
      }
    } while (prevSpellingError.isValid);

    // TODO:
  }

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    // No-op: Spelling and grammar checks shouldn't be undoable on their own,
    //        so we only implement modifyContent().
  }
}
