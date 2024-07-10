import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

import 'popover_list.dart';

class UserTagsFeatureDemo extends StatefulWidget {
  const UserTagsFeatureDemo({super.key});

  @override
  State<UserTagsFeatureDemo> createState() => _UserTagsFeatureDemoState();
}

class _UserTagsFeatureDemoState extends State<UserTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final StableTagPlugin _userTagPlugin;

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

    _userTagPlugin = StableTagPlugin()
      ..tagIndex.composingStableTag.addListener(_updateUserTagList)
      ..tagIndex.addListener(_updateUserTagList);

    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();

    _userTagPlugin.tagIndex
      ..composingStableTag.removeListener(_updateUserTagList)
      ..removeListener(_updateUserTagList);

    _composer.dispose();
    _editor.dispose();
    _document.dispose();

    super.dispose();
  }

  void _updateUserTagList() {
    setState(() {
      _users.clear();

      for (final node in _document) {
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
        if (_userTagPlugin.tagIndex.composingStableTag.value != null)
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
    return IntrinsicHeight(
      child: SuperEditor(
        editor: _editor,
        focusNode: _editorFocusNode,
        stylesheet: defaultStylesheet.copyWith(
          inlineTextStyler: (attributions, existingStyle) {
            TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

            if (attributions.contains(stableTagComposingAttribution)) {
              style = style.copyWith(
                color: Colors.blue,
              );
            }

            if (attributions.whereType<CommittedStableTagAttribution>().isNotEmpty) {
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
            selector: (a) => a == stableTagComposingAttribution,
            builder: (context, attribution) {
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
          _userTagPlugin,
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
  final StableTagPlugin userTagPlugin;
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

    widget.userTagPlugin.tagIndex.composingStableTag.addListener(_onComposingTokenChange);

    _onComposingTokenChange();
  }

  @override
  void didUpdateWidget(UserSelectionPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.userTagPlugin != oldWidget.userTagPlugin) {
      oldWidget.userTagPlugin.tagIndex.composingStableTag.removeListener(_onComposingTokenChange);
      widget.userTagPlugin.tagIndex.composingStableTag.addListener(_onComposingTokenChange);
    }
  }

  @override
  void dispose() {
    widget.userTagPlugin.tagIndex.composingStableTag.removeListener(_onComposingTokenChange);

    super.dispose();
  }

  Future<void> _onComposingTokenChange() async {
    final composingTag = widget.userTagPlugin.tagIndex.composingStableTag.value?.token;
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
    if (composingTag != widget.userTagPlugin.tagIndex.composingStableTag.value?.token) {
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
      FillInComposingStableTagRequest(name as String, userTagRule),
    ]);
  }

  void _cancelTag() {
    widget.editor.execute([
      CancelComposingStableTagRequest(userTagRule),
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
