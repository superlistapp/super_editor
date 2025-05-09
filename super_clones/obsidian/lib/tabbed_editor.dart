import 'package:flutter/material.dart';
import 'package:super_editor_obsidian/window.dart';
import 'package:tab_kit/tab_kit.dart';

class TabbedEditor extends StatefulWidget {
  const TabbedEditor({
    super.key,
    required this.tabController,
  });

  final NotebookTabController tabController;

  @override
  State<TabbedEditor> createState() => _TabbedEditorState();
}

class _TabbedEditorState extends State<TabbedEditor> {
  @override
  Widget build(BuildContext context) {
    return ScreenPartial(
      partialAppBar: NotebookTabBar(
        controller: widget.tabController,
        paddingStart: 12,
        style: NotebookTabBarStyle(
          barBackground: Colors.transparent,
          tabBackground: const Color(0xFF222222),
          tabWidth: 200,
          dividerColor: Colors.white.withOpacity(0.1),
        ),
        onAddTabPressed: () {},
      ),
      content: const SizedBox(),
    );
  }
}
