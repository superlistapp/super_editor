import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _layoutKey = GlobalKey();

  late DocumentEditor _editor;
  late DocumentComposer _composer;
  late SoftwareKeyboardHandler _softwareKeyboardHandler;

  TextInputConnection? _imeConnection;

  @override
  void initState() {
    super.initState();
    _editor = DocumentEditor(
      document: MutableDocument(nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(text: ""),
        ),
      ]),
    );

    _composer = DocumentComposer(document: _editor.document);

    _softwareKeyboardHandler = SoftwareKeyboardHandler(
      editor: _editor,
      composer: _composer,
      commonOps: CommonEditorOperations(
        editor: _editor,
        composer: _composer,
        documentLayoutResolver: () => _layoutKey.currentState as DocumentLayout,
      ),
    );
  }

  @override
  void dispose() {
    _closeKeyboard();
    _composer.dispose();
    super.dispose();
  }

  void _openKeyboard() {
    print("Opening keyboard (also connecting to IME, if needed)");
    _composer.openIme(_softwareKeyboardHandler);
  }

  void _closeKeyboard() {
    print("Closing keyboard (and disconnecting from IME)");
    _composer.closeIme();
  }

  void _endEditing() {
    print("End editing");
    _composer.closeIme();
    _composer.selection = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: SuperEditor(
              editor: _editor,
              composer: _composer,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BehindKeyboardPanel(
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

class BehindKeyboardPanel extends StatefulWidget {
  const BehindKeyboardPanel({
    Key? key,
    required this.onOpenKeyboard,
    required this.onCloseKeyboard,
    required this.onEndEditing,
  }) : super(key: key);

  final VoidCallback onOpenKeyboard;
  final VoidCallback onCloseKeyboard;
  final VoidCallback onEndEditing;

  @override
  State<BehindKeyboardPanel> createState() => _BehindKeyboardPanelState();
}

class _BehindKeyboardPanelState extends State<BehindKeyboardPanel> {
  bool _isExpanded = false;
  bool _isKeyboardOpen = false;
  double _maxBottomInsets = 0.0;
  double _latestBottomInsets = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newBottomInset = MediaQuery.of(context).viewInsets.bottom;
    print("BehindKeyboardPanel didChangeDependencies() - bottom inset: $newBottomInset");
    if (newBottomInset > _maxBottomInsets) {
      print("Setting max bottom insets to: $newBottomInset");
      _maxBottomInsets = newBottomInset;
      _isExpanded = true;

      if (!_isKeyboardOpen) {
        setState(() {
          _isKeyboardOpen = true;
        });
      }
    } else if (newBottomInset > _latestBottomInsets) {
      print("Keyboard is opening. We're already expanded");
      // The keyboard is expanding, but we're already expanded. Make sure
      // that our internal accounting for keyboard state is updated.
      if (!_isKeyboardOpen) {
        setState(() {
          _isKeyboardOpen = true;
        });
      }
    } else if (!_isExpanded) {
      // We don't want to be expanded. Follow the keyboard back down.
      _maxBottomInsets = newBottomInset;
    } else {
      // The keyboard is collapsing, but we want to stay expanded. Make sure
      // our internal accounting for keyboard state is udpated.
      if (_isKeyboardOpen) {
        setState(() {
          _isKeyboardOpen = false;
        });
      }
    }

    _latestBottomInsets = newBottomInset;
  }

  void _closeKeyboardAndPanel() {
    setState(() {
      _isExpanded = false;
      _maxBottomInsets = min(_latestBottomInsets, _maxBottomInsets);
    });

    widget.onEndEditing();
  }

  @override
  Widget build(BuildContext context) {
    print("Building toolbar. Is expanded? $_isKeyboardOpen");
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
                child: Icon(Icons.close),
              ),
              Spacer(),
              GestureDetector(
                onTap: _isKeyboardOpen ? widget.onCloseKeyboard : widget.onOpenKeyboard,
                child: Icon(_isKeyboardOpen ? Icons.keyboard_hide : Icons.keyboard),
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
