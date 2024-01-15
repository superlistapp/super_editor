import 'package:example/demos/supertextfield/_mobile_style_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of mobile text field.
class MobileSuperTextFieldDemo extends StatefulWidget {
  const MobileSuperTextFieldDemo({
    Key? key,
    required this.initialText,
    required this.textFieldFocusNode,
    required this.textFieldTapRegionGroupId,
    required this.createTextField,
  }) : super(key: key);

  final AttributedText initialText;
  final FocusNode textFieldFocusNode;
  final String textFieldTapRegionGroupId;
  final Widget Function(MobileTextFieldDemoConfig) createTextField;

  @override
  State<MobileSuperTextFieldDemo> createState() => _MobileSuperTextFieldDemoState();
}

class _MobileSuperTextFieldDemoState extends State<MobileSuperTextFieldDemo> {
  final _screenFocusNode = FocusNode();
  late ImeAttributedTextEditingController _textController;

  _TextFieldSizeMode _sizeMode = _TextFieldSizeMode.short;

  bool _showDebugPaint = false;

  @override
  void initState() {
    super.initState();

    initLoggers(Level.FINEST, {
      // textFieldLog,
      // scrollingTextFieldLog,
      // imeTextFieldLog,
      // androidTextFieldLog,
    });

    _textController = ImeAttributedTextEditingController(
      controller: AttributedTextEditingController(
        text: widget.initialText.copyText(0),
      ),
    );
  }

  @override
  void dispose() {
    deactivateLoggers({
      // textFieldLog,
      scrollingTextFieldLog,
      // imeTextFieldLog,
      // androidTextFieldLog,
    });

    super.dispose();
  }

  MobileTextFieldDemoConfig _createDemoConfig() {
    int? minLines;
    int? maxLines;
    switch (_sizeMode) {
      case _TextFieldSizeMode.singleLine:
        _textController.text = widget.initialText.copyText(0);
        minLines = 1;
        maxLines = 1;
        break;
      case _TextFieldSizeMode.short:
        _textController.text = widget.initialText.copyText(0);
        maxLines = 5;
        break;
      case _TextFieldSizeMode.tall:
        _textController.text = widget.initialText.copyText(0);
        // no-op
        break;
      case _TextFieldSizeMode.empty:
        _textController.text = AttributedText();
        minLines = 1;
        maxLines = 1;
        break;
    }

    return MobileTextFieldDemoConfig(
      controller: _textController,
      styleBuilder: _styleBuilder,
      minLines: minLines,
      maxLines: maxLines,
      showDebugPaint: _showDebugPaint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(builder: (context, isKeyboardVisible) {
      return Column(
        children: [
          Expanded(
            child: Scaffold(
              body: Focus(
                focusNode: _screenFocusNode,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: TapRegion(
                        groupId: widget.textFieldTapRegionGroupId,
                        onTapOutside: (_) => widget.textFieldFocusNode.unfocus(),
                        child: widget.createTextField(_createDemoConfig()),
                      ),
                    ),
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showDebugPaint = !_showDebugPaint;
                  });
                },
                child: const Icon(Icons.bug_report),
              ),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _sizeMode == _TextFieldSizeMode.singleLine
                    ? 0
                    : _sizeMode == _TextFieldSizeMode.short
                        ? 1
                        : _sizeMode == _TextFieldSizeMode.tall
                            ? 2
                            : 3,
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
                  BottomNavigationBarItem(
                    icon: Icon(Icons.short_text),
                    label: 'Empty',
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
                    } else if (newIndex == 3) {
                      _sizeMode = _TextFieldSizeMode.empty;
                    }
                  });
                },
              ),
            ),
          ),
          if (isKeyboardVisible)
            MobileStyleBar(
              textController: _textController,
            ),
        ],
      );
    });
  }

  TextStyle _styleBuilder(Set<Attribution> attributions) {
    return TextStyle(
      color: Colors.black,
      fontSize: 22,
      height: 1.4,
      fontWeight: attributions.contains(boldAttribution) ? FontWeight.bold : FontWeight.normal,
      fontStyle: attributions.contains(italicsAttribution) ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine(
        [
          if (attributions.contains(underlineAttribution)) TextDecoration.underline,
          if (attributions.contains(strikethroughAttribution)) TextDecoration.lineThrough,
        ],
      ),
    );
  }
}

enum _TextFieldSizeMode {
  singleLine,
  short,
  tall,
  empty,
}

class MobileTextFieldDemoConfig {
  const MobileTextFieldDemoConfig({
    required this.controller,
    required this.styleBuilder,
    this.minLines,
    this.maxLines,
    required this.showDebugPaint,
  });

  final ImeAttributedTextEditingController controller;
  final AttributionStyleBuilder styleBuilder;
  final int? minLines;
  final int? maxLines;
  final bool showDebugPaint;
}
