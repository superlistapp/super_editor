import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';

/// An object that knows how to group nodes in a document layout.
///
/// A [GroupBuilder] is used to group nodes and create a sub-tree
/// containing all the grouped nodes.
///
/// Each group has a header (the first node in the group) and one or more
/// child nodes.
///
/// This object must not hold any internal state between calls, because creating
/// a group can be recursive. For example, a [GroupBuilder] that groups
/// content below a header can start a group when it encounters a
/// level one header, another one when it encounters a level two header,
/// and then resume the level one header.
abstract class GroupBuilder {
  const GroupBuilder();

  /// Whether the component at [nodeIndex] can start a new group.
  ///
  /// If this method returns `true`, a new group is created even
  /// if [canAddToGroup] returns `false` for the node immediately
  /// before the node at [nodeIndex].
  bool canStartGroup({
    required int nodeIndex,
    required List<SingleColumnLayoutComponentViewModel> viewModels,
  });

  /// Whether the component at [nodeIndex] can be added to the group
  /// that contains [groupedComponents].
  ///
  /// This method does not modify [groupedComponents].
  bool canAddToGroup({
    required int nodeIndex,
    required List<SingleColumnLayoutComponentViewModel> allViewModels,
    required List<SingleColumnLayoutComponentViewModel> groupedComponents,
  });

  /// Builds a widget that represents the group.
  ///
  /// The [headerContentLink] can used to position widgets near to the
  /// header widget. Since document components can take all available width in
  /// the layout, the [headerContentLink] is necessary to know where the
  /// actual content starts. For example, text components usually have padding
  /// around then. The [headerContentLink] must be attached to the widget inside
  /// the padding.
  ///
  /// The [onCollapsedChanged] callback is called when the group is collapsed
  /// or expanded.
  ///
  /// The [children] list contains all widgets inside the group, including
  /// the header widget.
  Widget build(
    BuildContext context, {
    required LeaderLink headerContentLink,
    required GroupItem groupInfo,
    required OnCollapseChanged onCollapsedChanged,
    required List<Widget> children,
  });
}

/// A [GroupBuilder] that groups content below a header.
///
/// This builder creates a group when it encounters a header node
/// that contains all nodes between the start of the group and
/// another header with smaller or equal level.
///
/// Builds a toggleable [Widget] that allows collapsing and expanding
/// the group when tapping a button near the header.
class HeaderGroupBuilder implements GroupBuilder {
  HeaderGroupBuilder({
    required this.editor,
    this.buttonBuilder,
    this.guidelineBuilder,
    this.animateExpansion = true,
    this.animationDuration = _defaultAnimationDuration,
    this.animationCurve = Curves.easeInOut,
    this.maxChildren,
  });

  final Editor editor;

  /// Builder for the button that toggles the group.
  ///
  /// No animations are applied to the button when [buttonBuilder] is provided,
  /// i.e, apps that provide a custom button builder are responsible for its
  /// animations.
  final ToggleButtonBuilder? buttonBuilder;

  /// Builder for the guideline that is displayed below the button.
  final WidgetBuilder? guidelineBuilder;

  /// Whether the expansion and collapse of the group should be animated.
  ///
  /// When `true`, the group will animate its expansion and collapse. When `false`,
  /// the group will expand and collapse instantly.
  final bool animateExpansion;

  /// Duration of the animation that expands and collapses the group.
  ///
  /// Has no effect if [animateExpansion] is `false`.
  final Duration animationDuration;

  /// Curve of the animation that expands and collapses the group.
  ///
  /// Defaults to [Curves.easeInOut].
  final Curve animationCurve;

  /// Maximum number of children that can be grouped together.
  ///
  /// When a group reaches this limit, subsequent children will remain ungrouped.
  final int? maxChildren;

  @override
  bool canStartGroup({
    required int nodeIndex,
    required List<SingleColumnLayoutComponentViewModel> viewModels,
  }) {
    final currentViewModel = viewModels[nodeIndex];
    if (currentViewModel is! ParagraphComponentViewModel) {
      // Only paragraphs can have the header attribution.
      return false;
    }

    if (_getHeaderLevel(currentViewModel.blockType) == null) {
      // This paragraph is not a header.
      return false;
    }

    if (nodeIndex == viewModels.length - 1) {
      // This is the last component in the layout. Only start a group
      // if there is at least one child that can be grouped.
      return false;
    }

    return true;
  }

  @override
  bool canAddToGroup({
    required int nodeIndex,
    required List<SingleColumnLayoutComponentViewModel> allViewModels,
    required List<SingleColumnLayoutComponentViewModel> groupedComponents,
  }) {
    // +1 because the first component is the header.
    if (maxChildren != null && groupedComponents.length >= maxChildren! + 1) {
      return false;
    }

    final header = groupedComponents.first;
    final headerLevel = _getHeaderLevel((header as ParagraphComponentViewModel).blockType)!;

    final childViewModel = allViewModels[nodeIndex];
    if (childViewModel is ParagraphComponentViewModel) {
      final childHeaderLevel = _getHeaderLevel(childViewModel.blockType);
      if (childHeaderLevel != null && childHeaderLevel <= headerLevel) {
        return false;
      }
    }

    return true;
  }

  int? _getHeaderLevel(Attribution? blockType) => switch (blockType) {
        header1Attribution => 1,
        header2Attribution => 2,
        header3Attribution => 3,
        header4Attribution => 4,
        header5Attribution => 5,
        header6Attribution => 6,
        _ => null,
      };

  @override
  Widget build(
    BuildContext context, {
    required LeaderLink headerContentLink,
    required GroupItem groupInfo,
    required List<Widget> children,
    required OnCollapseChanged onCollapsedChanged,
  }) {
    return ToggleableGroup(
      editor: editor,
      groupInfo: groupInfo,
      headerContentLink: headerContentLink,
      onCollapsed: onCollapsedChanged,
      buttonBuilder: buttonBuilder ?? defaultToggleButtonBuilder,
      guidelineBuilder: guidelineBuilder ?? defaultGuidelineBuilder,
      animateExpansion: animateExpansion,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      header: children.first,
      children: children.length > 1 //
          ? children.skip(1).toList()
          : [],
    );
  }
}

/// A [GroupBuilder] that groups list items.
///
/// This builder creates a group when it encounters a list item node
/// that contains all list items between the start of the group and
/// another list item with smaller or equal level.
///
/// Builds a toggleable [Widget] that allows collapsing and expanding
/// the group when tapping a button near the first list item.
class ListItemGroupBuilder implements GroupBuilder {
  ListItemGroupBuilder({
    required this.editor,
    this.buttonBuilder,
    this.guidelineBuilder,
    this.animateExpansion = true,
    this.animationDuration = _defaultAnimationDuration,
    this.animationCurve = Curves.easeInOut,
    this.maxChildren,
  });

  final Editor editor;

  /// Builder for the button that toggles the group.
  ///
  /// No animations are applied to the button when [buttonBuilder] is provided,
  /// i.e, apps that provide a custom button builder are responsible for its
  /// animations.
  final ToggleButtonBuilder? buttonBuilder;

  /// Builder for the guideline that is displayed below the button.
  final WidgetBuilder? guidelineBuilder;

  /// Whether the expansion and collapse of the group should be animated.
  ///
  /// When `true`, the group will animate its expansion and collapse. When `false`,
  /// the group will expand and collapse instantly.
  final bool animateExpansion;

  /// Duration of the animation that expands and collapses the group.
  ///
  /// Has no effect if [animateExpansion] is `false`.
  final Duration animationDuration;

  /// Curve of the animation that expands and collapses the group.
  ///
  /// Defaults to [Curves.easeInOut].
  final Curve animationCurve;

  /// Maximum number of children that can be grouped together.
  ///
  /// When a group reaches this limit, subsequent children will remain ungrouped.
  final int? maxChildren;

  @override
  bool canStartGroup({
    required int nodeIndex,
    required List<SingleColumnLayoutComponentViewModel> viewModels,
  }) {
    if (viewModels[nodeIndex] is! ListItemComponentViewModel) {
      return false;
    }

    if (nodeIndex == viewModels.length - 1) {
      // This is the last component in the layout. Only start a group
      // if there is at least one child that can be grouped.
      return false;
    }

    if (!canAddToGroup(
      nodeIndex: nodeIndex + 1,
      allViewModels: viewModels,
      groupedComponents: [viewModels[nodeIndex]],
    )) {
      // This node can start a group, but the next node cannot be added to it.
      // For example, the current node is a unordered list item and the node
      // below it is an ordered list item.
      return false;
    }

    return true;
  }

  @override
  bool canAddToGroup(
      {required int nodeIndex,
      required List<SingleColumnLayoutComponentViewModel> allViewModels,
      required List<SingleColumnLayoutComponentViewModel> groupedComponents}) {
    // +1 because the first component is the header.
    if (maxChildren != null && groupedComponents.length >= maxChildren! + 1) {
      return false;
    }

    final childViewModel = allViewModels[nodeIndex];
    if (childViewModel is! ListItemComponentViewModel) {
      return false;
    }

    final header = groupedComponents.first;
    if (header.runtimeType != childViewModel.runtimeType) {
      // Don't group ordered lists with unordered lists.
      return false;
    }

    final headerIndentLevel = (header as ListItemComponentViewModel).indent;
    final childIndentLevel = (childViewModel).indent;

    return childIndentLevel > headerIndentLevel;
  }

  @override
  Widget build(BuildContext context,
      {required LeaderLink headerContentLink,
      required GroupItem groupInfo,
      required OnCollapseChanged onCollapsedChanged,
      required List<Widget> children}) {
    return ToggleableGroup(
      editor: editor,
      groupInfo: groupInfo,
      headerContentLink: headerContentLink,
      onCollapsed: onCollapsedChanged,
      buttonBuilder: buttonBuilder ?? defaultToggleButtonBuilder,
      guidelineBuilder: guidelineBuilder ?? defaultGuidelineBuilder,
      animateExpansion: animateExpansion,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      header: children.first,
      children: children.length > 1 //
          ? children.skip(1).toList()
          : [],
    );
  }
}

/// A [Widget] that groups other widgets below a [header].
///
/// Displays a button and guideline near the content of the [header] widget,
/// that is positioned using the [headerContentLink].
///
/// The group can be collapsed and expanded by tapping a button near the
/// [header]. When collapsing, the [header] is still visible and the [children]
/// are hidden.
///
/// Calls [onCollapsed] when the group is collapsed or expanded.
///
/// When the group is collapsed, the selection is changed to avoid that the base
/// or extent of the selection is inside the collapsed group.
///
/// Use [buttonBuilder] to customize the button that toggles the group. By default,
/// displays an arrow icon that rotates when the group is collapsed or expanded.
///
/// Use [guidelineBuilder] to customize the guideline that is displayed below the
/// button. By default, displays a vertical divider.
class ToggleableGroup extends StatefulWidget {
  const ToggleableGroup({
    super.key,
    required this.headerContentLink,
    required this.editor,
    required this.groupInfo,
    required this.onCollapsed,
    this.buttonBuilder = defaultToggleButtonBuilder,
    this.guidelineBuilder = defaultGuidelineBuilder,
    this.animateExpansion = true,
    this.animationDuration = _defaultAnimationDuration,
    this.animationCurve = Curves.easeInOut,
    required this.header,
    required this.children,
  });

  final LeaderLink headerContentLink;
  final Editor editor;
  final GroupItem groupInfo;
  final OnCollapseChanged onCollapsed;
  final ToggleButtonBuilder buttonBuilder;
  final WidgetBuilder guidelineBuilder;
  final bool animateExpansion;
  final Duration animationDuration;
  final Curve animationCurve;

  final Widget header;
  final List<Widget> children;

  @override
  State<ToggleableGroup> createState() => ToggleableGroupState();
}

@visibleForTesting
class ToggleableGroupState extends State<ToggleableGroup> with SingleTickerProviderStateMixin {
  /// Animates the expansion and collapse of the group.
  late final AnimationController _animationController;
  late final Animation _animation;

  /// Whether the toggle button and guideline should be visible.
  final _shouldDisplayButton = ValueNotifier(false);

  /// Whether the group is currently expanded, i.e, showing all children.
  bool _isExpanded = true;
  bool get isExpanded => _isExpanded;

  final _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      value: 1.0,
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    );
  }

  @override
  void didUpdateWidget(ToggleableGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }

    if (widget.animationCurve != oldWidget.animationCurve) {
      _animation = CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Toggles the group between expanded and collapsed.
  void _toggle() {
    if (_isExpanded) {
      //_animationController.reset();
      if (widget.animateExpansion) {
        _animationController.reverse();
      } else {
        _animationController.value = 0.0;
      }
      _adjustSelectionOnCollapsing();
    } else {
      if (widget.animateExpansion) {
        _animationController
          ..reset()
          ..forward();
      } else {
        _animationController.value = 1.0;
      }
    }

    setState(() {
      _isExpanded = !_isExpanded;
    });

    widget.onCollapsed(!_isExpanded);
  }

  void _onMouseEnter() {
    _shouldDisplayButton.value = true;
  }

  void _onMouseExit() {
    if (!_isExpanded) {
      return;
    }
    _shouldDisplayButton.value = false;
  }

  /// Adjusts the selection so that the base and extent are not inside the group.
  void _adjustSelectionOnCollapsing() {
    final selection = widget.editor.composer.selection;
    if (selection == null) {
      // There is no selection to adjust.
      return;
    }

    final headerNodeId = widget.groupInfo.rootNodeId;
    final headerNode = widget.editor.document.getNodeById(headerNodeId)!;

    final isSelectionNormalized = selection.isNormalized(widget.editor.document);

    final isBaseInsideGroup = selection.base.nodeId != headerNodeId && widget.groupInfo.contains(selection.base.nodeId);
    final isExtentInsideGroup =
        selection.extent.nodeId != headerNodeId && widget.groupInfo.contains(selection.extent.nodeId);

    if (isBaseInsideGroup && isExtentInsideGroup) {
      // The whole selection is inside the group. Move the selection
      // to the end of the header node.
      widget.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: headerNodeId,
              nodePosition: headerNode.endPosition,
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        )
      ]);

      return;
    }

    if (isBaseInsideGroup) {
      if (isSelectionNormalized) {
        // The selection starts inside this group and ends in a downstream node.
        // Move the selection base to the beginning of the first node below the group.
        final downstreamNodeIndex = _lastNodeIndex(widget.groupInfo) + 1;
        final downstreamNode = widget.editor.document.getNodeAt(downstreamNodeIndex)!;
        widget.editor.execute([
          ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: downstreamNode.id,
                nodePosition: downstreamNode.beginningPosition,
              ),
              extent: selection.extent,
            ),
            SelectionChangeType.alteredContent,
            SelectionReason.userInteraction,
          )
        ]);
        return;
      }

      // The selection starts inside this group and ends in an upstream node.
      // Move the selection base to the end of the header of the group.
      widget.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: headerNodeId,
              nodePosition: headerNode.endPosition,
            ),
            extent: selection.extent,
          ),
          SelectionChangeType.alteredContent,
          SelectionReason.userInteraction,
        )
      ]);

      return;
    }

    if (isExtentInsideGroup) {
      if (isSelectionNormalized) {
        // The selection starts at an upstream node end ends inside this group.
        // Move the selection extent to the end of the header node.
        widget.editor.execute([
          ChangeSelectionRequest(
            DocumentSelection(
              base: selection.base,
              extent: DocumentPosition(
                nodeId: headerNode.id,
                nodePosition: headerNode.endPosition,
              ),
            ),
            SelectionChangeType.alteredContent,
            SelectionReason.userInteraction,
          )
        ]);

        return;
      }

      // The selection starts at a downstream node end ends inside this group.
      // Move the selection extent to the beginning of the first node below the group.
      final downstreamNodeIndex = _lastNodeIndex(widget.groupInfo) + 1;
      final downstreamNode = widget.editor.document.getNodeAt(downstreamNodeIndex)!;
      widget.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection(
            base: selection.base,
            extent: DocumentPosition(
              nodeId: downstreamNode.id,
              nodePosition: downstreamNode.beginningPosition,
            ),
          ),
          SelectionChangeType.alteredContent,
          SelectionReason.userInteraction,
        )
      ]);

      return;
    }
  }

  /// The index of the last node within the group.
  ///
  /// If the last node also starts a group, returns the last index
  /// of that group.
  int _lastNodeIndex(GroupItem group) {
    final lastChild = group.children.lastOrNull;
    if (lastChild == null) {
      return widget.editor.document.getNodeIndexById(group.rootNodeId);
    }

    if (lastChild.isLeaf) {
      return widget.editor.document.getNodeIndexById(lastChild.rootNodeId);
    }

    return _lastNodeIndex(lastChild);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.header,
            _buildChildren(),
          ],
        ),
        Positioned.fill(
          child: _buildFadingFollower(
            child: _buildButtonAndGuideline(),
          ),
        ),
      ],
    );
  }

  /// Builds the children of the group.
  ///
  /// Animates its growing/shrinking when the group is expanded/collapsed.
  Widget _buildChildren() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _animation.value,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
      ),
    );
  }

  /// Builds a widget that follows the header and fades in/out
  /// when the mouse enters/exits the [child].
  Widget _buildFadingFollower({
    required Widget child,
  }) {
    return _buildFollower(
      child: ValueListenableBuilder(
        valueListenable: _shouldDisplayButton,
        builder: (context, isVisible, child) {
          return AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: widget.animationDuration,
            child: child!,
          );
        },
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.deferToChild,
          onEnter: (e) => _onMouseEnter(),
          onExit: (e) => _onMouseExit(),
          child: _buildButtonAndGuideline(),
        ),
      ),
    );
  }

  /// Builds a [child] positioned near the content of the header.
  Widget _buildFollower({
    required Widget child,
  }) {
    return Follower.withAligner(
      aligner: _ToggleButtonAligner(buttonKey: _buttonKey),
      link: widget.headerContentLink,
      child: child,
    );
  }

  Widget _buildButtonAndGuideline() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(),
        Expanded(
          child: _buildGuideline(),
        ),
      ],
    );
  }

  /// Builds the button that toggles the group.
  Widget _buildButton() {
    return KeyedSubtree(
      key: _buttonKey,
      child: widget.buttonBuilder(
        context,
        _isExpanded,
        _toggle,
      ),
    );
  }

  /// Builds the guideline that is displayed below the button.
  ///
  /// The guideline is only displayed when the group is expanded or
  /// while the collapse animation is running.
  Widget _buildGuideline() {
    return ListenableBuilder(
      listenable: _animationController,
      builder: (context, child) {
        return _isExpanded || _animationController.status == AnimationStatus.reverse
            ? widget.guidelineBuilder(context)
            : const SizedBox.shrink();
      },
    );
  }
}

/// A button that rotates an arrow icon when the group is expanded or collapsed.
Widget defaultToggleButtonBuilder(BuildContext context, bool isExpanded, VoidCallback onPressed) {
  return AnimatedRotation(
    duration: _defaultAnimationDuration,
    turns: isExpanded ? 0.25 : 0.0,
    child: SizedBox(
      height: 24,
      width: 24,
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.arrow_right),
          padding: EdgeInsets.zero,
          iconSize: 24,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

Widget defaultGuidelineBuilder(BuildContext context) {
  return const Column(
    children: [
      SizedBox(height: 2),
      Expanded(
        child: VerticalDivider(width: 4),
      ),
    ],
  );
}

/// A [FollowerAligner] that centers the button vertically with the header.
///
/// The regular aligner does not work because it uses the height of the whole
/// follower widget. Our follower contains both the button and the guideline,
/// and we want to center using only the button.
class _ToggleButtonAligner implements FollowerAligner {
  _ToggleButtonAligner({
    required this.buttonKey,
  });

  final GlobalKey buttonKey;

  @override
  FollowerAlignment align(Rect globalLeaderRect, Size followerSize) {
    final buttonBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonHeight = buttonBox?.size.height ?? 0;

    return FollowerAlignment(
      leaderAnchor: Alignment.centerLeft,
      followerAnchor: Alignment.topRight,
      followerOffset: Offset(-10, -buttonHeight / 2),
    );
  }
}

typedef OnCollapseChanged = void Function(bool isCollapsed);
typedef ToggleButtonBuilder = Widget Function(BuildContext context, bool isExpanded, VoidCallback onPressed);

/// Duration of the animation that expands and collapses the group.
const _defaultAnimationDuration = Duration(milliseconds: 300);
