import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

// This demo is for Android, only. You need to make changes to the Android
// Activity config for this demo to work.
//  - In AndroidManifest.xml, find the MainActivity declaration.
//    set `android:windowSoftInputMode="adjustResize"`

class PanelBehindKeyboardDemo extends StatefulWidget {
  const PanelBehindKeyboardDemo({
    Key? key,
  }) : super(key: key);

  @override
  State<PanelBehindKeyboardDemo> createState() => _PanelBehindKeyboardDemoState();
}

class _PanelBehindKeyboardDemoState extends State<PanelBehindKeyboardDemo> {
  late final FocusNode _focusNode;
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  final _isImeConnected = ValueNotifier<bool>(false);

  final _keyboardController = SoftwareKeyboardController();
  late final KeyboardPanelController _keyboardPanelController;
  bool _isKeyboardPanelVisible = false;

  @override
  void initState() {
    super.initState();

    _keyboardPanelController = KeyboardPanelController(_keyboardController);

    _focusNode = FocusNode();

    _doc = _createDocument();
    _composer = MutableDocumentComposer() //
      ..selectionNotifier.addListener(_onSelectionChange);
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    _isImeConnected.dispose();
    _composer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  MutableDocument _createDocument() {
    return MutableDocument(nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Example Doc"),
        metadata: {"blockType": header1Attribution},
      ),
      HorizontalRuleNode(id: Editor.createNodeId()),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Unordered list:"),
      ),
      ListItemNode(
        id: Editor.createNodeId(),
        itemType: ListItemType.unordered,
        text: AttributedText("Unordered 1"),
      ),
      ListItemNode(
        id: Editor.createNodeId(),
        itemType: ListItemType.unordered,
        text: AttributedText("Unordered 2"),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Ordered list:"),
      ),
      ListItemNode(
        id: Editor.createNodeId(),
        itemType: ListItemType.unordered,
        text: AttributedText("Ordered 1"),
      ),
      ListItemNode(
        id: Editor.createNodeId(),
        itemType: ListItemType.unordered,
        text: AttributedText("Ordered 2"),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('A blockquote:'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('This is a blockquote.'),
        metadata: {"blockType": blockquoteAttribution},
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Some code:'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('{\n  // This is come code.\n}'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Header"),
        metadata: {"blockType": header2Attribution},
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('More stuff 1'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('More stuff 2'),
      ),
    ]);
  }

  void _onSelectionChange() {
    print("Demo: _onSelectionChange()");
    print(" - selection: ${_composer.selection}");
    if (_isKeyboardPanelVisible) {
      // If the user is currently editing with the non-keyboard editing
      // panel, don't open the keyboard to cover it.
      return;
    }

    if (_composer.selection == null) {
      // If there's no selection, we don't want to pop open the keyboard.
      return;
    }

    print("Opening keyboard from _onSelectionChange()");
    _openKeyboard();
  }

  void _openKeyboard() {
    print("Opening keyboard (also connecting to IME, if needed)");
    _keyboardController.open();
  }

  void _endEditing() {
    print("End editing");
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            _buildTopPanelToggle(context),
            Expanded(
              child: _buildSuperEditor(context, _isKeyboardPanelVisible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperEditor(BuildContext context, bool isKeyboardPanelVisible) {
    _isKeyboardPanelVisible = isKeyboardPanelVisible;

    return SuperEditor(
      focusNode: _focusNode,
      editor: _editor,
      softwareKeyboardController: _keyboardController,
      selectionPolicies: const SuperEditorSelectionPolicies(
        clearSelectionWhenEditorLosesFocus: false,
        // Currently, closing the software keyboard causes the IME connection to close.
        clearSelectionWhenImeConnectionCloses: false,
      ),
      imePolicies: const SuperEditorImePolicies(
        openKeyboardOnSelectionChange: false,
      ),
    );
  }

  Widget _buildTopPanelToggle(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      toolbarBuilder: _buildTopPanel,
      keyboardPanelBuilder: _buildKeyboardPanel,
      contentBuilder: (context, wantsToShowKeyboardPanel) {
        return ElevatedButton(
          onPressed: _keyboardPanelController.toggleToolbar,
          child: Text('Toggle above-keyboard panel'),
        );
      },
    );
  }

  Widget _buildTopPanel(BuildContext context, bool isKeyboardPanelVisible) {
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
            onTap: () => _keyboardPanelController.toggleSoftwareKeyboardWithPanel(),
            child: Icon(isKeyboardPanelVisible ? Icons.keyboard : Icons.keyboard_hide),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildKeyboardPanel(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alignment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_align_left),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_align_center),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_align_right),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_align_justify),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Text Style',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_bold),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_italic),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildKeyboardPanelButton(
                      onPressed: () {},
                      child: Icon(Icons.format_strikethrough),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Convertions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                width: double.infinity,
                child: _buildKeyboardPanelButton(
                  onPressed: () {},
                  child: Text('Header 1'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildKeyboardPanelButton(
                  onPressed: () {},
                  child: Text('Header 2'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildKeyboardPanelButton(
                  onPressed: () {},
                  child: Text('Blockquote'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildKeyboardPanelButton(
                  onPressed: () {},
                  child: Text('Ordered List'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildKeyboardPanelButton(
                  onPressed: () {},
                  child: Text('Unordered List'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardPanelButton({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return TextButton(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all<Color>(Colors.black),
        backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
        minimumSize: WidgetStateProperty.all<Size>(Size(0, 60)),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        textStyle: WidgetStateProperty.all<TextStyle>(
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
