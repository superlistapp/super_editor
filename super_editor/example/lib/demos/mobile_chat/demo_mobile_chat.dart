import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class MobileChatDemo extends StatefulWidget {
  const MobileChatDemo({super.key});

  @override
  State<MobileChatDemo> createState() => _MobileChatDemoState();
}

class _MobileChatDemoState extends State<MobileChatDemo> {
  final FocusNode _focusNode = FocusNode();
  late final Editor _editor;
  late final KeyboardPanelController _keyboardPanelController;
  final SoftwareKeyboardController _softwareKeyboardController = SoftwareKeyboardController();

  @override
  void initState() {
    super.initState();

    final document = MutableDocument.empty();
    final composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: document, composer: composer);
    _keyboardPanelController = KeyboardPanelController(
      softwareKeyboardController: _softwareKeyboardController,
    );
  }

  @override
  void dispose() {
    _keyboardPanelController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _endEditing() {
    _keyboardPanelController.closeKeyboardAndPanel();

    _editor.execute([
      const ClearSelectionRequest(),
    ]);

    // If we clear SuperEditor's selection, but leave SuperEditor focused, then
    // SuperEditor will automatically place the caret at the end of the document.
    // This is because SuperEditor always expects a place for text input when it
    // has focus. To prevent this from happening, we explicitly remove focus
    // from SuperEditor.
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardScaffoldSafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCommentEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(width: 1, color: Colors.grey),
              left: BorderSide(width: 1, color: Colors.grey),
              right: BorderSide(width: 1, color: Colors.grey),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.075),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: KeyboardPanelScaffold(
            controller: _keyboardPanelController,
            aboveKeyboardBuilder: _buildKeyboardToolbar,
            keyboardPanelBuilder: (context) => Container(
              color: Colors.blue,
              height: 100,
            ),
            contentBuilder: (context, isKeyboardVisible) {
              return CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SuperEditor(
                    editor: _editor,
                    focusNode: _focusNode,
                    softwareKeyboardController: _softwareKeyboardController,
                    shrinkWrap: true,
                    stylesheet: _chatStylesheet,
                    selectionPolicies: const SuperEditorSelectionPolicies(
                      clearSelectionWhenEditorLosesFocus: false,
                      clearSelectionWhenImeConnectionCloses: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardToolbar(BuildContext context, bool isKeyboardPanelVisible) {
    return Container(
      width: double.infinity,
      height: 54,
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const SizedBox(width: 24),
          GestureDetector(
            onTap: _endEditing,
            child: const Icon(Icons.close),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _keyboardPanelController.toggleKeyboard(),
            child: Icon(isKeyboardPanelVisible ? Icons.keyboard : Icons.keyboard_hide),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

final _chatStylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.maxWidth: null,
          Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.first(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 12),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 12),
        };
      },
    ),
  ],
);
