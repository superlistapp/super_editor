import 'package:example/spikes/editor_abstractions/core/document_composer.dart';
import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:example/spikes/editor_abstractions/default_editor/horizontal_rule.dart';
import 'package:example/spikes/editor_abstractions/default_editor/list_items.dart';
import 'package:example/spikes/editor_abstractions/default_editor/paragraph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/document.dart';
import 'core/document_editor.dart';
import 'custom_components/text_with_hint.dart';
import 'default_editor/editor.dart';
import 'default_editor/styles.dart';
import 'default_editor/unknown_component.dart';

/// Configures an editor that only displays un-styled text.
///
/// Any node that isn't a `ParagraphNode` is displayed as an "x" placeholder.
Widget createPlainTextEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor.custom(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    composer: DocumentComposer(
      document: doc,
    ),
    keyboardActions: [
      moveCaretFromTitleToFirstParagraph,
      ...defaultKeyboardActions,
    ],
    textStyleBuilder: (attributions) {
      return TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.normal,
      );
    },
    componentBuilders: [
      (ComponentContext componentContext) {
        if (componentContext.currentNode is ParagraphNode) {
          return paragraphBuilder(componentContext);
        } else {
          return UnknownComponent();
        }
      }
    ],
    showDebugPaint: showDebugPaint,
  );
}

/// Configures a standard editor.
Widget createStyledEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor.custom(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    composer: DocumentComposer(
      document: doc,
    ),
    keyboardActions: [
      moveCaretFromTitleToFirstParagraph,
      ...defaultKeyboardActions,
    ],
    showDebugPaint: showDebugPaint,
  );
}

/// Configures a standard editor but with a dark theme.
///
/// Differences:
///  - All text is white instead of black
///  - Caret is bright yellow
///  - Text selection and selected outlines are a low opacity yellow
///  - HRs are painted green
Widget createDarkStyledEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor.custom(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    composer: DocumentComposer(
      document: doc,
    ),
    keyboardActions: [
      moveCaretFromTitleToFirstParagraph,
      ...defaultKeyboardActions,
    ],
    textStyleBuilder: (attributions) {
      final style = defaultStyleBuilder(attributions);
      return style.copyWith(
        color: Colors.white,
        fontFamily: GoogleFonts.merriweather().fontFamily,
        height: 1.8,
      );
    },
    selectionStyle: SelectionStyle(
      textCaretColor: Colors.yellow,
      selectionColor: Colors.yellow.withOpacity(0.3),
    ),
    componentBuilders: [
      (ComponentContext componentContext) {
        if (componentContext.currentNode is! HorizontalRuleNode) {
          return null;
        }
        final standardHr = horizontalRuleBuilder(componentContext) as HorizontalRuleComponent;

        return HorizontalRuleComponent(
          componentKey: standardHr.componentKey,
          color: Colors.lightGreenAccent,
          isSelected: standardHr.isSelected,
          selectionColor: standardHr.selectionColor,
        );
      },
      (ComponentContext componentContext) {
        if (componentContext.currentNode is! ListItemNode ||
            (componentContext.currentNode as ListItemNode).type != ListItemType.unordered) {
          return null;
        }
        final standardUl = unorderedListItemBuilder(componentContext) as UnorderedListItemComponent;

        return UnorderedListItemComponent(
          textKey: componentContext.componentKey,
          text: standardUl.text,
          styleBuilder: standardUl.styleBuilder,
          dotBuilder: (context, component) {
            return Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.opacity,
                  size: 12,
                  color: component.styleBuilder({}).color,
                ),
              ),
            );
          },
          indent: standardUl.indent,
          textSelection: standardUl.textSelection,
          selectionColor: standardUl.selectionColor,
          hasCaret: standardUl.hasCaret,
          caretColor: standardUl.caretColor,
          showDebugPaint: standardUl.showDebugPaint,
        );
      },
      ...defaultComponentBuilders,
    ],
    showDebugPaint: showDebugPaint,
  );
}
