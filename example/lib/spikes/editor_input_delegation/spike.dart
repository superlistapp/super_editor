import 'package:example/spikes/editor_input_delegation/document/rich_text_document.dart';
import 'package:flutter/material.dart';

import 'document/document_nodes.dart';
import 'editor.dart';

/// Spike:
/// How should we delegate input so that keys like arrows, backspace,
/// delete, page-up, page-down, and others can select and interact
/// with multiple document widgets?
///
/// Conclusion:
/// TODO:
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
///
/// Known Issues:
///  - empty line selection isn't quite right. When selecting empty lines,
///    there should be a concept of an invisible newline. The invisible
///    newlines should receive a small selection. Of course, the newlines
///    aren't real, so this an explicit effect that's added. When selecting
///    multiple empty lines, the last line should not show a selection because
///    the hypothetical newline happens after the selection. However, the
///    current implementation shows a selection on every empty line that
///    participates in the selection.
///
///  - when drag-selecting text within a single line, the y-position is
///    used to determine direction. Instead, the x-position should be
///    used when selecting within a single line.
///
///  - there is some weird measurement glitch with the SingleChildScrollView
///    and IntrinsicHeight where we overflow the bottom sometimes.

void main() {
  runApp(
    MaterialApp(
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
  RichTextDocument _doc;
  bool _showDebugPaint = false;

  @override
  void initState() {
    super.initState();
    _doc = _createLoremIpsumDoc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Editor(
        initialDocument: _doc,
        showDebugPaint: _showDebugPaint,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlatButton(
            onPressed: () {
              setState(() {
                _doc = _createEmptyDoc();
              });
            },
            child: Text('Empty Doc'),
          ),
          FlatButton(
            onPressed: () {
              setState(() {
                _doc = _createStartingPointDoc();
              });
            },
            child: Text('Starter Doc'),
          ),
          FlatButton(
            onPressed: () {
              setState(() {
                _doc = _createLoremIpsumDoc();
              });
            },
            child: Text('Lorem Ipsum Doc'),
          ),
          FlatButton(
            onPressed: () {
              setState(() {
                _doc = _createRichContentDoc();
              });
            },
            child: Text('Rich Text Doc'),
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

  RichTextDocument _createEmptyDoc() {
    return RichTextDocument(
      nodes: [
        TextNode(
          // TODO: I don't like how the client has to provide an ID...
          id: RichTextDocument.createNodeId(),
          text: '',
        ),
      ],
    );
  }

  // TODO: add hint text to these nodes
  RichTextDocument _createStartingPointDoc() {
    return RichTextDocument(
      nodes: [
        TextNode(
          id: RichTextDocument.createNodeId(),
          text: '',
          textType: 'header1',
        ),
        TextNode(
          id: RichTextDocument.createNodeId(),
          text: '',
        ),
      ],
    );
  }

  RichTextDocument _createLoremIpsumDoc() {
    return RichTextDocument(nodes: [
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum1,
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum2,
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum3,
      ),
    ]);
  }

  RichTextDocument _createRichContentDoc() {
    return RichTextDocument(nodes: [
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is rich text',
        textType: 'header1',
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum1,
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum1,
        textAlign: TextAlign.center,
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum1,
        textAlign: TextAlign.right,
      ),
      UnorderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 1st list item.',
      ),
      UnorderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 2nd list item.',
      ),
      UnorderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 3rd list item.',
        indent: 1,
      ),
      UnorderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 4th list item.',
        indent: 1,
      ),
      UnorderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 5th list item.',
      ),
      HorizontalRuleNode(id: RichTextDocument.createNodeId()),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 1st list item.',
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 2nd list item.',
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 3rd list item.',
        indent: 1,
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 4th list item.',
        indent: 1,
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 5th list item.',
        indent: 2,
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 6th list item.',
        indent: 2,
      ),
      OrderedListItemNode(
        id: RichTextDocument.createNodeId(),
        text: 'This is the 7th list item.',
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum2,
      ),
      ImageNode(
        id: RichTextDocument.createNodeId(),
        imageUrl:
            'https://images.unsplash.com/photo-1612099453097-26a809f51e96?ixid=MXwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHw%3D&ixlib=rb-1.2.1&auto=format&fit=crop&w=1050&q=80',
      ),
      TextNode(
        id: RichTextDocument.createNodeId(),
        text: _loremIpsum3,
      ),
    ]);
  }
}

const _loremIpsum1 =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
const _loremIpsum2 =
    'Nullam id elementum felis. Morbi ullamcorper gravida vulputate. Nulla sed gravida lorem. Nam tincidunt, arcu sit amet sodales aliquet, lectus magna volutpat felis, non pharetra risus risus dignissim mauris. Fusce diam massa, semper eu elementum in, dictum vel nulla. Etiam porta luctus augue, porttitor porta nibh. Donec risus arcu, viverra sed tincidunt id, lobortis non nulla. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean vel lobortis quam, ac pulvinar risus. Praesent laoreet tempor ex. Nunc eu ante nisl. Integer in magna ligula.';
const _loremIpsum3 =
    'Phasellus non gravida arcu. Pellentesque posuere orci et lorem fermentum, sed interdum metus vestibulum. Maecenas suscipit mollis sagittis. Mauris quis est blandit libero vehicula fringilla eget in augue. Etiam mi lectus, ullamcorper ac odio nec, maximus ultricies enim. Aenean nec est non nunc tincidunt rhoncus. Proin laoreet vitae libero ut faucibus. Donec bibendum laoreet dolor eu varius. Pellentesque ullamcorper turpis quis viverra semper.';
