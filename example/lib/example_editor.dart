import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Example of a rich text editor.
///
/// This editor will expand in functionality as the rich text
/// package expands.
class ExampleEditor extends StatefulWidget {
  @override
  _ExampleEditorState createState() => _ExampleEditorState();
}

class _ExampleEditorState extends State<ExampleEditor> {
  FocusNode _titleFocusNode;
  FocusNode _contentFocusNode;

  @override
  void initState() {
    super.initState();
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Display Material that covers all available space.
    // Display content at 500px wide, horizontally centered.
    return Material(
      child: SizedBox.expand(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
            ),
            child: SizedBox(
              width: double.infinity,
              child: _buildPage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 70),
        _buildTitle(),
        _buildContent(),
      ],
    );
  }

  Widget _buildTitle() {
    return RawKeyboardListener(
      focusNode: _titleFocusNode,
      onKey: (RawKeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _titleFocusNode.unfocus();
        } else if (event.logicalKey == LogicalKeyboardKey.tab) {
          _contentFocusNode.requestFocus();
        }
      },
      child: TextField(
        style: TextStyle(
          color: const Color(0xFF312F2C),
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: 'Enter your title',
          hintStyle: TextStyle(
            color: const Color(0xFFC3C1C1),
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
        ),
        cursorColor: Colors.black,
      ),
    );
  }

  Widget _buildContent() {
    return RawKeyboardListener(
      focusNode: _contentFocusNode,
      onKey: (RawKeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _contentFocusNode.unfocus();
        }
      },
      child: TextField(
        maxLines: null, // adds lines as content requires
        style: TextStyle(
          color: const Color(0xFF312F2C),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: 'Enter your content',
          hintStyle: TextStyle(
            color: const Color(0xFFC3C1C1),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
        ),
        cursorColor: Colors.black,
      ),
    );
  }
}
