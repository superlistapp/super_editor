import 'package:flutter/material.dart';

import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// A widget that positions the OS emoji & symbols toolbar at the text field's selection.
class SuperTextFieldImeControls extends StatefulWidget {
  const SuperTextFieldImeControls({
    Key? key,
    required this.textController,
    required this.textKey,
    required this.focusNode,
    required this.child,
  }) : super(key: key);

  /// [GlobalKey] that links this [SuperTextFieldImeControls] to
  /// the [ProseTextLayout] widget that paints the text for the text field.
  final GlobalKey<ProseTextState> textKey;

  /// Controller that owns the text content and text selection for the text field.
  final ImeAttributedTextEditingController textController;

  /// [FocusNode] of the text field.
  final FocusNode focusNode;

  /// The rest of the subtree for the text field.
  final Widget child;

  @override
  State<SuperTextFieldImeControls> createState() => _SuperTextFieldImeControlsState();
}

class _SuperTextFieldImeControlsState extends State<SuperTextFieldImeControls> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onContentChanged);
    widget.focusNode.addListener(_onFocusChanged);

    if (widget.focusNode.hasFocus) {
      // We got an already focused FocusNode, we need to update the IME controls.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _onFocusChanged();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SuperTextFieldImeControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textController != oldWidget.textController) {
      oldWidget.textController.removeListener(_onContentChanged);
      widget.textController.addListener(_onContentChanged);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);

      if (widget.focusNode.hasFocus) {
        // We got an already focused FocusNode, we need to attach to the IME.
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _onFocusChanged();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onContentChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      return;
    }

    _updateImeVisualInformation();
  }

  void _onContentChanged() {
    _updateImeVisualInformation();
  }

  /// Update our size, transform to the root node coordinates, and caret rect on the IME.
  void _updateImeVisualInformation() {
    _updateSizeAndTransform();
    _updateCaretRectIfNeeded();

    // Without showing the keyboard, the panel is always positioned at the screen center after the first time.
    // I'm not sure why this is needed in SuperTextField, but not in SuperEditor.
    widget.textController.showKeyboard();
  }

  /// Update our size and transform to the root node coordinates.
  ///
  /// The OS uses the transformer to convert the position from our local coordinates to global coordinates.
  void _updateSizeAndTransform() {
    if (!widget.textController.isAttachedToIme) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;

    widget.textController.setEditableSizeAndTransform(renderBox.size, renderBox.getTransformTo(null));

    // There are some operations that might affect our transform but we can't react to them.
    // For example, the text field might be resized or moved around the screen.
    // Because of this, we update our size and transform at every frame.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateSizeAndTransform();
    });
  }

  /// Set the caret rect on IME.
  void _updateCaretRectIfNeeded() {
    if (!widget.textController.isAttachedToIme) {
      return;
    }

    final text = widget.textKey.currentState;
    if (text == null) {
      return;
    }

    final selection = widget.textController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      // The panel is displayed only for collapsed selections.
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;

    // Compute the caret rect in the text layout space.
    final position = TextPosition(offset: selection.baseOffset);
    final textLayout = text.textLayout;
    final caretOffset = textLayout.getOffsetForCaret(position);
    final caretHeight = textLayout.getHeightForCaret(position) ?? textLayout.estimatedLineHeight;
    final caretRect = caretOffset & Size(1, caretHeight);

    // Convert the coordinates from the text layout space to the text field space.
    final textRenderBox = text.context.findRenderObject() as RenderBox;
    final textOffset = renderBox.globalToLocal(textRenderBox.localToGlobal(Offset.zero));
    final caretOffsetInTextFieldSpace = caretRect.shift(textOffset);

    widget.textController.setCaretRect(caretOffsetInTextFieldSpace);

    // There are some operations that change the caret position without changing the text
    // or the selection. For example, the text field padding might change, the font size, etc.
    // Because of this, we update the caret rect at every frame.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateCaretRectIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
