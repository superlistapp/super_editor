import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

/// A popover that displays a list, and responds to key presses to navigate
/// and select an item from the list.
class PopoverList extends StatefulWidget {
  const PopoverList({
    super.key,
    required this.editorFocusNode,
    required this.leaderLink,
    required this.listItems,
    this.isLoading = false,
    required this.onListItemSelected,
    required this.onCancelRequested,
  });

  /// [FocusNode] attached to the editor, which is expected to be an ancestor
  /// of this widget.
  final FocusNode editorFocusNode;

  /// Link to the widget that this popover follows.
  final LeaderLink leaderLink;

  /// The items displayed in this popover list.
  final List<PopoverListItem> listItems;

  /// Whether the data source is currently loading results.
  ///
  /// This popover shows an indeterminate loading indicator when [isLoading]
  /// is `true`.
  final bool isLoading;

  /// Callback that's executed when the user selects a highlighted list item,
  /// e.g., by pressing ENTER.
  final void Function(Object id) onListItemSelected;

  /// Callback that's executed when the user indicates the desire to cancel
  /// interaction, e.g., by pressing ESCAPE.
  final VoidCallback onCancelRequested;

  @override
  State<PopoverList> createState() => _PopoverListState();
}

class _PopoverListState extends State<PopoverList> {
  late final FocusNode _focusNode;

  final _listKey = GlobalKey<ScrollableState>();
  late final ScrollController _scrollController;
  int _selectedValueIndex = 0;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // Wait until next frame to request focus, so that the parent relationship
      // can be established between our focus node and the editor focus node.
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(PopoverList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.listItems.length != oldWidget.listItems.length) {
      // Make sure that the user's selection index remains in bound, even when
      // the list items are switched out.
      _selectedValueIndex = min(_selectedValueIndex, widget.listItems.length - 1);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final reservedKeys = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.escape,
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

    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        if (_selectedValueIndex > 0) {
          setState(() {
            // TODO: auto-scroll to new position
            _selectedValueIndex -= 1;
          });
        }
      case LogicalKeyboardKey.arrowDown:
        if (_selectedValueIndex < widget.listItems.length - 1) {
          setState(() {
            // TODO: auto-scroll to new position
            _selectedValueIndex += 1;
          });
        }
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        widget.onListItemSelected(widget.listItems[_selectedValueIndex].id);
      case LogicalKeyboardKey.escape:
        widget.onCancelRequested();
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorPopover(
      popoverFocusNode: _focusNode,
      editorFocusNode: widget.editorFocusNode,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTap: () => !_focusNode.hasPrimaryFocus ? _focusNode.requestFocus() : null,
        child: ListenableBuilder(
          listenable: _focusNode,
          builder: (context, child) {
            return CupertinoPopoverMenu(
              focalPoint: LeaderMenuFocalPoint(link: widget.leaderLink),
              child: SizedBox(
                width: 200,
                height: 125,
                child: _buildContent(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.listItems.isNotEmpty ? _buildList() : _buildEmptyDisplay();
  }

  Widget _buildList() {
    return SingleChildScrollView(
      key: _listKey,
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (int i = 0; i < widget.listItems.length; i += 1) ...[
            ColoredBox(
              color: i == _selectedValueIndex && _focusNode.hasPrimaryFocus
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
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
                      widget.listItems[i].label,
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < widget.listItems.length - 1) //
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.2),
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
          "NO ACTIONS",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class PopoverListItem {
  const PopoverListItem({
    required this.id,
    required this.label,
  });

  final Object id;
  final String label;
}
