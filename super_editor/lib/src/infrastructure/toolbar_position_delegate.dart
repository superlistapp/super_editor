import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/super_textfield/metrics.dart';

final _log = textFieldLog;

/// A [SingleChildLayoutDelegate] that interprets its child as a text editing
/// toolbar and positions that toolbar either above [desiredTopAnchorInTextField],
/// or below [desiredBottomAnchorInTextField].
class ToolbarPositionDelegate extends SingleChildLayoutDelegate {
  ToolbarPositionDelegate({
    required this.textFieldGlobalOffset,
    required this.desiredTopAnchorInTextField,
    required this.desiredBottomAnchorInTextField,
    this.screenPadding,
  });

  /// The global screen `Offset` of the text field, used to map local anchor
  /// point `Offset`s to global screen coordinates.
  final Offset textFieldGlobalOffset;

  /// The `Offset` within the text field, above which the toolbar positions
  /// itself.
  ///
  /// If the toolbar can't fit above the `desiredTopAnchorInTextField` without
  /// exceeding the available screen safe space, then the toolbar instead
  /// positions itself below the [desiredBottomAnchorInTextField].
  ///
  /// The `desiredTopAnchorInTextField` typically differs from
  /// [desiredBottomAnchorInTextField] because the top anchor `Offset`
  /// sits on the top of a line of text, while the bottom anchor `Offset`
  /// sits on the bottom of a line of text.
  final Offset desiredTopAnchorInTextField;

  /// The `Offset` within the text field, below which the toolbar positions
  /// itself.
  ///
  /// The toolbar is only positioned beneath `desiredBottomAnchorInTextField`
  /// if the toolbar cannot fit above [desiredTopAnchorInTextField].
  ///
  /// The [desiredTopAnchorInTextField] typically differs from
  /// `desiredBottomAnchorInTextField` because the top anchor `Offset`
  /// sits on the top of a line of text, while the bottom anchor `Offset`
  /// sits on the bottom of a line of text.
  final Offset desiredBottomAnchorInTextField;

  /// Minimum space from the screen edges.
  final EdgeInsets? screenPadding;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final heightNeeded = childSize.height + gapBetweenToolbarAndContent + (screenPadding?.top ?? 0.0);
    final fitsAboveTextField = (textFieldGlobalOffset.dy + desiredTopAnchorInTextField.dy) > heightNeeded;
    final desiredAnchor = fitsAboveTextField
        ? desiredTopAnchorInTextField
        : (desiredBottomAnchorInTextField + Offset(0, childSize.height));

    final desiredTopLeft = (desiredAnchor - Offset(childSize.width / 2, childSize.height)) + textFieldGlobalOffset;

    double x = max(desiredTopLeft.dx, (screenPadding?.left ?? 0));
    x = min(x, size.width - childSize.width - (screenPadding?.right ?? 0));

    final constrainedOffset = Offset(x, desiredTopLeft.dy);

    _log.finer('ToolbarPositionDelegate:');
    _log.finer(' - available space: $size');
    _log.finer(' - child size: $childSize');
    _log.finer(' - text field offset: $textFieldGlobalOffset');
    _log.finer(' - ideal y-position: ${textFieldGlobalOffset.dy + desiredTopAnchorInTextField.dy}');
    _log.finer(' - fits above text field: $fitsAboveTextField');
    _log.finer(' - desired anchor: $desiredAnchor');
    _log.finer(' - desired top left: $desiredTopLeft');
    _log.finer(' - actual offset: $constrainedOffset');

    return constrainedOffset;
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) {
    return true;
  }
}
