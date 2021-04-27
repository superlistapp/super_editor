import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/super_editor.dart';

/// Demo of a variety of [SuperTextField]
class TextFieldDemo extends StatefulWidget {
  @override
  _TextFieldDemoState createState() => _TextFieldDemoState();
}

class _TextFieldDemoState extends State<TextFieldDemo> {
  final _demoText1 = TextSpan(
    text: 'Super Editor',
    style: TextStyle(
      color: const Color(0xFF444444),
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.bold,
    ),
    children: [
      TextSpan(
        text: ' is an open source text editor for Flutter projects.',
        style: TextStyle(
          color: const Color(0xFF444444),
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.normal,
        ),
      ),
    ],
  );

  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
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
        child: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle('SuperTextField'),
                  SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      // no-op. Prevents unfocus from happening when text field is tapped.
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: SuperTextField(
                        focusNode: _focusNode,
                        hintBuilder: (context) {
                          return Text(
                            'enter some text',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          );
                        },
                        hintBehavior: HintBehavior.displayHintUntilTextEntered,
                        controller: AttributedTextEditingController(
                          text: AttributedText(
                            text:
                                'Super Editor is an open source text editor for Flutter projects.\n\nThis is paragraph 2\n\nThis is paragraph 3',
                            spans: AttributedSpans(
                              attributions: [
                                SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
                                SpanMarker(attribution: 'bold', offset: 11, markerType: SpanMarkerType.end),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: const Color(0xFF444444),
        fontSize: 32,
      ),
    );
  }
}
