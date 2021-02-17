import 'package:example/spikes/editor_abstractions/default_editor/list_items.dart';
import 'package:example/spikes/editor_abstractions/default_editor/paragraph.dart';
import 'package:example/spikes/editor_abstractions/default_editor/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'core/document.dart';
import 'core/document_editor.dart';
import 'core/document_selection.dart';
import 'default_editor/editor.dart';
import 'default_editor/text.dart';

Widget createPlainTextEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    componentBuilder: ({
      @required BuildContext context,
      @required Document document,
      @required DocumentNode currentNode,
      @required DocumentNodeSelection nodeSelection,
      @required GlobalKey key,
      bool showDebugPaint = false,
    }) {
      if (currentNode is ParagraphNode) {
        final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
            ? null
            : nodeSelection.nodeSelection as TextSelection;
        if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
          print('ERROR: Building a paragraph component but the selection is not a TextSelection: ${currentNode.id}');
        }
        final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;
        final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

        return TextComponent(
          key: key,
          text: currentNode.text,
          styleBuilder: (attributions) {
            return TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.normal,
            );
          },
          metadata: currentNode.metadata,
          textSelection: textSelection,
          hasCursor: hasCursor,
          highlightWhenEmpty: highlightWhenEmpty,
          showDebugPaint: showDebugPaint,
        );
      } else {
        return NotRecognizedComponent();
      }
    },
    showDebugPaint: showDebugPaint,
  );
}

class NotRecognizedComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Placeholder(),
    );
  }
}

Widget createStyledEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor.standard(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    showDebugPaint: showDebugPaint,
  );
}

Widget createDarkStyledEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    componentBuilder: ({
      @required BuildContext context,
      @required Document document,
      @required DocumentNode currentNode,
      @required DocumentNodeSelection nodeSelection,
      @required GlobalKey key,
      bool showDebugPaint = false,
    }) {
      if (currentNode is ParagraphNode) {
        final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
            ? null
            : nodeSelection.nodeSelection as TextSelection;
        if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
          print('ERROR: Building a paragraph component but the selection is not a TextSelection: ${currentNode.id}');
        }
        final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;
        final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

        return TextComponent(
          key: key,
          text: currentNode.text,
          styleBuilder: (attributions) {
            final style = defaultStyleBuilder(attributions);
            return style.copyWith(
              color: Colors.white,
            );
          },
          metadata: currentNode.metadata,
          textSelection: textSelection,
          hasCursor: hasCursor,
          highlightWhenEmpty: highlightWhenEmpty,
          showDebugPaint: showDebugPaint,
        );
      } else if (currentNode is ListItemNode && currentNode.type == ListItemType.unordered) {
        final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
        final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

        return UnorderedListItemComponent(
          textKey: key,
          text: currentNode.text,
          styleBuilder: (attributions) {
            final style = defaultStyleBuilder(attributions);
            return style.copyWith(
              color: Colors.white,
            );
          },
          indent: currentNode.indent,
          textSelection: textSelection,
          hasCursor: hasCursor,
          showDebugPaint: showDebugPaint,
        );
      } else if (currentNode is ListItemNode && currentNode.type == ListItemType.ordered) {
        int index = 1;
        DocumentNode nodeAbove = document.getNodeBefore(currentNode);
        while (nodeAbove != null &&
            nodeAbove is ListItemNode &&
            nodeAbove.type == ListItemType.ordered &&
            nodeAbove.indent >= currentNode.indent) {
          if ((nodeAbove as ListItemNode).indent == currentNode.indent) {
            index += 1;
          }
          nodeAbove = document.getNodeBefore(nodeAbove);
        }

        final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
        final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

        return OrderedListItemComponent(
          textKey: key,
          listIndex: index,
          text: currentNode.text,
          styleBuilder: (attributions) {
            final style = defaultStyleBuilder(attributions);
            return style.copyWith(
              color: Colors.white,
            );
          },
          textSelection: textSelection,
          hasCursor: hasCursor,
          indent: currentNode.indent,
          showDebugPaint: showDebugPaint,
        );
      } else {
        return defaultComponentBuilder(
          context: context,
          document: document,
          currentNode: currentNode,
          nodeSelection: nodeSelection,
          key: key,
          showDebugPaint: showDebugPaint,
        );
      }
    },
    showDebugPaint: showDebugPaint,
  );
}
