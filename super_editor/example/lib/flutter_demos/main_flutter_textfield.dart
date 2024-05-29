import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(_FlutterTextFieldDemoApp());
}

class _FlutterTextFieldDemoApp extends StatelessWidget {
  const _FlutterTextFieldDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _DemoTextField(),
          ),
        ),
      ),
    );
  }
}

class _DemoTextField extends StatefulWidget {
  const _DemoTextField();

  @override
  State<_DemoTextField> createState() => _DemoTextFieldState();
}

class _DemoTextFieldState extends State<_DemoTextField> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: _textController,
        decoration: InputDecoration(
          hintText: "Enter text...",
        ),
        contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
          // If supported, show the system context menu.
          if (SystemContextMenu.isSupported(context)) {
            return SystemContextMenu.editableText(
              editableTextState: editableTextState,
            );
          }
          // Otherwise, show the flutter-rendered context menu for the current
          // platform.
          return AdaptiveTextSelectionToolbar.editableText(
            editableTextState: editableTextState,
          );
        });
  }
}
