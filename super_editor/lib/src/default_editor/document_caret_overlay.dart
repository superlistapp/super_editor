import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
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
  }) : super(key: key);

  /// The editor's [DocumentComposer], which reports the current selection.
  final DocumentComposer composer;

  /// Delegate that returns a reference to the editor's [DocumentLayout], so
  /// that the current selection can be mapped to an (x,y) offset and a height.
  final DocumentLayout Function() documentLayoutResolver;

  /// The visual style of the caret that this overlay paints.
  final CaretStyle caretStyle;

  @override
  State<CaretDocumentOverlay> createState() => _CaretDocumentOverlayState();
}

class _CaretDocumentOverlayState extends State<CaretDocumentOverlay> with SingleTickerProviderStateMixin {
  Rect? _caret;
  late final BlinkController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = BlinkController(tickerProvider: this);

    widget.composer.selectionNotifier.addListener(_onSelectionChange);

    _startOrStopBlinking();
  }

  @override
  void didUpdateWidget(CaretDocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.composer.selectionNotifier.addListener(_onSelectionChange);

      _startOrStopBlinking();
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_onSelectionChange);

    _blinkController.dispose();

    super.dispose();
  }

  void _onSelectionChange() {
    _updateCaretFlash();

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // The Flutter pipeline isn't running. Schedule a re-build and re-position the caret.
      setState(() {
        // The caret is positioned in the build() call.
      });
    }
  }

  void _startOrStopBlinking() {
    if (widget.composer.selection == null && !_blinkController.isBlinking) {
      return;
    }

    if (widget.composer.selection != null && _blinkController.isBlinking) {
      return;
    }

    widget.composer.selection != null //
        ? _blinkController.startBlinking()
        : _blinkController.stopBlinking();
  }

  void _updateCaretFlash() {
    final documentSelection = widget.composer.selection;
    if (documentSelection == null) {
      _caret = null;
      _blinkController.stopBlinking();
      return;
    }

    _blinkController.startBlinking();
    _blinkController.jumpToOpaque();
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

    // Use a RepaintBoundary so that caret flashing doesn't invalidate our
    // ancestor painting.
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
  }
}

const primaryCaretKey = ValueKey("caret_primary");
