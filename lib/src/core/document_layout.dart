import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

import 'document_selection.dart';
import 'document.dart';

/// Abstract representation of a document layout.
///
/// Regardless of how a document is displayed, a `DocumentLayout` needs
/// to answer various questions about where content sits within the layout.
/// A `DocumentLayout` is the source of truth for the mapping between logical
/// `DocumentPosition`s and visual (x,y) positions. For example, this mapping
/// allows the app to determine which portion of a `String` should be selected
/// when the user drags from one (x,y) position to another (x,y) position on
/// the screen.
abstract class DocumentLayout {
  /// Returns the `DocumentPosition` that corresponds to the given
  /// `layoutOffset`, or `null` if the `layoutOffset` does not exist
  /// within a piece of document content.
  DocumentPosition? getDocumentPositionAtOffset(Offset layoutOffset);

  /// Returns the `DocumentPosition` at the y-value of the given `layoutOffset`
  /// that sits closest to the x-value of the given `layoutOffset`, or `null`
  /// if there is no document content at the given y-value.
  ///
  /// For example, a y-position within the first line of a paragraph, and an
  /// x-position that sits to the left of the paragraph would return the
  /// `DocumentPosition` for the first character within the paragraph.
  DocumentPosition? getDocumentPositionNearestToOffset(Offset layoutOffset);

  /// Returns the bounding box of the component that renders the given
  /// `position`, or `null` if no corresponding component can be found, or
  /// the corresponding component has not yet been laid out.
  Rect? getRectForPosition(DocumentPosition position);

  /// Returns a `DocumentSelection` that begins near `baseOffset` and extends
  /// to `extentOffset`, or `null` if no document content sits between the
  /// provided points.
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset);

  /// Returns the `MouseCursor` that's desired by the component at `documentOffset`, or
  /// `null` if the document has no preference for the `MouseCursor` at the given
  /// `documentOffset`.
  MouseCursor? getDesiredCursorAtOffset(Offset documentOffset);

  /// Returns the `DocumentComponent` that renders the `DocumentNode` with
  /// the given `nodeId`, or `null` if no such component exists.
  DocumentComponent? getComponentByNodeId(String nodeId);
}

/// Contract for all widgets that operate as document components
/// within a `DocumentLayout`.
mixin DocumentComponent<T extends StatefulWidget> on State<T> {
  /// Returns the node position within this component at the given
  /// `localOffset`, or `null` if the `localOffset` does not sit
  /// within any content.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic? getPositionAtOffset(Offset localOffset);

  /// Returns the (x,y) `Offset` for the given `nodePosition`.
  ///
  /// If the given `nodePosition` corresponds to a component where
  /// a position is ambiguous with regard to an (x,y) `Offset`, like
  /// an image or horizontal rule, it's up to that component to
  /// choose a reasonable `Offset`, such as the center of the image.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  Offset getOffsetForPosition(dynamic nodePosition);

  /// Returns a `Rect` for the given `nodePosition`.
  ///
  /// If the given `nodePosition` corresponds to a single (x,y)
  /// offset rather than a `Rect`, a `Rect` with zero width and
  /// height may be returned.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  Rect? getRectForPosition(dynamic nodePosition);

  /// Returns the node position that represents the "beginning" of
  /// the content within this component, such as the first character
  /// of a paragraph.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic getBeginningPosition();

  /// Returns the earliest position within this component's
  /// `DocumentNode` that appears at or near the given `x` position.
  ///
  /// This is useful, for example, when moving selection into the
  /// beginning of some text while maintaining the existing horizontal
  /// position of the selection.
  dynamic getBeginningPositionNearX(double x);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved left one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant `movementModifier`.
  ///
  /// The structure and options for `movementModifier`s is
  /// determined by each component/node combination.
  ///
  /// Returns `null` if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns `null` if there is nowhere to move left within this
  /// component, such as when the `currentPosition` is the first
  /// character within a paragraph.
  dynamic movePositionLeft(dynamic currentPosition, [Map<String, dynamic> movementModifiers]);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved right one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant `movementModifier`.
  ///
  /// The structure and options for `movementModifier`s is
  /// determined by each component/node combination.
  ///
  /// Returns null if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move right within this
  /// component, such as when the `currentPosition` refers to the
  /// last character in a paragraph.
  dynamic movePositionRight(dynamic currentPosition, [Map<String, dynamic> movementModifiers]);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved up one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move up within this
  /// component, such as when the `currentPosition` refers to
  /// the first line of a paragraph.
  dynamic movePositionUp(dynamic currentPosition);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved down one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move down within this
  /// component, such as when the `currentPosition` refers to
  /// the last line of a paragraph.
  dynamic movePositionDown(dynamic currentPosition);

  /// Returns the node position that represents the "end" of
  /// the content within this component, such as the last character
  /// of a paragraph.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic getEndPosition();

  /// Returns the latest position within this component's
  /// `DocumentNode` that appears at or near the given `x` position.
  ///
  /// This is useful, for example, when moving selection into the
  /// end of some text while maintaining the existing horizontal
  /// position of the selection.
  dynamic getEndPositionNearX(double x);

  /// Returns a selection of content that appears between the `localBaseOffset`
  /// and the `localExtentOffset`.
  ///
  /// The selection type depends on the type of `DocumentNode` that this
  /// component displays.
  dynamic getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset);

  /// Returns a node selection within this component's `DocumentNode` that
  /// is collapsed at the given `nodePosition`.
  dynamic getCollapsedSelectionAt(dynamic nodePosition);

  /// Returns a node selection within this component's `DocumentNode` that
  /// spans from `basePosition` to `extentPosition`.
  dynamic getSelectionBetween({
    @required dynamic basePosition,
    @required dynamic extentPosition,
  });

  /// Returns a node selection that includes all content within the node.
  dynamic getSelectionOfEverything();

  /// Returns the desired `MouseCursor` at the given (x,y) `localOffset`, or
  /// `null` if this component has no preference for the cursor style.
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset);
}

/// Contract for document components that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
///
/// The node positions accepted by a `TextComposable` are `dynamic`
/// rather than `TextPosition`s because an editor might be configured
/// to include complex text composition, like tables, which might
/// choose to index positions based on cell IDs, or row and column
/// indices.
abstract class TextComposable {
  /// Returns a `TextSelection` that encompasses the entire word
  /// found at the given `nodePosition`.
  TextSelection getWordSelectionAt(dynamic nodePosition);

  /// Returns all text surrounding `nodePosition` that is not
  /// broken by white space.
  String getContiguousTextAt(dynamic nodePosition);

  /// Returns the node position that corresponds to a text location
  /// that is one line above the given `nodePosition`, or `null` if
  /// there is no position one line up.
  dynamic? getPositionOneLineUp(dynamic nodePosition);

  /// Returns the node position that corresponds to a text location
  /// that is one line below the given `nodePosition`, or `null` if
  /// there is no position one line down.
  dynamic? getPositionOneLineDown(dynamic nodePosition);

  /// Returns the node position that corresponds to the first character
  /// in the line of text that contains the given `nodePosition`.
  dynamic getPositionAtStartOfLine(dynamic nodePosition);

  /// Returns the node position that corresponds to the last character
  /// in the line of text that contains the given `nodePosition`.
  dynamic getPositionAtEndOfLine(dynamic nodePosition);
}

/// Builds a widget that renders the desired UI for one or
/// more `DocumentNode`s.
///
/// Every widget returned from a `ComponentBuilder` should be
/// a `StatefulWidget` that mixes in `DocumentComponent`.
///
/// A `ComponentBuilder` might be invoked with a type of
/// `DocumentNode` that it doesn't know how to work with. When
/// this happens, the `ComponentBuilder` should return `null`,
/// indicating that it doesn't know how to build a component
/// for the given `DocumentNode`.
///
/// See `ComponentContext` for expectations about how to use
/// the context to build a component widget.
typedef ComponentBuilder = Widget? Function(ComponentContext);

/// Information that is provided to a `ComponentBuilder` to
/// construct an appropriate `DocumentComponent` widget.
class ComponentContext {
  const ComponentContext({
    required this.context,
    required this.document,
    required this.documentNode,
    required this.componentKey,
    this.nodeSelection,
    this.extensions = const {},
  });

  /// The `BuildContext` for the parent of the `DocumentComponent`
  /// that needs to be built.
  final BuildContext context;

  /// The `Document` that contains the `DocumentNode`.
  final Document document;

  /// The `DocumentNode` for which a component is needed.
  final DocumentNode documentNode;

  /// A `GlobalKey` that must be assigned to the `DocumentComponent`
  /// widget returned by a `ComponentBuilder`.
  ///
  /// The `componentKey` is used by the `DocumentLayout` to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;

  /// The current selected region within the `documentNode`.
  ///
  /// The component should paint this selection.
  final DocumentNodeSelection? nodeSelection;

  /// May contain additional information needed to build the
  /// component, based on the specific type of the `documentNode`.
  final Map<String, dynamic> extensions;
}
