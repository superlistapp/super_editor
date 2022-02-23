import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

const brandAttribution = NamedAttribution('brand');
const flutterAttribution = NamedAttribution('flutter');

class InteractiveTextFieldDemo extends StatefulWidget {
  @override
  _InteractiveTextFieldDemoState createState() => _InteractiveTextFieldDemoState();
}

class _InteractiveTextFieldDemoState extends State<InteractiveTextFieldDemo> {
  final _textFieldController = AttributedTextEditingController(
    text: AttributedText(
        text: 'Super Editor is an open source text editor for Flutter projects.',
        spans: AttributedSpans(attributions: [
          const SpanMarker(attribution: brandAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: brandAttribution, offset: 11, markerType: SpanMarkerType.end),
          const SpanMarker(attribution: flutterAttribution, offset: 47, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: flutterAttribution, offset: 53, markerType: SpanMarkerType.end),
        ])),
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

    final overlay = Overlay.of(context)!;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Remove focus from text field when the user taps anywhere else.
        _focusNode!.unfocus();
      },
      child: Center(
        child: SizedBox(
          width: 400,
          child: GestureDetector(
            onTap: () {
              // no-op. Prevents unfocus from happening when text field is tapped.
            },
            child: SizedBox(
              width: double.infinity,
              child: SuperDesktopTextField(
                textController: _textFieldController,
                focusNode: _focusNode,
                textStyleBuilder: _textStyleBuilder,
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
      ),
    );
  }

  TextStyle _textStyleBuilder(Set<Attribution> attributions) {
    TextStyle textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );

    if (attributions.contains(brandAttribution)) {
      textStyle = textStyle.copyWith(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      );
    }
    if (attributions.contains(flutterAttribution)) {
      textStyle = textStyle.copyWith(
        color: Colors.blue,
      );
    }

    return textStyle;
  }
}
