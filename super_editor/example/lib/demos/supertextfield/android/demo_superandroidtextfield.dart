import 'package:example/demos/supertextfield/_mobile_textfield_demo.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of [SuperAndroidTextField].
class SuperAndroidTextFieldDemo extends StatefulWidget {
  @override
  _SuperAndroidTextFieldDemoState createState() => _SuperAndroidTextFieldDemoState();
}

class _SuperAndroidTextFieldDemoState extends State<SuperAndroidTextFieldDemo> {
  @override
  void initState() {
    super.initState();
    initLoggers(Level.FINER, {androidTextFieldLog, imeTextFieldLog});
  }

  @override
  void dispose() {
    deactivateLoggers({androidTextFieldLog, imeTextFieldLog});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileSuperTextFieldDemo(
      initialText: AttributedText(
          text:
              'This is a custom textfield implementation called SuperAndroidTextField. It is super long so that we can mess with scrolling. This drags it out even further so that we can get multiline scrolling, too. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin tempor sapien est, in eleifend purus rhoncus fringilla. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nulla varius libero lorem, eget tincidunt ante porta accumsan. Morbi quis ante at nunc molestie ullamcorper.'),
      createTextField: _buildTextField,
    );
  }

  Widget _buildTextField(MobileTextFieldDemoConfig config) {
    final genericTextStyle = config.styleBuilder({});
    final lineHeight = genericTextStyle.fontSize! * (genericTextStyle.height ?? 1.0);

    return SuperAndroidTextField(
      textController: config.controller,
      textStyleBuilder: config.styleBuilder,
      hintBehavior: HintBehavior.displayHintUntilTextEntered,
      hintBuilder: StyledHintBuilder(
          hintText: AttributedText(text: "Enter text"),
          hintTextStyleBuilder: (attributions) {
            return config.styleBuilder(attributions).copyWith(color: Colors.grey);
          }).build,
      selectionColor: Colors.blue.withOpacity(0.4),
      caretColor: Colors.green,
      handlesColor: Colors.lightGreen,
      minLines: config.minLines,
      maxLines: config.maxLines,
      lineHeight: lineHeight,
      textInputAction: TextInputAction.done,
      showDebugPaint: config.showDebugPaint,
    );
  }
}
