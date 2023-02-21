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
    required this.isDocumentLayoutAvailable,
    required this.layoutLinksResolver,
    required this.caretStyle,
    required this.document,
  }) : super(key: key);

  /// The editor's [DocumentComposer], which reports the current selection.
  final DocumentComposer composer;

  /// Delegate that returns a reference to the editor's [DocumentLayout], so
  /// that the current selection can be mapped to an (x,y) offset and a height.
  final DocumentLayout Function() documentLayoutResolver;

  /// Returns whether or not we can access the document layout.
  ///
  /// When this method returns `true`, we assume it's safe to call [documentLayoutResolver].
  final bool Function() isDocumentLayoutAvailable;

  /// Returns the [LayerLink]s used to position the caret.
  final LayoutLinks Function() layoutLinksResolver;

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
  late final BlinkController _blinkController;

  /// Holds the current caret height.
  ///
  /// When the selection moves between nodes, the caret height might change.
  /// Holds `null` when there is no selection.
  double? _caretHeight = null;

  @override
  void initState() {
    super.initState();
    widget.composer.selectionNotifier.addListener(_scheduleCaretUpdate);
    widget.document.addListener(_scheduleCaretUpdate);
    _blinkController = BlinkController(tickerProvider: this)..startBlinking();

    // If we already have a selection, we need to display the caret.
    if (widget.composer.selection != null) {
      _scheduleCaretUpdate();
    }
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

      // Selection has changed, we need to update the caret.
      if (widget.composer.selection != oldWidget.composer.selection) {
        _scheduleCaretUpdate();
      }
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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateCaretHeight();
    });
  }

  void _updateCaretHeight() {
    if (!mounted) {
      return;
    }

    final documentSelection = widget.composer.selection;
    if (documentSelection == null) {
      _blinkController.stopBlinking();
      setState(() {
        _caretHeight = null;
      });
      return;
    }
    _blinkController.startBlinking();
    _blinkController.jumpToOpaque();

    final documentLayout = widget.documentLayoutResolver();
    setState(() {
      _caretHeight = documentLayout.getRectForPosition(documentSelection.extent)!.height;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDocumentLayoutAvailable()) {
      // We don't have a layout yet so we can't access the caret layer link to position the caret.
      // Wait until the next frame.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }

    if (widget.composer.selection == null) {
      // There isn't a selection so we don't need to show the caret.
      return const SizedBox();
    }

    // IgnorePointer so that when the user double and triple taps, the
    // caret doesn't intercept those later taps.
    return IgnorePointer(
      child: CompositedTransformFollower(
        link: widget.layoutLinksResolver().caret,
        showWhenUnlinked: false,
        child: RepaintBoundary(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _blinkController,
                builder: (context, child) {
                  return Container(
                    key: primaryCaretKey,
                    height: _caretHeight,
                    width: widget.caretStyle.width,
                    decoration: BoxDecoration(
                      color: widget.caretStyle.color.withOpacity(_blinkController.opacity),
                      borderRadius: widget.caretStyle.borderRadius,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const primaryCaretKey = ValueKey("caret_primary");
