import 'package:example/demos/supertextfield/demo_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '_robot.dart';

class SingleLineTextFieldDemo extends StatefulWidget {
  @override
  State<SingleLineTextFieldDemo> createState() => _SingleLineTextFieldDemoState();
}

class _SingleLineTextFieldDemoState extends State<SingleLineTextFieldDemo> with TickerProviderStateMixin {
  final _textFieldController = AttributedTextEditingController(
    text: AttributedText(),
  );

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
      ..text = AttributedText();
    // _demoRobot
    //   ..typeText(AttributedText('Hello World! This is a robot typing some text into a SuperTextField.'))
    //   ..start();
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
                  child: ColoredBox(
                    color: Colors.yellow,
                    child: SuperTextField(
                      textController: _textFieldController,
                      focusNode: _focusNode,
                      hintBehavior: HintBehavior.displayHintUntilTextEntered,
                      inputSource: TextInputSource.ime,
                      maxLines: 1,
                      minLines: 1,
                      textStyleBuilder: (_) => TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        height: 1.8,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                      controlsColor: Colors.red,
                      selectionColor: Colors.green,
                      caretStyle: CaretStyle(
                        width: 1,
                        color: Colors.blue,
                      ),
                      blinkTimingMode: BlinkTimingMode.timer,
                      hintBuilder: (_) => Text(
                        'Type an URL',
                        style: TextStyle(
                          color: Colors.grey,
                          height: 1.8,
                          fontSize: 14,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
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
