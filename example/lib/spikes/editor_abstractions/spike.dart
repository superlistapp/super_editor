import 'package:example/spikes/editor_abstractions/example_editors.dart';
import 'package:flutter/material.dart';

import 'core/document.dart';
import 'example_docs.dart';

/// Spike:
/// How should we delegate input so that keys like arrows, backspace,
/// delete, page-up, page-down, and others can select and interact
/// with multiple document widgets?
///
/// Conclusion:
/// Through a lot of hacking work and refactoring, the following
/// abstractions have appeared:
///  - Document
///  - DocumentPosition
///  - DocumentSelection
///  - DocumentEditor
///  - DocumentLayout
///  - DocumentInteractor
///  - DocumentComposer
///  - Editor
///
/// Thoughts:
///  - We can't allow individual document widgets to respond to user
///    input because individual widgets won't have the document-level
///    awareness to understand and process actions that impact multiple
///    document nodes. For example: the user selects a paragraph, a list item,
///    and an image and then presses "delete". It can't be the job of
///    any of those individual widgets to handle the "delete" key press.
///
///  - We should try to completely separate painting concerns from input
///    concerns. The framework has not done a great job of this when it
///    comes to EditableText, which prevented us from using existing widgets.
///    We should see if we can create more highly composable text selection
///    and editing tools to achieve grater versatility.

void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(
        textTheme: TextTheme(
          bodyText1: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: const Color(0xFF312F2C),
          ),
        ),
      ),
      home: EditorSpike(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class EditorSpike extends StatefulWidget {
  @override
  _EditorSpikeState createState() => _EditorSpikeState();
}

class _EditorSpikeState extends State<EditorSpike> {
  Document _doc;
  _EditorType _editorType = _EditorType.standard;
  bool _showDebugPaint = false;

  @override
  void initState() {
    super.initState();
    _doc = createLoremIpsumDoc();
  }

  @override
  Widget build(BuildContext context) {
    Widget editor;
    switch (_editorType) {
      case _EditorType.plainText:
        editor = createPlainTextEditor(_doc, _showDebugPaint);
        break;
      case _EditorType.dark:
        // editor = createStyledEditor(_doc, _showDebugPaint);
        editor = createDarkStyledEditor(_doc, _showDebugPaint);
        break;
      case _EditorType.standard:
      default:
        // editor = createDarkStyledEditor(_doc, _showDebugPaint);
        editor = createStyledEditor(_doc, _showDebugPaint);
        break;
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: editor,
      drawer: _buildDrawer(),
      backgroundColor:
          _editorType == _EditorType.dark ? const Color(0xFF222222) : Theme.of(context).scaffoldBackgroundColor,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: Theme.of(context).iconTheme.copyWith(
            color: _editorType == _EditorType.dark ? Colors.white : Colors.black,
          ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _doc = createEmptyDoc();
              });
            },
            child: Text('Empty Doc'),
          ),
          SizedBox(width: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _doc = createStartingPointDoc();
              });
            },
            child: Text('Starter Doc'),
          ),
          SizedBox(width: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _doc = createLoremIpsumDoc();
              });
            },
            child: Text('Lorem Ipsum Doc'),
          ),
          SizedBox(width: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _doc = createRichContentDoc();
              });
            },
            child: Text('Rich Text Doc'),
          ),
          SizedBox(width: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _doc = createListItemsDoc();
              });
            },
            child: Text('List Items Doc'),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Switch(
          value: _showDebugPaint,
          onChanged: (newValue) {
            setState(() {
              _showDebugPaint = newValue;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 24),
            Divider(),
            ListTile(
              title: Text('Plain Text Editor'),
              onTap: () {
                setState(() {
                  _editorType = _EditorType.plainText;
                  Navigator.of(context).pop();
                });
              },
            ),
            Divider(),
            ListTile(
              title: Text('Styled Text Editor'),
              onTap: () {
                setState(() {
                  _editorType = _EditorType.standard;
                  Navigator.of(context).pop();
                });
              },
            ),
            Divider(),
            ListTile(
              title: Text('Dark Text Editor'),
              onTap: () {
                setState(() {
                  _editorType = _EditorType.dark;
                  Navigator.of(context).pop();
                });
              },
            ),
            Divider(),
          ],
        ),
      ),
    );
  }
}

enum _EditorType {
  plainText,
  standard,
  dark,
}
