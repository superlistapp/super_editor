import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../super_textfield/super_textfield_inspector.dart';
import '../super_textfield/super_textfield_robot.dart';
import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor popover focus", () {
    testWidgetsOnDesktop("shares focus with editor", (tester) async {
      final editContext = await tester
          .createDocument()
          .withSingleParagraph()
          .withInputSource(TextInputSource.ime)
          .autoFocus(true)
          .pump();

      // Select some content in the document.
      // TODO: use robot selection when it becomes available (#672)
      const documentSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
      editContext.editContext.composer.selection = documentSelection;
      await tester.pumpAndSettle();
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Show a popover that has a text field and give focus to the text field.
      await _showPopover(tester, editContext.focusNode.context!, editorFocusNode: editContext.focusNode);
      await tester.placeCaretInSuperTextField(0);

      // Ensure the popover has primary focus and the editor still has its selection.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Close the popover.
      await _hidePopover(tester);

      // Ensure the editor regained focus and the selection is unchanged.
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);
    });

    testWidgetsOnMobile("shares focus with editor", (tester) async {
      final editContext = await tester.createDocument().withSingleParagraph().autoFocus(true).pump();

      // Select some content in the document.
      // TODO: use robot selection when it becomes available (#672)
      const documentSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 20),
        ),
      );
      editContext.editContext.composer.selection = documentSelection;
      await tester.pumpAndSettle();
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Show a popover that has a text field and give focus to the text field.
      await _showPopover(tester, editContext.focusNode.context!, editorFocusNode: editContext.focusNode);
      await tester.placeCaretInSuperTextField(0);
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));

      // Ensure the popover has primary focus and the editor still has its selection.
      expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);

      // Close the popover.
      await _hidePopover(tester);

      // Ensure the editor regained focus and the selection is unchanged.
      expect(SuperEditorInspector.hasFocus(), isTrue);
      expect(SuperEditorInspector.findDocumentSelection(), documentSelection);
    });
  });
}

OverlayEntry? _overlayEntry;

Future<void> _showPopover(
  WidgetTester tester,
  BuildContext context, {
  required FocusNode editorFocusNode,
}) async {
  _overlayEntry = OverlayEntry(builder: (innerContext) {
    return _Popover(
      editorFocusNode: editorFocusNode,
      textFieldFocusNode: FocusNode(),
    );
  });

  Overlay.of(context).insert(_overlayEntry!);

  await tester.pump();
}

Future<void> _hidePopover(WidgetTester tester) async {
  _overlayEntry!.remove();

  await tester.pump();
}

class _Popover extends StatelessWidget {
  const _Popover({
    Key? key,
    required this.editorFocusNode,
    required this.textFieldFocusNode,
  }) : super(key: key);

  final FocusNode editorFocusNode;
  final FocusNode textFieldFocusNode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300, minHeight: 56),
        child: FocusWithCustomParent(
          parentFocusNode: editorFocusNode,
          focusNode: textFieldFocusNode,
          child: SuperTextField(
            focusNode: textFieldFocusNode,
            lineHeight: 20,
          ),
        ),
      ),
    );
  }
}
