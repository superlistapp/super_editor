import 'dart:math';

import 'package:example_docs/theme.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A Widget that allows the user to increment or decrement a [value].
///
/// Displays a textfield with the current [value], surrounded by the increment and
/// decrement buttons.
///
/// Selects all the content on the textfield upon focus.
class IncrementDecrementField extends StatefulWidget {
  const IncrementDecrementField({
    super.key,
    required this.value,
    required this.onChange,
  });

  /// The current value.
  final int value;

  /// Called when the user presses one of the buttons or when the user
  /// presses ENTER on the textfield.
  ///
  /// If the user clears the textfield, no change is reported. Instead,
  /// the textfield value is reset to the current [value].
  final void Function(int value) onChange;

  @override
  State<IncrementDecrementField> createState() => _IncrementDecrementFieldState();
}

class _IncrementDecrementFieldState extends State<IncrementDecrementField> {
  final ImeAttributedTextEditingController _controller = ImeAttributedTextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller
      ..text = AttributedText(widget.value.toString())
      ..onPerformActionPressed = _onPerformAction;

    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant IncrementDecrementField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = AttributedText(widget.value.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPerformAction(TextInputAction action) {
    if (action == TextInputAction.done) {
      final value = int.tryParse(_controller.text.text.trim());
      if (value != null) {
        widget.onChange(value);
      }

      _controller.text = AttributedText(widget.value.toString());
    }
  }

  void _onIncrement() {
    final value = int.tryParse(_controller.text.text.trim());
    if (value == null) {
      return;
    }

    widget.onChange(value + 1);
  }

  void _onDecrement() {
    final value = int.tryParse(_controller.text.text.trim());
    if (value == null) {
      return;
    }

    widget.onChange(max(value - 1, 1));
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selectAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: _onDecrement,
          style: defaultToolbarButtonStyle,
          child: const Icon(Icons.remove),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 24,
          width: 32,
          child: SuperDesktopTextField(
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            inputSource: TextInputSource.ime,
            textInputAction: TextInputAction.done,
            textController: _controller,
            minLines: 1,
            maxLines: 1,
            textStyleBuilder: (attributions) => const TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
            decorationBuilder: (context, child) {
              return Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _focusNode.hasFocus ? const Color(0xFF0B57D0) : const Color(0xFF747775),
                    width: 1,
                  ),
                ),
                child: Center(child: child),
              );
            },
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _onIncrement,
          style: defaultToolbarButtonStyle,
          child: const Icon(Icons.add),
        )
      ],
    );
  }
}
