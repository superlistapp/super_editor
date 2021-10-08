import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/text_scrollview.dart';
import 'package:super_editor/src/infrastructure/super_textfield/ios/_editing_controls.dart';

import '../../attributed_text.dart';
import '../../super_selectable_text.dart';
import '../super_textfield.dart' hide SuperTextFieldScrollview, SuperTextFieldScrollviewState;
import '_caret.dart';
import '_floating_cursor.dart';
import '_toolbar.dart';
import '_user_interaction.dart';

export '../infrastructure/magnifier.dart';
export '_caret.dart';
export '_handles.dart';
export '_toolbar.dart';
export '_user_interaction.dart';

final _log = iosTextFieldLog;

class SuperIOSTextField extends StatefulWidget {
  const SuperIOSTextField({
    Key? key,
    this.focusNode,
    this.textController,
    required this.caretColor,
    required this.selectionColor,
    required this.handlesColor,
    this.textStyleBuilder = defaultStyleBuilder,
    this.minLines,
    this.maxLines = 1,
    this.lineHeight,
    this.textInputAction = TextInputAction.done,
    this.showDebugPaint = false,
    this.onPerformActionPressed,
  })  : assert(minLines == null || minLines == 1 || lineHeight != null, 'minLines > 1 requires a non-null lineHeight'),
        assert(maxLines == null || maxLines == 1 || lineHeight != null, 'maxLines > 1 requires a non-null lineHeight'),
        super(key: key);

  /// [FocusNode] attached to this text field.
  final FocusNode? focusNode;

  /// Controller that owns the text content and text selection for
  /// this text field.
  final ImeAttributedTextEditingController? textController;

  /// Text style factory that creates styles for the content in
  /// [textController] based on the attributions in that content.
  final AttributionStyleBuilder textStyleBuilder;

  /// Color of the caret.
  final Color caretColor;

  /// Color of the selection rectangle for selected text.
  final Color selectionColor;

  /// Color of the selection handles.
  final Color handlesColor;

  /// The minimum height of this text field, represented as a
  /// line count.
  ///
  /// If [minLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [maxLines]
  ///  * [lineHeight]
  final int? minLines;

  /// The maximum height of this text field, represented as a
  /// line count.
  ///
  /// If text exceeds the maximum line height, scrolling dynamics
  /// are added to accommodate the overflowing text.
  ///
  /// If [maxLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [minLines]
  ///  * [lineHeight]
  final int? maxLines;

  /// The height of a single line of text in this text field, used
  /// with [minLines] and [maxLines] to size the text field.
  ///
  /// An explicit [lineHeight] is required because rich text in this
  /// text field might have lines of varying height, which would
  /// result in a constantly changing text field height during scrolling.
  /// To avoid that situation, a single, explicit [lineHeight] is
  /// provided and used for all text field height calculations.
  final double? lineHeight;

  /// The type of action associated with the action button on the mobile
  /// keyboard.
  final TextInputAction textInputAction;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  /// Callback invoked when the user presses the "action" button
  /// on the keyboard, e.g., "done", "call", "emergency", etc.
  final Function(TextInputAction)? onPerformActionPressed;

  @override
  _SuperIOSTextFieldState createState() => _SuperIOSTextFieldState();
}

class _SuperIOSTextFieldState extends State<SuperIOSTextField> with SingleTickerProviderStateMixin {
  final _textFieldKey = GlobalKey();
  final _textFieldLayerLink = LayerLink();
  final _textContentLayerLink = LayerLink();
  final _scrollKey = GlobalKey<IOSTextFieldTouchInteractorState>();
  final _textContentKey = GlobalKey<SuperSelectableTextState>();

  late FocusNode _focusNode;

  late ImeAttributedTextEditingController _textEditingController;
  late FloatingCursorController _floatingCursorController;

  final _magnifierLayerLink = LayerLink();
  late IOSEditingOverlayController _editingOverlayController;

  late TextScrollController _textScrollController;

  // OverlayEntry that displays the toolbar and magnifier, and
  // positions the invisible touch targets for base/extent
  // dragging.
  OverlayEntry? _controlsOverlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode())
      ..unfocus()
      ..addListener(_onFocusChange);
    if (_focusNode.hasFocus) {
      _showHandles();
    }

    _textEditingController = (widget.textController ?? ImeAttributedTextEditingController())
      ..addListener(_onTextOrSelectionChange)
      ..onIOSFloatingCursorChange = _onFloatingCursorChange;

    _textScrollController = TextScrollController(
      textController: _textEditingController,
      tickerProvider: this,
    )..addListener(_onTextScrollChange);

    _floatingCursorController = FloatingCursorController(
      textController: _textEditingController,
    );

    _editingOverlayController = IOSEditingOverlayController(
      textController: _textEditingController,
      magnifierFocalPoint: _magnifierLayerLink,
    );
  }

  @override
  void didUpdateWidget(SuperIOSTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
      }
      _focusNode.addListener(_onFocusChange);
    }

    if (widget.textController != oldWidget.textController) {
      _textEditingController
        ..removeListener(_onTextOrSelectionChange)
        ..onIOSFloatingCursorChange = null;

      if (widget.textController != null) {
        _textEditingController = widget.textController!;
      } else {
        _textEditingController = ImeAttributedTextEditingController();
      }

      _textEditingController
        ..addListener(_onTextOrSelectionChange)
        ..onIOSFloatingCursorChange = _onFloatingCursorChange;
    }

    if (widget.showDebugPaint != oldWidget.showDebugPaint) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        _rebuildHandles();
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    // On Hot Reload we need to remove any visible overlay controls and then
    // bring them back a frame later to avoid having the controls attempt
    // to access the layout of the text. The text layout is not immediately
    // available upon Hot Reload. Accessing it results in an exception.
    _removeEditingOverlayControls();

    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      _showHandles();
    });
  }

  @override
  void dispose() {
    _removeEditingOverlayControls();

    _textEditingController
      ..removeListener(_onTextOrSelectionChange)
      ..onIOSFloatingCursorChange = null;
    if (widget.textController == null) {
      _textEditingController.dispose();
    }

    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    _textScrollController
      ..removeListener(_onTextScrollChange)
      ..dispose();

    super.dispose();
  }

  bool get _isMultiline => widget.minLines != 1 || widget.maxLines != 1;

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (!_textEditingController.isAttachedToIme) {
        _log.info('Attaching TextInputClient to TextInput');
        setState(() {
          _textEditingController.attachToIme(
            textInputAction: widget.textInputAction,
          );

          _showHandles();
        });
      }
    } else {
      _log.info('Lost focus. Detaching TextInputClient from TextInput.');
      setState(() {
        _textEditingController.detachFromIme();
        _textEditingController.selection = const TextSelection.collapsed(offset: -1);
        _removeEditingOverlayControls();
      });
    }
  }

  void _onTextOrSelectionChange() {
    if (_textEditingController.selection.isCollapsed) {
      _editingOverlayController.hideToolbar();
    }
  }

  void _onTextScrollChange() {
    if (_controlsOverlayEntry != null) {
      _rebuildHandles();
    }
  }

  /// Displays [IOSEditingControls] in the app's [Overlay], if not already
  /// displayed.
  void _showHandles() {
    if (_controlsOverlayEntry == null) {
      _controlsOverlayEntry = OverlayEntry(builder: (overlayContext) {
        return IOSEditingControls(
          editingController: _editingOverlayController,
          textScrollController: _textScrollController,
          textFieldLayerLink: _textFieldLayerLink,
          textFieldKey: _textFieldKey,
          textContentLayerLink: _textContentLayerLink,
          textContentKey: _textContentKey,
          handleColor: widget.handlesColor,
          popoverToolbarBuilder: _defaultPopoverToolbarBuilder,
          showDebugPaint: widget.showDebugPaint,
        );
      });

      Overlay.of(context)!.insert(_controlsOverlayEntry!);
    }
  }

  /// Rebuilds the [IOSEditingControls] in the app's [Overlay], if
  /// they're currently displayed.
  void _rebuildHandles() {
    _controlsOverlayEntry?.markNeedsBuild();
  }

  /// Removes [IOSEditingControls] from the app's [Overlay], if they're
  /// currently displayed.
  void _removeEditingOverlayControls() {
    if (_controlsOverlayEntry != null) {
      _controlsOverlayEntry!.remove();
      _controlsOverlayEntry = null;
    }
  }

  void _onFloatingCursorChange(RawFloatingCursorPoint point) {
    _floatingCursorController.updateFloatingCursor(_textContentKey.currentState!, point);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      key: _textFieldKey,
      focusNode: _focusNode,
      child: CompositedTransformTarget(
        link: _textFieldLayerLink,
        child: IOSTextFieldTouchInteractor(
          focusNode: _focusNode,
          selectableTextKey: _textContentKey,
          textFieldLayerLink: _textFieldLayerLink,
          textController: _textEditingController,
          editingOverlayController: _editingOverlayController,
          textScrollController: _textScrollController,
          isMultiline: _isMultiline,
          handleColor: widget.handlesColor,
          showDebugPaint: widget.showDebugPaint,
          child: TextScrollView(
            key: _scrollKey,
            textScrollController: _textScrollController,
            textKey: _textContentKey,
            textEditingController: _textEditingController,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            lineHeight: widget.lineHeight,
            perLineAutoScrollDuration: const Duration(milliseconds: 100),
            showDebugPaint: widget.showDebugPaint,
            child: ListenableBuilder(
              listenable: _textEditingController,
              builder: (context) {
                final textSpan = _textEditingController.text.text.isNotEmpty
                    ? _textEditingController.text.computeTextSpan(widget.textStyleBuilder)
                    : AttributedText(text: 'enter text').computeTextSpan(
                        (attributions) => widget.textStyleBuilder(attributions).copyWith(color: Colors.grey));

                return CompositedTransformTarget(
                  link: _textContentLayerLink,
                  child: Stack(
                    children: [
                      // TODO: switch out textSelectionDecoration and textCaretFactory
                      //       for backgroundBuilders and foregroundBuilders, respectively
                      //
                      //       add the floating cursor as a foreground builder
                      SuperSelectableText(
                        key: _textContentKey,
                        textSpan: textSpan,
                        textSelection: _textEditingController.selection,
                        textSelectionDecoration: TextSelectionDecoration(selectionColor: widget.selectionColor),
                        showCaret: true,
                        textCaretFactory: IOSTextFieldCaretFactory(
                          color: _floatingCursorController.isShowingFloatingCursor ? Colors.grey : widget.caretColor,
                          width: 2,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: IOSFloatingCursor(
                          controller: _floatingCursorController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Widget _defaultPopoverToolbarBuilder(BuildContext context, IOSEditingOverlayController controller) {
  return IOSTextfieldToolbar(
    onCutPressed: () {
      final textController = controller.textController;
      final selection = textController.selection;
      if (selection.isCollapsed) {
        return;
      }

      final selectedText = selection.textInside(textController.text.text);

      textController.deleteSelectedText();

      Clipboard.setData(ClipboardData(text: selectedText));
    },
    onCopyPressed: () {
      final textController = controller.textController;
      final selection = textController.selection;
      final selectedText = selection.textInside(textController.text.text);

      Clipboard.setData(ClipboardData(text: selectedText));
    },
    onPastePressed: () async {
      final clipboardContent = await Clipboard.getData('text/plain');
      if (clipboardContent == null || clipboardContent.text == null) {
        return;
      }

      final textController = controller.textController;
      final selection = textController.selection;
      if (selection.isCollapsed) {
        textController.insertAtCaret(text: clipboardContent.text!);
      } else {
        textController.replaceSelectionWithUnstyledText(replacementText: clipboardContent.text!);
      }
    },
  );
}
