import 'package:example/spikes/editor_abstractions/core/document_composer.dart';
import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:example/spikes/editor_abstractions/default_editor/horizontal_rule.dart';
import 'package:example/spikes/editor_abstractions/default_editor/paragraph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/document.dart';
import 'core/document_editor.dart';
import 'default_editor/editor.dart';

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
    keyboardActions: defaultKeyboardActions,
    textStyleBuilder: (attributions) {
      return TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.normal,
      );
    },
    componentBuilder: (ComponentContext componentContext) {
      if (componentContext.currentNode is ParagraphNode) {
        return defaultComponentBuilder(componentContext);
      } else {
        return NotRecognizedComponent();
      }
    },
    showDebugPaint: showDebugPaint,
  );
}

// TODO: turn into real component in default editor
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

/// Configures a standard editor.
Widget createStyledEditor(Document doc, [bool showDebugPaint = false]) {
  return Editor.standard(
    document: doc,
    editor: DocumentEditor(
      document: doc,
    ),
    composer: DocumentComposer(
      document: doc,
    ),
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
    keyboardActions: defaultKeyboardActions,
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
    componentBuilder: (ComponentContext componentContext) {
      if (componentContext.currentNode is HorizontalRuleNode) {
        final standardHr = defaultComponentBuilder(componentContext) as HorizontalRuleComponent;

        return HorizontalRuleComponent(
          componentKey: standardHr.componentKey,
          color: Colors.lightGreenAccent,
          isSelected: standardHr.isSelected,
          selectionColor: standardHr.selectionColor,
        );
      } else {
        return defaultComponentBuilder(componentContext);
      }
    },
    showDebugPaint: showDebugPaint,
  );
}
