import 'package:super_editor/src/core/document.dart';

/// Document position for a [DocumentNode] that is either fully selected
/// or unselected, like an image or a horizontal rule.
///
/// A `BinaryNodePosition` doesn't support upstream or downstream caret
/// positions - it only supports complete selection or non-selection.
class BinaryNodePosition implements NodePosition {
  const BinaryNodePosition.included() : isIncluded = true;
  const BinaryNodePosition.notIncluded() : isIncluded = false;

  final bool isIncluded;

  @override
  String toString() => "[BinaryNodePosition] - is included: $isIncluded";

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
