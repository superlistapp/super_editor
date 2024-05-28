import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

import 'popover_list.dart';

class SlackTagsFeatureDemo extends StatefulWidget {
  const SlackTagsFeatureDemo({super.key});

  @override
  State<SlackTagsFeatureDemo> createState() => _SlackTagsFeatureDemoState();
}

class _SlackTagsFeatureDemoState extends State<SlackTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final SlackTagPlugin _slackTagPlugin;

  late final FocusNode _editorFocusNode;

  final _users = <String>[];

  @override
  void initState() {
    super.initState();

    _document = MutableDocument.empty();
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
    );

    _slackTagPlugin = SlackTagPlugin()
      ..tagIndex.composingSlackTag.addListener(_onTagCompositionChange)
      ..tagIndex.addListener(_updateUserTagList);

    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();

    _slackTagPlugin.tagIndex
      ..composingSlackTag.removeListener(_onTagCompositionChange)
      ..removeListener(_updateUserTagList);

    _composer.dispose();
    _editor.dispose();
    _document.dispose();

    super.dispose();
  }

  void _onTagCompositionChange() {
    print("_onTagCompositionChange() - value: ${_slackTagPlugin.tagIndex.composingSlackTag.value?.token}");

    final paragraph = _document.nodes.first as ParagraphNode;
    print("Attributions in paragraph:");
    print("${paragraph.text.getAttributionSpansByFilter((a) => true)}");
  }

  void _updateUserTagList() {
    setState(() {
      _users.clear();

      for (final node in _document.nodes) {
        if (node is! TextNode) {
          continue;
        }

        final userSpans = node.text.getAttributionSpansInRange(
          attributionFilter: (a) => a is CommittedStableTagAttribution,
          range: SpanRange(0, node.text.length - 1),
        );

        for (final userSpan in userSpans) {
          _users.add(node.text.substring(userSpan.start, userSpan.end + 1));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InTheLabScaffold(
          content: _buildEditor(),
          supplemental: _buildTagList(),
        ),
        ListenableBuilder(
            listenable: _slackTagPlugin.tagIndex.composingSlackTag,
            builder: (context, child) {
              if (_slackTagPlugin.tagIndex.composingSlackTag.value == null) {
                return const SizedBox();
              }

              return Follower.withOffset(
                link: _composingLink,
                offset: Offset(0, 16),
                leaderAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                showWhenUnlinked: false,
                child: UserSelectionPopover(
                  editor: _editor,
                  userTagPlugin: _slackTagPlugin,
                  editorFocusNode: _editorFocusNode,
                ),
              );
            }),
      ],
    );
  }

  Widget _buildEditor() {
    return IntrinsicHeight(
      child: SuperEditor(
        editor: _editor,
        document: _document,
        composer: _composer,
        focusNode: _editorFocusNode,
        stylesheet: defaultStylesheet.copyWith(
          inlineTextStyler: (attributions, existingStyle) {
            TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

            if (attributions.contains(slackTagComposingAttribution)) {
              style = style.copyWith(
                color: Colors.blue,
              );
            }

            if (attributions.whereType<CommittedSlackTagAttribution>().isNotEmpty) {
              style = style.copyWith(
                color: Colors.orange,
              );
            }

            return style;
          },
          addRulesAfter: [
            ...darkModeStyles,
          ],
        ),
        documentOverlayBuilders: [
          AttributedTextBoundsOverlay(
            selector: (a) => a == slackTagComposingAttribution,
            builder: (context, attribution) {
              print("AttributedTextBoundsOverlay - attribution: $attribution");
              return Leader(
                link: _composingLink,
                child: const SizedBox(),
              );
            },
          ),
          DefaultCaretOverlayBuilder(
            caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
          ),
        ],
        plugins: {
          _slackTagPlugin,
        },
      ),
    );
  }

  Widget _buildTagList() {
    if (_users.isEmpty) {
      return const SizedBox();
    }

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final tag in _users) //
              Chip(label: Text(tag)),
          ],
        ),
      ),
    );
  }
}

final _composingLink = LeaderLink();

class UserSelectionPopover extends StatefulWidget {
  const UserSelectionPopover({
    Key? key,
    required this.editor,
    required this.userTagPlugin,
    required this.editorFocusNode,
  }) : super(key: key);

  final Editor editor;
  final SlackTagPlugin userTagPlugin;
  final FocusNode editorFocusNode;

  @override
  State<UserSelectionPopover> createState() => _UserSelectionPopoverState();
}

class _UserSelectionPopoverState extends State<UserSelectionPopover> {
  final _userCandidates = <String>[
    "Miguel Rodriguez",
    "Matt Carron",
    "John Smith",
    "Sally Smith",
    "Bob Baker",
    "Jane July",
    "Kelly Baker",
    "Alicia Daniel",
    "Alexander D.",
    "Franco Albany de Alice",
  ];
  final _matchingUsers = <String>[];

  final _popoverFocusNode = FocusNode();
  bool _isLoadingMatches = false;

  @override
  void initState() {
    super.initState();

    widget.userTagPlugin.tagIndex.composingSlackTag.addListener(_onComposingTokenChange);

    _onComposingTokenChange();
  }

  @override
  void didUpdateWidget(UserSelectionPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.userTagPlugin != oldWidget.userTagPlugin) {
      oldWidget.userTagPlugin.tagIndex.composingSlackTag.removeListener(_onComposingTokenChange);
      widget.userTagPlugin.tagIndex.composingSlackTag.addListener(_onComposingTokenChange);
    }
  }

  @override
  void dispose() {
    widget.userTagPlugin.tagIndex.composingSlackTag.removeListener(_onComposingTokenChange);

    _popoverFocusNode.dispose();

    super.dispose();
  }

  Future<void> _onComposingTokenChange() async {
    final composingTag = widget.userTagPlugin.tagIndex.composingSlackTag.value?.token;
    if (composingTag == null) {
      // The user isn't composing a tag. Therefore, this popover shouldn't
      // have focus.
      setState(() {
        _matchingUsers.clear();
      });
      return;
    }

    // Simulate a load time
    setState(() {
      _isLoadingMatches = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) {
      return;
    }
    if (composingTag != widget.userTagPlugin.tagIndex.composingSlackTag.value?.token) {
      // The user changed the token. Our search results are invalid. Fizzle.
      return;
    }

    // Filter the user list based on the composing token.
    setState(() {
      _isLoadingMatches = false;
      _selectMatchingUsers(composingTag);
      _popoverFocusNode.requestFocus();
    });
  }

  void _selectMatchingUsers(String composingTag) {
    final splitOnWhitespace = RegExp(r'\s+');
    final searchTokens = composingTag.split(splitOnWhitespace);
    print("Search tokens: $searchTokens");

    // Match user names by searching for prefix matches on each part of a
    // user's name. Examples:
    //
    // Search "j s" can match "John Smith" and "Jane Smith".
    //
    // Search "fe d" can match "Franco Albany de Alice"
    _matchingUsers
      ..clear()
      ..addAll(_userCandidates.where((user) {
        final nameTokens = user.split(splitOnWhitespace);
        int nameSearchTokenOffset = 0;
        for (int i = 0; i < searchTokens.length; i += 1) {
          if (i >= nameTokens.length) {
            return false;
          }

          int matchOffset = nameSearchTokenOffset;
          for (; matchOffset < nameTokens.length; matchOffset += 1) {
            if (nameTokens[matchOffset].toLowerCase().startsWith(searchTokens[i].toLowerCase())) {
              break;
            }
          }

          if (matchOffset >= nameTokens.length) {
            // We didn't find any downstream match for the search token in this user's
            // name. Don't include it.
            return false;
          }

          nameSearchTokenOffset = matchOffset + 1;
        }

        return true;
      }));
  }

  void _onUserSelected(Object name) {
    widget.editor.execute([
      FillInComposingSlackTagRequest(name as String),
    ]);
  }

  void _cancelTag() {
    widget.editor.execute([
      CancelComposingSlackTagRequest(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_matchingUsers.isEmpty) {
      return const SizedBox();
    }

    return PopoverList(
      editorFocusNode: widget.editorFocusNode,
      popoverFocusNode: _popoverFocusNode,
      leaderLink: _composingLink,
      listItems: _matchingUsers
          .map(
            (userName) => PopoverListItem(id: userName, label: userName),
          )
          .toList(),
      isLoading: _isLoadingMatches,
      onListItemSelected: _onUserSelected,
      onCancelRequested: _cancelTag,
    );
  }
}
