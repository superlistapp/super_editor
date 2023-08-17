import 'package:example/demos/supertextfield/demo_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class InteractiveTextFieldDemo extends StatefulWidget {
  @override
  State<InteractiveTextFieldDemo> createState() => _InteractiveTextFieldDemoState();
}

class _InteractiveTextFieldDemoState extends State<InteractiveTextFieldDemo> {
  static const _tapRegionGroupId = "desktop";

  final _textFieldController = AttributedTextEditingController(
    text: AttributedText(
      'Super Editor is an open source text editor for Flutter projects.',
      AttributedSpans(
        attributions: [
          const SpanMarker(attribution: brandAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: brandAttribution, offset: 11, markerType: SpanMarkerType.end),
          const SpanMarker(attribution: flutterAttribution, offset: 47, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: flutterAttribution, offset: 53, markerType: SpanMarkerType.end),
        ],
      ),
    ),
  );

  OverlayEntry? _popupEntry;
  Offset _popupOffset = Offset.zero;

  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode!.dispose();
    super.dispose();
  }

  void _onRightClick(
      BuildContext textFieldContext, AttributedTextEditingController textController, Offset localOffset) {
    // Only show menu if some text is selected
    if (textController.selection.isCollapsed) {
      return;
    }

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final textFieldBox = textFieldContext.findRenderObject() as RenderBox;
    _popupOffset = textFieldBox.localToGlobal(localOffset, ancestor: overlayBox);

    if (_popupEntry == null) {
      _popupEntry = OverlayEntry(builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            _closePopup();
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  left: _popupOffset.dx,
                  top: _popupOffset.dy,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: textController.selection.textInside(textController.text.text),
                            ));
                            _closePopup();
                          },
                          child: const Text('Copy'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });

      overlay.insert(_popupEntry!);
    } else {
      _popupEntry!.markNeedsBuild();
    }
  }

  void _closePopup() {
    if (_popupEntry == null) {
      return;
    }

    _popupEntry!.remove();
    _popupEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) {
        // Remove focus from text field when the user taps anywhere else.
        _focusNode!.unfocus();
      },
      child: Center(
        child: SizedBox(
          width: 400,
          child: SizedBox(
            width: double.infinity,
            child: SuperDesktopTextField(
              focusNode: _focusNode,
              tapRegionGroupId: _tapRegionGroupId,
              textController: _textFieldController,
              inputSource: TextInputSource.ime,
              textStyleBuilder: demoTextStyleBuilder,
              blinkTimingMode: BlinkTimingMode.timer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decorationBuilder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _focusNode!.hasFocus ? Colors.blue : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: child,
                );
              },
              hintBuilder: (context) {
                return const Text(
                  'enter some text',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                );
              },
              hintBehavior: HintBehavior.displayHintUntilTextEntered,
              minLines: 5,
              maxLines: 5,
              onRightClick: _onRightClick,
            ),
          ),
        ),
      ),
    );
  }
}
