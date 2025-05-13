import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:super_editor_obsidian/sidebar.dart';
import 'package:super_editor_obsidian/tabbed_editor.dart';
import 'package:tab_kit/tab_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureMacWindow();

  runApp(const MyApp());
}

Future<void> _configureMacWindow() async {
  await WindowManipulator.initialize();

  // Let us display our tabs at the top of the window.
  WindowManipulator.makeTitlebarTransparent();
  WindowManipulator.hideTitle();
  WindowManipulator.enableFullSizeContentView();

  // Make the toolbar taller, to match our tab height.
  WindowManipulator.addToolbar();
  WindowManipulator.setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unifiedCompact);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final NotebookTabController _editorTabController;

  @override
  void initState() {
    super.initState();

    _editorTabController = NotebookTabController(initialTabs: [
      // const TabDescriptor(id: "1", title: "This is a document"),
    ])
      ..addTab(const TabDescriptor(id: "1", title: "This is a document"));
  }

  @override
  void dispose() {
    _editorTabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Sidebar(),
          Expanded(
            child: TabbedEditor(
              tabController: _editorTabController,
            ),
          ),
        ],
      ),
    );
  }
}
