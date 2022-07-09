import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// Demo of [SuperTextField] with a context menu that opens in response
/// to various gestures on desktop.
class TextFieldWithContextMenuDemo extends StatefulWidget {
  @override
  _TextFieldWithContextMenuDemoState createState() => _TextFieldWithContextMenuDemoState();
}

class _TextFieldWithContextMenuDemoState extends State<TextFieldWithContextMenuDemo> {
  final _superTextFieldKey = GlobalKey();

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

  GestureOverrideResult _onTapDown(details) {
    if (_isCtrlPressed && defaultTargetPlatform == TargetPlatform.macOS) {
      _contextMenuOverlay.show(context, details.globalOffset);
      return GestureOverrideResult.handled;
    }

    return GestureOverrideResult.notHandled;
  }

  GestureOverrideResult _onRightTapDown(details) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _contextMenuOverlay.show(context, details.globalOffset);
      return GestureOverrideResult.handled;
    }

    return GestureOverrideResult.notHandled;
  }

  GestureOverrideResult _onRightTapUp(details) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _contextMenuOverlay.show(context, details.globalOffset);
      return GestureOverrideResult.handled;
    }

    return GestureOverrideResult.notHandled;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: conditionally add gesture callbacks when conditions call for them.
    // For example, for ALT + LEFT CLICK, start with no callback. When the keyboard
    // listener reports ALT is pressed, add the callback. Do this in two ways: first,
    // immediately call replaceGestureRecognizers on the RawGestureDetectorState, and
    // then in the next build, include the callback in the widget tree.

    return Center(
      child: SuperTextFieldDesktopGestureExtensions(
        superTextFieldKey: _superTextFieldKey,
        onTapDown: _onTapDown,
        onRightTapDown: _onRightTapDown,
        onRightTapUp: _onRightTapUp,
        child: _buildTextField(),
      ),
    );
  }

  Widget _buildTextField() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 300),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
        ),
        child: SuperTextField(
          key: _superTextFieldKey,
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
        ),
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
