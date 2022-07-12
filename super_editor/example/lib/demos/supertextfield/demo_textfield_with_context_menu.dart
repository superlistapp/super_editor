import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Demo of [SuperTextField] with a context menu that opens in response
/// to various gestures on desktop.
class TextFieldWithContextMenuDemo extends StatefulWidget {
  @override
  _TextFieldWithContextMenuDemoState createState() => _TextFieldWithContextMenuDemoState();
}

class _TextFieldWithContextMenuDemoState extends State<TextFieldWithContextMenuDemo> {
  GlobalKey? _textFieldKey;
  late final _contextMenuOverlay;

  KeyMessageHandler? _existingKeyMessageHandler;
  bool _isCtrlPressed = false;

  @override
  void initState() {
    super.initState();
    _contextMenuOverlay = _ContextMenuOverlay();

    _existingKeyMessageHandler = ServicesBinding.instance.keyEventManager.keyMessageHandler;
    ServicesBinding.instance.keyEventManager.keyMessageHandler = _handleGlobalKeyMessage;
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyEventManager.keyMessageHandler = _existingKeyMessageHandler;

    _contextMenuOverlay.hide();
    super.dispose();
  }

  bool _handleGlobalKeyMessage(KeyMessage keyMessage) {
    for (final event in keyMessage.events) {
      if (event.logicalKey.synonyms.contains(LogicalKeyboardKey.control)) {
        if (event is KeyDownEvent) {
          setState(() {
            _isCtrlPressed = true;
          });
        } else if (event is KeyUpEvent) {
          setState(() {
            _isCtrlPressed = false;
          });
        }
      }
    }

    return _existingKeyMessageHandler?.call(keyMessage) ?? false;
  }

  void _onTapDown(TapDownDetails details) {
    if (_isCtrlPressed && defaultTargetPlatform == TargetPlatform.macOS) {
      _contextMenuOverlay.show(context, details.globalPosition);
    }
  }

  void _onRightTapDown(TapDownDetails details) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _contextMenuOverlay.show(context, details.globalPosition);

      // This shows you how you would calculate the text position for
      // a gesture override.
      final textFieldBox = _textFieldKey!.currentContext!.findRenderObject() as RenderBox;
      final textLayout = (_textFieldKey!.currentState as ProseTextBlock).textLayout;
      final textPosition = textLayout.getPositionNearestToOffset(
        textFieldBox.globalToLocal(details.globalPosition),
      );
      print("You right-clicked near text position: $textPosition");
    }
  }

  void _onRightTapUp(TapUpDetails details) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _contextMenuOverlay.show(context, details.globalPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(),
            const SizedBox(height: 24),
            _buildDescription(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: SuperTextField(
        hintBuilder: (context) {
          return Text(
            "enter text here...",
            style: const TextStyle(color: Colors.grey),
          );
        },
        textStyleBuilder: (_) {
          return const TextStyle(
            color: Colors.black,
            fontSize: 18,
          );
        },
        gestureOverrideBuilder: _gestureOverrideBuilder,
      ),
    );
  }

  Widget _gestureOverrideBuilder(BuildContext context, textFieldGlobalKey, [Widget? child]) {
    _textFieldKey = textFieldGlobalKey;
    return GestureDetector(
      onTapDown: _onTapDown,
      onSecondaryTapDown: _onRightTapDown,
      onSecondaryTapUp: _onRightTapUp,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  Widget _buildDescription() {
    return const Text(
      "This SuperTextField includes gesture overrides:\n"
      " • Right tap down on Mac to open a context menu\n"
      " • Right tap up on Windows to open a context menu\n"
      " • Control + Left tap down on Mac to open a context menu",
      style: TextStyle(
        color: Colors.grey,
        fontSize: 14,
        height: 1.8,
      ),
    );
  }
}

class _ContextMenuOverlay {
  OverlayEntry? _entry;
  late Offset _globalOffset;

  void show(BuildContext context, Offset globalOffset) {
    _globalOffset = globalOffset;

    if (_entry == null) {
      _entry = OverlayEntry(builder: (innerContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => hide(),
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              left: _globalOffset.dx,
              top: _globalOffset.dy,
              child: Container(
                width: 200,
                height: 125,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        );
      });

      Overlay.of(context)!.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}
