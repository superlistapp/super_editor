import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/multi_node_editing.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';

import '../attributions.dart';

/// Toolbar that provides document editing capabilities, like converting
/// paragraphs to blockquotes and list items, and inserting horizontal
/// rules.
///
/// This toolbar is intended to be placed just above the keyboard on a
/// mobile device.
class KeyboardEditingToolbar extends StatelessWidget {
  KeyboardEditingToolbar({
    Key? key,
    required this.editor,
    required this.document,
    required this.composer,
    required this.commonOps,
    this.brightness,
  }) : super(key: key) {
    _toolbarOps = KeyboardEditingToolbarOperations(
      editor: editor,
      document: document,
      composer: composer,
      commonOps: commonOps,
    );
  }

  final Editor editor;
  final Document document;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;
  final Brightness? brightness;

  late final KeyboardEditingToolbarOperations _toolbarOps;

  @override
  Widget build(BuildContext context) {
    final selection = composer.selection;

    if (selection == null) {
      return const SizedBox();
    }

    final brightness = this.brightness ?? MediaQuery.of(context).platformBrightness;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: brightness,
        disabledColor: brightness == Brightness.light ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: brightness == Brightness.light ? Colors.black : Colors.white,
        ),
        child: Material(
          child: Container(
            width: double.infinity,
            height: 48,
            color: brightness == Brightness.light ? const Color(0xFFDDDDDD) : const Color(0xFF222222),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ListenableBuilder(
                        listenable: composer,
                        builder: (context, _) {
                          final selectedNode = document.getNodeById(selection.extent.nodeId);
                          final isSingleNodeSelected = selection.extent.nodeId == selection.base.nodeId;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toolbarOps.toggleBold : null,
                                icon: const Icon(Icons.format_bold),
                                color: _toolbarOps.isBoldActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toolbarOps.toggleItalics : null,
                                icon: const Icon(Icons.format_italic),
                                color: _toolbarOps.isItalicsActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toolbarOps.toggleUnderline : null,
                                icon: const Icon(Icons.format_underline),
                                color: _toolbarOps.isUnderlineActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toolbarOps.toggleStrikethrough : null,
                                icon: const Icon(Icons.strikethrough_s),
                                color: _toolbarOps.isStrikethroughActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header1Attribution)
                                    ? _toolbarOps.convertToHeader1
                                    : null,
                                icon: const Icon(Icons.title),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header2Attribution)
                                    ? _toolbarOps.convertToHeader2
                                    : null,
                                icon: const Icon(Icons.title),
                                iconSize: 18,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        ((selectedNode is ParagraphNode &&
                                                selectedNode.hasMetadataValue('blockType')) ||
                                            (selectedNode is TextNode && selectedNode is! ParagraphNode))
                                    ? _toolbarOps.convertToParagraph
                                    : null,
                                icon: const Icon(Icons.wrap_text),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode && selectedNode.type != ListItemType.ordered))
                                    ? _toolbarOps.convertToOrderedListItem
                                    : null,
                                icon: const Icon(Icons.looks_one_rounded),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode &&
                                                selectedNode.type != ListItemType.unordered))
                                    ? _toolbarOps.convertToUnorderedListItem
                                    : null,
                                icon: const Icon(Icons.list),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is TextNode &&
                                        (selectedNode is! ParagraphNode ||
                                            selectedNode.getMetadataValue('blockType') != blockquoteAttribution)
                                    ? _toolbarOps.convertToBlockquote
                                    : null,
                                icon: const Icon(Icons.format_quote),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is ParagraphNode &&
                                        selectedNode.text.text.isEmpty
                                    ? _toolbarOps.convertToHr
                                    : null,
                                icon: const Icon(Icons.horizontal_rule),
                              ),
                            ],
                          );
                        }),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFCCCCCC),
                ),
                IconButton(
                  onPressed: _toolbarOps.closeKeyboard,
                  icon: const Icon(Icons.keyboard_hide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class KeyboardEditingToolbarOperations {
  KeyboardEditingToolbarOperations({
    required this.editor,
    required this.document,
    required this.composer,
    required this.commonOps,
    this.brightness,
  });

  final Editor editor;
  final Document document;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;
  final Brightness? brightness;

  bool get isBoldActive => _doesSelectionHaveAttributions({boldAttribution});
  void toggleBold() => _toggleAttributions({boldAttribution});

  bool get isItalicsActive => _doesSelectionHaveAttributions({italicsAttribution});
  void toggleItalics() => _toggleAttributions({italicsAttribution});

  bool get isUnderlineActive => _doesSelectionHaveAttributions({underlineAttribution});
  void toggleUnderline() => _toggleAttributions({underlineAttribution});

  bool get isStrikethroughActive => _doesSelectionHaveAttributions({strikethroughAttribution});
  void toggleStrikethrough() => _toggleAttributions({strikethroughAttribution});

  bool _doesSelectionHaveAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return false;
    }

    if (selection.isCollapsed) {
      return composer.preferences.currentAttributions.containsAll(attributions);
    }

    return document.doesSelectedTextContainAttributions(selection, attributions);
  }

  void _toggleAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return;
    }

    selection.isCollapsed
        ? commonOps.toggleComposerAttributions(attributions)
        : commonOps.toggleAttributionsOnSelection(attributions);
  }

  void convertToHeader1() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header1Attribution,
        },
      );
    } else {
      editor.execute([
        ChangeParagraphBlockTypeRequest(
          nodeId: selectedNode.id,
          blockType: header1Attribution,
        ),
      ]);
    }
  }

  void convertToHeader2() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header2Attribution,
        },
      );
    } else {
      editor.execute([
        ChangeParagraphBlockTypeRequest(
          nodeId: selectedNode.id,
          blockType: header2Attribution,
        ),
      ]);
    }
  }

  void convertToParagraph() {
    commonOps.convertToParagraph();
  }

  void convertToOrderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.ordered, selectedNode.text);
  }

  void convertToUnorderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.unordered, selectedNode.text);
  }

  void convertToBlockquote() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToBlockquote(selectedNode.text);
  }

  void convertToHr() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    editor.execute([
      ReplaceNodeRequest(
        existingNodeId: selectedNode.id,
        newNode: ParagraphNode(
          id: selectedNode.id,
          text: AttributedText('---'),
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: selectedNode.id,
            nodePosition: const TextNodePosition(offset: 3),
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.userInteraction,
      ),
      const InsertCharacterAtCaretRequest(character: " "),
    ]);
  }

  void closeKeyboard() {
    editor.execute([
      const ChangeSelectionRequest(
        null,
        SelectionChangeType.clearSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }
}
