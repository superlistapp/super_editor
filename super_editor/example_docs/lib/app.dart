import 'package:example_docs/app_menu.dart';
import 'package:example_docs/editor.dart';
import 'package:example_docs/theme.dart';
import 'package:example_docs/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

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
  const MainScreen({
    super.key,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FocusNode _editorFocusNode = FocusNode();
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  int _zoomLevel = 100;

  @override
  void initState() {
    super.initState();

    _document = _createInitialDocument();
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer);
  }

  @override
  void dispose() {
    _editor.dispose();
    _composer.dispose();
    _document.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFf9fbfd),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppHeaderPane(
              editorFocusNode: _editorFocusNode,
              document: _document,
              editor: _editor,
              composer: _composer,
              onZoomChange: (zoom) => setState(() {
                _zoomLevel = zoom;
              }),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, thickness: 1, color: Color(0xFFc4c7c5)),
            Expanded(
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: _zoomLevel / 100.0,
                child: DocsEditor(
                  focusNode: _editorFocusNode,
                  document: _document,
                  composer: _composer,
                  editor: _editor,
                ),
              ),
            ),
          ],
        ));
  }
}

/// The pane that appears at the top of the app, which includes the document title, app menu,
/// and editor toolbar.
class _AppHeaderPane extends StatelessWidget {
  const _AppHeaderPane({
    required this.editorFocusNode,
    required this.document,
    required this.editor,
    required this.composer,
    required this.onZoomChange,
  });

  final FocusNode editorFocusNode;
  final Document document;
  final Editor editor;
  final MutableDocumentComposer composer;
  final void Function(int zoom) onZoomChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Column(
        children: [
          _buildTitleAndMenuBar(),
          const SizedBox(height: 16),
          DocsEditorToolbar(
            editorFocusNode: editorFocusNode,
            document: document,
            editor: editor,
            composer: composer,
            onZoomChange: onZoomChange,
          ),
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

// Creates the document that's initially displayed when the app launches.
MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Welcome to a Super Editor version of Docs!"),
        metadata: {
          "blockType": header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("By: The Super Editor Team"),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "This is an example document editor experience, which is meant to mimic the UX of Google Docs. We created this example app to ensure that common desktop word processing UX can be built with Super Editor."),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "A typical desktop word processor is comprised of a pane at the top of the window, which includes some combination of information about the current document, as well as toolbars that present editing options. The remainder of the window is filled by an editable document."),
      ),
    ],
  );
}
