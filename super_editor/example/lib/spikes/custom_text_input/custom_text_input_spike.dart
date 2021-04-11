import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Spike:
/// Create a minimal widget implementation that directly handles text input.
///
/// This spike implements:
///  - A widget that implements `TextInputClient` and opens a connection to
///    the underlying platform. This approach seems to be specifically tailored
///    to Android and iOS, where various adjustments are made to content
///    by the platform.
///  - A widget that listens to `RawKeyboard` and processes every keystroke.
///
/// Conclusion:
/// I think we should try an initial implementation using `RawKeyboard` instead
/// of `TextInputClient`. We don't need mobile affordances for desktop and web,
/// and that's most of what `TextInputClient` provides.

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: CustomTextInputSpike(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class CustomTextInputSpike extends StatefulWidget {
  @override
  _CustomTextInputSpikeState createState() => _CustomTextInputSpikeState();
}

class _CustomTextInputSpikeState extends State<CustomTextInputSpike> {
  FocusNode _rootFocusNode;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _rootFocusNode.requestFocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Focus(
        focusNode: _rootFocusNode,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextInputClientExample(),
                SizedBox(height: 100),
                RawKeyboardExample(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TextInputClientExample extends StatefulWidget {
  @override
  _TextInputClientExampleState createState() => _TextInputClientExampleState();
}

class _TextInputClientExampleState extends State<TextInputClientExample> implements TextInputClient {
  TextEditingController _editingController;
  TextInputConnection _textInputConnection;
  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // final AutofillGroupState? newAutofillGroup = AutofillGroup.of(context);
    // if (currentAutofillScope != newAutofillGroup) {
    //   _currentAutofillScope?.unregister(autofillId);
    //   _currentAutofillScope = newAutofillGroup;
    //   newAutofillGroup?.register(this);
    //   _isInAutofillContext = _isInAutofillContext || _shouldBeInAutofillContext;
    // }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    RawKeyboard.instance.removeListener(_onKeyPressed);
    _currentAutofillScope?.dispose();
    _editingController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _openInputConnection();
      RawKeyboard.instance.addListener(_onKeyPressed);
    } else {
      _closeInputConnectionIfNeeded();
      RawKeyboard.instance.removeListener(_onKeyPressed);
    }
  }

  AutofillGroupState _currentAutofillScope;
  @override
  AutofillScope get currentAutofillScope => _currentAutofillScope;

  @override
  TextEditingValue get currentTextEditingValue => _editingController.value;

  void _openInputConnection() {
    if (_textInputConnection == null) {
      _textInputConnection = TextInput.attach(this, _createTextInputConfiguration());
      _textInputConnection.show();

      // TODO: why is style being set on the input connection? does the platform make text layout decisions, too?
      // final TextStyle style = widget.style;
      // ..setStyle(
      //   fontFamily: style.fontFamily,
      //   fontSize: style.fontSize,
      //   fontWeight: style.fontWeight,
      //   textDirection: _textDirection,
      //   textAlign: widget.textAlign,
      // )
      _textInputConnection
        .setEditingState(_editingController.value);
    } else {
      _textInputConnection.show();
    }
  }

  TextInputConfiguration _createTextInputConfiguration() {
    return TextInputConfiguration(
      inputType: TextInputType.text,
      readOnly: false,
      obscureText: false,
      autocorrect: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      enableSuggestions: false,
      inputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.none,
      keyboardAppearance: Brightness.light,
      autofillConfiguration: null,
    );
  }

  @override
  void performAction(TextInputAction action) {
    print('performAction(): $action');
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    print('performPrivateCommand(): $action');
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    print('showAutocorrectionPrompRect() - start: $start, end: $end');
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    print('updateEditingValue(): "${value.text}", selection: ${value.selection}');
    _editingController.value = value;
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    print('updateFloatingCursor(): $point');
  }

  void _closeInputConnectionIfNeeded() {
    if (_textInputConnection != null) {
      _textInputConnection.close();
      _textInputConnection = null;
    }
  }

  @override
  void connectionClosed() {
    print('connectionClosed()');
  }

  void _onKeyPressed(RawKeyEvent keyEvent) {
    print('Key pressed: $keyEvent');
    if (keyEvent.logicalKey == LogicalKeyboardKey.backspace && keyEvent is RawKeyUpEvent) {
      // print(' - its backspace');
      final currentText = _editingController.text;

      if (currentText.isEmpty) {
        return;
      }

      _editingController.value = TextEditingValue(
        text: currentText.substring(0, currentText.length - 1),
        selection: _editingController.selection.copyWith(
          extentOffset: _editingController.selection.extentOffset - 1,
        ),
      );
      _textInputConnection.setEditingState(_editingController.value);
      print('Did backspace: "${_editingController.value.text}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: AnimatedBuilder(
        animation: FocusManager.instance,
        builder: (context, child) {
          return Focus(
            focusNode: _focusNode,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: child,
            ),
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 50),
          child: AnimatedBuilder(
            animation: _editingController,
            builder: (context, child) {
              return Text(
                _editingController.text,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  height: 1.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RawKeyboardExample extends StatefulWidget {
  @override
  _RawKeyboardExampleState createState() => _RawKeyboardExampleState();
}

class _RawKeyboardExampleState extends State<RawKeyboardExample> {
  TextEditingController _editingController;
  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_onKeyPressed);
    _focusNode.dispose();
    _editingController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      RawKeyboard.instance.addListener(_onKeyPressed);
    } else {
      RawKeyboard.instance.removeListener(_onKeyPressed);
    }
  }

  void _onKeyPressed(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyUpEvent) {
      return;
    }

    print('Key pressed: $keyEvent');

    if (_isCharacterKey(keyEvent.logicalKey)) {
      _editingController.value = TextEditingValue(
        text: _editingController.text + keyEvent.logicalKey.keyLabel,
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
      _editingController.value = TextEditingValue(
        text: _editingController.text + '\n',
      );
    } else if (keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      // print(' - its backspace');
      final currentText = _editingController.text;

      if (currentText.isEmpty) {
        print('Text is empty. Nothing to delete: "$currentText"');
        return;
      }

      _editingController.value = TextEditingValue(
        text: currentText.substring(0, currentText.length - 1),
        // selection: _editingController.selection.copyWith(
        //   extentOffset: _editingController.selection.extentOffset - 1,
        // ),
      );
      print('Did backspace: "${_editingController.value.text}"');
    }
  }

  bool _isCharacterKey(LogicalKeyboardKey key) {
    // keyLabel for a character should be: 'a', 'b',...,'A','B',...
    if (key.keyLabel.length != 1) {
      return false;
    }
    return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890.,/;\'[]\\`~!@#\$%^&*()_+<>?:"{}|'
        .contains(key.keyLabel);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: AnimatedBuilder(
        animation: FocusManager.instance,
        builder: (context, child) {
          return Focus(
            focusNode: _focusNode,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: child,
            ),
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 50),
          child: AnimatedBuilder(
            animation: _editingController,
            builder: (context, child) {
              return Text(
                _editingController.text,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  height: 1.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
