import 'package:example_docs/app_menu.dart';
import 'package:example_docs/editor.dart';
import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';

class DocsApp extends StatelessWidget {
  const DocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Docs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        backgroundColor: Color(0xFFf9fbfd),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppHeaderPane(),
            SizedBox(height: 4),
            Divider(height: 1, thickness: 1, color: Color(0xFFc4c7c5)),
            Expanded(
              child: DocsEditor(),
            ),
          ],
        ));
  }
}

/// The pane that appears at the top of the app, which includes the document title, app menu,
/// and editor toolbar.
class _AppHeaderPane extends StatelessWidget {
  const _AppHeaderPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Column(
        children: [
          _buildTitleAndMenuBar(),
          const SizedBox(height: 16),
          const _DocsEditorToolbar(),
        ],
      ),
    );
  }

  Widget _buildTitleAndMenuBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 8),
        Image.asset("assets/images/docs_logo.png"),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDocumentTitleAndActions(),
            _buildMenus(),
          ],
        )
      ],
    );
  }

  Widget _buildDocumentTitleAndActions() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            width: menuButtonHorizontalPadding), // Push title to the right to match first letter of first menu item
        Text(
          "Some Document",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(width: 24),
        Icon(Icons.star_border, size: 18, color: titleActionIconColor),
        SizedBox(width: 12),
        Icon(Icons.drive_folder_upload, size: 18, color: titleActionIconColor),
        SizedBox(width: 12),
        Icon(Icons.cloud_done_outlined, size: 18, color: titleActionIconColor),
      ],
    );
  }

  Widget _buildMenus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuButton("File"),
        _buildMenuButton("Edit"),
        _buildMenuButton("View"),
        _buildMenuButton("Insert"),
        _buildMenuButton("Format"),
        _buildMenuButton("Tools"),
        _buildMenuButton("Extensions"),
        _buildMenuButton("Help"),
      ],
    );
  }

  Widget _buildMenuButton(String label) {
    return DocsAppMenu(
      label: label,
      items: const [
        // TODO: create options for each menu that matches Google Docs
        DocsAppMenuItem(id: "new", label: "New"),
        DocsAppMenuItem(id: "open", label: "Open"),
        DocsAppMenuItem(id: "copy", label: "Make a Copy"),
      ],
      onSelected: (_) {},
    );
  }
}

/// The application toolbar that includes document editing options such as font family,
/// font size, text alignment, etc.
class _DocsEditorToolbar extends StatefulWidget {
  const _DocsEditorToolbar();

  @override
  State<_DocsEditorToolbar> createState() => _DocsEditorToolbarState();
}

class _DocsEditorToolbarState extends State<_DocsEditorToolbar> {
  @override
  Widget build(BuildContext context) {
    return const Material(
      color: toolbarBackgroundColor,
      shape: StadiumBorder(),
      child: SizedBox(
        width: double.infinity,
        height: 36,
      ),
    );
  }
}
