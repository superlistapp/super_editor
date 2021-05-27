import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../core/document.dart';
import '../core/document_layout.dart';
import '../core/document_selection.dart';
import 'document_interaction.dart';
import 'multi_node_editing.dart';

final _log = Logger(scope: 'box_component.dart');

/// Editor layout component that displays content that is either
/// entirely selected, or not selected, like an image or a
/// horizontal rule.
class BoxComponent extends StatefulWidget {
  const BoxComponent({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  _BoxComponentState createState() => _BoxComponentState();
}

class _BoxComponentState extends State<BoxComponent> with DocumentComponent {
  @override
  BinaryPosition getBeginningPosition() {
    return BinaryPosition.included();
  }

  @override
  BinaryPosition getBeginningPositionNearX(double x) {
    return BinaryPosition.included();
  }

  @override
  BinaryPosition? movePositionLeft(dynamic currentPosition, [Set<MovementModifier>? movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition? movePositionRight(dynamic currentPosition, [Set<MovementModifier>? movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition? movePositionUp(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryPosition? movePositionDown(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinarySelection? getCollapsedSelectionAt(nodePosition) {
    if (nodePosition is! BinaryPosition) {
      return null;
    }

    return BinarySelection.all();
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return null;
  }

  @override
  BinaryPosition getEndPosition() {
    return BinaryPosition.included();
  }

  @override
  getEndPositionNearX(double x) {
    return BinaryPosition.included();
  }

  @override
  Offset getOffsetForPosition(nodePosition) {
    if (nodePosition is! BinaryPosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset(myBox.size.width / 2, myBox.size.height / 2);
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! BinaryPosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset.zero & myBox.size;
  }

  @override
  Rect getRectForSelection(dynamic basePosition, dynamic extentPosition) {
    if (basePosition is! BinaryPosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $basePosition');
    }
    if (extentPosition is! BinaryPosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $extentPosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset.zero & myBox.size;
  }

  @override
  BinaryPosition getPositionAtOffset(Offset localOffset) {
    return BinaryPosition.included();
  }

  @override
  BinarySelection? getSelectionBetween({basePosition, extentPosition}) {
    if (basePosition is! BinaryPosition || extentPosition is! BinaryPosition) {
      return null;
    }

    return BinarySelection.all();
  }

  @override
  BinarySelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return BinarySelection.all();
  }

  @override
  BinarySelection getSelectionOfEverything() {
    return BinarySelection.all();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Document position for a [DocumentNode] that is either fully selected
/// or unselected, like an image or a horizontal rule.
class BinaryPosition {
  const BinaryPosition.included() : isIncluded = true;
  const BinaryPosition.notIncluded() : isIncluded = false;

  final bool isIncluded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryPosition && runtimeType == other.runtimeType && isIncluded == other.isIncluded;

  @override
  int get hashCode => isIncluded.hashCode;
}

/// Document selection for a [DocumentNode] that is either fully selected
/// or unselected, like an image or a horizontal rule.
///
/// Technically, a [BinarySelection] represents the same thing as a [BinaryPosition],
/// because a binary selectable node is either completely selected or unselected.
/// However, participation within a generic editor requires that binary selectable
/// nodes behave like all other nodes, i.e., offering a "position" type and a
/// "selection" type.
class BinarySelection {
  const BinarySelection.all() : position = const BinaryPosition.included();
  const BinarySelection.none() : position = const BinaryPosition.notIncluded();

  final BinaryPosition position;

  /// A [BinarySelection] is always collapsed because there is no distinction
  /// between the "beginning" or "end" of a [BinarySelection], therefore, there
  /// is no content between the "base" and "extent" of such a selection.
  bool get isCollapsed => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinarySelection && runtimeType == other.runtimeType && position == other.position;

  @override
  int get hashCode => position.hashCode;
}
