import 'package:flutter/widgets.dart';

import 'document_selection.dart';
import 'document.dart';

/// Obtains a [DocumentLayout].
///
/// This typedef is provided because a [DocumentLayout] typically
/// comes from a [State] object, which can change over time, and must
/// be obtained via [GlobalKey]. Therefore, a resolver function like
/// this is passed around, instead of a direct reference to a
/// [DocumentLayout].
typedef DocumentLayoutResolver = DocumentLayout Function();

/// Abstract representation of a document layout.
///
/// Regardless of how a document is displayed, a [DocumentLayout] needs
/// to answer various questions about where content sits within the layout.
/// A [DocumentLayout] is the source of truth for the mapping between logical
/// [DocumentPosition]s and visual (x,y) positions. For example, this mapping
/// allows the app to determine which portion of a [String] should be selected
/// when the user drags from one (x,y) position to another (x,y) position on
/// the screen.
abstract class DocumentLayout {
  /// Returns the [DocumentPosition] that corresponds to the given
  /// [layoutOffset], or [null] if the [layoutOffset] does not exist
  /// within a piece of document content.
  DocumentPosition? getDocumentPositionAtOffset(Offset layoutOffset);

  /// Returns the [DocumentPosition] at the y-value of the given [layoutOffset]
  /// that sits closest to the x-value of the given [layoutOffset], or [null]
  /// if there is no document content at the given y-value.
  ///
  /// For example, a y-position within the first line of a paragraph, and an
  /// x-position that sits to the left of the paragraph would return the
  /// [DocumentPosition] for the first character within the paragraph.
  DocumentPosition? getDocumentPositionNearestToOffset(Offset layoutOffset);

  /// Returns the bounding box of the component that renders the given
  /// [position], or [null] if no corresponding component can be found, or
  /// the corresponding component has not yet been laid out.
  Rect? getRectForPosition(DocumentPosition position);

  /// Returns a [Rect] that bounds the content selected between
  /// [basePosition] and [extentPosition].
  Rect? getRectForSelection(DocumentPosition basePosition, DocumentPosition extentPosition);

  /// Returns a [DocumentSelection] that begins near [baseOffset] and extends
  /// to [extentOffset], or [null] if no document content sits between the
  /// provided points.
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset);

  /// Returns the [MouseCursor] that's desired by the component at [documentOffset], or
  /// [null] if the document has no preference for the [MouseCursor] at the given
  /// [documentOffset].
  MouseCursor? getDesiredCursorAtOffset(Offset documentOffset);

  /// Returns the [DocumentComponent] that renders the [DocumentNode] with
  /// the given [nodeId], or [null] if no such component exists.
  DocumentComponent? getComponentByNodeId(String nodeId);

  /// Converts [ancestorOffset] from the [ancestor]'s coordinate space to the
  /// same location on the screen within this [DocumentLayout]'s coordinate space.
  Offset getDocumentOffsetFromAncestorOffset(Offset ancestorOffset, RenderObject ancestor);

  /// Converts [documentOffset] from this [DocumentLayout]'s coordinate space
  /// to the same location on the screen within the [ancestor]'s coordinate space.
  Offset getAncestorOffsetFromDocumentOffset(Offset documentOffset, RenderObject ancestor);

  /// Converts [documentOffset] from this [DocumentLayout]'s coordinate space
  /// to the same location on the screen in the global coordinate space.
  Offset getGlobalOffsetFromDocumentOffset(Offset documentOffset);
}

/// Contract for all widgets that operate as document components
/// within a [DocumentLayout].
///
/// `DocumentComponent` is defined as a mixin on a `State<T>` because
/// document layouts may require access to a `DocumentComponent`'s
/// `RenderBox`.
mixin DocumentComponent<T extends StatefulWidget> on State<T> {
  /// Returns the node position within this component at the given
  /// [localOffset], or [null] if the [localOffset] does not sit
  /// within any content.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  NodePosition? getPositionAtOffset(Offset localOffset);

  /// Returns the (x,y) [Offset] for the given [nodePosition], or throws
  /// an exception if the given [nodePosition] is not compatible
  /// with this component's node type.
  ///
  /// If the given [nodePosition] corresponds to a component where
  /// a position is ambiguous with regard to an (x,y) [Offset], like
  /// an image or horizontal rule, it's up to that component to
  /// choose a reasonable [Offset], such as the center of the image.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  Offset getOffsetForPosition(NodePosition nodePosition);

  /// Returns a [Rect] for the given [nodePosition], or throws
  /// an exception if the given [nodePosition] is not compatible
  /// with this component's node type.
  ///
  /// If the given [nodePosition] corresponds to a single (x,y)
  /// offset rather than a [Rect], a [Rect] with zero width and
  /// height may be returned.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  Rect getRectForPosition(NodePosition nodePosition);

  /// Returns a [Rect] that bounds the content selected between
  /// [baseNodePosition] and [extentNodePosition].
  ///
  /// Throws an exception if [baseNodePosition] or [extentNodePosition] are
  /// not an appropriate type of node position for this component.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition);

  /// Returns the node position that represents the "beginning" of
  /// the content within this component, such as the first character
  /// of a paragraph.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  NodePosition getBeginningPosition();

  /// Returns the earliest position within this component's
  /// [DocumentNode] that appears at or near the given [x] position.
  ///
  /// This is useful, for example, when moving selection into the
  /// beginning of some text while maintaining the existing horizontal
  /// position of the selection.
  NodePosition getBeginningPositionNearX(double x);

  /// Returns a new position within this component's node that
  /// corresponds to the [currentPosition] moved left one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant [movementModifier].
  ///
  /// The structure and options for [movementModifier] is
  /// determined by each component/node combination.
  ///
  /// Returns [null] if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns [null] if there is nowhere to move left within this
  /// component, such as when the [currentPosition] is the first
  /// character within a paragraph.
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]);

  /// Returns a new position within this component's node that
  /// corresponds to the [currentPosition] moved right one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant [movementModifier].
  ///
  /// The structure and options for [movementModifier] is
  /// determined by each component/node combination.
  ///
  /// Returns null if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move right within this
  /// component, such as when the [currentPosition] refers to the
  /// last character in a paragraph.
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]);

  /// Returns a new position within this component's node that
  /// corresponds to the [currentPosition] moved up one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move up within this
  /// component, such as when the [currentPosition] refers to
  /// the first line of a paragraph.
  NodePosition? movePositionUp(NodePosition currentPosition);

  /// Returns a new position within this component's node that
  /// corresponds to the [currentPosition] moved down one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move down within this
  /// component, such as when the [currentPosition] refers to
  /// the last line of a paragraph.
  NodePosition? movePositionDown(NodePosition currentPosition);

  /// Returns the [NodePosition that represents the "end" of
  /// the content within this component, such as the last character
  /// of a paragraph.
  ///
  /// See [Document] for more information about [DocumentNode]s and
  /// node positions.
  NodePosition getEndPosition();

  /// Returns the latest position within this component's
  /// [DocumentNode] that appears at or near the given [x] position.
  ///
  /// This is useful, for example, when moving selection into the
  /// end of some text while maintaining the existing horizontal
  /// position of the selection.
  NodePosition getEndPositionNearX(double x);

  /// Returns a selection of content that appears between the [localBaseOffset]
  /// and the [localExtentOffset], or [null] if the given region does not
  /// include any of the content within this component.
  ///
  /// The selection type depends on the type of [DocumentNode] that this
  /// component displays.
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset);

  /// Returns a [NodeSelection] within this component's [DocumentNode] that
  /// is collapsed at the given [nodePosition]
  ///
  /// Throws an exception if the given [nodePosition] is not compatible with
  /// this component's node type.
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition);

  /// Returns a [NodeSelection] within this component's [DocumentNode] that
  /// spans from [basePosition] to [extentPosition].
  ///
  /// Throws an exception if [basePosition] or [extentPosition] are
  /// incompatible with this component's node type.
  NodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  });

  /// Returns a [NodeSelection that includes all content within the node.
  NodeSelection getSelectionOfEverything();

  /// Returns `true` if this component changes its visual appearance when
  /// selected, or `false` otherwise.
  ///
  /// A component that doesn't support visual selection should never be
  /// allowed to appear at the boundary of a selection. The user should not
  /// be able to tap this component to select it, nor should the user be
  /// able to expand a selection with this component as the base or extent.
  /// Implementation of these restrictions are the responsibility of the
  /// document layout.
  bool isVisualSelectionSupported() => true;

  /// Returns the desired [MouseCursor] at the given (x,y) [localOffset], or
  /// [null] if this component has no preference for the cursor style.
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset);
}

/// A [DocumentComponent] that wraps, and defers to, another [DocumentComponent].
///
/// Consider a text component that displays hint text when it's empty. A `TextComponent`
/// already exists. How do you add a hint to that? Create a new component called
/// `TextWithHintComponent` that internally builds a `TextComponent` and adds a hint
/// display when needed. The `TextWithHintComponent` needs to conform to the
/// `DocumentComponent` contract, but `TextWithHintComponent` doesn't care about any
/// of these details. It wants to forward all the `DocumentComponent` calls to
/// its inner `TextComponent`.
///
/// `ProxyDocumentComponent` implements all [DocumentComponent] behaviors to forward
/// to the component that's being wrapped. The only thing that the implementer needs
/// to provide is [childDocumentComponentKey], which is a `GlobalKey` that provides
/// access to the child [DocumentComponent].
mixin ProxyDocumentComponent<T extends StatefulWidget> implements DocumentComponent<T> {
  DocumentComponent get childDocumentComponentKey;

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    return childDocumentComponentKey.getPositionAtOffset(localOffset);
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    return childDocumentComponentKey.getOffsetForPosition(nodePosition);
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    return childDocumentComponentKey.getRectForPosition(nodePosition);
  }

  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    return childDocumentComponentKey.getRectForSelection(baseNodePosition, extentNodePosition);
  }

  @override
  NodePosition getBeginningPosition() {
    return childDocumentComponentKey.getBeginningPosition();
  }

  @override
  NodePosition getBeginningPositionNearX(double x) {
    return childDocumentComponentKey.getBeginningPositionNearX(x);
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    return childDocumentComponentKey.movePositionLeft(currentPosition, movementModifier);
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    return childDocumentComponentKey.movePositionRight(currentPosition, movementModifier);
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    return childDocumentComponentKey.movePositionUp(currentPosition);
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    return childDocumentComponentKey.movePositionDown(currentPosition);
  }

  @override
  NodePosition getEndPosition() {
    return childDocumentComponentKey.getEndPosition();
  }

  @override
  NodePosition getEndPositionNearX(double x) {
    return childDocumentComponentKey.getEndPositionNearX(x);
  }

  @override
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return childDocumentComponentKey.getSelectionInRange(localBaseOffset, localExtentOffset);
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    return childDocumentComponentKey.getCollapsedSelectionAt(nodePosition);
  }

  @override
  NodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    return childDocumentComponentKey.getSelectionBetween(basePosition: basePosition, extentPosition: extentPosition);
  }

  @override
  NodeSelection getSelectionOfEverything() {
    return childDocumentComponentKey.getSelectionOfEverything();
  }

  @override
  bool isVisualSelectionSupported() => childDocumentComponentKey.isVisualSelectionSupported();

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return childDocumentComponentKey.getDesiredCursorAtOffset(localOffset);
  }
}

/// Preferences for how the document selection should change, e.g.,
/// move word-by-word instead of character-by-character.
///
/// Default values are provided, such as [MovementModifier.word]. These
/// defaults are understood by the default node implementations. If you
/// introduce custom nodes/content, you can create your own
/// [MovementModifier]s by instantiating them with [id]s of your choice,
/// so long as those [id]s don't conflict with existing [id]s. You're
/// responsible for implementing whatever behavior those custom
/// [MovementModifier]s represent.
///
/// There is no default value for character-by-character movement because that
/// is the default movement that occurs when **no** movement modifiers are at
/// play.
class MovementModifier {
  /// Move text selection word-by-word.
  ///
  /// See also:
  ///
  ///  * [line], which moves text selection line-by-line.
  static const word = MovementModifier('word');

  /// Move text selection line-by-line.
  ///
  /// See also:
  ///
  ///  * [word], which moves text selection word-by-word.
  static const line = MovementModifier('line');

  /// Creates a movement modifier that is globally uniquely identified by the
  /// provided [id].
  const MovementModifier(this.id);

  /// Identifier that uniquely identifies this [MovementModifier] globally.
  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MovementModifier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Information that is provided to a [ComponentBuilder] to
/// construct an appropriate [DocumentComponent] widget.
class ComponentContext {
  /// Creates a component context.
  const ComponentContext({
    required this.context,
    required this.document,
    this.documentSelection,
    required this.documentNode,
    required this.componentKey,
    required this.showCaret,
    this.nodeSelection,
    this.extensions = const {},
  });

  /// The [BuildContext] for the parent of the [DocumentComponent]
  /// that needs to be built.
  final BuildContext context;

  /// The [Document] that contains the [DocumentNode].
  final Document document;

  /// The current user selection in the [document].
  final DocumentSelection? documentSelection;

  /// The [DocumentNode] for which a component is needed.
  final DocumentNode documentNode;

  /// A [GlobalKey] that must be assigned to the [DocumentComponent]
  /// widget returned by a [ComponentBuilder].
  ///
  /// The [componentKey] is used by the [DocumentLayout] to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;

  /// [true] if the extent component should display a caret,
  /// [false] otherwise.
  ///
  /// Not every component has a caret to display, e.g., an
  /// image, but the components that do have a caret, e.g.,
  /// a paragraph, should respect this property.
  final bool showCaret;

  /// The current selected region within the [documentNode].
  ///
  /// The component should paint this selection.
  final DocumentNodeSelection? nodeSelection;

  /// May contain additional information needed to build the
  /// component, based on the specific type of the [documentNode].
  final Map<String, dynamic> extensions;
}
