import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';

/// Displays a task + chat UI.
///
/// The content area is confined to a vertically oriented layout,
/// similar to a "task pane" on the right side of a task app. In
/// that content area is a task definition at the top, followed by
/// some messages, and then capped off by a message input `TextField`.
///
/// The message input field is always docked to the bottom of the display area.
///
/// When the content + messages are shorter than the viewport, the messages
/// are docked to the bottom of the viewport.
///
/// When the content + messages are taller than the viewport, the messages are
/// placed directly below the content, like a `Column`.
///
/// This was an exercise to determine if a `SuperEditor` could be combined with
/// a conditionally docked widget without relying on `Sliver`s. The solution in
/// this demo is a custom `RenderBox` that implements the desired layout behavior.
class TaskAndChatWithRenderObjectDemo extends StatefulWidget {
  @override
  _TaskAndChatWithRenderObjectDemoState createState() => _TaskAndChatWithRenderObjectDemoState();
}

class _TaskAndChatWithRenderObjectDemoState extends State<TaskAndChatWithRenderObjectDemo> {
  final _scrollViewportKey = GlobalKey();

  late DocumentEditor _editor;

  @override
  void initState() {
    super.initState();

    _editor = DocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1234',
            text: AttributedText(
                text:
                    'Notice that when this document is short enough, the messages are pushed to the bottom of the viewport.\n\nTry adding more content to see things scroll.'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: _scrollViewportKey,
              child: Builder(builder: (context) {
                final viewportBox = _scrollViewportKey.currentContext?.findRenderObject();
                if (viewportBox == null) {
                  // We don't know the size of the viewport yet. Return an empty box
                  // and schedule another frame to reflow our layout based on the
                  // viewport size.
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    if (mounted) {
                      setState(() {});
                    }
                  });

                  return const SizedBox();
                }

                final viewportSize = (viewportBox as RenderBox).size;
                print('viewportSize: $viewportSize');

                return ColumnWithBottomPin(
                  viewportHeight: viewportSize.height,
                  child: _buildHeaderAndDocument(),
                  pinnedToBottom: _buildMessages(),
                );
              }),
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  // Builds the demo display with the [child] displayed in the center
  // at proportions that mimic a task area with a chat section beneath it.
  Widget _buildScaffold({
    required Widget child,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 5),
                blurRadius: 5,
                color: Colors.black.withOpacity(0.4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeaderAndDocument() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        children: [
          _buildTaskHeader(),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: SuperEditor(editor: _editor),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Task and chat scrolling',
          style: TextStyle(
            color: Color(0xFF444444),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(
              Icons.star,
              color: Color(0xFFDDDDDD),
              size: 14,
            ),
            SizedBox(width: 8),
            Icon(
              Icons.save,
              color: Color(0xFFDDDDDD),
              size: 14,
            ),
            SizedBox(width: 8),
            Icon(
              Icons.group,
              color: Color(0xFFDDDDDD),
              size: 14,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildMessages() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEEEEE),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'This is the start of your conversation',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Yesterday at 23:49',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          _buildMessage('Message input is mounted to bottom.'),
          const SizedBox(height: 16),
          _buildMessage('Messages are pushed down when space is available.'),
          const SizedBox(height: 16),
          _buildMessage('When the task content is longer, the messages are pushed down.'),
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            color: Colors.lightBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(2),
            )),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.grey.shade300,
      child: TextField(
        style: const TextStyle(
          fontSize: 14,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: "what's up?",
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Vertical layout that displays [child] above [pinnedToBottom], similar
/// to a `Column`.
///
/// `ColumnWithBottomPin` expects to be placed within a scrollable
/// viewport whose height is [viewportHeight].
///
/// When [child] + [pinnedToBottom] are shorter than [viewportHeight], the
/// [pinnedToBottom] widget is positioned so that it's bottom edge is
/// [viewportHeight] from the top of this layout. This effectively "docks"
/// the [pinnedToBottom] widget at the bottom of the available space.
///
/// When [child] + [pinnedToBottom] are taller than [viewportHeight], the
/// two widgets are stacked vertically, exactly like a `Column`.
class ColumnWithBottomPin extends MultiChildRenderObjectWidget {
  ColumnWithBottomPin({
    Key? key,
    required this.viewportHeight,
    required this.child,
    this.pinnedToBottom,
  }) : super(key: key, children: [
          child,
          if (pinnedToBottom != null) pinnedToBottom,
        ]);

  final double viewportHeight;
  final Widget child;
  final Widget? pinnedToBottom;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderColumnWithBottomPin(
      viewportHeight: viewportHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderColumnWithBottomPin renderObject) {
    renderObject.viewportHeight = viewportHeight;
  }
}

/// Renders a vertical layout with two children where the 2nd child is
/// pinned to the bottom of the available `viewportHeight`, if the two
/// children don't require the full `viewportHeight`.
///
/// See [ColumnWithBottomPin], which is the `Widget` associated with
/// `RenderColumnWithBottomPin`.
class RenderColumnWithBottomPin extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderColumnWithBottomPin({
    required double viewportHeight,
    List<RenderBox>? children,
  }) : _viewportHeight = viewportHeight {
    addAll(children);
  }

  double _viewportHeight;
  double get viewportHeight => _viewportHeight;
  set viewportHeight(double newValue) {
    if (newValue != _viewportHeight) {
      _viewportHeight = newValue;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) child.parentData = MultiChildLayoutParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final mainChildWidth = getChildrenAsList().first.computeMinIntrinsicWidth(height);
    final pinToBottomWidth = getChildrenAsList().last.computeMinIntrinsicWidth(height);

    return mainChildWidth.isFinite || pinToBottomWidth.isFinite ? min(mainChildWidth, pinToBottomWidth) : 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final mainChildWidth = getChildrenAsList().first.computeMaxIntrinsicWidth(height);
    final pinToBottomWidth = getChildrenAsList().last.computeMaxIntrinsicWidth(height);

    if (mainChildWidth.isFinite && pinToBottomWidth.isFinite) {
      return max(mainChildWidth, pinToBottomWidth);
    } else if (mainChildWidth.isFinite) {
      return mainChildWidth;
    } else if (pinToBottomWidth.isFinite) {
      return pinToBottomWidth;
    } else {
      return 0.0;
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final mainChildHeight = getChildrenAsList().first.computeMinIntrinsicHeight(width);
    final pinToBottomHeight = getChildrenAsList().last.computeMinIntrinsicHeight(width);

    return mainChildHeight + pinToBottomHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final mainChildHeight = getChildrenAsList().first.computeMaxIntrinsicHeight(width);
    final pinToBottomHeight = getChildrenAsList().last.computeMaxIntrinsicHeight(width);

    return mainChildHeight + pinToBottomHeight;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final mainChildSize = getChildrenAsList().first.computeDryLayout(constraints);
    final pinToBottomSize = getChildrenAsList().last.computeDryLayout(constraints);

    return Size(
      max(mainChildSize.width, pinToBottomSize.width),
      mainChildSize.height + pinToBottomSize.height,
    );
  }

  @override
  void performLayout() {
    final mainChild = getChildrenAsList().first;
    final pinnedToBottom = getChildrenAsList().last;

    // Measure the bottom widget first so that we can apply a min-height
    // to the content widget based on the remaining space.
    pinnedToBottom.layout(constraints, parentUsesSize: true);

    // Determine the minimum height for the content based on the vertical space
    // that the pinnedToBottom widget DIDN'T take up.
    final contentMinHeight = max(viewportHeight - pinnedToBottom.size.height, 0.0);

    // Layout the content widget, forcing it to be at least as tall as any vertical
    // space that the pinnedToBottom widget didn't take up.
    mainChild.layout(constraints.enforce(BoxConstraints(minHeight: contentMinHeight)), parentUsesSize: true);

    // The content widget is always positioned at the top left corner.
    (mainChild.parentData as MultiChildLayoutParentData).offset = Offset.zero;

    // The pinnedToBottom widget is either placed at the bottom of the viewport
    // height, or it's placed immediately below the content.
    final pinnedToBottomY = pinnedToBottom.size.height + mainChild.size.height <= viewportHeight
        ? viewportHeight - pinnedToBottom.size.height
        : mainChild.size.height;
    (pinnedToBottom.parentData as MultiChildLayoutParentData).offset = Offset(0, pinnedToBottomY);

    // Our height is either the same as the viewportHeight, if the content is
    // short enough, or it's the height of the content + pinnedToBottom widgets.
    size = Size(
      constraints.maxWidth,
      max(viewportHeight, mainChild.size.height + pinnedToBottom.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
