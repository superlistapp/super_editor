import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '_robot.dart';

class EmojisTextFieldDemo extends StatefulWidget {
  const EmojisTextFieldDemo({
    Key? key,
    required this.direction,
  }) : super(key: key);

  final TextAffinity direction;

  @override
  _EmojisTextFieldDemoState createState() => _EmojisTextFieldDemoState();
}

class _EmojisTextFieldDemoState extends State<EmojisTextFieldDemo> with TickerProviderStateMixin {
  final _textFieldController = AttributedTextEditingController();

  GlobalKey<SuperDesktopTextFieldState>? _textKey;
  late TextFieldDemoRobot _demoRobot;

  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _demoRobot = TextFieldDemoRobot(
      focusNode: _focusNode,
      tickerProvider: this,
      textController: _textFieldController,
      textKey: _textKey,
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _startDemo();
    });
  }

  @override
  void dispose() {
    _demoRobot.dispose();
    _focusNode!.dispose();
    super.dispose();
  }

  void _startDemo() {
    _textFieldController
      ..selection = const TextSelection.collapsed(offset: 0)
      ..text = AttributedText(
        text: 'turtle 🐢 bomb 💣 skull ☠',
      );

    if (widget.direction == TextAffinity.upstream) {
      // simulate pressing backspace
      _demoRobot
        ..insertCaretAt(TextPosition(offset: _textFieldController.text.text.length))
        ..pause(const Duration(seconds: 1))
        ..backspaceCharacters(_textFieldController.text.text.length)
        ..start();
    } else {
      // simulate pressing delete
      _demoRobot
        ..insertCaretAt(const TextPosition(offset: 0))
        ..pause(const Duration(seconds: 1))
        ..deleteCharacters(_textFieldController.text.text.length)
        ..start();
    }
  }

  void _restartDemo() {
    _demoRobot.cancelActions();
    _startDemo();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Remove focus from text field when the user taps anywhere else.
        _focusNode!.unfocus();
      },
      child: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  // no-op. Prevents unfocus from happening when text field is tapped.
                },
                child: SizedBox(
                  width: double.infinity,
                  child: SuperDesktopTextField(
                    key: _textKey,
                    textController: _textFieldController,
                    focusNode: _focusNode,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decorationBuilder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _focusNode!.hasFocus ? Colors.blue : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    hintBuilder: (context) {
                      return const Text(
                        'enter some text',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      );
                    },
                    hintBehavior: HintBehavior.displayHintUntilTextEntered,
                    minLines: 1,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _restartDemo,
                child: const Text('Restart Demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
