import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Document overlay that paints a caret with the given [caretStyle].
class CaretDocumentOverlay extends StatefulWidget {
  const CaretDocumentOverlay({
    Key? key,
    required this.editor,
    required this.composer,
    required this.documentLayoutResolver,
    required this.caretStyle,
  }) : super(key: key);

  final Editor editor;

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

class _CaretDocumentOverlayState extends State<CaretDocumentOverlay>
    with SingleTickerProviderStateMixin
    implements EditListener {
  final _caret = ValueNotifier<Rect?>(null);
  late final BlinkController _blinkController;
  BoxConstraints? _previousConstraints;

  @override
  void initState() {
    super.initState();
    widget.composer.selectionComponent.selectionNotifier.addListener(_scheduleCaretUpdate);
    widget.editor.addListener(this);
    _blinkController = BlinkController(tickerProvider: this)..startBlinking();

    // If we already have a selection, we need to display the caret.
    if (widget.composer.selectionComponent.selection != null) {
      _scheduleCaretUpdate();
    }
  }

  @override
  void didUpdateWidget(CaretDocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor) {
      oldWidget.editor.removeListener(this);
      widget.editor.addListener(this);
    }

    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionComponent.selectionNotifier.removeListener(_scheduleCaretUpdate);
      widget.composer.selectionComponent.selectionNotifier.addListener(_scheduleCaretUpdate);

      // Selection has changed, we need to update the caret.
      if (widget.composer.selectionComponent.selection != oldWidget.composer.selectionComponent.selection) {
        _scheduleCaretUpdate();
      }
    }
  }

  @override
  void dispose() {
    widget.composer.selectionComponent.selectionNotifier.removeListener(_scheduleCaretUpdate);
    widget.editor.removeListener(this);
    _blinkController.dispose();
    super.dispose();
  }

  @override
  void onEdit(List<EditEvent> changes) {
    _scheduleCaretUpdate();
  }

  /// Schedules a caret update after the current frame.
  void _scheduleCaretUpdate() {
    // Give the document a frame to update its layout before we lookup
    // the extent offset.
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateCaretOffset();
    });
  }

  void _updateCaretOffset() {
    if (!mounted) {
      return;
    }

    final documentSelection = widget.composer.selectionComponent.selection;
    if (documentSelection == null) {
      _caret.value = null;
      _blinkController.stopBlinking();
      return;
    }

    _blinkController.startBlinking();
    _blinkController.jumpToOpaque();

    final documentLayout = widget.documentLayoutResolver();
    _caret.value = documentLayout.getRectForPosition(documentSelection.extent)!;
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer so that when the user double and triple taps, the
    // caret doesn't intercept those later taps.
    return IgnorePointer(
      child: ValueListenableBuilder<Rect?>(
        valueListenable: _caret,
        builder: (context, caret, child) {
          // We use a LayoutBuilder because the appropriate offset for the caret
          // is based on the flow of content, which is based on the document's
          // size/constraints. We need to re-calculate the caret offset when the
          // constraints change.
          return LayoutBuilder(builder: (context, constraints) {
            if (_previousConstraints != null && constraints != _previousConstraints) {
              // Use a post-frame callback to avoid calling setState() during build.
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                _updateCaretOffset();
              });
            }
            _previousConstraints = constraints;

            return RepaintBoundary(
              child: Stack(
                children: [
                  if (caret != null)
                    Positioned(
                      top: caret.top,
                      left: caret.left,
                      height: caret.height,
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
          });
        },
      ),
    );
  }
}

const primaryCaretKey = ValueKey("caret_primary");
