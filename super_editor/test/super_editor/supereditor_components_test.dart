import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor component", () {
    testWidgetsOnMac("HintTextComponent places caret on tap", (tester) async {
      // Based on bug #726
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .withAddedComponents([const HintTextComponentBuilder()])
          .autoFocus(false)
          .pump();

      // Tap on the hint text component to place the caret.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure that the document now shows the caret within the hint text component.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });
  });
}

class HintTextComponentBuilder implements ComponentBuilder {
  const HintTextComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    // This component builder can work with the standard paragraph view model.
    // We'll defer to the standard paragraph component builder to create it.
    return null;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    final textSelection = componentViewModel.selection;

    return TextWithHintComponent(
      key: componentContext.componentKey,
      text: componentViewModel.text,
      textStyleBuilder: defaultStyleBuilder,
      metadata: componentViewModel.blockType != null
          ? {
              'blockType': componentViewModel.blockType,
            }
          : {},
      // This is the text displayed as a hint.
      hintText: AttributedText(
        text: 'this is hint text...',
        spans: AttributedSpans(
          attributions: [
            const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 15, markerType: SpanMarkerType.end),
          ],
        ),
      ),
      // This is the function that selects styles for the hint text.
      hintStyleBuilder: (Set<Attribution> attributions) => defaultStyleBuilder(attributions).copyWith(
        color: const Color(0xFFDDDDDD),
      ),
      textSelection: textSelection,
      selectionColor: componentViewModel.selectionColor,
    );
  }
}
