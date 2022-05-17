import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// An iOS floating cursor.
///
/// Displays a red caret at a position and height determined
/// by the given [FloatingCursorController].
///
/// An [IOSFloatingCursor] should be displayed on top of the
/// associated text and it should have the same width and
/// height as the text it corresponds with.
class IOSFloatingCursor extends StatelessWidget {
  const IOSFloatingCursor({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final FloatingCursorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context) {
        return Stack(
          children: [
            if (controller.isShowingFloatingCursor)
              Positioned(
                left: controller.floatingCursorOffset.dx,
                top: controller.floatingCursorOffset.dy,
                child: Container(
                  width: 2,
                  height: controller.floatingCursorHeight,
                  color: Colors.red,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Controller for an iOS floating cursor.
///
/// Floating cursor [RawFloatingCursorPoint] data should be forwarded from a
/// [TextInputClient] to [updateFloatingCursor()], along with a [TextLayout].
/// The platform only provides pixel drag offsets, therefore the [TextLayout]
/// is needed to obtain the offset of the original selection, as well as map
/// new offsets back to [TextPosition]s.
class FloatingCursorController with ChangeNotifier {
  FloatingCursorController({
    required AttributedTextEditingController textController,
  }) : _textController = textController;

  final AttributedTextEditingController _textController;

  Offset? _floatingCursorStartOffset;
  Offset? _floatingCursorCurrentOffset;

  /// Whether the user is currently using the floating cursor.
  bool get isShowingFloatingCursor => _floatingCursorCurrentOffset != null;

  /// The current offset of the floating cursor from the top-left
  /// corner of the associated text.
  ///
  /// Callers must ensure that [isShowingFloatingCursor] is `true`
  /// before invoking [floatingCursorOffset].
  Offset get floatingCursorOffset => _floatingCursorStartOffset! + _floatingCursorCurrentOffset!;

  double _floatingCursorHeight = 0;

  /// The current height of the floating cursor.
  ///
  /// The cursor height is determined by the line height of the current
  /// [TextPosition].
  ///
  /// Returns `0.0` when the floating cursor is not being used.
  double get floatingCursorHeight => _floatingCursorHeight;

  void updateFloatingCursor(TextLayout textLayout, RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
        _floatingCursorStartOffset = textLayout.getOffsetAtPosition(_textController.selection.extent);
        _floatingCursorCurrentOffset = point.offset;

        final textPosition =
            textLayout.getPositionNearestToOffset(_floatingCursorStartOffset! + _floatingCursorCurrentOffset!);

        _floatingCursorHeight = textLayout.getLineHeightAtPosition(textPosition);

        _textController.selection = TextSelection.collapsed(
          offset: textPosition.offset,
        );
        break;
      case FloatingCursorDragState.Update:
        _floatingCursorCurrentOffset = point.offset;

        final textPosition =
            textLayout.getPositionNearestToOffset(_floatingCursorStartOffset! + _floatingCursorCurrentOffset!);

        _floatingCursorHeight = textLayout.getLineHeightAtPosition(textPosition);

        _textController.selection = TextSelection.collapsed(
          offset: textPosition.offset,
        );
        break;
      case FloatingCursorDragState.End:
        _floatingCursorStartOffset = null;
        _floatingCursorCurrentOffset = null;
        _floatingCursorHeight = 0;
        break;
    }

    notifyListeners();
  }
}
