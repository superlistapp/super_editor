import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

import '../_mobile_textfield_demo.dart';

/// Demo of [SuperIOSTextField].
class SuperIOSTextFieldDemo extends StatefulWidget {
  @override
  _SuperIOSTextFieldDemoState createState() => _SuperIOSTextFieldDemoState();
}

class _SuperIOSTextFieldDemoState extends State<SuperIOSTextFieldDemo> {
  @override
  void initState() {
    super.initState();
    initLoggers(Level.FINE, {iosTextFieldLog, imeTextFieldLog});
  }

  @override
  void dispose() {
    deactivateLoggers({iosTextFieldLog, imeTextFieldLog});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileSuperTextFieldDemo(
      initialText: AttributedText(
          text:
              'This is a custom textfield implementation called SuperIOSTextfield. It is super long so that we can mess with scrolling. This drags it out even further so that we can get multiline scrolling, too. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin tempor sapien est, in eleifend purus rhoncus fringilla. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nulla varius libero lorem, eget tincidunt ante porta accumsan. Morbi quis ante at nunc molestie ullamcorper.'),
      createTextField: _buildTextField,
    );
  }

  Widget _buildTextField(MobileTextFieldDemoConfig config) {
    final genericTextStyle = config.styleBuilder({});
    final lineHeight = genericTextStyle.fontSize! * (genericTextStyle.height ?? 1.0);

    return SuperIOSTextField(
      textController: config.controller,
      textStyleBuilder: config.styleBuilder,
      hintBehavior: HintBehavior.displayHintUntilTextEntered,
      hintBuilder: StyledHintBuilder(
          hintText: AttributedText(text: "Enter text"),
          hintTextStyleBuilder: (attributions) {
            return config.styleBuilder(attributions).copyWith(color: Colors.grey);
          }).build,
      selectionColor: Colors.blue.withOpacity(0.4),
      caretColor: Colors.blue,
      handlesColor: Colors.blue,
      minLines: config.minLines,
      maxLines: config.maxLines,
      lineHeight: lineHeight,
      textInputAction: TextInputAction.done,
      showDebugPaint: config.showDebugPaint,
    );
  }
}
