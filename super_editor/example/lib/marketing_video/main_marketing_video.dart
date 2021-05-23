import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:linkify/linkify.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(
    MaterialApp(
      home: MarketingVideo(),
    ),
  );
}

class MarketingVideo extends StatefulWidget {
  @override
  _MarketingVideoState createState() => _MarketingVideoState();
}

class _MarketingVideoState extends State<MarketingVideo> {
  final _docLayoutKey = GlobalKey();
  DocumentEditor _editor;
  DocumentComposer _composer;

  @override
  void initState() {
    super.initState();

    final doc = MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(text: ''),
        ),
      ],
    );
    _editor = DocumentEditor(document: doc);
    _composer = DocumentComposer(
        initialSelection: DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: doc.nodes.first.id,
        nodePosition: doc.nodes.first.endPosition,
      ),
    ));

    _startRobot();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _startRobot() async {
    final robot = DocumentEditingRobot(
      editor: _editor,
      composer: _composer,
      documentLayoutFinder: () => _docLayoutKey.currentState as DocumentLayout,
    );

    robot
      ..pause(const Duration(seconds: 20))
      // ..typeText('🎉')
      ..typeText('🔥')
      ..pause(const Duration(seconds: 5))
      ..backspace();
    await robot.start();

    // TODO: fix bug here. If we use select all to select the emoji
    //       and delete, the resulting selection is wrong
    // robot
    //   ..selectAll()
    //   ..backspace();
    // await robot.start();

    robot
      ..pause(const Duration(seconds: 3))
      ..typeText('Introducing')
      ..pause(const Duration(milliseconds: 500))
      ..newline()
      ..addAttribution(titleAttribution)
      ..typeText('A new Flutter text Editor')
      ..pause(const Duration(seconds: 2))
      ..moveCaretLeft(count: 7)
      ..pause(const Duration(milliseconds: 250))
      ..moveCaretLeft(count: 18, expand: true)
      ..pause(const Duration(milliseconds: 1000))
      // TODO: this is a hack because _updateComposerPreferencesAtSelection is
      //       clearing out the current style when it shouldn't be
      ..addAttribution(titleAttribution)
      ..addAttribution(superlistBrandAttribution)
      ..typeText('Super')
      ..removeAttribution(superlistBrandAttribution)
      ..removeAttribution(titleAttribution)
      ..pause(const Duration(seconds: 1))
      ..moveCaretRight(count: 8)
      // ..pause(const Duration(seconds: 1))
      ..newline()
      ..newline()
      ..addAttribution(headerAttribution)
      ..typeText('v0.1.0')
      ..removeAttribution(headerAttribution)
      ..pause(const Duration(milliseconds: 2000))
      ..newline()
      // ..typeText('https://pasinfotech.com/wp-content/uploads/2019/06/flutter-banner.jpg ')
      ..typeText('https://rb.gy/5htwc7 ')
      ..pause(const Duration(seconds: 2))
      ..newline()
      ..newline()
      ..typeText(' * ')
      ..addAttribution(boldAttribution)
      ..typeText('bold')
      ..removeAttribution(boldAttribution)
      ..typeText(' text')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..addAttribution(italicsAttribution)
      ..typeText('italic')
      ..removeAttribution(italicsAttribution)
      ..typeText(' text')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..addAttribution(strikethroughAttribution)
      ..typeText('strikethrough')
      ..removeAttribution(strikethroughAttribution)
      ..typeText(' text')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..backspace()
      ..newline()
      ..typeText('> Blockquotes, too')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..newline()
      ..typeText(' * unordered lists')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..typeText('also')
      ..newline()
      ..backspace()
      ..newline()
      ..typeText(' 1. ordered')
      ..newline()
      ..typeText('lists')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..backspace()
      ..newline()
      ..typeText(' * horizontal rules')
      ..pause(const Duration(milliseconds: 500))
      ..newline()
      ..backspace()
      ..newline()
      ..typeText('--- ')
      ..typeText(' ')
      ..pause(const Duration(milliseconds: 1000))
      ..newline()
      ..typeText('and')
      ..pause(const Duration(milliseconds: 500))
      ..typeText('.')
      ..pause(const Duration(milliseconds: 500))
      ..typeText('.')
      ..pause(const Duration(milliseconds: 500))
      ..typeText('.')
      ..newline()
      ..newline()
      ..pause(const Duration(milliseconds: 1000))
      ..typeText("WE'RE.")
      ..newline()
      ..pause(const Duration(milliseconds: 500))
      ..typeText('JUST.')
      ..newline()
      ..pause(const Duration(milliseconds: 500))
      ..typeText('GETTING.')
      ..newline()
      ..pause(const Duration(milliseconds: 500))
      ..addAttribution(boldAttribution)
      ..typeText('STARTED!')
      ..removeAttribution(boldAttribution)
      ..pause(const Duration(milliseconds: 1000))
      ..typeTextFast(
          '🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 ')
      ..typeTextFast(
          '🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 ')
      ..typeTextFast(
          '🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 🚀 ');
    // ..pause(const Duration(milliseconds: 3000))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline()
    // ..pause(const Duration(milliseconds: 500))
    // ..newline();
    await robot.start();

    // robot
    //   ..typeText('Hello World!')
    //   ..newline()
    //   ..newline()
    //   ..typeText('This is some more text');
    //
    // await robot.start();
    //
    // robot
    //   ..pause(const Duration(seconds: 2))
    //   ..selectContent(DocumentSelection(
    //     base: DocumentPosition(
    //       nodeId: _editor.document.nodes.last.id,
    //       nodePosition: _editor.document.nodes.last.endPosition,
    //     ),
    //     extent: DocumentPosition(
    //       nodeId: _editor.document.nodes.first.id,
    //       nodePosition: _editor.document.nodes.first.beginningPosition,
    //     ),
    //   ))
    //   ..backspace()
    //   ..typeText('Yada yada yada')
    //   ..pause(const Duration(seconds: 2))
    //   ..backspace()
    //   ..backspace()
    //   ..backspace()
    //   ..backspace()
    //   ..backspace();
    //
    // await robot.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 48),
        child: Editor.custom(
          documentLayoutKey: _docLayoutKey,
          editor: _editor,
          composer: _composer,
          textStyleBuilder: _textStyleBuilder,
          componentVerticalSpacing: 0,
        ),
      ),
    );
  }
}

TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  TextStyle textStyle = defaultStyleBuilder(attributions).copyWith(
    fontSize: 18,
  );

  if (attributions.contains(titleAttribution)) {
    textStyle = textStyle.copyWith(
      fontSize: 24,
    );
  }

  if (attributions.contains(headerAttribution)) {
    textStyle = textStyle.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.bold,
    );
  }

  if (attributions.contains(superlistBrandAttribution)) {
    textStyle = textStyle.copyWith(
      color: Colors.red,
      fontWeight: FontWeight.bold,
      fontStyle: FontStyle.italic,
    );
  }

  return textStyle;
}

final superlistBrandAttribution = NamedAttribution('superlist_brand');
final titleAttribution = NamedAttribution('titleAttribution');
final headerAttribution = NamedAttribution('header');

class DocumentEditingRobot {
  DocumentEditingRobot({
    @required DocumentEditor editor,
    @required DocumentComposer composer,
    @required DocumentLayoutFinder documentLayoutFinder,
    int randomSeed,
  })  : _editor = editor,
        _composer = composer,
        _docLayoutFinder = documentLayoutFinder,
        _random = Random(randomSeed);

  final DocumentEditor _editor;
  final DocumentComposer _composer;
  final DocumentLayoutFinder _docLayoutFinder;
  final _actionQueue = <RobotAction>[];
  final _random;

  void placeCaret(DocumentPosition position) {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          _composer.selection = DocumentSelection.collapsed(position: position);
        },
      ),
    );
  }

  void select(DocumentSelection selection) {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          _composer.selection = selection;
        },
      ),
    );
  }

  void selectAll() {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          _composer.selection = DocumentSelection(
            base: DocumentPosition(
              nodeId: _editor.document.nodes.first.id,
              nodePosition: _editor.document.nodes.first.beginningPosition,
            ),
            extent: DocumentPosition(
              nodeId: _editor.document.nodes.last.id,
              nodePosition: _editor.document.nodes.last.endPosition,
            ),
          );
        },
      ),
    );
  }

  void moveCaretLeft({
    int count = 1,
    bool expand = false,
  }) {
    for (int i = 0; i < count; ++i) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            _moveHorizontally(
              editor: _editor,
              composer: _composer,
              documentLayout: _docLayoutFinder(),
              expandSelection: expand,
              moveLeft: true,
            );
          },
        ),
      );
    }
  }

  void moveCaretRight({
    int count = 1,
    bool expand = false,
  }) {
    for (int i = 0; i < count; ++i) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            _moveHorizontally(
              editor: _editor,
              composer: _composer,
              documentLayout: _docLayoutFinder(),
              expandSelection: expand,
              moveLeft: false,
            );
          },
        ),
      );
    }
  }

  void moveCaretUp({expand = false}) {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          // TODO: use same command as editor
        },
      ),
    );
  }

  void moveCaretDown({expand = false}) {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          // TODO: use same command as editor
        },
      ),
    );
  }

  void typeText(String text) {
    for (final character in text.characters) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            if (!_composer.selection.isCollapsed) {
              _editor.executeCommand(DeleteSelectionCommand(documentSelection: _composer.selection));
            }

            insertCharacterIntoTextComposableCommand(
              editor: _editor,
              composer: _composer,
              character: character,
            );

            if (character == ' ') {
              _convertParagraphIfDesired(
                editor: _editor,
                composer: _composer,
              );
            }
          },
        ),
      );
    }
  }

  void typeTextFast(String text) {
    for (final character in text.characters) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            if (!_composer.selection.isCollapsed) {
              _editor.executeCommand(DeleteSelectionCommand(documentSelection: _composer.selection));
            }

            insertCharacterIntoTextComposableCommand(
              editor: _editor,
              composer: _composer,
              character: character,
            );

            if (character == ' ') {
              _convertParagraphIfDesired(
                editor: _editor,
                composer: _composer,
              );
            }
          },
          true,
        ),
      );
    }
  }

  void addAttribution(Attribution attribution) {
    _actionQueue.add(() {
      _composer.preferences.addStyle(attribution);
    });
  }

  void removeAttribution(Attribution attribution) {
    _actionQueue.add(() {
      _composer.preferences.removeStyle(attribution);
    });
  }

  void newline() {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          final node = _editor.document.getNodeById(_composer.selection.extent.nodeId);

          if (node is ParagraphNode) {
            if (node.metadata['blockType'] == 'blockquote') {
              blockquoteInsertNewline(editor: _editor, composer: _composer);
            } else {
              paragraphInsertNewline(editor: _editor, composer: _composer);
            }
          } else if (node is ListItemNode) {
            listItemInsertNewline(editor: _editor, composer: _composer);
          } else {
            _editor.executeCommand(EditorCommandFunction((doc, transaction) {
              final newNodeId = DocumentEditor.createNodeId();

              transaction.insertNodeAt(
                doc.nodes.length,
                ParagraphNode(
                  id: newNodeId,
                  text: AttributedText(text: ''),
                ),
              );

              _composer.selection = DocumentSelection.collapsed(
                  position: DocumentPosition(
                nodeId: newNodeId,
                nodePosition: TextPosition(offset: 0),
              ));
            }));
          }
        },
      ),
    );
  }

  void backspace() {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          if (_composer.selection.isCollapsed) {
            final node = _editor.document.getNodeById(_composer.selection.extent.nodeId);

            if (node is ListItemNode && _composer.selection.extent.nodePosition == node.beginningPosition) {
              _editor.executeCommand(UnIndentListItemCommand(nodeId: node.id));
            }
            deleteUpstreamContentCommand(editor: _editor, composer: _composer);
          } else {
            _editor.executeCommand(
              DeleteSelectionCommand(documentSelection: _composer.selection),
            );
          }
        },
      ),
    );
  }

  void delete() {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          if (_composer.selection.isCollapsed) {
            deleteDownstreamContentCommand(editor: _editor, composer: _composer);
          } else {
            _editor.executeCommand(
              DeleteSelectionCommand(documentSelection: _composer.selection),
            );
          }
        },
      ),
    );
  }

  void paste(String text) {
    _actionQueue.add(
      _randomPauseBefore(
        () {
          // TODO: use same command as editor
        },
      ),
    );
  }

  void pause(Duration duration) {
    _actionQueue.add(
      () async {
        await Future.delayed(duration);
      },
    );
  }

  RobotAction _randomPauseBefore(RobotAction action, [bool fastMode = false]) {
    return () async {
      await Future.delayed(_randomWaitPeriod(fastMode));
      await action();
    };
  }

  Duration _randomWaitPeriod([bool fastMode = false]) {
    return Duration(milliseconds: _random.nextInt(fastMode ? 45 : 200) + (fastMode ? 5 : 50));
  }

  Future<void> start() async {
    while (_actionQueue.isNotEmpty) {
      final action = _actionQueue.removeAt(0);
      await action();
    }
  }

  Future<void> cancel() async {
    _actionQueue.clear();
  }
}

typedef RobotAction = FutureOr<void> Function();

typedef DocumentLayoutFinder = DocumentLayout Function();

void _moveHorizontally({
  @required DocumentEditor editor,
  @required DocumentComposer composer,
  @required DocumentLayout documentLayout,
  @required bool expandSelection,
  @required bool moveLeft,
  Map<String, dynamic> movementModifiers = const {},
}) {
  if (composer.selection == null) {
    return;
  }

  final currentExtent = composer.selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = editor.document.getNodeById(nodeId);
  if (node == null) {
    throw Exception('Could not find the node with the current selection extent: $nodeId');
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    throw Exception('Could not find a component for the document node at "$nodeId"');
  }

  String newExtentNodeId = nodeId;
  dynamic newExtentNodePosition = moveLeft
      ? extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifiers)
      : extentComponent.movePositionRight(currentExtent.nodePosition, movementModifiers);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = moveLeft ? editor.document.getNodeBefore(node) : editor.document.getNodeAfter(node);

    if (nextNode == null) {
      // We're at the beginning/end of the document and can't go
      // anywhere.
      return;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      throw Exception('Could not find next component to move the selection horizontally. Next node ID: ${nextNode.id}');
    }
    newExtentNodePosition = moveLeft ? nextComponent.getEndPosition() : nextComponent.getBeginningPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  if (expandSelection) {
    // Selection should be expanded.
    composer.selection = composer.selection.expandTo(
      newExtent,
    );
  } else {
    // Selection should be replaced by new collapsed position.
    composer.selection = DocumentSelection.collapsed(
      position: newExtent,
    );
  }
}

bool _convertParagraphIfDesired({
  @required DocumentEditor editor,
  @required DocumentComposer composer,
}) {
  if (composer.selection == null) {
    // This method shouldn't be invoked if the given node
    // doesn't have the caret, but we check just in case.
    return false;
  }

  final document = editor.document;
  final node = document.getNodeById(composer.selection.extent.nodeId);
  if (node is! ParagraphNode) {
    return false;
  }
  final paragraphNode = node as ParagraphNode;

  final text = paragraphNode.text;
  final textSelection = composer.selection.extent.nodePosition as TextPosition;
  final textBeforeCaret = text.text.substring(0, textSelection.offset);

  final unorderedListItemMatch = RegExp(r'^\s*[\*-]\s+$');
  final hasUnorderedListItemMatch = unorderedListItemMatch.hasMatch(textBeforeCaret);

  final orderedListItemMatch = RegExp(r'^\s*[1].*\s+$');
  final hasOrderedListItemMatch = orderedListItemMatch.hasMatch(textBeforeCaret);

  if (hasUnorderedListItemMatch || hasOrderedListItemMatch) {
    int startOfNewText = textBeforeCaret.length;
    while (startOfNewText < paragraphNode.text.text.length && paragraphNode.text.text[startOfNewText] == ' ') {
      startOfNewText += 1;
    }
    // final adjustedText = node.text.text.substring(startOfNewText);
    final adjustedText = paragraphNode.text.copyText(startOfNewText);
    final newNode = hasUnorderedListItemMatch
        ? ListItemNode.unordered(id: paragraphNode.id, text: adjustedText)
        : ListItemNode.ordered(id: paragraphNode.id, text: adjustedText);
    final nodeIndex = document.getNodeIndex(paragraphNode);

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction
          ..deleteNodeAt(nodeIndex)
          ..insertNodeAt(nodeIndex, newNode);
      }),
    );

    // We removed some text at the beginning of the list item.
    // Move the selection back by that same amount.
    final textPosition = composer.selection.extent.nodePosition as TextPosition;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: paragraphNode.id,
        nodePosition: TextPosition(offset: textPosition.offset - startOfNewText),
      ),
    );

    return true;
  }

  final hrMatch = RegExp(r'^---*\s$');
  final hasHrMatch = hrMatch.hasMatch(textBeforeCaret);
  if (hasHrMatch) {
    // Insert an HR before this paragraph and then clear the
    // paragraph's content.
    final paragraphNodeIndex = document.getNodeIndex(paragraphNode);

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction.insertNodeAt(
          paragraphNodeIndex,
          HorizontalRuleNode(
            id: DocumentEditor.createNodeId(),
          ),
        );
      }),
    );

    paragraphNode.text =
        paragraphNode.text.removeRegion(startOffset: 0, endOffset: hrMatch.firstMatch(textBeforeCaret).end);

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: paragraphNode.id,
        nodePosition: TextPosition(offset: 0),
      ),
    );

    return true;
  }

  final blockquoteMatch = RegExp(r'^>\s$');
  final hasBlockquoteMatch = blockquoteMatch.hasMatch(textBeforeCaret);
  if (hasBlockquoteMatch) {
    int startOfNewText = textBeforeCaret.length;
    while (startOfNewText < paragraphNode.text.text.length && paragraphNode.text.text[startOfNewText] == ' ') {
      startOfNewText += 1;
    }
    final adjustedText = paragraphNode.text.copyText(startOfNewText);
    final newNode = ParagraphNode(
      id: paragraphNode.id,
      text: adjustedText,
      metadata: {'blockType': blockquoteAttribution},
    );
    final nodeIndex = document.getNodeIndex(paragraphNode);

    editor.executeCommand(
      EditorCommandFunction((document, transaction) {
        transaction
          ..deleteNodeAt(nodeIndex)
          ..insertNodeAt(nodeIndex, newNode);
      }),
    );

    // We removed some text at the beginning of the list item.
    // Move the selection back by that same amount.
    final textPosition = composer.selection.extent.nodePosition as TextPosition;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: paragraphNode.id,
        nodePosition: TextPosition(offset: textPosition.offset - startOfNewText),
      ),
    );

    return true;
  }

  // URL match, e.g., images, social, etc.
  final extractedLinks = linkify(text.text,
      options: LinkifyOptions(
        humanize: false,
      ));
  final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
  final String nonEmptyText =
      extractedLinks.fold('', (value, element) => element is TextElement ? value + element.text.trim() : value);
  if (linkCount == 1 && nonEmptyText.isEmpty) {
    // This node's text is just a URL, try to interpret it
    // as a known type.
    final link = extractedLinks.firstWhereOrNull((element) => element is UrlElement).text;
    _processUrlNode(
      document: document,
      editor: editor,
      nodeId: node.id,
      originalText: text.text,
      url: link,
    );
    return true;
  }

  // No pattern match was found
  return false;
}

Future<void> _processUrlNode({
  @required Document document,
  @required DocumentEditor editor,
  @required String nodeId,
  @required String originalText,
  @required String url,
}) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    return;
  }

  final contentType = response.headers['content-type'];
  if (contentType == null) {
    return;
  }
  if (!contentType.startsWith('image/')) {
    return;
  }

  // The URL is an image. Convert the node.
  final node = document.getNodeById(nodeId);
  if (node is! ParagraphNode) {
    return;
  }
  final currentText = (node as ParagraphNode).text.text;
  if (currentText.trim() != originalText.trim()) {
    return;
  }

  final imageNode = ImageNode(
    id: node.id,
    imageUrl: url,
  );
  final nodeIndex = document.getNodeIndex(node);

  editor.executeCommand(
    EditorCommandFunction((document, transaction) {
      transaction
        ..deleteNodeAt(nodeIndex)
        ..insertNodeAt(nodeIndex, imageNode);
    }),
  );
}
