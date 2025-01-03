import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/super_text_field.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Tap handler that can (optionally) respond to single, double, and triple taps, as well as dictate the cursor
/// appearance on desktop.
abstract class SuperTextFieldTapHandler {
  MouseCursor? mouseCursorForContentHover(SuperTextFieldGestureDetails details) => null;

  TapHandlingInstruction onTapDown(SuperTextFieldGestureDetails details) => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onTapUp(SuperTextFieldGestureDetails details) => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onTapCancel() => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onDoubleTapDown(SuperTextFieldGestureDetails details) =>
      TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onDoubleTapUp(SuperTextFieldGestureDetails details) => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onDoubleTapCancel() => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onTripleTapDown(SuperTextFieldGestureDetails details) =>
      TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onTripleTapUp(SuperTextFieldGestureDetails details) => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onTripleTapCancel() => TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onSecondaryTapDown(SuperTextFieldGestureDetails details) =>
      TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onSecondaryTapUp(SuperTextFieldGestureDetails details) =>
      TapHandlingInstruction.continueHandling;

  TapHandlingInstruction onSecondaryTapCancel() => TapHandlingInstruction.continueHandling;
}

/// Information about a gesture that happened within a [SuperTextField].
class SuperTextFieldGestureDetails {
  SuperTextFieldGestureDetails({
    required this.textLayout,
    required this.textController,
    required this.globalOffset,
    required this.layoutOffset,
    required this.textOffset,
  });

  /// The text layout of the text field.
  ///
  /// It can be used to pull information about the logical position
  /// where the tap occurred. For example, to find the [TextPosition]
  /// that is nearest to the tap.
  final ProseTextLayout textLayout;

  /// The controller that holds the current text and selection of the text field.
  /// It can be used to pull information about the text and its attributions.
  final AttributedTextEditingController textController;

  /// The position of the gesture in global coordinates.
  final Offset globalOffset;

  /// The position of the gesture in [SuperTextField]'s coordinate space. This
  /// coordinate space contains the text layout and the padding around the text.
  final Offset layoutOffset;

  /// The position of the gesture in the text coordinate space.
  final Offset textOffset;
}
