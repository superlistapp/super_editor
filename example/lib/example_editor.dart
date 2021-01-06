import 'package:flutter/material.dart';

/// Example of a rich text editor.
///
/// This editor will expand in functionality as the rich text
/// package expands.
class ExampleEditor extends StatelessWidget {
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
              child: _buildPageContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TITLE'),
      ],
    );
  }
}
