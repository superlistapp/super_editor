import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Example of various [TextWithHintComponent] visual configurations.
class TextWithHintDemo extends StatefulWidget {
  @override
  _TextWithHintDemoState createState() => _TextWithHintDemoState();
}

class _TextWithHintDemoState extends State<TextWithHintDemo> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextWithHintComponent(
                text: AttributedText(text: ''),
                hintText: AttributedText(text: 'hint text...'),
                textAlign: TextAlign.left,
                textStyleBuilder: (attributions) {
                  return const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 30,
                  );
                },
                showCaret: true,
                textSelection: const TextSelection.collapsed(offset: 0),
              ),
              const SizedBox(height: 24),
              TextWithHintComponent(
                text: AttributedText(text: ''),
                hintText: AttributedText(text: 'hint text...'),
                textAlign: TextAlign.left,
                textStyleBuilder: (attributions) {
                  return const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 24,
                  );
                },
                showCaret: true,
                textSelection: const TextSelection.collapsed(offset: 0),
              ),
              const SizedBox(height: 24),
              TextWithHintComponent(
                text: AttributedText(text: ''),
                hintText: AttributedText(text: 'hint text...'),
                textAlign: TextAlign.left,
                textStyleBuilder: (attributions) {
                  return const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 14,
                  );
                },
                showCaret: true,
                textSelection: const TextSelection.collapsed(offset: 0),
              ),
              const SizedBox(height: 24),
              TextWithHintComponent(
                text: AttributedText(
                    text:
                        'orem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.'),
                textAlign: TextAlign.left,
                textStyleBuilder: (attributions) {
                  return const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 18,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
