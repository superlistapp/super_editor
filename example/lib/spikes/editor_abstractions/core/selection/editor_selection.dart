import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../document/rich_text_document.dart';

/// A selection within a `RichTextDocument`.
///
/// A `DocumentSelection` spans from a `base` position to an
/// `extent` position, and includes all content in between.
///
/// `base` and `extent` are instances of `DocumentPosition`,
/// which represents a single position within a `RichTextDocument`.
///
/// A `DocumentSelection` does not hold a reference to a
/// `RichTextDocument`, it only represents a directional selection
/// of a `RichTextDocument`. The `base` and `extent` positions must
/// be interpreted within the context of a specific `RichTextDocument`
/// to locate nodes between `base` and `extent`, and to identify
/// partial content that is selected within the `base` and `extent`
/// nodes within the document.
class DocumentSelection {
  const DocumentSelection.collapsed({
    @required DocumentPosition position,
  })  : assert(position != null),
        base = position,
        extent = position;

  DocumentSelection({
    @required this.base,
    @required this.extent,
  })  : assert(base != null),
        assert(extent != null);

  final DocumentPosition<dynamic> base;
  final DocumentPosition<dynamic> extent;

  bool get isCollapsed => base == extent;

  @override
  String toString() {
    return '[DocumentSelection] - \n  base: ($base),\n  extent: ($extent)';
  }

  DocumentSelection collapse() {
    if (isCollapsed) {
      return this;
    } else {
      return DocumentSelection(
        base: extent,
        extent: extent,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelection && runtimeType == other.runtimeType && base == other.base && extent == other.extent;

  @override
  int get hashCode => base.hashCode ^ extent.hashCode;

  DocumentSelection copyWith({
    DocumentPosition base,
    DocumentPosition extent,
  }) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.base,
    );
  }

  DocumentSelection expandTo(DocumentPosition newExtent) {
    return copyWith(
      extent: newExtent,
    );
  }
}

class DocumentNodeSelection<SelectionType> {
  DocumentNodeSelection({
    @required this.nodeId,
    @required this.nodeSelection,
    this.isBase = false,
    this.isExtent = false,
    // TODO: either remove highlightWhenEmpty from this class, or move
    //       this class to a different place. Visual preferences don't
    //       belong here.
    this.highlightWhenEmpty = false,
  });

  final String nodeId;
  final SelectionType nodeSelection;
  final bool isBase;
  final bool isExtent;
  final bool highlightWhenEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentNodeSelection &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          nodeSelection == other.nodeSelection;

  @override
  int get hashCode => nodeId.hashCode ^ nodeSelection.hashCode;

  @override
  String toString() {
    return '[DocumentNodeSelection] - node: "$nodeId", selection: ($nodeSelection)';
  }
}
