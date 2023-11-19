import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field.dart';

/// An app that demos [SuperTextField].
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
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
  final _darkBackground = const Color(0xFF222222);
  final _lightBackground = Colors.white;
  final _brightness = ValueNotifier<Brightness>(Brightness.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _brightness,
      builder: (context, brightness, child) {
        return Theme(
          data: ThemeData(brightness: brightness),
          child: child!,
        );
      },
      child: Builder(builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;

        return Scaffold(
            body: ColoredBox(
          color: isLight ? _lightBackground : _darkBackground,
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SingleLineTextField(),
                      const SizedBox(height: 16),
                      _MultiLineTextField(),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: ListenableBuilder(
                  listenable: _brightness,
                  builder: (context, child) {
                    return child!;
                  },
                  child: _buildCornerFabs(),
                ),
              ),
            ],
          ),
        ));
      }),
    );
  }

  Widget _buildCornerFabs() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: _buildLightAndDarkModeToggle(),
    );
  }

  Widget _buildLightAndDarkModeToggle() {
    return FloatingActionButton(
      backgroundColor: _brightness.value == Brightness.light ? _darkBackground : _lightBackground,
      foregroundColor: _brightness.value == Brightness.light ? _lightBackground : _darkBackground,
      elevation: 5,
      onPressed: () {
        _brightness.value = _brightness.value == Brightness.light ? Brightness.dark : Brightness.light;
      },
      child: _brightness.value == Brightness.light
          ? const Icon(
              Icons.dark_mode,
            )
          : const Icon(
              Icons.light_mode,
            ),
    );
  }
}

class _SingleLineTextField extends StatefulWidget {
  const _SingleLineTextField();

  @override
  State<_SingleLineTextField> createState() => _SingleLineTextFieldState();
}

class _SingleLineTextFieldState extends State<_SingleLineTextField> {
  final _focusNode = FocusNode();
  final _textController = ImeAttributedTextEditingController(
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return TapRegion(
      groupId: "textfields",
      onTapOutside: (_) => _focusNode.unfocus(),
      child: TextFieldBorder(
        focusNode: _focusNode,
        borderBuilder: _borderBuilder,
        child: SuperTextField(
          focusNode: _focusNode,
          textController: _textController,
          controlsColor: isLight ? Colors.black : Colors.white,
          textStyleBuilder: (_) => _textStyleBuilder(_, isLight),
          hintBuilder: _createHintBuilder("Enter single line text..."),
          padding: const EdgeInsets.all(4),
          minLines: 1,
          maxLines: 1,
          inputSource: TextInputSource.ime,
        ),
      ),
    );
  }
}

class _MultiLineTextField extends StatefulWidget {
  const _MultiLineTextField();

  @override
  State<_MultiLineTextField> createState() => _MultiLineTextFieldState();
}

class _MultiLineTextFieldState extends State<_MultiLineTextField> {
  final _focusNode = FocusNode();
  final _textController = ImeAttributedTextEditingController(
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return TapRegion(
      groupId: "textfields",
      onTapOutside: (_) => _focusNode.unfocus(),
      child: TextFieldBorder(
        focusNode: _focusNode,
        borderBuilder: _borderBuilder,
        child: SuperTextField(
          focusNode: _focusNode,
          controlsColor: isLight ? Colors.black : Colors.white,
          textController: _textController,
          textStyleBuilder: (_) => _textStyleBuilder(_, isLight),
          hintBuilder: _createHintBuilder("Type some text..."),
          padding: const EdgeInsets.all(4),
          minLines: 5,
          maxLines: 5,
          inputSource: TextInputSource.ime,
        ),
      ),
    );
  }
}

BoxDecoration _borderBuilder(TextFieldBorderState borderState) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: borderState.hasError //
          ? Colors.red
          : borderState.hasFocus
              ? Colors.blue
              : Colors.grey.shade300,
      width: borderState.hasError ? 2 : 1,
    ),
  );
}

TextStyle _textStyleBuilder(Set<Attribution> attributions, bool isLight) {
  return defaultTextFieldStyleBuilder(attributions).copyWith(
    color: isLight ? Colors.black : Colors.white,
  );
}

WidgetBuilder _createHintBuilder(String hintText) {
  return (BuildContext context) {
    return Text(
      hintText,
      style: TextStyle(color: Colors.grey),
    );
  };
}
