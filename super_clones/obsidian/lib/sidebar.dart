import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:super_editor_obsidian/vault_menu.dart';
import 'package:super_editor_obsidian/window.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  List<LineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final vaultDirectory = Directory("/Users/matt/Projects/blog_flutterbountyhunters_com/blog_content");

    final lineItems = <LineItem>[];
    await for (final entity in vaultDirectory.list(recursive: true)) {
      final indentLevel = entity.path
              .replaceFirst(vaultDirectory.path, "")
              .split(Platform.pathSeparator)
              .fold(0, (previousValue, element) => element.isNotEmpty ? previousValue + 1 : previousValue) -
          1;
      print("Relative path: '${entity.path.replaceFirst(vaultDirectory.path, "").split(Platform.pathSeparator)}'");

      if (entity is Directory) {
        lineItems.add(
          LineItem(
              indentLevel: indentLevel, isContainer: true, isOpen: false, name: basenameWithoutExtension(entity.path)),
        );
      } else if (entity is File) {
        lineItems.add(
          LineItem(indentLevel: indentLevel, isContainer: false, name: basenameWithoutExtension(entity.path)),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lineItems = lineItems;
    });

    // _lineItems = [
    //   LineItem(indentLevel: 0, isContainer: true, name: "drafts"),
    //   LineItem(indentLevel: 0, isContainer: true, name: "fbh-policies"),
    //   LineItem(indentLevel: 0, isContainer: true, name: "future-plans", isOpen: true),
    //   LineItem(indentLevel: 1, isContainer: true, name: "hello", isOpen: true),
    //   LineItem(indentLevel: 2, isContainer: false, name: "one", isActive: true),
    //   LineItem(indentLevel: 1, isContainer: false, name: "Build a smoother, cleaner, easier Flutter world"),
    //   LineItem(indentLevel: 1, isContainer: false, name: "Flutter in Motion Conference"),
    //   LineItem(indentLevel: 1, isContainer: false, name: "Golden all the things"),
    //   LineItem(indentLevel: 0, isContainer: true, name: "published"),
    //   LineItem(indentLevel: 0, isContainer: false, name: "Top level note"),
    // ];
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(
      appBar: const SizedBox(),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: VaultMenu(lineItems: _lineItems),
        ),
      ),
    );
  }

  Widget _buildScaffold({
    required Widget appBar,
    required Widget content,
  }) {
    return SizedBox(
      width: 360,
      child: ScreenPartial(
        partialAppBar: appBar,
        content: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(width: 1, color: Colors.white.withOpacity(0.1))),
          ),
          position: DecorationPosition.foreground,
          child: content,
        ),
      ),
    );
  }
}
