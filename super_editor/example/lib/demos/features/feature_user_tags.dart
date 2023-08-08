import 'package:example/demos/features/feature_demo_scaffold.dart';
import 'package:example/demos/features/popover_list.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

class UserTagsFeatureDemo extends StatefulWidget {
  const UserTagsFeatureDemo({super.key});

  @override
  State<UserTagsFeatureDemo> createState() => _UserTagsFeatureDemoState();
}

class _UserTagsFeatureDemoState extends State<UserTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final UserTagPlugin _userTagPlugin;

  late final FocusNode _editorFocusNode;

  final _users = <String>[];

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text: ""))]);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
      listeners: [
        FunctionalEditListener(_onEdit),
      ],
    );

    _userTagPlugin = UserTagPlugin();

    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();

    _composer.dispose();
    _editor.dispose();
    _document.dispose();

    super.dispose();
  }

  void _onEdit(List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      return;
    }

    _updateUserTagList();
  }

  void _updateUserTagList() {
    setState(() {
      _users.clear();

      for (final node in _document.nodes) {
        if (node is! TextNode) {
          continue;
        }

        final userSpans = node.text.getAttributionSpansInRange(
          attributionFilter: (a) => a is UserTagAttribution,
          range: SpanRange(start: 0, end: node.text.text.length - 1),
        );

        for (final userSpan in userSpans) {
          _users.add(node.text.text.substring(userSpan.start, userSpan.end + 1));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FeatureDemoScaffold(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildEditor(),
              ),
              _buildTagList(),
            ],
          ),
        ),
        if (_userTagPlugin.userTagIndex.composingUserTag.value != null)
          Follower.withOffset(
            link: _composingLink,
            offset: Offset(0, 16),
            leaderAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            showWhenUnlinked: false,
            child: UserSelectionPopover(
              editor: _editor,
              userTagPlugin: _userTagPlugin,
              editorFocusNode: _editorFocusNode,
            ),
          ),
      ],
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      document: _document,
      composer: _composer,
      focusNode: _editorFocusNode,
      stylesheet: defaultStylesheet.copyWith(
        inlineTextStyler: (attributions, existingStyle) {
          TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

          if (attributions.contains(userTagComposingAttribution)) {
            style = style.copyWith(
              color: Colors.blue,
            );
          }

          if (attributions.whereType<UserTagAttribution>().isNotEmpty) {
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
          selector: (a) => a == userTagComposingAttribution,
          builder: (context, attribution) {
            return Leader(
              link: _composingLink,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                ),
              ),
            );
          },
        ),
        DefaultCaretOverlayBuilder(
          CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
      plugins: {
        _userTagPlugin,
      },
    );
  }

  Widget _buildTagList() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _users.isNotEmpty
            ? SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tag in _users) //
                      Chip(label: Text(tag)),
                  ],
                ),
              )
            : Text(
                "NO USERS",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
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
  final UserTagPlugin userTagPlugin;
  final FocusNode editorFocusNode;

  @override
  State<UserSelectionPopover> createState() => _UserSelectionPopoverState();
}

class _UserSelectionPopoverState extends State<UserSelectionPopover> {
  final _userCandidates = <String>[
    "miguel",
    "matt",
    "john",
    "sally",
    "bob",
    "jane",
    "kelly",
  ];
  final _matchingUsers = <String>[];

  bool _isLoadingMatches = false;

  @override
  void initState() {
    super.initState();

    widget.userTagPlugin.userTagIndex.composingUserTag.addListener(_onComposingTokenChange);

    _onComposingTokenChange();
  }

  @override
  void didUpdateWidget(UserSelectionPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.userTagPlugin != oldWidget.userTagPlugin) {
      oldWidget.userTagPlugin.userTagIndex.composingUserTag.removeListener(_onComposingTokenChange);
      widget.userTagPlugin.userTagIndex.composingUserTag.addListener(_onComposingTokenChange);
    }
  }

  @override
  void dispose() {
    widget.userTagPlugin.userTagIndex.composingUserTag.removeListener(_onComposingTokenChange);

    super.dispose();
  }

  Future<void> _onComposingTokenChange() async {
    final composingTag = widget.userTagPlugin.userTagIndex.composingUserTag.value?.token;
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

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) {
      return;
    }
    if (composingTag != widget.userTagPlugin.userTagIndex.composingUserTag.value?.token) {
      // The user changed the token. Our search results are invalid. Fizzle.
      return;
    }

    // Filter the user list based on the composing token.
    setState(() {
      _isLoadingMatches = false;
      _selectMatchingUsers(composingTag);
    });
  }

  void _selectMatchingUsers(String composingTag) {
    _matchingUsers
      ..clear()
      ..addAll(_userCandidates.where((user) => user.toLowerCase().contains(composingTag.toLowerCase())));
  }

  void _onUserSelected(Object name) {
    widget.editor.execute([
      FillInComposingUserTagRequest(name as String, defaultUserTagRule),
    ]);
  }

  void _cancelTag() {
    widget.editor.execute([
      CancelComposingUserTagRequest(defaultUserTagRule),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopoverList(
      editorFocusNode: widget.editorFocusNode,
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
