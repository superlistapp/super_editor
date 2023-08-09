import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// Positions invisible widgets around runs of attributed text.
///
/// The attributions that are bounded are selected with a given [selector].
///
/// The bounding widget is build with a given [builder], so that any number
/// of use-cases can be implemented with this widget.
class AttributionBounds extends StatefulWidget {
  const AttributionBounds({
    Key? key,
    required this.document,
    required this.layout,
    required this.selector,
    required this.builder,
  }) : super(key: key);

  final Document document;
  final DocumentLayout layout;
  final AttributionBoundsSelector selector;
  final AttributionBoundsBuilder builder;

  @override
  State<AttributionBounds> createState() => _AttributionBoundsState();
}

class _AttributionBoundsState extends State<AttributionBounds> {
  final _bounds = <_AttributionBounds>{};

  @override
  void initState() {
    super.initState();

    _findBounds();
    widget.document.addListener(_onDocumentChange);
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChange);
    super.dispose();
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    if (!mounted) {
      return;
    }

    setState(() {
      _findBounds();
    });
  }

  void _findBounds() {
    _bounds.clear();

    for (final node in widget.document.nodes) {
      if (node is! TextNode) {
        continue;
      }

      final spans = node.text.getAttributionSpansInRange(
        attributionFilter: widget.selector,
        range: SpanRange(start: 0, end: node.text.text.length - 1),
      );

      for (final span in spans) {
        final range = DocumentRange(
          start: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.start)),
          end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.end + 1)),
        );

        _bounds.add(
          _AttributionBounds(
            span.attribution,
            widget.layout.getRectForSelection(range.start, range.end) ?? Rect.zero,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _buildBounds(),
      ),
    );
  }

  List<Widget> _buildBounds() {
    _findBounds();

    final boundWidgets = <Widget>[];
    for (final bound in _bounds) {
      final boundWidget = widget.builder(context, bound.attribution);
      if (boundWidget != null) {
        boundWidgets.add(
          Positioned.fromRect(
            rect: bound.rect,
            child: boundWidget,
          ),
        );
      }
    }

    return boundWidgets;
  }
}

class _AttributionBounds {
  const _AttributionBounds(this.attribution, this.rect);

  final Attribution attribution;
  final Rect rect;
}

/// Filter function that decides whether the text with the given [attribution]
/// should have a widget boundary placed around it.
typedef AttributionBoundsSelector = bool Function(Attribution attribution);

/// Builder that (optionally) returns a widget that positioned at the size
/// and location of attributed text.
typedef AttributionBoundsBuilder = Widget? Function(BuildContext context, Attribution attribution);
