import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class AttributedText {
  AttributedText({
    this.text = '',
    List<TextAttributionMarker> attributions,
  }) : attributions = attributions ?? [] {
    int previousOffset = -1;
    for (final attribution in this.attributions) {
      if (attribution.offset < previousOffset) {
        throw Exception('The given attributions are not in the correct order.');
      }
      previousOffset = attribution.offset;
    }
  }

  // TODO: handle text insertion and deletion
  final String text;
  final List<TextAttributionMarker> attributions;

  bool hasAttributionAt(
    int offset, {
    String name,
  }) {
    TextAttributionMarker markerBefore = _getStartingMarkerAtOrBefore(offset, name: name);
    if (markerBefore == null) {
      // print(' - there is no start marker for "$name" before $offset');
      return false;
    }
    TextAttributionMarker markerAfter =
        markerBefore != null ? _getEndingMarkerAtOrAfter(markerBefore.offset, name: name) : null;
    if (markerAfter == null) {
      throw Exception('Found an open-ended attribution. It starts with: $markerBefore');
    }

    // print('Looking for "$name" at $offset. Before: ${markerBefore.offset}, After: ${markerAfter.offset}');

    return (markerBefore.offset <= offset) && (offset <= markerAfter.offset);
  }

  void addAttribution(String name, TextRange range) {
    if (!range.isValid) {
      return;
    }

    print('addAttribution()');
    if (!hasAttributionAt(range.start, name: name)) {
      print(' - adding start marker at: ${range.start}');
      _insertMarker(TextAttributionMarker(
        name: name,
        offset: range.start,
        markerType: AttributionMarkerType.start,
      ));
    }

    // Delete all `name` attributions between `range.start`
    // and `range.end`.
    final markersToDelete = attributions
        .where((attribution) => attribution.name == name)
        .where((attribution) => attribution.offset > range.start)
        .where((attribution) => attribution.offset <= range.end)
        .toList();
    print(' - removing ${markersToDelete.length} markers between ${range.start} and ${range.end}');
    // TODO: ideally we'd say "remove all" but that method doesn't
    //       seem to exist?
    attributions.removeWhere((element) => markersToDelete.contains(element));

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == AttributionMarkerType.end) {
      // If we didn't delete any markers, the span that began at
      // `range.start` or before needs to be capped off.
      //
      // If we deleted some markers, but the last marker was an
      // `end` marker, we still have an open-ended span and we
      // need to cap it off.
      print(' - inserting ending marker at: ${range.end}');
      _insertMarker(TextAttributionMarker(
        name: name,
        offset: range.end,
        markerType: AttributionMarkerType.end,
      ));
    }
    // Else, `range.end` is in the middle of larger span and
    // doesn't need to be inserted.

    print(' - all attributions after:');
    attributions.where((element) => element.name == name).forEach((element) {
      print(' - $element');
    });
  }

  void removeAttribution(String name, TextRange range) {
    if (!range.isValid) {
      return;
    }

    if (hasAttributionAt(range.start, name: name)) {
      final markerAtStart = _getMarkerAt(name, range.start);

      if (markerAtStart == null) {
        _insertMarker(TextAttributionMarker(
          name: name,
          // Note: if `range.start` is zero, then markerAtStart
          // must not be null, so this condition never triggers.
          offset: range.start - 1,
          markerType: AttributionMarkerType.end,
        ));
      } else if (markerAtStart.isStart) {
        _removeMarker(markerAtStart);
      } else {
        throw Exception(
            '_hasAttributionAt() said there was an attribution for "$name" at offset "${range.start}", but there is an `end` marker at that position.');
      }
    }

    // Delete all `name` attributions between `range.start`
    // and `range.end`.
    final markersToDelete = attributions
        .where((attribution) => attribution.name == name)
        .where((attribution) => attribution.offset > range.start)
        .where((attribution) => attribution.offset <= range.end)
        .toList();
    // TODO: ideally we'd say "remove all" but that method doesn't
    //       seem to exist?
    attributions.removeWhere((element) => markersToDelete.contains(element));

    if (range.end >= text.length - 1) {
      // If the range ends at the end of the text, we don't need to
      // insert any `start` markers because there can't be any
      // other `end` markers later in the text.
      return;
    }

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == AttributionMarkerType.start) {
      // The last marker we deleted was a `start` marker.
      // Therefore, an `end` marker appears somewhere down the line.
      // We can't leave it dangling. Add a `start` marker back.
      _insertMarker(TextAttributionMarker(
        name: name,
        offset: range.end + 1,
        markerType: AttributionMarkerType.start,
      ));
    }
  }

  /// If ALL of the text in `range` contains the given
  /// attribution `name`, that attribution is removed
  /// from the text in `range`. Otherwise, all of the
  /// text in `range` is given the attribution `name`.
  void toggleAttribution(String name, TextRange range) {
    if (_isContinuousAttribution(name, range)) {
      removeAttribution(name, range);
    } else {
      addAttribution(name, range);
    }
  }

  bool _isContinuousAttribution(String name, TextRange range) {
    TextAttributionMarker markerBefore = _getNearestMarkerBefore(range.start, name: name);

    if (markerBefore == null || markerBefore.isEnd) {
      return false;
    }

    final indexBefore = attributions.indexOf(markerBefore);
    final nextMarker = attributions
        .sublist(indexBefore)
        .firstWhere((marker) => marker.name == name && marker.offset > indexBefore, orElse: () => null);

    if (nextMarker == null) {
      throw Exception('Inconsistent attributions state. Found a `start` marker with no matching `end`.');
    }
    if (nextMarker.isStart) {
      throw Exception('Inconsistent attributions state. Found a `start` marker following a `start` marker.');
    }

    // If there is even one additional marker in the `range`
    // of interest, it means that the given attribution is
    // not applied to the entire range.
    return nextMarker.offset >= range.end;
  }

  /// Preconditions:
  ///  - there must not already exist a marker with the same
  ///    attribution at the same offset.
  void _insertMarker(TextAttributionMarker newMarker) {
    TextAttributionMarker markerAfter =
        attributions.firstWhere((existingMarker) => existingMarker.offset >= newMarker.offset, orElse: () => null);

    if (markerAfter != null) {
      final markerAfterIndex = attributions.indexOf(markerAfter);
      attributions.insert(markerAfterIndex, newMarker);
    } else {
      // Insert the new marker at the end.
      attributions.add(newMarker);
    }
  }

  /// Preconditions:
  ///  - `marker` must exist in the `attributions` list.
  void _removeMarker(TextAttributionMarker marker) {
    final index = attributions.indexOf(marker);
    if (index < 0) {
      throw Exception('Tried to remove a marker that isn\'t in attributions list: $marker');
    }
    attributions.removeAt(index);
  }

  TextAttributionMarker _getNearestMarkerBefore(
    int offset, {
    String name,
  }) {
    TextAttributionMarker markerBefore;
    final markers = name != null ? attributions.where((marker) => marker.name == name) : attributions;

    for (final marker in markers) {
      if (marker.offset <= offset) {
        markerBefore = marker;
      }
      if (marker.offset >= offset) {
        break;
      }
    }

    return markerBefore;
  }

  TextAttributionMarker _getStartingMarkerAtOrBefore(int offset, {String name}) {
    return attributions //
        .reversed // search from the end so its the nearest start marker
        .where((marker) => name == null || marker.name == name)
        .firstWhere((marker) => marker.isStart && marker.offset <= offset, orElse: () => null);
  }

  TextAttributionMarker _getEndingMarkerAtOrAfter(int offset, {String name}) {
    return attributions
        .where((marker) => name == null || marker.name == name)
        .firstWhere((marker) => marker.isEnd && marker.offset >= offset, orElse: () => null);
  }

  TextAttributionMarker _getMarkerAt(String name, int offset) {
    return attributions
        .where((marker) => marker.name == name)
        .firstWhere((marker) => marker.offset == offset, orElse: () => null);
  }

  // TODO: move this behavior to another class and make it extensible
  //       so that attributions can be interpreted as desired.
  TextSpan computeTextSpan([TextStyle baseStyle]) {
    // print('computeTextSpan()');
    // print(' - base style line height: ${baseStyle?.height}');
    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      // print(' - text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: baseStyle);
    }

    final spanBuilder = TextSpanBuilder(text: text);

    // Cut up attributions in a series of corresponding "start"
    // and "end" points for every different combination of
    // attributions.
    final startPoints = <int>[0]; // we always start at zero
    final endPoints = <int>[];

    // print(' - accumulating start and end points:');
    for (final marker in attributions) {
      // print(' - marker at ${marker.offset}');
      if (marker.isStart) {
        // Add a `start` point.
        if (!startPoints.contains(marker.offset)) {
          // print(' - adding start point at ${marker.offset}');
          startPoints.add(marker.offset);
        }

        // If there is no styling before this `start` point
        // then there won't be an `end` just before this
        // `start` point. Insert one.
        if (marker.offset > 0 && !endPoints.contains(marker.offset - 1)) {
          // print(' - going back one and adding end point at: ${marker.offset - 1}');
          endPoints.add(marker.offset - 1);
        }
      }
      if (marker.isEnd) {
        // Add an `end` point.
        if (!endPoints.contains(marker.offset)) {
          // print(' - adding an end point at: ${marker.offset}');
          endPoints.add(marker.offset);
        }

        // Automatically start another range if we aren't at
        // the end of the string. We do this because we're not
        // guaranteed to have another `start` marker after this
        // `end` marker.
        if (marker.offset < text.length - 1 && !startPoints.contains(marker.offset + 1)) {
          // print(' - jumping forward one to add a start point at: ${marker.offset + 1}');
          startPoints.add(marker.offset + 1);
        }
      }
    }
    if (!endPoints.contains(text.length - 1)) {
      // This condition occurs when there are no style spans, or
      // when the final span is un-styled.
      // print(' - adding a final endpoint at end of text');
      endPoints.add(text.length - 1);
    }

    if (startPoints.length != endPoints.length) {
      print(' - start points: $startPoints');
      print(' - end points: $endPoints');
      throw Exception(
          ' - mismatch between number of start points and end points. Start: ${startPoints.length}, End: ${endPoints.length}');
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
      // print(' - span range: ${ranges[i]}');
    }

    // Iterate through the ranges and build a TextSpan.
    for (final range in ranges) {
      // print(' - styling range: $range');
      spanBuilder
        ..start(style: _computeStyleAt(range.start, baseStyle))
        ..end(offset: range.end);
    }
    return spanBuilder.build(baseStyle);
  }

  TextStyle _computeStyleAt(int offset, [TextStyle baseStyle]) {
    final attributions = _getAllAttributionsAt(offset);
    // print(' - attributions at $offset: $attributions');
    return _addStyles(baseStyle ?? TextStyle(), attributions);
  }

  Set<String> _getAllAttributionsAt(int offset) {
    final allNames = attributions.fold(<String>{}, (allNames, marker) => allNames..add(marker.name));
    final attributionsAtOffset = <String>{};
    for (final name in allNames) {
      final hasAttribution = hasAttributionAt(offset, name: name);
      // print(' - has "$name" attribution at $offset? ${hasAttribution}');
      if (hasAttribution) {
        attributionsAtOffset.add(name);
      }
    }
    return attributionsAtOffset;
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

  AttributedText copyText(int startOffset, [int endOffset]) {
    return AttributedText(
      text: text.substring(startOffset, endOffset),
      attributions: _copyAttributionRegion(startOffset, endOffset),
    );
  }

  List<TextAttributionMarker> _copyAttributionRegion(int startOffset, [int endOffset]) {
    endOffset = endOffset ?? text.length;

    final List<TextAttributionMarker> cutAttributions = [];

    final Set<String> neededStartMarkers = {};
    final Set<String> neededEndMarkers = {};
    for (int i = 0; i < attributions.length; ++i) {
      final marker = attributions[i];

      if (marker.offset < startOffset) {
        // Track any markers that begin before the `startOffset`
        // and continue beyond `startOffset`.
        if (marker.isStart) {
          neededStartMarkers.add(marker.name);
        } else {
          neededStartMarkers.remove(marker.name);
        }
      } else if (marker.offset == startOffset) {
        // At the very beginning of the copied region,
        // re-insert any unmatched `start` markers that
        // were removed.
        for (final startMarkerName in neededStartMarkers) {
          cutAttributions.add(TextAttributionMarker(
            name: startMarkerName,
            offset: marker.offset,
            markerType: AttributionMarkerType.start,
          ));
        }
      } else if (startOffset <= marker.offset && marker.offset < endOffset) {
        cutAttributions.add(marker);

        // Track any markers that begin between `startOffset`
        // and `endOffset` and continue beyond `endOffset`.
        if (marker.markerType == AttributionMarkerType.start) {
          neededEndMarkers.add(marker.name);
        } else {
          neededEndMarkers.remove(marker.name);
        }
      } else if (marker.offset == endOffset - 1) {
        // At the very end of the copy region, replace
        // any `end` markers that fell beyond the range.
        for (final endMarkerName in neededEndMarkers) {
          cutAttributions.add(TextAttributionMarker(
            name: endMarkerName,
            offset: marker.offset,
            markerType: AttributionMarkerType.end,
          ));
        }
      }
    }

    return cutAttributions;
  }

  AttributedText copyAndAppend(AttributedText other) {
    final List<TextAttributionMarker> combinedAttributions = List.from(attributions)..addAll(other.attributions);
    _mergeBackToBackAttributions(combinedAttributions, text.length - 1);

    return AttributedText(
      text: text + other.text,
      attributions: combinedAttributions,
    );
  }

  void _mergeBackToBackAttributions(List<TextAttributionMarker> attributions, int mergePoint) {
    // Look for any compatible attributions at
    // `mergePoint` and `mergePoint+1` and combine them.
    final startEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint).toList();
    final endEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint + 1).toList();
    for (final startEdgeMarker in startEdgeMarkers) {
      final matchingEndEdgeMarker = endEdgeMarkers.firstWhere((marker) => marker.name == startEdgeMarker.name);
      if (startEdgeMarker.isEnd && matchingEndEdgeMarker.isStart) {
        // These two attributions should be combined into one.
        // To do this, delete these two markers from the original
        // attribution list.
        attributions..remove(startEdgeMarker)..remove(matchingEndEdgeMarker);
      }
    }
  }

  AttributedText insertString({
    @required String textToInsert,
    @required int startOffset,
  }) {
    final combinedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        textToInsert +
        (startOffset < text.length ? text.substring(startOffset) : '');

    List<TextAttributionMarker> expandedAttributions = _expandAttributions(
      attributions: attributions,
      startOffset: startOffset,
      count: textToInsert.length,
    );

    return AttributedText(
      text: combinedText,
      attributions: expandedAttributions,
    );
  }

  List<TextAttributionMarker> _expandAttributions({
    @required List<TextAttributionMarker> attributions,
    @required int startOffset,
    @required int count,
  }) {
    print('Inserting startOffset: $startOffset');
    return attributions.map(
      (marker) {
        print(' - looking at marker at ${marker.offset}');
        // The rule here for expansion is that if text is inserted
        // at the very beginning of a span, or immediately after a
        // span, the text should be included in the span.
        if (marker.offset > startOffset || (marker.isEnd && marker.offset == startOffset - 1)) {
          print(' - pushing it forward');
          return marker.copyWith(offset: marker.offset + count);
        } else {
          print(' - leaving it alone');
          return marker;
        }
      },
    ).toList();
  }

  /// `startOffset` inclusive, `endOffset` exclusive
  AttributedText removeRegion({
    @required int startOffset,
    @required int endOffset,
  }) {
    print('Removing text region from $startOffset to $endOffset');
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    List<TextAttributionMarker> contractedAttributions = _contractAttributions(
      attributions: attributions,
      startOffset: startOffset,
      count: endOffset - startOffset,
    );
    print(' - remaining attributions:');
    for (final attribution in contractedAttributions) {
      print(' - ${attribution.name} - ${attribution.markerType}: ${attribution.offset}');
    }

    return AttributedText(
      text: reducedText,
      attributions: contractedAttributions,
    );
  }

  List<TextAttributionMarker> _contractAttributions({
    @required List<TextAttributionMarker> attributions,
    @required int startOffset,
    @required int count,
  }) {
    final contractedAttributions = <TextAttributionMarker>[];

    // Add all the markers that are unchanged.
    contractedAttributions.addAll(attributions.where((marker) => marker.offset <= startOffset));

    print('Removing $count characters starting at $startOffset');
    final needToEndAttributions = <String>{};
    final needToStartAttributions = <String>{};
    attributions
        .where((marker) => (startOffset < marker.offset) && (marker.offset < startOffset + count))
        .forEach((marker) {
      // Get rid of this marker and keep track of
      // any open-ended attributions that need to
      // be closed.
      print(' - removing ${marker.markerType} at ${marker.offset}');
      if (marker.isStart) {
        if (needToEndAttributions.contains(marker.name)) {
          // We've already removed an `end` marker so now
          // we're even.
          needToEndAttributions.remove(marker.name);
        } else {
          // We've removed a `start` marker that needs to
          // be replaced down the line.
          needToStartAttributions.add(marker.name);
        }
      } else {
        if (needToStartAttributions.contains(marker.name)) {
          // We've already removed a `start` marker so now
          // we're even.
          needToStartAttributions.remove(marker.name);
        } else {
          // We've removed an `end` marker that needs to
          // be replaced down the line.
          needToEndAttributions.add(marker.name);
        }
      }
    });

    // Re-insert any markers that are needed to retain
    // symmetry after the deletions above.
    needToStartAttributions.forEach((name) {
      print(' - adding back a start marker at ${startOffset + count}');
      contractedAttributions.add(TextAttributionMarker(
        name: name,
        offset: startOffset + count,
        markerType: AttributionMarkerType.start,
      ));
    });
    needToEndAttributions.forEach((name) {
      print(' - adding back an end marker at ${startOffset + count}');
      contractedAttributions.add(TextAttributionMarker(
        name: name,
        offset: startOffset + count,
        markerType: AttributionMarkerType.end,
      ));
    });

    // Add all remaining markers but with an `offset`
    // that is less by `count`.
    contractedAttributions.addAll(
      attributions
          .where((marker) => marker.offset >= startOffset + count)
          .map((marker) => marker.copyWith(offset: marker.offset - count)),
    );

    return contractedAttributions;
  }
}

class TextAttributionMarker implements Comparable<TextAttributionMarker> {
  const TextAttributionMarker({
    @required this.name,
    @required this.offset,
    @required this.markerType,
  });

  // TODO: replace String name with a TextAttribution type. We need
  //       hyperlinks to be able to hold their URL.
  final String name;
  final int offset;
  final AttributionMarkerType markerType;

  bool get isStart => markerType == AttributionMarkerType.start;

  bool get isEnd => markerType == AttributionMarkerType.end;

  TextAttributionMarker copyWith({
    String name,
    int offset,
    AttributionMarkerType markerType,
  }) =>
      TextAttributionMarker(
        name: name ?? this.name,
        offset: offset ?? this.offset,
        markerType: markerType ?? this.markerType,
      );

  @override
  String toString() => '[TextAttributionMarker] - name: $name, offset: $offset, type: $markerType';

  @override
  int compareTo(TextAttributionMarker other) {
    return offset - other.offset;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextAttributionMarker &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          offset == other.offset &&
          markerType == other.markerType;

  @override
  int get hashCode => name.hashCode ^ offset.hashCode ^ markerType.hashCode;
}

enum AttributionMarkerType {
  start,
  end,
}

class TextSpanBuilder {
  TextSpanBuilder({
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
