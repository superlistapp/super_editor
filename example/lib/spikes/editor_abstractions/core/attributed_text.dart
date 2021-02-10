import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'attributed_spans.dart';

class AttributedText {
  AttributedText({
    this.text = '',
    AttributedSpans spans,
  }) : _spans = spans ?? AttributedSpans(length: text.length);

  // TODO: allow for text insertion and deletion
  final String text;
  final AttributedSpans _spans;

  /// Returns true if the text has the given attribution at
  /// `offset`, or false otherwise.
  bool hasAttributionAt(
    int offset, {
    String name,
  }) {
    return _spans.hasAttributionAt(offset, name: name);
  }

  /// Returns true if the text contains at least one character of
  /// attribution for each of the given `attributions` within the
  /// given `range`, returns false otherwise.
  bool hasAttributionsWithin({
    @required Set<String> attributions,
    @required TextRange range,
  }) {
    return _spans.hasAttributionsWithin(
      attributions: attributions,
      start: range.start,
      end: range.end,
    );
  }

  /// Returns all attributions that cover the given `offset` within
  /// the text.
  Set<String> getAllAttributionsAt(int offset) {
    return _spans.getAllAttributionsAt(offset);
  }

  /// Adds the given attribution to all characters within the given
  /// `range`, inclusive.
  void addAttribution(String name, TextRange range) {
    _spans.addAttribution(name: name, start: range.start, end: range.end);
  }

  /// Removes the given attribution from all characters within the
  /// given `range`, inclusive.
  void removeAttribution(String name, TextRange range) {
    _spans.addAttribution(name: name, start: range.start, end: range.end);
  }

  /// If ALL of the text in `range` contains the given attribution
  /// `name`, that attribution is removed from the text in `range`.
  /// Otherwise, all of the text in `range` is given the attribution
  /// `name`.
  void toggleAttribution(String name, TextRange range) {
    _spans.toggleAttribution(name: name, start: range.start, end: range.end);
  }

  // TODO: move this behavior to another class and make it extensible
  //       so that attributions can be interpreted as desired.
  TextSpan computeTextSpan([TextStyle baseStyle]) {
    print('computeTextSpan() - text length: ${text.length}');
    print(' - attributions used to compute spans:');
    print(_spans);

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      print(' - text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: baseStyle);
    }

    final spanBuilder = _TextSpanBuilder(text: text);

    // Cut up attributions in a series of corresponding "start"
    // and "end" points for every different combination of
    // attributions.
    final startPoints = <int>[0]; // we always start at zero
    final endPoints = <int>[];

    print(' - accumulating start and end points:');
    for (final marker in _spans.attributions) {
      print(' - marker at ${marker.offset}');
      print(' - start points before change: $startPoints');
      print(' - end points before change: $endPoints');

      if (marker.isStart) {
        // Add a `start` point.
        if (!startPoints.contains(marker.offset)) {
          print(' - adding start point at ${marker.offset}');
          startPoints.add(marker.offset);
        }

        // If there is no styling before this `start` point
        // then there won't be an `end` just before this
        // `start` point. Insert one.
        if (marker.offset > 0 && !endPoints.contains(marker.offset - 1)) {
          print(' - going back one and adding end point at: ${marker.offset - 1}');
          endPoints.add(marker.offset - 1);
        }
      }
      if (marker.isEnd) {
        // Add an `end` point.
        if (!endPoints.contains(marker.offset)) {
          print(' - adding an end point at: ${marker.offset}');
          endPoints.add(marker.offset);
        }

        // Automatically start another range if we aren't at
        // the end of the string. We do this because we're not
        // guaranteed to have another `start` marker after this
        // `end` marker.
        if (marker.offset < text.length - 1 && !startPoints.contains(marker.offset + 1)) {
          print(' - jumping forward one to add a start point at: ${marker.offset + 1}');
          startPoints.add(marker.offset + 1);
        }
      }

      print(' - start points after change: $startPoints');
      print(' - end points after change: $endPoints');
    }
    if (!endPoints.contains(text.length - 1)) {
      // This condition occurs when there are no style spans, or
      // when the final span is un-styled.
      print(' - adding a final endpoint at end of text');
      endPoints.add(text.length - 1);
    }

    if (startPoints.length != endPoints.length) {
      print(' - start points: $startPoints');
      print(' - end points: $endPoints');
      throw Exception(
          ' - mismatch between number of start points and end points. Text length: ${text.length}, Start: ${startPoints.length} -> ${startPoints}, End: ${endPoints.length} -> ${endPoints}, from attributions: ${_spans.attributions}');
    }

    // Sort the start and end points so that they can be
    // processed from beginning to end.
    startPoints.sort();
    endPoints.sort();

    // Convert the "start" and "end" points to a series of
    // ranges for easy processing.
    final ranges = <TextRange>[];
    for (int i = 0; i < startPoints.length; ++i) {
      ranges.add(TextRange(
        start: startPoints[i],
        end: endPoints[i],
      ));
      print(' - span range: ${ranges[i]}');
    }

    // Iterate through the ranges and build a TextSpan.
    for (final range in ranges) {
      print(' - styling range: $range');
      spanBuilder
        ..start(style: _computeStyleAt(range.start, baseStyle))
        ..end(offset: range.end);
    }
    return spanBuilder.build(baseStyle);
  }

  TextStyle _computeStyleAt(int offset, [TextStyle baseStyle]) {
    final attributions = _spans.getAllAttributionsAt(offset);
    // print(' - attributions at $offset: $attributions');
    return _addStyles(baseStyle ?? TextStyle(), attributions);
  }

  TextStyle _addStyles(TextStyle base, Set<String> attributions) {
    TextStyle newStyle = base;
    for (final attribution in attributions) {
      switch (attribution) {
        case 'bold':
          newStyle = newStyle.copyWith(
            fontWeight: FontWeight.bold,
          );
          break;
        case 'italics':
          newStyle = newStyle.copyWith(
            fontStyle: FontStyle.italic,
          );
          break;
        case 'strikethrough':
          newStyle = newStyle.copyWith(
            decoration: TextDecoration.lineThrough,
          );
          break;
      }
    }
    return newStyle;
  }

  /// Copies all text and attributions from `startOffset` to
  /// `endOffset`, inclusive.
  AttributedText copyText(int startOffset, [int endOffset]) {
    print('copyText() - start: $startOffset, end: $endOffset');

    // Note: -1 because copyText() uses an exclusive `start` and `end` but
    // _copyAttributionRegion() uses an inclusive `start` and `end`.
    final startCopyOffset = startOffset < text.length ? startOffset : text.length - 1;
    int endCopyOffset;
    if (endOffset == startOffset) {
      endCopyOffset = startCopyOffset;
    } else if (endOffset != null) {
      endCopyOffset = endOffset - 1;
    } else {
      endCopyOffset = text.length - 1;
    }
    print(' - copy offsets, start: $startCopyOffset, end: $endCopyOffset');

    return AttributedText(
      text: text.substring(startOffset, endOffset),
      spans: _spans.copyAttributionRegion(startCopyOffset, endCopyOffset),
    );
  }

  /// Copies this `AttributedText` and appends the text and spans
  /// in the `other` AttributedText` to the end of the copy.
  AttributedText copyAndAppend(AttributedText other) {
    print('copyAndAppend()');
    print(' - our attributions before pushing them:');
    print(_spans);
    if (other.text.isEmpty) {
      print(' - `other` has no text. Returning a direct copy of ourselves.');
      return AttributedText(
        text: text,
        spans: _spans.copy(),
      );
    }

    return AttributedText(
      text: text + other.text,
      spans: _spans.copy()..addToEnd(other._spans),
    );
  }

  /// Returns a copy of this `AttributedText` with `textToInsert`
  /// inserted at `startOffset`.
  ///
  /// Any attributions that spanned `startOffset` are applied to
  /// the inserted text. All spans that start after `startOffset`
  /// are pushed back by the length of `textToInsert`.
  AttributedText insertString({
    @required String textToInsert,
    @required int startOffset,
    Set<String> applyAttributions = const {},
  }) {
    print('insertString() - text: "$textToInsert", start: $startOffset, attributions: $applyAttributions');

    print(' - copying text to the left');
    final startText = this.copyText(0, startOffset);

    print(' - copying text to the right');
    final endText = this.copyText(startOffset);

    print(' - creating new attributed text for insertion');
    final insertedText = AttributedText(
      text: textToInsert,
    );
    final insertTextRange = TextRange(start: 0, end: textToInsert.length - 1);
    for (String name in applyAttributions) {
      insertedText.addAttribution(name, insertTextRange);
    }

    print(' - combining left text, insertion text, and right text');
    return startText.copyAndAppend(insertedText).copyAndAppend(endText);
  }

  /// Cuts a region of text and attributions from `startOffset`,
  /// inclusive, to `endOffset`, exclusive.
  AttributedText removeRegion({
    @required int startOffset,
    @required int endOffset,
  }) {
    print('Removing text region from $startOffset to $endOffset');
    print(' - initial attributions:');
    print(_spans);
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    AttributedSpans contractedAttributions = _spans.copy()
      ..contractAttributions(
        startOffset: startOffset,
        count: endOffset - startOffset,
      );
    print(' - reduced text length: ${reducedText.length}');
    print(' - remaining attributions:');
    print(contractedAttributions);

    return AttributedText(
      text: reducedText,
      spans: contractedAttributions,
    );
  }
}

class _TextSpanBuilder {
  _TextSpanBuilder({
    @required this.text,
  });

  final String text;
  final List<TextSpan> _spans = [];

  int _currentOffset = 0;
  bool _expectsStart = true;
  TextStyle _currentStyle;

  void start({
    TextStyle style,
  }) {
    if (!_expectsStart) {
      throw Exception('Expected a span `end` but was told to `start()`. Offset: $_currentOffset');
    }
    if (_currentOffset >= text.length) {
      throw Exception(
          'Cannot start a new span beyond the end of the given text. Offset: $_currentOffset, Text: "$text"');
    }
    // print(' - starting span at $_currentOffset');
    _expectsStart = false;

    _currentStyle = style;
  }

  void end({
    @required int offset,
  }) {
    if (_expectsStart) {
      throw Exception('Expected a span `start` but was told to `end()`. Offset: $offset');
    }
    // print(' - ending span at $offset');
    _expectsStart = true;

    _spans.add(TextSpan(
      text: text.substring(_currentOffset, offset + 1),
      style: _currentStyle,
    ));

    _currentOffset = offset + 1;
    _currentStyle = null;
  }

  TextSpan build([TextStyle baseStyle]) {
    if (_currentOffset != text.length) {
      throw Exception('Some of the text was left without a span. This text will be lost if not styled.');
    }

    return _spans.length > 1
        ? TextSpan(
            children: List.of(_spans),
            style: baseStyle,
          )
        : TextSpan(
            text: text,
            style: _spans.isNotEmpty ? _spans.first.style : baseStyle,
          );
  }
}
