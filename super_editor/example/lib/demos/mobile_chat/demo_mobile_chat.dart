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

  final _imeConnectionNotifier = ValueNotifier<bool>(false);

  _Panel? _visiblePanel;

  @override
  void initState() {
    super.initState();

    final document = MutableDocument.empty();
    final composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: document, composer: composer);

    _keyboardPanelController = KeyboardPanelController(_softwareKeyboardController);
  }

  @override
  void dispose() {
    _imeConnectionNotifier.dispose();
    _keyboardPanelController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePanel(_Panel panel) {
    setState(() {
      if (_visiblePanel == panel) {
        _visiblePanel = null;
        _keyboardPanelController.showSoftwareKeyboard();
      } else {
        _visiblePanel = panel;
        _keyboardPanelController.showKeyboardPanel();
      }
    });
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
            isImeConnected: _imeConnectionNotifier,
            toolbarBuilder: _buildKeyboardToolbar,
            keyboardPanelBuilder: (context) {
              switch (_visiblePanel) {
                case _Panel.panel1:
                  return Container(
                    color: Colors.blue,
                    height: double.infinity,
                  );
                case _Panel.panel2:
                  return Container(
                    color: Colors.red,
                    height: double.infinity,
                  );
                default:
                  return const SizedBox();
              }
            },
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
                    isImeConnected: _imeConnectionNotifier,
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
    if (!isKeyboardPanelVisible) {
      _visiblePanel = null;
    }

    return Container(
      width: double.infinity,
      height: 54,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 24),
          const Spacer(),
          _PanelButton(
            icon: Icons.text_fields,
            isActive: _visiblePanel == _Panel.panel1,
            onPressed: () => _togglePanel(_Panel.panel1),
          ),
          const SizedBox(width: 16),
          _PanelButton(
            icon: Icons.align_horizontal_left,
            isActive: _visiblePanel == _Panel.panel2,
            onPressed: () => _togglePanel(_Panel.panel2),
          ),
          const SizedBox(width: 16),
          _PanelButton(
            icon: Icons.account_circle,
            onPressed: () => _showBottomSheetWithOptions(context),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _keyboardPanelController.closeKeyboardAndPanel,
            child: Icon(Icons.keyboard_hide),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

enum _Panel {
  panel1,
  panel2;
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    this.isActive = false,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? Colors.grey : Colors.transparent,
          ),
          child: Icon(icon),
        ),
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

Future<void> _showBottomSheetWithOptions(BuildContext context) async {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      return _BottomSheetWithoutButtonOptions();
    },
  );
}

class _BottomSheetWithoutButtonOptions extends StatefulWidget {
  const _BottomSheetWithoutButtonOptions();

  @override
  State<_BottomSheetWithoutButtonOptions> createState() => _BottomSheetWithoutButtonOptionsState();
}

class _BottomSheetWithoutButtonOptionsState extends State<_BottomSheetWithoutButtonOptions> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "This bottom sheet represents a feature in which the user wants to temporarily leave the editor, and the toolbar, to review or select an option. We expect the keyboard or panel to close when this opens, and to re-open when this closes.",
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Some Options"),
          ),
        ],
      ),
    );
  }
}
