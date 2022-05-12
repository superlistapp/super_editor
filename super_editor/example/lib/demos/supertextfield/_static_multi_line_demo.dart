import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '_robot.dart';

class StaticMultiLineTextFieldDemo extends StatefulWidget {
  @override
  _StaticMultiLineTextFieldDemoState createState() => _StaticMultiLineTextFieldDemoState();
}

class _StaticMultiLineTextFieldDemoState extends State<StaticMultiLineTextFieldDemo> with TickerProviderStateMixin {
  final _textFieldController = AttributedTextEditingController(
    text: AttributedText(
        // text:
        //     'Super Editor is an open source text editor for Flutter projects.\n\nThis is paragraph 2\n\nThis is paragraph 3',
        // spans: AttributedSpans(
        //   attributions: [
        //     SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
        //     SpanMarker(attribution: 'bold', offset: 11, markerType: SpanMarkerType.end),
        //   ],
        // ),
        ),
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
    _demoRobot
      ..typeText(AttributedText(text: 'Hello World!'))
      ..pause(const Duration(milliseconds: 500))
      ..typeText(AttributedText(text: '\n\nThis is a robot typing'))
      ..pause(const Duration(milliseconds: 500))
      ..typeText(AttributedText(text: '\nsome text into a SuperTextField.'))
      ..start();
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
                      return Material(
                        borderRadius: BorderRadius.circular(4),
                        elevation: 5,
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
                    minLines: 5,
                    maxLines: 5,
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
