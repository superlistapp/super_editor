import 'package:example/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Demo of the simplest possible delta-based input system, for use when
/// debugging issues and concerns with delta-based input without bringing
/// all the rest of Super Editor into the picture.
class SimpleDeltasInputDemo extends StatefulWidget {
  @override
  _SimpleDeltasInputState createState() => _SimpleDeltasInputState();
}

class _SimpleDeltasInputState extends State<SimpleDeltasInputDemo> implements DeltaTextInputClient {
  final _textGlobalKey = GlobalKey(debugLabel: "text_input");
  AttributedText _text = AttributedText(text: "Hello, world!");

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _detachFromIme();
    super.dispose();
  }

  void _onTapOnText(TapUpDetails details) {
    final globalTapOffset = details.globalPosition;
    final textBox = _textGlobalKey.currentContext!.findRenderObject() as RenderBox;
    final textTapOffset = textBox.globalToLocal(globalTapOffset);

    final textLayout = _textGlobalKey.currentState as TextLayout;
    final textTapPosition = textLayout.getPositionNearestToOffset(textTapOffset);
    appLog.info("User tapped at text offset ${textTapPosition.offset}");

    setState(() {
      _currentTextEditingValue = TextEditingValue(
        text: _text.text,
        selection: TextSelection.collapsed(offset: textTapPosition.offset),
      );
    });

    _connectToIme();
    _sendTextEditingValueToIme();
  }

  TextInputConnection? _inputConnection;
  void _connectToIme() {
    if (_inputConnection != null) {
      // Already connected
      return;
    }

    _inputConnection = TextInput.attach(
      this,
      _createInputConfiguration(),
    );

    _inputConnection!
      ..show()
      ..setEditingState(currentTextEditingValue!);

    appLog.fine('Is attached to input client? ${_inputConnection!.attached}');
  }

  TextInputConfiguration _createInputConfiguration() {
    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: false,
      enableSuggestions: false,
      inputAction: TextInputAction.done,
      keyboardAppearance: MediaQuery.of(context).platformBrightness,
    );
  }

  void _detachFromIme() {
    if (_inputConnection == null) {
      return;
    }

    appLog.info('Detaching TextInputClient from TextInput.');

    _inputConnection!.close();
    _currentTextEditingValue = null;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue? _currentTextEditingValue;

  void _sendTextEditingValueToIme() {
    if (_inputConnection == null) {
      return;
    }
    if (_currentTextEditingValue == null) {
      return;
    }

    _inputConnection!.setEditingState(_currentTextEditingValue!);
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void performAction(TextInputAction action) {
    // no-op
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // no-op
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // no-op
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    final initialTextEditingValue = currentTextEditingValue;

    appLog.info("Received list of text editing deltas.");
    for (final delta in textEditingDeltas) {
      appLog.info(" - delta: $delta");
      appLog.info(" - old text: ${delta.oldText}");
      if (delta is TextEditingDeltaInsertion) {
        appLog.info(" - text inserted: ${delta.textInserted}");
        appLog.info(" - insertion offset: ${delta.insertionOffset}");
      } else if (delta is TextEditingDeltaReplacement) {
        appLog.info(" - replacing: ${delta.textReplaced}");
        appLog.info(" - with text: ${delta.replacementText}");
        appLog.info(" - replaced range: ${delta.replacedRange}");
      } else if (delta is TextEditingDeltaDeletion) {
        appLog.info(" - text deleted: ${delta.textDeleted}");
        appLog.info(" - deleted range: ${delta.deletedRange}");
      }

      setState(() {
        _currentTextEditingValue = delta.apply(currentTextEditingValue!);
        _text = AttributedText(text: _currentTextEditingValue!.text);
      });
    }

    if (currentTextEditingValue != initialTextEditingValue) {
      _sendTextEditingValueToIme();
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // no-op: we use deltas, not full text changes
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // no-op
  }

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
  }

  @override
  void showToolbar() {
    // TODO: implement showToolbar
  }

  @override
  void connectionClosed() {
    // no-op
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTapUp: _onTapOnText,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: SuperTextWithSelection.single(
            key: _textGlobalKey,
            richText: _text.computeTextSpan(
              (attributions) => const TextStyle(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            userSelection: UserSelection(
              selection: _currentTextEditingValue?.selection ?? const TextSelection.collapsed(offset: -1),
              hasCaret: true,
            ),
          ),
        ),
      ),
    );
  }
}
