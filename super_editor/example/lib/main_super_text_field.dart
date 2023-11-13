import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field.dart';

void main() {
  runApp(
    MaterialApp(
      home: _SuperTextFieldDemo(),
    ),
  );
}

class _SuperTextFieldDemo extends StatefulWidget {
  const _SuperTextFieldDemo();

  @override
  State<_SuperTextFieldDemo> createState() => _SuperTextFieldDemoState();
}

class _SuperTextFieldDemoState extends State<_SuperTextFieldDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Shortcuts(
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.escape): ExceptionIntent("This should never execute!"),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (DismissIntent intent) {
              print("Action executed for dismiss intent");
              return null;
            }),
            ExceptionIntent: CallbackAction<ExceptionIntent>(onInvoke: (ExceptionIntent intent) {
              throw Exception(intent.message);
            }),
          },
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleLineTextField(),
                  const SizedBox(height: 16),
                  MultiLineTextField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SingleLineTextField extends StatefulWidget {
  const SingleLineTextField({super.key});

  @override
  State<SingleLineTextField> createState() => _SingleLineTextFieldState();
}

class _SingleLineTextFieldState extends State<SingleLineTextField> {
  final _focusNode = FocusNode();
  late final _textController = ImeAttributedTextEditingController(
    controller: AttributedTextEditingController(),
  );

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: ListenableBuilder(
        listenable: _focusNode,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _focusNode.hasFocus ? Colors.blue : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: child,
          );
        },
        child: SuperTextField(
          focusNode: _focusNode,
          textController: _textController,
          textStyleBuilder: (attributions) {
            return defaultTextFieldStyleBuilder(attributions).copyWith(
              color: Colors.black,
            );
          },
          hintBuilder: (_) => Text(
            "Type some text...",
            style: TextStyle(color: Colors.grey),
          ),
          minLines: 1,
          maxLines: 1,
          inputSource: TextInputSource.ime,
          imeConfiguration: TextInputConfiguration(keyboardAppearance: Brightness.light),
          selectorHandlers: {
            ...defaultTextFieldSelectorHandlers,
            MacOsSelectors.cancelOperation: ({
              required SuperTextFieldContext textFieldContext,
            }) {
              print("Intercepted ESC selector");
              Actions.maybeInvoke(context, DismissIntent());
            },
          },
        ),
      ),
    );
  }
}

class MultiLineTextField extends StatefulWidget {
  const MultiLineTextField({super.key});

  @override
  State<MultiLineTextField> createState() => _MultiLineTextFieldState();
}

class _MultiLineTextFieldState extends State<MultiLineTextField> {
  final _focusNode = FocusNode();
  late final _textController = ImeAttributedTextEditingController(
    controller: AttributedTextEditingController(),
  );

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: ListenableBuilder(
        listenable: _focusNode,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _focusNode.hasFocus ? Colors.blue : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: child,
          );
        },
        child: SuperTextField(
          focusNode: _focusNode,
          textController: _textController,
          textStyleBuilder: (attributions) {
            return defaultTextFieldStyleBuilder(attributions).copyWith(
              color: Colors.black,
            );
          },
          hintBuilder: (_) => Text(
            "Type some text...",
            style: TextStyle(color: Colors.grey),
          ),
          minLines: 5,
          maxLines: 5,
          inputSource: TextInputSource.ime,
          imeConfiguration: TextInputConfiguration(keyboardAppearance: Brightness.light),
          selectorHandlers: {
            ...defaultTextFieldSelectorHandlers,
          },
        ),
      ),
    );
  }
}

class ExceptionIntent extends Intent {
  const ExceptionIntent(this.message);

  final String message;
}
