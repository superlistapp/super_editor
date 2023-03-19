import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Document overlay that paints a caret with the given [caretStyle].
class CaretDocumentOverlay extends StatefulWidget {
  const CaretDocumentOverlay({
    Key? key,
    required this.composer,
    required this.documentLayoutResolver,
    required this.caretStyle,
    required this.document,
  }) : super(key: key);

  /// The editor's [DocumentComposer], which reports the current selection.
  final DocumentComposer composer;

  /// Delegate that returns a reference to the editor's [DocumentLayout], so
  /// that the current selection can be mapped to an (x,y) offset and a height.
  final DocumentLayout Function() documentLayoutResolver;

  /// The editor's [Document].
  ///
  /// Some operations that affect caret position don't trigger a selection change, e.g.,
  /// indenting a list item.
  ///
  /// We need to listen to all document changes to update the caret position when these
  /// operations happen.
  final Document document;

  /// The visual style of the caret that this overlay paints.
  final CaretStyle caretStyle;

  @override
  State<CaretDocumentOverlay> createState() => _CaretDocumentOverlayState();
}

class _CaretDocumentOverlayState extends State<CaretDocumentOverlay> with SingleTickerProviderStateMixin {
  Rect? _caret;
  late final BlinkController _blinkController;

  bool _isCaretDirty = false;

  @override
  void initState() {
    super.initState();
    widget.composer.selectionNotifier.addListener(_scheduleCaretUpdate);
    widget.document.addListener(_scheduleCaretUpdate);
    _blinkController = BlinkController(tickerProvider: this)..startBlinking();
  }

  @override
  void didUpdateWidget(CaretDocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_scheduleCaretUpdate);
      widget.document.addListener(_scheduleCaretUpdate);
    }

    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_scheduleCaretUpdate);
      widget.composer.selectionNotifier.addListener(_scheduleCaretUpdate);
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_scheduleCaretUpdate);
    widget.document.removeListener(_scheduleCaretUpdate);
    _blinkController.dispose();
    super.dispose();
  }

  /// Schedules a caret update after the current frame.
  void _scheduleCaretUpdate() {
    // Give the document a frame to update its layout before we lookup
    // the extent offset.
    _isCaretDirty = true;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!_isCaretDirty) {
        return;
      }

      _updateCaretAfterContentChange();
    });
  }

  /// Updates the caret rect, adjusts the blinking behavior, and schedules a rebuild so that the
  /// new caret rect and blinking state are reflected in the widget tree.
  void _updateCaretAfterContentChange() {
    if (!mounted) {
      return;
    }

    setState(() {
      final documentSelection = widget.composer.selection;
      if (documentSelection == null) {
        _caret = null;
        _blinkController.stopBlinking();
        return;
      }

      _blinkController.startBlinking();
      _blinkController.jumpToOpaque();

      _positionCaret();

      _isCaretDirty = false;
    });
  }

  /// Updates the caret rect, immediately, without scheduling a rebuild.
  void _positionCaret() {
    final documentSelection = widget.composer.selection;
    if (documentSelection == null) {
      return;
    }

    final documentLayout = widget.documentLayoutResolver();
    final selectedComponent = documentLayout.getComponentByNodeId(widget.composer.selection!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method ot run again in a moment
      // to correct for this.
      return;
    }

    _caret = documentLayout.getRectForPosition(documentSelection.extent)!;
  }

  @override
  Widget build(BuildContext context) {
    _positionCaret();

    // IgnorePointer so that when the user double and triple taps, the
    // caret doesn't intercept those later taps.
    return IgnorePointer(
      // We use a LayoutBuilder because the appropriate offset for the caret
      // is based on the flow of content, which is based on the document's
      // size/constraints. We need to re-calculate the caret offset when the
      // constraints change.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            child: Stack(
              children: [
                if (_caret != null)
                  Positioned(
                    top: _caret!.top,
                    left: _caret!.left,
                    height: _caret!.height,
                    child: AnimatedBuilder(
                      animation: _blinkController,
                      builder: (context, child) {
                        return Container(
                          key: primaryCaretKey,
                          width: widget.caretStyle.width,
                          decoration: BoxDecoration(
                            color: widget.caretStyle.color.withOpacity(_blinkController.opacity),
                            borderRadius: widget.caretStyle.borderRadius,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const primaryCaretKey = ValueKey("caret_primary");
