import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'desktop_textfield.dart';

/// Widget that wraps a [SuperTextField] and handles desired gestures on
/// desktop that go beyond the standard interactions of a [SuperTextField].
class SuperTextFieldDesktopGestureExtensions extends StatefulWidget {
  static SuperTextFieldDesktopGestureExtensionsState? of(BuildContext context) {
    return context.findAncestorStateOfType();
  }

  const SuperTextFieldDesktopGestureExtensions({
    Key? key,
    required this.superTextFieldKey,
    this.onTapDown,
    this.onTapUp,
    this.onRightTapDown,
    this.onRightTapUp,
    required this.child,
  }) : super(key: key);

  /// [GlobalKey] that's bound to the [SuperTextField] within this
  /// [SuperTextFieldDesktopGestureExtensions].
  final GlobalKey superTextFieldKey;

  final GestureOverrideResult Function(SuperTextFieldTapDetails)? onTapDown;

  final GestureOverrideResult Function(SuperTextFieldTapDetails)? onTapUp;

  final GestureOverrideResult Function(SuperTextFieldTapDetails)? onRightTapDown;

  final GestureOverrideResult Function(SuperTextFieldTapDetails)? onRightTapUp;

  /// This widget's child, which should include a [SuperTextField] that's
  /// bound to [superTextFieldKey].
  final Widget child;

  @override
  State<SuperTextFieldDesktopGestureExtensions> createState() => SuperTextFieldDesktopGestureExtensionsState();
}

class SuperTextFieldDesktopGestureExtensionsState extends State<SuperTextFieldDesktopGestureExtensions>
    with SuperTextFieldGestureOverrides {
  @override
  GestureOverrideResult onTapDown(SuperTextFieldTapDetails details) {
    return widget.onTapDown?.call(details) ?? GestureOverrideResult.notHandled;
  }

  @override
  GestureOverrideResult onTapUp(SuperTextFieldTapDetails details) {
    return widget.onTapUp?.call(details) ?? GestureOverrideResult.notHandled;
  }

  void _onRightTapDown(TapDownDetails details) {
    widget.onRightTapDown?.call(_tapDetailsFromTapDown(details));
  }

  void _onRightTapUp(TapUpDetails details) {
    widget.onRightTapUp?.call(_tapDetailsFromTapUp(details));
  }

  // Converts a Flutter `TapDownDetails` to our `SuperTextFieldTapDetails`.
  SuperTextFieldTapDetails _tapDetailsFromTapDown(TapDownDetails details) {
    final textLayout = (widget.superTextFieldKey.currentState as ProseTextBlock).textLayout;
    final textBox = (widget.superTextFieldKey.currentContext)!.findRenderObject() as RenderBox;
    final nearestTextPosition = textLayout.getPositionNearestToOffset(
      textBox.globalToLocal(details.globalPosition),
    );

    return SuperTextFieldTapDetails(
      globalOffset: details.globalPosition,
      textFieldRenderBox: textBox,
      nearestTextPosition: nearestTextPosition,
    );
  }

  // Converts a Flutter `TapUpDetails` to our `SuperTextFieldTapDetails`.
  SuperTextFieldTapDetails _tapDetailsFromTapUp(TapUpDetails details) {
    final textLayout = (widget.superTextFieldKey.currentState as ProseTextBlock).textLayout;
    final textBox = (widget.superTextFieldKey.currentContext)!.findRenderObject() as RenderBox;
    final nearestTextPosition = textLayout.getPositionNearestToOffset(
      textBox.globalToLocal(details.globalPosition),
    );

    return SuperTextFieldTapDetails(
      globalOffset: details.globalPosition,
      textFieldRenderBox: textBox,
      nearestTextPosition: nearestTextPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: widget.onRightTapDown != null ? _onRightTapDown : null,
      onSecondaryTapUp: widget.onRightTapUp != null ? _onRightTapUp : null,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
