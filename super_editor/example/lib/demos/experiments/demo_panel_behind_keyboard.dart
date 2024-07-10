import 'dart:math';

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
  final _keyboardController = SoftwareKeyboardController();
  final _keyboardState = ValueNotifier(_InputState.closed);
  final _nonKeyboardEditorState = ValueNotifier(_InputState.closed);

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    _doc = _createDocument();
    _composer = MutableDocumentComposer() //
      ..selectionNotifier.addListener(_onSelectionChange);
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // Check the IME connection at the end of the frame so that SuperEditor has
      // an opportunity to connect to our software keyboard controller.
      _keyboardState.value = _keyboardController.isConnectedToIme ? _InputState.open : _InputState.closed;
    });
  }

  @override
  void dispose() {
    _closeKeyboard();
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
    if (_nonKeyboardEditorState.value == _InputState.open) {
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

  void _closeKeyboard() {
    print("Closing keyboard (and disconnecting from IME)");
    _keyboardController.close();
  }

  void _endEditing() {
    print("End editing");
    _keyboardController.close();

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
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SuperEditor(
                focusNode: _focusNode,
                editor: _editor,
                softwareKeyboardController: _keyboardController,
                selectionPolicies: const SuperEditorSelectionPolicies(
                  clearSelectionWhenEditorLosesFocus: false,
                ),
                imePolicies: const SuperEditorImePolicies(
                  openKeyboardOnSelectionChange: false,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BehindKeyboardPanel(
              keyboardState: _keyboardState,
              nonKeyboardEditorState: _nonKeyboardEditorState,
              onOpenKeyboard: _openKeyboard,
              onCloseKeyboard: _closeKeyboard,
              onEndEditing: _endEditing,
            ),
          ),
        ],
      ),
    );
  }
}

class _BehindKeyboardPanel extends StatefulWidget {
  const _BehindKeyboardPanel({
    Key? key,
    required this.keyboardState,
    required this.nonKeyboardEditorState,
    required this.onOpenKeyboard,
    required this.onCloseKeyboard,
    required this.onEndEditing,
  }) : super(key: key);

  final ValueNotifier<_InputState> keyboardState;
  final ValueNotifier<_InputState> nonKeyboardEditorState;
  final VoidCallback onOpenKeyboard;
  final VoidCallback onCloseKeyboard;
  final VoidCallback onEndEditing;

  @override
  State<_BehindKeyboardPanel> createState() => __BehindKeyboardPanelState();
}

class __BehindKeyboardPanelState extends State<_BehindKeyboardPanel> {
  double _maxBottomInsets = 0.0;
  double _latestBottomInsets = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newBottomInset = MediaQuery.of(context).viewInsets.bottom;
    print("_BehindKeyboardPanel didChangeDependencies() - bottom inset: $newBottomInset");
    if (newBottomInset > _maxBottomInsets) {
      print("Setting max bottom insets to: $newBottomInset");
      _maxBottomInsets = newBottomInset;
      widget.nonKeyboardEditorState.value = _InputState.open;

      if (widget.keyboardState.value != _InputState.open) {
        setState(() {
          widget.keyboardState.value = _InputState.open;
        });
      }
    } else if (newBottomInset > _latestBottomInsets) {
      print("Keyboard is opening. We're already expanded");
      // The keyboard is expanding, but we're already expanded. Make sure
      // that our internal accounting for keyboard state is updated.
      if (widget.keyboardState.value != _InputState.open) {
        setState(() {
          widget.keyboardState.value = _InputState.open;
        });
      }
    } else if (widget.nonKeyboardEditorState.value == _InputState.closed) {
      // We don't want to be expanded. Follow the keyboard back down.
      _maxBottomInsets = newBottomInset;
    } else {
      // The keyboard is collapsing, but we want to stay expanded. Make sure
      // our internal accounting for keyboard state is updated.
      if (widget.keyboardState.value == _InputState.open) {
        setState(() {
          widget.keyboardState.value = _InputState.closed;
        });
      }
    }

    _latestBottomInsets = newBottomInset;
  }

  void _closeKeyboardAndPanel() {
    setState(() {
      widget.nonKeyboardEditorState.value = _InputState.closed;
      _maxBottomInsets = min(_latestBottomInsets, _maxBottomInsets);
    });

    widget.onEndEditing();
  }

  @override
  Widget build(BuildContext context) {
    print("Building toolbar. Is expanded? ${widget.keyboardState.value == _InputState.open}");
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 54,
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _closeKeyboardAndPanel,
                child: const Icon(Icons.close),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.keyboardState.value == _InputState.open ? widget.onCloseKeyboard : widget.onOpenKeyboard,
                child: Icon(widget.keyboardState.value == _InputState.open ? Icons.keyboard_hide : Icons.keyboard),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: _maxBottomInsets,
          child: ColoredBox(
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }
}

enum _InputState {
  open,
  closed,
}
