import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/widgets.dart';

import '../selectable_text/selectable_text.dart';

class UnorderedListItemComponent extends StatelessWidget {
  const UnorderedListItemComponent({
    Key key,
    @required this.textKey,
    this.text = '',
    this.textStyle,
    this.indent = 0,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final String text;
  final TextStyle textStyle;
  final int indent;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = 25.0 * indent;

    return Row(
      children: [
        SizedBox(
          width: 25 + indentSpace,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
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
        ),
        Expanded(
          child: SelectableText(
            // TODO: figure out what to do with the incoming key
            key: GlobalKey(),
            text: text,
            style: textStyle,
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
    @required this.textKey,
    @required this.listIndex,
    this.text = '',
    this.numeralTextStyle,
    this.textStyle,
    this.indent = 0,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final int listIndex;
  final String text;
  final TextStyle numeralTextStyle;
  final TextStyle textStyle;
  final int indent;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = 25.0 * indent;

    return Row(
      children: [
        SizedBox(
          width: 25 + indentSpace,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: Text(
                '$listIndex',
                key: textKey,
                style: numeralTextStyle,
              ),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            // TODO: figure out what to do with the incoming key
            key: GlobalKey(),
            text: text,
            style: textStyle,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}
