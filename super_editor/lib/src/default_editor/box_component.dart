import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/super_editor.dart';

import '../core/document.dart';
import '../core/document_layout.dart';

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
  BinaryNodePosition getBeginningPosition() {
    return BinaryNodePosition.included();
  }

  @override
  BinaryNodePosition getBeginningPositionNearX(double x) {
    return BinaryNodePosition.included();
  }

  @override
  BinaryNodePosition? movePositionLeft(dynamic currentPosition, [Set<MovementModifier>? movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryNodePosition? movePositionRight(dynamic currentPosition, [Set<MovementModifier>? movementModifiers]) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryNodePosition? movePositionUp(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinaryNodePosition? movePositionDown(dynamic currentPosition) {
    // BoxComponents don't support internal movement.
    return null;
  }

  @override
  BinarySelection getCollapsedSelectionAt(nodePosition) {
    if (nodePosition is! BinaryNodePosition) {
      throw Exception('The given nodePosition ($nodePosition) is not compatible with BoxComponent');
    }

    return BinarySelection.all();
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return null;
  }

  @override
  BinaryNodePosition getEndPosition() {
    return BinaryNodePosition.included();
  }

  @override
  BinaryNodePosition getEndPositionNearX(double x) {
    return BinaryNodePosition.included();
  }

  @override
  Offset getOffsetForPosition(nodePosition) {
    if (nodePosition is! BinaryNodePosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset(myBox.size.width / 2, myBox.size.height / 2);
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! BinaryNodePosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset.zero & myBox.size;
  }

  @override
  Rect getRectForSelection(dynamic basePosition, dynamic extentPosition) {
    if (basePosition is! BinaryNodePosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $basePosition');
    }
    if (extentPosition is! BinaryNodePosition) {
      throw Exception('Expected nodePosition of type BinaryPosition but received: $extentPosition');
    }

    final myBox = context.findRenderObject() as RenderBox;
    return Offset.zero & myBox.size;
  }

  @override
  BinaryNodePosition getPositionAtOffset(Offset localOffset) {
    return BinaryNodePosition.included();
  }

  @override
  BinarySelection getSelectionBetween({required basePosition, required extentPosition}) {
    if (basePosition is! BinaryNodePosition) {
      throw Exception('The given basePosition ($basePosition) is not compatible with BoxComponent');
    }
    if (extentPosition is! BinaryNodePosition) {
      throw Exception('The given extentPosition ($extentPosition) is not compatible with BoxComponent');
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
class BinaryNodePosition implements NodePosition {
  const BinaryNodePosition.included() : isIncluded = true;
  const BinaryNodePosition.notIncluded() : isIncluded = false;

  final bool isIncluded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryNodePosition && runtimeType == other.runtimeType && isIncluded == other.isIncluded;

  @override
  int get hashCode => isIncluded.hashCode;
}

/// Document selection for a [DocumentNode] that is either fully selected
/// or unselected, like an image or a horizontal rule.
///
/// Technically, a [BinarySelection] represents the same thing as a [BinaryNodePosition],
/// because a binary selectable node is either completely selected or unselected.
/// However, participation within a generic editor requires that binary selectable
/// nodes behave like all other nodes, i.e., offering a "position" type and a
/// "selection" type.
class BinarySelection implements NodeSelection {
  const BinarySelection.all() : position = const BinaryNodePosition.included();
  const BinarySelection.none() : position = const BinaryNodePosition.notIncluded();

  final BinaryNodePosition position;

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
