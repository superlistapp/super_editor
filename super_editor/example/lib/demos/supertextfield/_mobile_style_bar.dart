import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class MobileStyleBar extends StatelessWidget {
  const MobileStyleBar({
    Key? key,
    required this.textController,
  }) : super(key: key);

  final AttributedTextEditingController textController;

  bool _isAttributionActive(Attribution attribution) {
    if (textController.selection.isCollapsed) {
      return textController.composingAttributions.contains(attribution);
    } else {
      final selection = textController.selection;
      return textController.text.hasAttributionsThroughout(
        attributions: {attribution},
        range: SpanRange(start: selection.start, end: selection.end - 1),
      );
    }
  }

  void _toggleAttribution(Attribution attribution) {
    if (textController.selection.isCollapsed) {
      textController.toggleComposingAttributions({attribution});
    } else {
      textController.toggleSelectionAttributions([attribution]);
    }
  }

  void _clearAttributions() {
    if (textController.selection.isCollapsed) {
      textController.clearComposingAttributions();
    } else {
      textController.clearSelectionAttributions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Material(
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AnimatedBuilder(
                  animation: textController,
                  builder: (context, child) {
                    return Row(
                      children: [
                        IconButton(
                          color: _isAttributionActive(boldAttribution) ? Colors.red : Colors.black,
                          onPressed: () {
                            _toggleAttribution(boldAttribution);
                          },
                          icon: const Icon(Icons.format_bold),
                        ),
                        IconButton(
                          color: _isAttributionActive(italicsAttribution) ? Colors.red : Colors.black,
                          onPressed: () {
                            _toggleAttribution(italicsAttribution);
                          },
                          icon: const Icon(Icons.format_italic),
                        ),
                        IconButton(
                          color: _isAttributionActive(underlineAttribution) ? Colors.red : Colors.black,
                          onPressed: () {
                            _toggleAttribution(underlineAttribution);
                          },
                          icon: const Icon(Icons.format_underline),
                        ),
                        IconButton(
                          color: _isAttributionActive(strikethroughAttribution) ? Colors.red : Colors.black,
                          onPressed: () {
                            _toggleAttribution(strikethroughAttribution);
                          },
                          icon: const Icon(Icons.format_strikethrough),
                        ),
                        IconButton(
                          color: Colors.black,
                          onPressed: () {
                            _clearAttributions();
                          },
                          icon: const Icon(Icons.format_clear),
                        ),
                      ],
                    );
                  }),
            ),
          ),
        ),
      ],
    );
  }
}
