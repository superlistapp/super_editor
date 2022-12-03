import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _PanelBehindKeyboardDemoState extends State<PanelBehindKeyboardDemo> with TextInputClient {
  TextInputConnection? _imeConnection;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _disconnectFromIme();
    super.dispose();
  }

  void _connectToIme() {
    print("Connecting to IME");
    if (_imeConnection == null) {
      _imeConnection = TextInput.attach(this, const TextInputConfiguration());
    } else {
      print(" - already connected");
    }

    print(" - showing keyboard");
    _imeConnection!
      ..show()
      ..setEditingState(currentTextEditingValue!);
  }

  void _disconnectFromIme() {
    if (_imeConnection == null) {
      return;
    }

    _imeConnection!.close();
    _imeConnection = null;
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => const TextEditingValue(
        text: "",
        selection: TextSelection(baseOffset: 0, extentOffset: 0),
      );

  @override
  void updateEditingValue(TextEditingValue value) {}

  @override
  void performAction(TextInputAction action) {}

  @override
  void performSelector(String selectorName) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void connectionClosed() {
    print('Text input connection closed');
    _imeConnection = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _connectToIme,
            child: Container(
              color: Colors.white,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BehindKeyboardPanel(
              onCollapseKeyboard: _disconnectFromIme,
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
    required this.onCollapseKeyboard,
  }) : super(key: key);

  final VoidCallback onCollapseKeyboard;

  @override
  State<BehindKeyboardPanel> createState() => _BehindKeyboardPanelState();
}

class _BehindKeyboardPanelState extends State<BehindKeyboardPanel> {
  bool _isExpanded = false;
  double _maxBottomInsets = 0.0;
  double _latestBottomInsets = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newBottomInset = MediaQuery.of(context).viewInsets.bottom;
    print("BehindKeyboardPanel didChangeDependencies() - bottom inset: $newBottomInset");
    _latestBottomInsets = newBottomInset;
    if (newBottomInset > _maxBottomInsets) {
      print("Setting max bottom insets to: $newBottomInset");
      _isExpanded = true;
      _maxBottomInsets = newBottomInset;
    } else if (!_isExpanded) {
      // We don't want to be expanded. Follow the keyboard back down.
      _maxBottomInsets = newBottomInset;
    }
  }

  void _closeKeyboardAndPanel() {
    setState(() {
      _isExpanded = false;
      _maxBottomInsets = min(_latestBottomInsets, _maxBottomInsets);
      widget.onCollapseKeyboard();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                onTap: widget.onCollapseKeyboard,
                child: Icon(Icons.keyboard_hide),
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
