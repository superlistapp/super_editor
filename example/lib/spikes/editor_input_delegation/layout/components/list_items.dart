import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/widgets.dart';

import 'paragraph/selectable_text.dart';

class UnorderedListItemComponent extends StatelessWidget {
  const UnorderedListItemComponent({
    Key key,
    this.text = '',
    this.showDebugPaint = false,
  }) : super(key: key);

  final String text;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 25,
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            // TODO: figure out what to do with the incoming key
            key: GlobalKey(),
            text: text,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

class OrderedListItemComponent extends StatelessWidget {
  const OrderedListItemComponent({
    Key key,
    @required this.listIndex,
    this.text = '',
    this.showDebugPaint = false,
  }) : super(key: key);

  final int listIndex;
  final String text;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 25,
          child: Center(
            child: Text('$listIndex'),
          ),
        ),
        Expanded(
          child: SelectableText(
            // TODO: figure out what to do with the incoming key
            key: GlobalKey(),
            text: text,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}
