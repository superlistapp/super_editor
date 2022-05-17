import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_text_layout/super_text_layout.dart';

/// Demo of a variety of `SelectableText` configurations.
class SelectableTextDemo extends StatefulWidget {
  @override
  _SelectableTextDemoState createState() => _SelectableTextDemoState();
}

class _SelectableTextDemoState extends State<SelectableTextDemo> {
  final _demoText1 = const TextSpan(
    text: 'Super Editor',
    style: TextStyle(
      color: Color(0xFF444444),
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.bold,
    ),
    children: [
      TextSpan(
        text: ' is an open source text editor for Flutter projects.',
        style: TextStyle(
          color: Color(0xFF444444),
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.normal,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle('SuperTextWithSelection Widget'),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'EMPTY TEXT WITH CARET',
                  demo: SuperTextWithSelection.single(
                    richText: const TextSpan(
                      text: '',
                      style: TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                    userSelection: const UserSelection(
                      selection: TextSelection.collapsed(offset: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITHOUT SELECTION OR CARET',
                  demo: SuperTextWithSelection.single(
                    richText: _demoText1,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH CARET + COLLAPSED SELECTION',
                  demo: SuperTextWithSelection.single(
                    richText: _demoText1,
                    userSelection: UserSelection(
                      selection: TextSelection.collapsed(offset: _demoText1.toPlainText().length),
                      hasCaret: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH LEFT-TO-RIGHT SELECTION + CARET',
                  demo: SuperTextWithSelection.single(
                    richText: _demoText1,
                    userSelection: const UserSelection(
                      selection: TextSelection(baseOffset: 0, extentOffset: 12),
                      hasCaret: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH RIGHT-TO-LEFT SELECTION + CARET',
                  demo: SuperTextWithSelection.single(
                    richText: _demoText1,
                    userSelection: UserSelection(
                      selection: TextSelection(
                          baseOffset: _demoText1.toPlainText().length,
                          extentOffset: _demoText1.toPlainText().length - 17),
                      hasCaret: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF444444),
        fontSize: 32,
      ),
    );
  }

  Widget _buildDemo({
    required String title,
    required Widget demo,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(4),
              )),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        demo,
      ],
    );
  }
}
