import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field.dart';

/// An app that demos [SuperTextField].
void main() {
  runApp(
    MaterialApp(
      home: _SuperTextFieldDemo(),
    ),
  );
}

class _SuperTextFieldDemo extends StatefulWidget {
  const _SuperTextFieldDemo();

  @override
  State<_SuperTextFieldDemo> createState() => _SuperTextFieldDemoState();
}

class _SuperTextFieldDemoState extends State<_SuperTextFieldDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SingleLineTextField(),
              const SizedBox(height: 16),
              _MultiLineTextField(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleLineTextField extends StatefulWidget {
  const _SingleLineTextField();

  @override
  State<_SingleLineTextField> createState() => _SingleLineTextFieldState();
}

class _SingleLineTextFieldState extends State<_SingleLineTextField> {
  final _focusNode = FocusNode();
  final _textController = ImeAttributedTextEditingController(
    controller: AttributedTextEditingController(),
  );

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: "textfields",
      onTapOutside: (_) => _focusNode.unfocus(),
      child: TextFieldBorder(
        focusNode: _focusNode,
        borderBuilder: _borderBuilder,
        child: SuperTextField(
          focusNode: _focusNode,
          textController: _textController,
          textStyleBuilder: _textStyleBuilder,
          hintBuilder: _createHintBuilder("Enter single line text..."),
          padding: const EdgeInsets.all(4),
          minLines: 1,
          maxLines: 1,
          inputSource: TextInputSource.ime,
        ),
      ),
    );
  }
}

class _MultiLineTextField extends StatefulWidget {
  const _MultiLineTextField();

  @override
  State<_MultiLineTextField> createState() => _MultiLineTextFieldState();
}

class _MultiLineTextFieldState extends State<_MultiLineTextField> {
  final _focusNode = FocusNode();
  final _textController = ImeAttributedTextEditingController(
    controller: AttributedTextEditingController(),
  );

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: "textfields",
      onTapOutside: (_) => _focusNode.unfocus(),
      child: TextFieldBorder(
        focusNode: _focusNode,
        borderBuilder: _borderBuilder,
        child: SuperTextField(
          focusNode: _focusNode,
          textController: _textController,
          textStyleBuilder: _textStyleBuilder,
          hintBuilder: _createHintBuilder("Type some text..."),
          padding: const EdgeInsets.all(4),
          minLines: 5,
          maxLines: 5,
          inputSource: TextInputSource.ime,
        ),
      ),
    );
  }
}

BoxDecoration _borderBuilder(TextFieldBorderState borderState) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: borderState.hasError //
          ? Colors.red
          : borderState.hasFocus
              ? Colors.blue
              : Colors.grey.shade300,
      width: borderState.hasError ? 2 : 1,
    ),
  );
}

TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  return defaultTextFieldStyleBuilder(attributions).copyWith(
    color: Colors.black,
  );
}

WidgetBuilder _createHintBuilder(String hintText) {
  return (BuildContext context) {
    return Text(
      hintText,
      style: TextStyle(color: Colors.grey),
    );
  };
}
