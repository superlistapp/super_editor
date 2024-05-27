import 'package:example_perf/demos/long_doc_demo.dart';
import 'package:example_perf/demos/rebuild_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const SuperEditorPerfDemoApp());
}

class SuperEditorPerfDemoApp extends StatelessWidget {
  const SuperEditorPerfDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Editor Performance Demo App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const HomeScreen(),
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Displays various demos that are selected from a list of
/// options in a drawer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  _MenuItem? _selectedMenuItem;

  @override
  void initState() {
    super.initState();

    _selectedMenuItem = _menu[0].items[0];
  }

  void _toggleDrawer() {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.of(context).pop();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  void _closeDrawer() {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  void _selectMenuItem(_MenuItem item) {
    setState(() {
      _selectedMenuItem = item;
      _closeDrawer();
    });
  }

  @override
  Widget build(BuildContext context) {
    // We need a FocusScope above the Overlay so that focus can be shared between
    // SuperEditor in one OverlayEntry, and the popover toolbar in another OverlayEntry.
    return FocusScope(
      // We need our own [Overlay] instead of the one created by the navigator
      // because overlay entries added to navigator's [Overlay] are always
      // displayed above all routes.
      //
      // We display the editor's toolbar in an [OverlayEntry], so inserting it
      // at the navigator's [Overlay] causes widgets that are displayed in routes,
      // e.g. [DropdownButton] items, to be displayed beneath the toolbar.
      child: Overlay(
        initialEntries: [
          OverlayEntry(builder: (context) {
            return Scaffold(
              key: _scaffoldKey,
              body: Stack(
                children: [
                  _selectedMenuItem!.pageBuilder(context),
                  _buildDrawerButton(),
                ],
              ),
              drawer: _buildDrawer(),
            );
          })
        ],
      ),
    );
  }

  Widget _buildDrawerButton() {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          height: 56,
          width: 56,
          child: IconButton(
            icon: const Icon(Icons.menu),
            color: Theme.of(context).colorScheme.onSurface,
            splashRadius: 24,
            onPressed: _toggleDrawer,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SingleChildScrollView(
        primary: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in _menu) ...[
                if (group.title != null) _DrawerHeader(title: group.title),
                for (final item in group.items) ...[
                  _DrawerButton(
                    icon: item.icon,
                    title: item.title,
                    isSelected: item == _selectedMenuItem,
                    onPressed: () {
                      _selectMenuItem(item);
                    },
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Demo options that are shown in the `HomeScreen` drawer.
final _menu = <_MenuGroup>[
  _MenuGroup(
    title: 'Super Editor',
    items: [
      _MenuItem(
        icon: Icons.description,
        title: 'Rebuild Count Demo',
        pageBuilder: (context) {
          return const RebuildCountDemo();
        },
      ),
      _MenuItem(
        icon: Icons.description,
        title: 'Long Doc Demo',
        pageBuilder: (context) {
          return const LongDocDemo();
        },
      ),
    ],
  ),
];

class _MenuGroup {
  const _MenuGroup({
    this.title,
    required this.items,
  });

  final String? title;
  final List<_MenuItem> items;
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.pageBuilder,
  });

  final IconData icon;
  final String title;
  final WidgetBuilder pageBuilder;
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.title,
  });

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        title!,
        style: const TextStyle(
          color: Color(0xFF444444),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  const _DrawerButton({
    required this.icon,
    required this.title,
    this.isSelected = false,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ButtonStyle(
            backgroundColor: WidgetStateColor.resolveWith((states) {
              if (isSelected) {
                return const Color(0xFFBBBBBB);
              }

              if (states.contains(WidgetState.hovered)) {
                return Colors.grey.withOpacity(0.1);
              }

              return Colors.transparent;
            }),
            // splashFactory: NoSplash.splashFactory,
            foregroundColor:
                WidgetStateColor.resolveWith((states) => isSelected ? Colors.white : const Color(0xFFBBBBBB)),
            elevation: WidgetStateProperty.resolveWith((states) => 0),
            padding: WidgetStateProperty.resolveWith((states) => const EdgeInsets.all(16))),
        onPressed: isSelected ? null : onPressed,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
