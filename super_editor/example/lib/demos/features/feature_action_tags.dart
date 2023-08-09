import 'package:example/demos/features/feature_demo_scaffold.dart';
import 'package:example/demos/features/popover_list.dart';
import 'package:flutter/material.dart' hide ListenableBuilder;
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

class ActionTagsFeatureDemo extends StatefulWidget {
  const ActionTagsFeatureDemo({super.key});

  @override
  State<ActionTagsFeatureDemo> createState() => _ActionTagsFeatureDemoState();
}

class _ActionTagsFeatureDemoState extends State<ActionTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final ActionTagsPlugin _actionTagPlugin;

  late final FocusNode _editorFocusNode;

  final _actions = <String>[];

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
        (request) => request is ConvertSelectedTextNodeRequest //
            ? ConvertSelectedTextNodeCommand(request.newType)
            : null,
        ...defaultRequestHandlers,
      ],
      listeners: [
        FunctionalEditListener(_onEdit),
      ],
    );

    _actionTagPlugin = ActionTagsPlugin();

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

    _updateActionTagList();
  }

  void _updateActionTagList() {
    print("_updateActionTagList()");
    setState(() {
      _actions.clear();

      for (final node in _document.nodes) {
        if (node is! TextNode) {
          continue;
        }

        final actionSpans = node.text.getAttributionSpansInRange(
          attributionFilter: (a) => a == actionTagComposingAttribution,
          range: SpanRange(start: 0, end: node.text.text.length - 1),
        );

        for (final actionSpan in actionSpans) {
          _actions.add(node.text.text.substring(actionSpan.start, actionSpan.end + 1));
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
        if (_actionTagPlugin.composingActionTag.value != null)
          Follower.withOffset(
            link: _composingLink,
            offset: Offset(0, 16),
            leaderAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            showWhenUnlinked: false,
            child: _ActionTagsListPopover(
              editor: _editor,
              actionTagPlugin: _actionTagPlugin,
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
      componentBuilders: [
        TaskComponentBuilder(_editor),
        ...defaultComponentBuilders,
      ],
      stylesheet: defaultStylesheet.copyWith(
        inlineTextStyler: (attributions, existingStyle) {
          TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

          if (attributions.contains(actionTagComposingAttribution)) {
            style = style.copyWith(
              color: Colors.blue,
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
          selector: (a) => a == actionTagComposingAttribution,
          builder: (BuildContext context, Attribution attribution) {
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
          caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
      plugins: {
        _actionTagPlugin,
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
        child: _actions.isNotEmpty
            ? SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tag in _actions) //
                      Chip(label: Text(tag)),
                  ],
                ),
              )
            : Text(
                "NOT COMPOSING",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

final _composingLink = LeaderLink();

class _ActionTagsListPopover extends StatefulWidget {
  const _ActionTagsListPopover({
    required this.editor,
    required this.actionTagPlugin,
    required this.editorFocusNode,
  });

  final Editor editor;
  final ActionTagsPlugin actionTagPlugin;
  final FocusNode editorFocusNode;

  @override
  State<_ActionTagsListPopover> createState() => _ActionTagsListPopoverState();
}

class _ActionTagsListPopoverState extends State<_ActionTagsListPopover> {
  static const _actionCandidates = <_TextNodeConversion>[
    _TextNodeConversion("Header 1", TextNodeType.header1),
    _TextNodeConversion("Header 2", TextNodeType.header2),
    _TextNodeConversion("Header 3", TextNodeType.header3),
    _TextNodeConversion("Ordered List Item", TextNodeType.orderedListItem),
    _TextNodeConversion("Unordered List Item", TextNodeType.unorderedListItem),
    _TextNodeConversion("Task", TextNodeType.task),
    _TextNodeConversion("Paragraph ", TextNodeType.paragraph),
  ];
  final _matchingActions = <_TextNodeConversion>[];

  @override
  void initState() {
    super.initState();

    widget.actionTagPlugin.composingActionTag.addListener(_onComposingTokenChange);

    final initialComposingTag = widget.actionTagPlugin.composingActionTag.value?.tag.token;
    if (initialComposingTag != null) {
      _selectMatchingActions(initialComposingTag);
    }
  }

  @override
  void didUpdateWidget(_ActionTagsListPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.actionTagPlugin != oldWidget.actionTagPlugin) {
      oldWidget.actionTagPlugin.composingActionTag.removeListener(_onComposingTokenChange);
      widget.actionTagPlugin.composingActionTag.addListener(_onComposingTokenChange);
    }
  }

  @override
  void dispose() {
    widget.actionTagPlugin.composingActionTag.removeListener(_onComposingTokenChange);

    super.dispose();
  }

  Future<void> _onComposingTokenChange() async {
    final composingTag = widget.actionTagPlugin.composingActionTag.value?.tag.token;
    if (composingTag == null) {
      // The user isn't composing a tag.
      setState(() {
        _matchingActions.clear();
      });
      return;
    }

    // Filter the user list based on the composing token.
    setState(() {
      _selectMatchingActions(composingTag);
    });
  }

  void _selectMatchingActions(String composingTag) {
    _matchingActions
      ..clear()
      ..addAll(_actionCandidates
          .where((availableAction) => availableAction.name.toLowerCase().contains(composingTag.toLowerCase())));
  }

  void _onItemSelected(Object type) {
    widget.editor.execute([
      SubmitComposingActionTagRequest(),
      ConvertSelectedTextNodeRequest(type as TextNodeType),
    ]);
  }

  void _cancelTag() {
    widget.editor.execute([
      CancelComposingActionTagRequest(defaultActionTagRule),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopoverList(
      editorFocusNode: widget.editorFocusNode,
      leaderLink: _composingLink,
      listItems: _matchingActions
          .map(
            (action) => PopoverListItem(id: action.type, label: action.name),
          )
          .toList(),
      onListItemSelected: _onItemSelected,
      onCancelRequested: _cancelTag,
    );
  }
}

class ConvertSelectedTextNodeRequest implements EditRequest {
  ConvertSelectedTextNodeRequest(this.newType);

  final TextNodeType newType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvertSelectedTextNodeRequest && runtimeType == other.runtimeType && newType == other.newType;

  @override
  int get hashCode => newType.hashCode;
}

class ConvertSelectedTextNodeCommand implements EditCommand {
  ConvertSelectedTextNodeCommand(this.newType);

  final TextNodeType newType;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);

    if (composer.selection == null) {
      // There's no selected node to convert.
      return;
    }

    final extentPosition = composer.selection!.extent.nodePosition;
    if (extentPosition is! TextNodePosition) {
      // The selected node isn't a text node. We only convert text nodes.
      return;
    }

    final oldNode = document.getNodeById(composer.selection!.extent.nodeId) as TextNode;

    late final TextNode newNode;
    switch (newType) {
      case TextNodeType.header1:
        newNode = ParagraphNode(
          id: oldNode.id,
          text: oldNode.text,
          metadata: Map.from(oldNode.metadata)..["blockType"] = header1Attribution,
        );
      case TextNodeType.header2:
        newNode = ParagraphNode(
          id: oldNode.id,
          text: oldNode.text,
          metadata: Map.from(oldNode.metadata)..["blockType"] = header2Attribution,
        );
      case TextNodeType.header3:
        newNode = ParagraphNode(
          id: oldNode.id,
          text: oldNode.text,
          metadata: Map.from(oldNode.metadata)..["blockType"] = header3Attribution,
        );
      case TextNodeType.orderedListItem:
        newNode = ListItemNode(
          id: oldNode.id,
          itemType: ListItemType.ordered,
          text: oldNode.text,
        );
      case TextNodeType.unorderedListItem:
        newNode = ListItemNode(
          id: oldNode.id,
          itemType: ListItemType.unordered,
          text: oldNode.text,
        );
      case TextNodeType.task:
        newNode = TaskNode(
          id: oldNode.id,
          text: oldNode.text,
          isComplete: false,
        );
      case TextNodeType.paragraph:
        newNode = ParagraphNode(
          id: oldNode.id,
          text: oldNode.text,
          metadata: Map.from(oldNode.metadata)..["blockType"] = paragraphAttribution,
        );
    }

    document.replaceNode(oldNode: oldNode, newNode: newNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(newNode.id),
      ),
    ]);
  }
}

class _TextNodeConversion {
  const _TextNodeConversion(this.name, this.type);

  final String name;
  final TextNodeType type;
}

enum TextNodeType {
  header1,
  header2,
  header3,
  orderedListItem,
  unorderedListItem,
  task,
  paragraph,
}
