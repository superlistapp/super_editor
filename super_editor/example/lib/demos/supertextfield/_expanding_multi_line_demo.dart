import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '_robot.dart';

class ExpandingMultiLineTextFieldDemo extends StatefulWidget {
  @override
  _ExpandingMultiLineTextFieldDemoState createState() => _ExpandingMultiLineTextFieldDemoState();
}

class _ExpandingMultiLineTextFieldDemoState extends State<ExpandingMultiLineTextFieldDemo> {
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

  GlobalKey<SuperTextFieldState> _textKey;
  TextFieldDemoRobot _demoRobot;

  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _demoRobot = TextFieldDemoRobot(
      textController: _textFieldController,
      textKey: _textKey,
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _textFieldController.selection = TextSelection.collapsed(offset: 0);
      _demoRobot
        ..typeText(AttributedText(text: 'Hello World!'))
        ..pause(const Duration(milliseconds: 500))
        ..typeText(AttributedText(text: '\n\nThis is a robot typing'))
        ..pause(const Duration(milliseconds: 500))
        ..typeText(AttributedText(text: '\nsome text into a SuperTextField.'))
        ..start();
    });
  }

  @override
  void dispose() {
    _demoRobot.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Remove focus from text field when the user taps anywhere else.
        _focusNode.unfocus();
      },
      child: Center(
        child: SizedBox(
          width: 400,
          child: GestureDetector(
            onTap: () {
              // no-op. Prevents unfocus from happening when text field is tapped.
            },
            child: SizedBox(
              width: double.infinity,
              child: SuperTextField(
                key: _textKey,
                controller: _textFieldController,
                focusNode: _focusNode,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                hintBuilder: (context) {
                  return Text(
                    'enter some text',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  );
                },
                hintBehavior: HintBehavior.displayHintUntilTextEntered,
                minLines: 1,
                maxLines: 5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
