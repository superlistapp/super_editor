import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';

/// A [SuperEditorPlugin] that finds inline Markdown syntax immediately upstream from the
/// caret and converts it into attributions.
///
/// Inline Markdown syntax includes things like `**token**` for bold, `*token*` for
/// italics, `~token~` for strikethrough, and `[token](url)` for hyperlinks.
///
/// When this plugin finds inline Markdown syntax, that syntax is removed when the corresponding
/// attribution is applied. For example, "**bold**" becomes "bold" with a bold attribution
/// applied to it.
///
/// This plugin only identifies spans of Markdown styles within individual [TextNode]s, which
/// immediately precedes the caret. For example, "Hello **bold**|" will apply the bold style,
/// but "Hello **bold** wo|" won't apply bold.
///
/// To add this plugin to a [SuperEditor] widget, provide a [MarkdownImmediateTokenInlineStylePlugin] in
/// the `plugins` property.
///
///   SuperEditor(
///     //...
///     plugins: {
///       markdownInlineStylePlugin,
///     },
///   );
///
/// To add this plugin directly to an [Editor], without involving a [SuperEditor]
/// widget, call [attach] with the given [Editor]. When that [Editor] is no longer needed,
/// call [detach] to clean up all plugin references.
///
///   markdownInlineStylePlugin.attach(editor);
///
///
class MarkdownImmediateTokenInlineStylePlugin extends SuperEditorPlugin {
  MarkdownImmediateTokenInlineStylePlugin() {
    _markdownInlineStyleReaction = MarkdownImmediateTokenInlineStyleReaction();
  }

  /// An [EditReaction] that finds and converts Markdown styling into attributed
  /// styles.
  late EditReaction _markdownInlineStyleReaction;

  @override
  void attach(Editor editor) {
    editor.reactionPipeline.insert(0, _markdownInlineStyleReaction);
  }

  @override
  void detach(Editor editor) {
    editor.reactionPipeline.remove(_markdownInlineStyleReaction);
  }
}

class MarkdownImmediateTokenInlineStyleReaction implements EditReaction {
  MarkdownImmediateTokenInlineStyleReaction();

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      // No edits means no Markdown insertions. Nothing for this plugin to do.
      return;
    }
    if (changeList.where((edit) => edit is DocumentEdit && edit.change is TextInsertionEvent).isEmpty) {
      // No text insertions. Nothing for this plugin to do.
      return;
    }

    final document = editContext.find<MutableDocument>(Editor.documentKey);
    final composer = editContext.find<MutableDocumentComposer>(Editor.composerKey);
    final selection = composer.selection;
    if (selection == null) {
      // No selection, so no caret for us to search before.
      return;
    }
    if (!selection.isCollapsed) {
      // It's not clear how the user would insert a Markdown character when the
      // selection is expanded. Fizzle.
      return;
    }
    final extent = selection.extent;

    final editedTextNodeIds = _findEditedTextNodes(document, changeList);
    if (!editedTextNodeIds.contains(extent.nodeId)) {
      // None of the changes happened in the node where the caret sits. Therefore,
      // there's no way the user added Markdown styling near the caret.
      return;
    }

    final changeRequests = _applyInlineMarkdownBeforeCaret(document, extent);
    if (changeRequests.isEmpty) {
      // No inline Markdown was applied. Fizzle.
      return;
    }

    requestDispatcher.execute(changeRequests);
  }

  /// Finds and returns the node IDs for every [TextNode] that was altered during this
  /// transaction.
  List<String> _findEditedTextNodes(Document document, List<EditEvent> changeList) {
    final editedTextNodes = <String, String>{};
    for (final change in changeList) {
      if (change is! DocumentEdit || change.change is! NodeDocumentChange) {
        continue;
      }

      final nodeId = (change.change as NodeDocumentChange).nodeId;
      if (editedTextNodes.containsKey(nodeId)) {
        continue;
      }

      if (document.getNodeById(nodeId) is! TextNode) {
        continue;
      }

      editedTextNodes[nodeId] = document.getNodeById(nodeId)!.id;
    }

    return editedTextNodes.values.toList();
  }

  List<EditRequest> _applyInlineMarkdownBeforeCaret(
    Document document,
    DocumentPosition caretPosition,
  ) {
    final editedNode = document.getNodeById(caretPosition.nodeId) as TextNode;
    final caretOffset = (caretPosition.nodePosition as TextNodePosition).offset;
    final inlineParser = _UpstreamInlineMarkdownParser(editedNode.text, caretOffset: caretOffset);

    final markdownRun = inlineParser.findMarkdown();
    if (markdownRun == null) {
      return const [];
    }

    return [
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: editedNode.id,
            nodePosition: TextNodePosition(offset: markdownRun.start),
          ),
          end: DocumentPosition(
            nodeId: editedNode.id,
            nodePosition: TextNodePosition(offset: markdownRun.end),
          ),
        ),
      ),
      InsertAttributedTextRequest(
        DocumentPosition(
          nodeId: editedNode.id,
          nodePosition: TextNodePosition(offset: markdownRun.start),
        ),
        markdownRun.appliedText,
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: editedNode.id,
            nodePosition: TextNodePosition(offset: markdownRun.start + markdownRun.appliedText.length),
          ),
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
    ];
  }
}

class _UpstreamInlineMarkdownParser {
  _UpstreamInlineMarkdownParser(
    this.attributedText, {
    required this.caretOffset,
  });

  final AttributedText attributedText;
  final int caretOffset;

  final _possibleSyntaxes = <_UpstreamMarkdownSyntaxParser>[];

  _InlineMarkdownRun? findMarkdown() {
    if (caretOffset == 0) {
      // Can't possibly have an upstream Markdown syntax when the caret is
      // at the beginning of the text.
      return null;
    }

    int offset = caretOffset - 1;
    _UpstreamMarkdownSyntaxParser? successfulParser;
    do {
      // Update all existing possible syntaxes and also add new possible syntaxes.
      _updateAndFindSyntaxes(attributedText.text[offset], offset);

      // Check if any possible syntax has completed into a valid Markdown syntax.
      successfulParser = _possibleSyntaxes.firstWhereOrNull((parser) => parser.isValid && parser.isComplete);

      offset -= 1;
    } while (offset >= 0 && attributedText.text[offset] != " " && _possibleSyntaxes.isNotEmpty);

    if (successfulParser == null) {
      return null;
    }

    return _InlineMarkdownRun(
      successfulParser.calculateFinalText(attributedText),
      // +1 because we always -1 in the loop above, even when we found what we're looking for.
      offset + 1,
      // Note: end offset is exclusive.
      caretOffset,
    );
  }

  void _updateAndFindSyntaxes(String character, int characterIndex) {
    // Update all existing possible syntaxes.
    for (int i = _possibleSyntaxes.length - 1; i >= 0; i -= 1) {
      // Add the latest character to the existing syntax parser.
      _possibleSyntaxes[i].prependCharacter(character);

      if (!_possibleSyntaxes[i].isValid) {
        // This syntax is no longer valid. Remove it.
        _possibleSyntaxes.removeAt(i);
      }
    }

    // Add new possible syntaxes for the given character.
    final styleSyntax = _StyleUpstreamMarkdownSyntaxParser.maybeCreateForCharacter(character, characterIndex);
    if (styleSyntax != null) {
      _possibleSyntaxes.add(styleSyntax);
    }
    // final linkSyntax = _LinkMarkdownSyntaxParser.maybeCreateForCharacter(character, characterIndex);
    // if (linkSyntax != null) {
    //   _possibleSyntaxes.add(linkSyntax);
    // }
  }
}

abstract interface class _UpstreamMarkdownSyntaxParser {
  /// Whether this parser still contains a valid syntax.
  ///
  /// Upstream parsers are told to consume one character after another with
  /// [prependCharacter]. A syntax that begins valid, such as "*" might then become
  /// invalid when adding another character, such as "~*". When adding a character
  /// invalidates the syntax, this property switches from `true` to `false`.
  bool get isValid;

  /// Whether the current text within this parser represents a complete Markdown
  /// syntax.
  ///
  /// For style parsers, the parser is considered complete when it finds both
  /// opening and closing syntaxes of the same form, e.g., "*italics*" or "**bold**".
  ///
  /// For a link parser, the syntax needs to full close the link. For example,
  /// "link](google.com)" is valid as we parse upstream, but it's not complete.
  /// "[a link](google.com)" is both valid and complete.
  bool get isComplete;

  /// Prepends the given upstream [character] to this syntax and then re-evaluates
  /// the validity of this syntax.
  ///
  /// The following are some examples of a syntax that prepends a character and remains
  /// valid:
  ///
  ///   - "*" -> "**"
  ///   - "**" -> "***"
  ///   - "_" -> "_"
  ///   - "__" -> "___"
  ///
  /// The following are some example of a syntax that prepends a character and becomes
  /// invalid:
  ///
  ///   - "***" -> "****"
  ///   - "___" -> "____"
  ///   - "~" -> "*~"
  ///
  /// After prepending a character, clients should check [isValid] to ensure that this
  /// syntax is still a valid Markdown syntax.
  void prependCharacter(String character);

  /// Calculates the [AttributedText] that should replace the [existingText] based on the
  /// parsed Markdown.
  ///
  /// This should only be called when [isComplete] is `true`.
  ///
  /// The final text is calculated, rather than returned, because the final attributions
  /// might be based on existing attributions. For example, applying bold shouldn't remove
  /// existing italics, and vis-a-versa. But this decision about which attributions to
  /// retain needs to a per-parser responsibility. For example, it might not make sense
  /// to retain bold or italics if the user applies an inline code style.
  AttributedText calculateFinalText(AttributedText existingText);
}

class _StyleUpstreamMarkdownSyntaxParser implements _UpstreamMarkdownSyntaxParser {
  static const _possibleStartCharacters = {"*", "_", "~", "`"};

  /// Inspects the given [character] and if its a style character such as "*", "_", "~",
  /// it might be the closing character of a Markdown style, and a new
  /// [_StyleUpstreamMarkdownSyntaxParser] is returned, otherwise `null` is returned.
  static _StyleUpstreamMarkdownSyntaxParser? maybeCreateForCharacter(String character, int characterIndex) {
    if (!_possibleStartCharacters.contains(character)) {
      return null;
    }

    switch (character) {
      case "*":
      case "_":
        return _StyleUpstreamMarkdownSyntaxParser(character, 3, characterIndex);
      case "~":
      case "`":
        return _StyleUpstreamMarkdownSyntaxParser(character, 1, characterIndex);
      default:
        throw Exception("Unrecognized Markdown style trigger: '$character'");
    }
  }

  static const _lookingForCloseSyntax = 1;
  static const _lookingForOpenSyntax = 2;
  static const _done = 3;

  _StyleUpstreamMarkdownSyntaxParser(this._triggerCharacter, this._maxSyntaxLength, this._triggerIndex)
      : assert(_triggerCharacter.length == 1),
        assert(_possibleStartCharacters.contains(_triggerCharacter)),
        _closingSyntax = _triggerCharacter {
    if (_maxSyntaxLength == 1) {
      // Only one closing character is allowed, so we start off already looking
      // for the opening syntax upstream.
      _phase = _lookingForOpenSyntax;
    } else {
      // The closing syntax might be 1+ character, so we start off by looking for
      // more closing syntax characters.
      _phase = _lookingForCloseSyntax;
    }

    _allParsedText.write(_triggerCharacter);
    _currentIndex = _triggerIndex;
  }

  final String _triggerCharacter;
  final int _triggerIndex;
  final int _maxSyntaxLength;
  final _allParsedText = StringBuffer();
  late int _currentIndex;

  String _closingSyntax;
  String _openingSyntax = "";
  late int _phase = _lookingForCloseSyntax;

  @override
  bool get isValid => _isValid;
  bool _isValid = true;

  @override
  bool get isComplete => _isComplete;
  bool _isComplete = false;

  @override
  void prependCharacter(String character) {
    _allParsedText.write(character);
    _currentIndex -= 1;

    switch (_phase) {
      case _lookingForCloseSyntax:
        if (character == _triggerCharacter) {
          // We found another character that belongs to our style syntax, e.g.,
          // from "*" to "**", from "_" to "__".
          _closingSyntax = "$character$_closingSyntax";
        } else {
          // We've moved from the closing syntax into the styled content.
          _phase = _lookingForOpenSyntax;
        }
      case _lookingForOpenSyntax:
        if (character == _triggerCharacter) {
          // Prepend the current character to what might end up being the starting
          // syntax.
          _openingSyntax = "$character$_openingSyntax";
        }

        if (_openingSyntax == _closingSyntax) {
          // We just found an opening syntax that matches our closing syntax.
          // Therefore, we have found a complete Markdown run.
          _isComplete = true;
          _phase = _done;
        }
      case _done:
        // More characters were added after already finding a complete Markdown
        // style. This changes the syntax from valid to invalid because its now
        // more than just a style.
        _isValid = false;
    }
  }

  @override
  AttributedText calculateFinalText(AttributedText existingText) {
    if (!_isComplete) {
      throw Exception(
        "Can't calculate inline Markdown text for a parser whose content is incomplete: '${_allParsedText.toString()}'.",
      );
    }
    if (!_isValid) {
      throw Exception(
          "Can't calculate inline Markdown text for a parser whose content is invalid: '${_allParsedText.toString()}'.");
    }

    final newStyles = <Attribution>{};
    switch (_openingSyntax) {
      case "***":
      case "___":
        newStyles.addAll([italicsAttribution, boldAttribution]);
      case "**":
      case "__":
        newStyles.add(boldAttribution);
      case "*":
      case "_":
        newStyles.add(italicsAttribution);
      case "~":
        newStyles.add(strikethroughAttribution);
      case "`":
        newStyles.add(codeAttribution);
    }

    // Imagine that we've identified something like "**token**". In that case, we'd
    // want to remove the opening and closing "**" and then apply bold to the rest of
    // the text. We want to leave any other existing attributions alone.
    final syntaxLength = _closingSyntax.length;
    final appliedText = existingText.copyText(
      _currentIndex + syntaxLength,
      _triggerIndex - syntaxLength + 1,
    );
    for (final attribution in newStyles) {
      appliedText.addAttribution(attribution, SpanRange(0, appliedText.text.length - 1));
    }

    return appliedText;
  }
}

// class _LinkMarkdownSyntaxParser implements _UpstreamMarkdownSyntaxParser {
//   /// Inspects the given [character] and if its a ")", it might be the closing
//   /// character of a Markdown link and a new [_LinkMarkdownSyntaxParser] is
//   /// returned, otherwise `null` is returned.
//   static _LinkMarkdownSyntaxParser? maybeCreateForCharacter(String character, int characterIndex) {
//     if (character != ")") {
//       return null;
//     }
//     return _LinkMarkdownSyntaxParser(characterIndex);
//   }
//
//   static const _lookingForUrlOpen = 1;
//   static const _lookingForLinkClose = 2;
//   static const _lookingForLinkOpen = 3;
//   static const _done = 4;
//
//   _LinkMarkdownSyntaxParser(this._triggerIndex) : _currentSyntax = ")" {
//     _allParsedText = ")";
//     _currentIndex = _triggerIndex;
//   }
//
//   int _triggerIndex;
//   String _allParsedText = "";
//   late int _currentIndex;
//
//   String _currentSyntax;
//   String _url = "";
//   String _link = "";
//   int _phase = 1;
//
//   @override
//   bool get isValid => _isValid;
//   bool _isValid = true;
//
//   @override
//   bool get isComplete => _isComplete;
//   bool _isComplete = false;
//
//   @override
//   void prependCharacter(String character) {
//     _allParsedText = "$character$_allParsedText";
//     print("Trying to find Markdown link in: '$_allParsedText'");
//     _currentIndex -= 1;
//     if (!_isValid) {
//       return;
//     }
//
//     _currentSyntax = "$character$_currentSyntax";
//
//     switch (_phase) {
//       case _lookingForUrlOpen:
//         if (character == "(") {
//           _phase = _lookingForLinkClose;
//         } else {
//           // This character is part of the URL.
//           _url = "$character$_url";
//         }
//       case _lookingForLinkClose:
//         if (character == "]") {
//           _phase = _lookingForLinkOpen;
//         } else {
//           // We expect "]" appear immediately upstream from "(", but it's not.
//           // This is not a valid link syntax.
//           _isValid = false;
//           return;
//         }
//       case _lookingForLinkOpen:
//         if (character == "[") {
//           _isComplete = true;
//         } else {
//           // This character is part of the link label.
//           _link = "$character$_link";
//         }
//       case _done:
//         // More characters were added after already finding a complete Markdown
//         // link. This changes the syntax from valid to invalid because its now
//         // more than just a link.
//         _isValid = false;
//     }
//   }
//
//   @override
//   AttributedText calculateFinalText(AttributedText existingText) {
//     if (!_isComplete) {
//       throw Exception(
//         "Can't calculate inline Markdown text for a parser (Links) whose content is incomplete: '${_allParsedText.toString()}'.",
//       );
//     }
//     if (!_isValid) {
//       throw Exception(
//           "Can't calculate inline Markdown text for a parser (Links) whose content is invalid: '${_allParsedText.toString()}'.");
//     }
//
//     print("Calculating final text:");
//     print(" - total text: '${_allParsedText.toString()}'");
//     print(" - link: $_link");
//     print(" - URL: $_url");
//
//     // Copy the link text out of the existing text. For example, if the existing text
//     // is "Hello [my link](http://google.com)" we want to copy "my link".
//     //
//     // At this point in the process, the `_currentIndex` points to the character one place
//     // upstream from the opening "[".
//     final styledLink = existingText.copyText(_currentIndex + 1, _currentIndex + 1 + _link.length)
//       ..addAttribution(
//         LinkAttribution(url: Uri.parse(_url)),
//         SpanRange(0, _link.length - 1),
//       );
//     return styledLink;
//   }
// }

class _InlineMarkdownRun {
  const _InlineMarkdownRun(this.appliedText, this.start, this.end);

  final AttributedText appliedText;
  final int start;
  final int end;
}
