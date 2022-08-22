import 'package:super_editor/super_editor.dart';

Document createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Super Editor with tagging',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              "This demo integrates the ability to tag terms and fake users. Try it out by typing a \"#\" or \"@\" to open a popover that searches for values.",
        ),
      ),
    ],
  );
}
