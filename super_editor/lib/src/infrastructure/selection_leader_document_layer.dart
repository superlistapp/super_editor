import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';

/// A document layer that positions leader widgets at the user's selection bounds.
///
/// A collapsed selection has a single leader where the caret should appear. An expanded
/// selection has a leader at both sides of the selection, as well as a leader that spans
/// the entire expanded selection. Leader width is always `1` and leader height is based
/// on the document's self-reported caret height for the given document position.
///
/// When no selection exists, no leaders are built in the layer's widget tree.
class SelectionLeadersDocumentLayer extends StatefulWidget {
  const SelectionLeadersDocumentLayer({
    Key? key,
    required this.document,
    required this.selection,
    required this.documentLayoutResolver,
    required this.links,
    this.showDebugLeaderBounds = false,
  }) : super(key: key);

  /// The editor's [Document], which is used to find the start and end of
  /// the user's expanded selection.
  final Document document;

  /// The current user's selection within a document.
  final ValueListenable<DocumentSelection?> selection;

  /// Delegate that returns a reference to the editor's [DocumentLayout], so
  /// that the current selection can be mapped to an (x,y) offset and a height.
  final DocumentLayout Function() documentLayoutResolver;

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  State<SelectionLeadersDocumentLayer> createState() => _SelectionLeadersDocumentLayerState();
}

class _SelectionLeadersDocumentLayerState extends State<SelectionLeadersDocumentLayer>
    with SingleTickerProviderStateMixin {
  Rect? _caret;

  Rect? _upstream;
  Rect? _downstream;
  Rect? _expandedSelectionBounds;

  @override
  void initState() {
    super.initState();

    widget.selection.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(SelectionLeadersDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onSelectionChange() {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // The Flutter pipeline isn't running. Schedule a re-build and re-position the caret.
      setState(() {
        // The leaders are positioned in the build() call.
      });
    }
  }

  /// Updates the caret rect, immediately, without scheduling a rebuild.
  void _positionCaret() {
    _caret = null;
    _upstream = null;
    _downstream = null;
    _expandedSelectionBounds = null;

    final documentSelection = widget.selection.value;
    if (documentSelection == null) {
      return;
    }

    final documentLayout = widget.documentLayoutResolver();
    final selectedComponent = documentLayout.getComponentByNodeId(widget.selection.value!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method ot run again in a moment
      // to correct for this.
      return;
    }

    if (documentSelection.isCollapsed) {
      _caret = documentLayout.getRectForPosition(documentSelection.extent)!;
    } else {
      _upstream = documentLayout.getRectForPosition(
        widget.document.selectUpstreamPosition(documentSelection.base, documentSelection.extent),
      )!;
      _downstream = documentLayout.getRectForPosition(
        widget.document.selectDownstreamPosition(documentSelection.base, documentSelection.extent),
      )!;
      _expandedSelectionBounds = documentLayout.getRectForSelection(
        documentSelection.base,
        documentSelection.extent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _positionCaret();

    return IgnorePointer(
      child: Stack(
        children: [
          if (_caret != null)
            Positioned(
              top: _caret!.top,
              left: _caret!.left,
              width: 1,
              height: _caret!.height,
              child: Leader(
                link: widget.links.caretLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFFFF0000))),
                      )
                    : null,
              ),
            ),
          if (_upstream != null)
            Positioned(
              top: _upstream!.top,
              left: _upstream!.left,
              width: 1,
              height: _upstream!.height,
              child: Leader(
                link: widget.links.upstreamLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFF00FF00))),
                      )
                    : null,
              ),
            ),
          if (_downstream != null)
            Positioned(
              top: _downstream!.top,
              left: _downstream!.left,
              width: 1,
              height: _downstream!.height,
              child: Leader(
                link: widget.links.downstreamLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFF0000FF))),
                      )
                    : null,
              ),
            ),
          if (_expandedSelectionBounds != null)
            Positioned.fromRect(
              rect: _expandedSelectionBounds!,
              child: Leader(
                link: widget.links.expandedSelectionBoundsLink,
                child: widget.showDebugLeaderBounds
                    ? DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(width: 4, color: const Color(0xFFFF00FF))),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// A collection of [LayerLink]s that should be positioned near important
/// visual selection locations, such as at the caret position.
class SelectionLayerLinks {
  SelectionLayerLinks({
    LeaderLink? caretLink,
    LeaderLink? upstreamLink,
    LeaderLink? downstreamLink,
    LeaderLink? expandedSelectionBoundsLink,
  }) {
    this.caretLink = caretLink ?? LeaderLink();
    this.upstreamLink = upstreamLink ?? LeaderLink();
    this.downstreamLink = downstreamLink ?? LeaderLink();
    this.expandedSelectionBoundsLink = expandedSelectionBoundsLink ?? LeaderLink();
  }

  /// [LayerLink] that's connected to a rectangle at the collapsed selection caret
  /// position.
  late final LeaderLink caretLink;

  /// [LayerLink] that's connected to a rectangle at the expanded selection upstream
  /// position.
  late final LeaderLink upstreamLink;

  /// [LayerLink] that's connected to a rectangle at the expanded selection downstream
  /// position.
  late final LeaderLink downstreamLink;

  /// [LayerLink] that's connected to a rectangle that bounds the entire expanded
  /// selection, from the top of upstream to the bottom of downstream.
  late final LeaderLink expandedSelectionBoundsLink;
}
