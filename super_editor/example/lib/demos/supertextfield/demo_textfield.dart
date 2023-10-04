import 'package:example/demos/supertextfield/_emojis_demo.dart';
import 'package:example/demos/supertextfield/_expanding_multi_line_demo.dart';
import 'package:example/demos/supertextfield/_interactive_demo.dart';
import 'package:example/demos/supertextfield/_textfield_within_scrollable_demo.dart';
import 'package:example/demos/supertextfield/_single_line_demo.dart';
import 'package:example/demos/supertextfield/_static_multi_line_demo.dart';
import 'package:example/demos/supertextfield/_textfield_demo_screen.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/super_editor.dart';

// TODO: demos:
//   - Single line: typing more than can fit on a single line
//       - auto-scrolls to right while typing
//       - auto-scrolls left when jumping to beginning of line
//       - auto-scrolls left/right when moving characters at boundary
//       - auto-scrolls left/right when moving by word
//   - Multi-line
//       -
//   - Widget going from single-line to multi-line, gracefully handling shift

/// Demo of a variety of [SuperTextField]
class TextFieldDemo extends StatefulWidget {
  @override
  State<TextFieldDemo> createState() => _TextFieldDemoState();
}

class _TextFieldDemoState extends State<TextFieldDemo> {
  late WidgetBuilder _demoBuilder;

  @override
  void initState() {
    super.initState();

    _demoBuilder = (_) => InteractiveTextFieldDemo();
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldDemoScreen(
      menuItems: [
        DemoMenuItem(
          label: 'Interactive demo',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => InteractiveTextFieldDemo();
            });
          },
        ),
        DemoMenuItem(
          label: 'Single-line demo',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => SingleLineTextFieldDemo();
            });
          },
        ),
        DemoMenuItem(
          label: 'Static multi-line demo',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => StaticMultiLineTextFieldDemo();
            });
          },
        ),
        DemoMenuItem(
          label: 'Expanding multi-line demo',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => ExpandingMultiLineTextFieldDemo();
            });
          },
        ),
        DemoMenuItem(
          label: 'Backspace emojis',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => const EmojisTextFieldDemo(
                    key: ValueKey('backspace'),
                    direction: TextAffinity.upstream,
                  );
            });
          },
        ),
        DemoMenuItem(
          label: 'Delete emojis',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => const EmojisTextFieldDemo(
                    key: ValueKey('delete'),
                    direction: TextAffinity.downstream,
                  );
            });
          },
        ),
        DemoMenuItem(
          label: 'TextField Scrollable',
          onPressed: () {
            setState(() {
              _demoBuilder = (_) => const TextFieldWithinScrollableDemo();
            });
          },
        ),
      ],
      child: _demoBuilder(context),
    );
  }
}
