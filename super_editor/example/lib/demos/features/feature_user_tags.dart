import 'dart:math';

import 'package:example/demos/features/feature_demo_scaffold.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
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
      keyboardActions: [
        ..._userTagPlugin.keyboardActions,
        ...defaultKeyboardActions,
      ],
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
          ..._darkModeStyles,
        ],
      ),
      documentOverlayBuilders: [
        _TokenBoundsOverlay(
          selector: (a) => a == userTagComposingAttribution,
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

// Makes text light, for use during dark mode styling.
final _darkModeStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 32,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
];

class _TokenBoundsOverlay implements DocumentLayerBuilder {
  const _TokenBoundsOverlay({
    required this.selector,
  });

  final AttributionBoundsSelector selector;

  @override
  Widget build(BuildContext context, SuperEditorContext editContext) {
    return _AttributionBounds(
      layout: editContext.documentLayout,
      document: editContext.document,
      selector: selector,
    );
  }
}

class _AttributionBounds extends StatefulWidget {
  const _AttributionBounds({
    Key? key,
    required this.layout,
    required this.document,
    required this.selector,
  }) : super(key: key);

  final DocumentLayout layout;
  final Document document;
  final AttributionBoundsSelector selector;

  @override
  State<_AttributionBounds> createState() => _AttributionBoundsState();
}

class _AttributionBoundsState extends State<_AttributionBounds> {
  final _bounds = <Rect>{};

  @override
  void initState() {
    super.initState();

    _findBounds();
    widget.document.addListener(_onDocumentChange);
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChange);
    super.dispose();
  }

  void _onDocumentChange(changeLog) {
    if (!mounted) {
      return;
    }

    setState(() {
      _findBounds();
    });
  }

  void _findBounds() {
    _bounds.clear();

    for (final node in widget.document.nodes) {
      if (node is! TextNode) {
        continue;
      }

      final spans = node.text.getAttributionSpansInRange(
        attributionFilter: widget.selector,
        range: SpanRange(start: 0, end: node.text.text.length - 1),
      );

      final documentRanges = spans.map(
        (span) => DocumentRange(
          start: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.start)),
          end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.end + 1)),
        ),
      );

      _bounds.addAll(documentRanges.map(
        (range) => widget.layout.getRectForSelection(range.start, range.end) ?? Rect.zero,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final bound in _bounds) //
            Positioned.fromRect(
              rect: bound,
              child: Leader(
                link: _composingLink,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

typedef AttributionBoundsSelector = bool Function(Attribution attribution);

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

  late final FocusNode _focusNode;

  final _listKey = GlobalKey<ScrollableState>();
  late final ScrollController _scrollController;
  int _selectedValueIndex = -1;

  bool _isLoadingMatches = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _scrollController = ScrollController();

    widget.userTagPlugin.userTagIndex.composingUserTag.addListener(_onComposingTokenChange);
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

    _scrollController.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  Future<void> _onComposingTokenChange() async {
    final composingTag = widget.userTagPlugin.userTagIndex.composingUserTag.value?.token;
    if (composingTag == null) {
      // The user isn't composing a tag. Therefore, this popover shouldn't
      // have focus.
      setState(() {
        _focusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        _matchingUsers.clear();
      });
      return;
    }

    // The user is composing a tag. Ensure that we have focus.
    if (!_focusNode.hasPrimaryFocus) {
      _focusNode.requestFocus();
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

      _matchingUsers
        ..clear()
        ..addAll(_userCandidates.where((user) => user.toLowerCase().contains(composingTag.toLowerCase())));

      _selectedValueIndex = min(_selectedValueIndex, _matchingUsers.length - 1);
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final reservedKeys = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
    };

    final key = event.logicalKey;
    if (!reservedKeys.contains(key)) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      // Only handle up events, so we don't run our behavior twice
      // for the same key press.
      return KeyEventResult.handled;
    }

    bool didChange = false;
    switch (key) {
      // TODO: navigate popover with arrow keys
      case LogicalKeyboardKey.arrowUp:
        if (_selectedValueIndex > 0) {
          _selectedValueIndex -= 1;
          // TODO: auto-scroll to new position
          didChange = true;
        }
      case LogicalKeyboardKey.arrowDown:
        if (_selectedValueIndex < _matchingUsers.length - 1) {
          _selectedValueIndex += 1;
          // TODO: auto-scroll to new position
          didChange = true;
        }
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _chooseUser();
    }

    if (didChange) {
      setState(() {
        // We changed something in our presentation. Rebuild.
      });
    }

    return KeyEventResult.handled;
  }

  void _chooseUser() {
    if (_selectedValueIndex < 0 || _selectedValueIndex >= _matchingUsers.length) {
      // The current selection doesn't correspond to a user in the matches list. Fizzle.
      return;
    }

    widget.editor.execute([
      FillInComposingUserTagRequest(_matchingUsers[_selectedValueIndex], defaultUserTagRule),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      parentNode: widget.editorFocusNode,
      onKeyEvent: _onKeyEvent,
      child: ListenableBuilder(
        listenable: _focusNode,
        builder: (context, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _focusNode.hasFocus ? Colors.blue : Colors.transparent),
            ),
            child: CupertinoPopoverMenu(
              focalPoint: LeaderMenuFocalPoint(link: _composingLink),
              child: SizedBox(
                width: 200,
                height: 125,
                child: _buildContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingMatches) {
      return Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _matchingUsers.isNotEmpty ? _buildUserList() : _buildEmptyDisplay();
  }

  Widget _buildUserList() {
    return SingleChildScrollView(
      key: _listKey,
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (int i = 0; i < _matchingUsers.length; i += 1) ...[
            ColoredBox(
              color: i == _selectedValueIndex ? Colors.white.withOpacity(0.05) : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_circle,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _matchingUsers[i],
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < _matchingUsers.length - 1) //
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Divider(
                  color: Colors.white.withOpacity(0.2),
                  height: 1,
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyDisplay() {
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          "NO USERS",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
