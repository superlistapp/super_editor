import 'package:flutter/material.dart';

class FlutterTextFieldDemo extends StatefulWidget {
  @override
  _FlutterTextFieldDemoState createState() => _FlutterTextFieldDemoState();
}

class _FlutterTextFieldDemoState extends State<FlutterTextFieldDemo> {
  final _screenFocusNode = FocusNode();
  final _textController = TextEditingController(
    text:
        'This is a regular TextField, which implements TextInputClient internally. Sed vestibulum ex ac mauris euismod consequat. Sed eu ipsum interdum, feugiat tortor sit amet, suscipit quam. Morbi lacus lectus, gravida ut odio ac, porta rhoncus metus. Curabitur nulla ante, pulvinar a aliquet id, imperdiet placerat justo. Mauris tristique aliquam tincidunt. Quisque eu aliquam risus. Quisque scelerisque ac massa eu aliquet.',
  );

  _TextFieldSizeMode _sizeMode = _TextFieldSizeMode.short;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          _screenFocusNode.requestFocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Focus(
          focusNode: _screenFocusNode,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _sizeMode == _TextFieldSizeMode.singleLine
            ? 0
            : _sizeMode == _TextFieldSizeMode.short
                ? 1
                : 2,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.short_text),
            label: 'Single Line',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wrap_text_rounded),
            label: 'Short',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wrap_text_rounded),
            label: 'Tall',
          ),
        ],
        onTap: (int newIndex) {
          setState(() {
            if (newIndex == 0) {
              _sizeMode = _TextFieldSizeMode.singleLine;
            } else if (newIndex == 1) {
              _sizeMode = _TextFieldSizeMode.short;
            } else if (newIndex == 2) {
              _sizeMode = _TextFieldSizeMode.tall;
            }
          });
        },
      ),
    );
  }

  Widget _buildTextField() {
    int? minLines;
    int? maxLines;
    switch (_sizeMode) {
      case _TextFieldSizeMode.singleLine:
        minLines = 1;
        maxLines = 1;
        break;
      case _TextFieldSizeMode.short:
        maxLines = 5;
        break;
      case _TextFieldSizeMode.tall:
        // no-op
        break;
    }

    return TextField(
      controller: _textController,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: TextInputAction.done,
    );
  }
}

enum _TextFieldSizeMode {
  singleLine,
  short,
  tall,
}
