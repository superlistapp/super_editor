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
/// The layout is implemented with a [CustomScrollView] and relevant `Sliver`s.
class TaskAndChatWithCustomScrollViewDemo extends StatefulWidget {
  @override
  State<TaskAndChatWithCustomScrollViewDemo> createState() => _TaskAndChatWithCustomScrollViewDemoState();
}

class _TaskAndChatWithCustomScrollViewDemoState extends State<TaskAndChatWithCustomScrollViewDemo> {
  final _scrollViewportKey = GlobalKey();

  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  @override
  void initState() {
    super.initState();

    _doc = MutableDocument(
      nodes: [
        ParagraphNode(
          id: '1234',
          text: AttributedText(
            'Notice that when this document is short enough, the messages are pushed to the bottom of the viewport.\n\nTry adding more content to see things scroll.',
          ),
        )
      ],
    );
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              key: _scrollViewportKey,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                SliverToBoxAdapter(
                  child: SuperEditor(
                    editor: _editor,
                    stylesheet: defaultStylesheet.copyWith(
                      documentPadding: const EdgeInsets.all(48),
                    ),
                  ),
                ),
                SliverStickToBottom(child: _buildMessages()),
              ],
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

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Task and chat scrolling',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
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
          ),
          SizedBox(height: 16),
        ],
      ),
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

class SliverStickToBottom extends SingleChildRenderObjectWidget {
  /// Creates a sliver that positions its child at the bottom of the screen or
  /// scrolls it off screen if there's not enough space
  const SliverStickToBottom({
    required Widget child,
    Key? key,
  }) : super(key: key, child: child);

  @override
  RenderSliverStickToBottom createRenderObject(BuildContext context) => RenderSliverStickToBottom();
}

class RenderSliverStickToBottom extends RenderSliverSingleBoxAdapter {
  /// Creates a [RenderSliver] that wraps a [RenderBox] will be aligned at the
  /// bottom or scrolled off screen
  RenderSliverStickToBottom({
    RenderBox? child,
  }) : super(child: child);

  @override
  void performLayout() {
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    double? childExtent;
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child!.size.width;
        break;
      case Axis.vertical:
        childExtent = child!.size.height;
        break;
    }
    final paintedChildSize = calculatePaintOffset(
      constraints,
      from: 0,
      to: childExtent,
    );
    final cacheExtent = calculateCacheOffset(
      constraints,
      from: 0,
      to: childExtent,
    );

    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      paintOrigin: max(0, constraints.remainingPaintExtent - childExtent),
      scrollExtent: childExtent,
      paintExtent: min(childExtent, constraints.remainingPaintExtent),
      cacheExtent: min(cacheExtent, constraints.remainingPaintExtent),
      maxPaintExtent: max(childExtent, constraints.remainingPaintExtent),
      hitTestExtent: paintedChildSize,
      hasVisualOverflow: childExtent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
    );
    setChildParentData(child!, constraints, geometry!);
  }
}
