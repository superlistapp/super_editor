import 'dart:math';

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
        print('Attributions:');
        for (final attribution in this.attributions) {
          print(' - $attribution');
        }
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

  /// `range` end is `inclusive`.
  void addAttribution(String name, TextRange range) {
    if (!range.isValid) {
      return;
    }
    if (range.end >= text.length) {
      throw Exception('Attribution range exceeds text length. Text length: ${text.length}, given range: $range');
    }

    print('addAttribution(): $range');
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
    if (range.end >= text.length) {
      throw Exception('Attribution range exceeds text length.');
    }

    print('removeAttribution(): $range');
    if (hasAttributionAt(range.start, name: name)) {
      final markerAtStart = _getMarkerAt(name, range.start);

      if (markerAtStart == null) {
        print(' - inserting new `end` marker at start of range');
        _insertMarker(TextAttributionMarker(
          name: name,
          // Note: if `range.start` is zero, then markerAtStart
          // must not be null, so this condition never triggers.
          offset: range.start - 1,
          markerType: AttributionMarkerType.end,
        ));
      } else if (markerAtStart.isStart) {
        print(' - removing a `start` marker at start of range');
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
    print(' - removing ${markersToDelete.length} markers between ${range.start} and ${range.end}');
    // TODO: ideally we'd say "remove all" but that method doesn't
    //       seem to exist?
    attributions.removeWhere((element) => markersToDelete.contains(element));

    if (range.end >= text.length - 1) {
      // If the range ends at the end of the text, we don't need to
      // insert any `start` markers because there can't be any
      // other `end` markers later in the text.
      print(' - this range goes to the end of the text, so we don\'t need to insert any more markers.');
      print(' - all attributions after:');
      attributions.where((element) => element.name == name).forEach((element) {
        print(' - $element');
      });
      return;
    }

    final lastDeletedMarker = markersToDelete.isNotEmpty ? markersToDelete.last : null;

    if (lastDeletedMarker == null || lastDeletedMarker.markerType == AttributionMarkerType.start) {
      // The last marker we deleted was a `start` marker.
      // Therefore, an `end` marker appears somewhere down the line.
      // We can't leave it dangling. Add a `start` marker back.
      print(' - inserting a final `start` marker at the end to keep symmetry');
      _insertMarker(TextAttributionMarker(
        name: name,
        offset: range.end + 1,
        markerType: AttributionMarkerType.start,
      ));
    }

    print(' - all attributions after:');
    attributions.where((element) => element.name == name).forEach((element) {
      print(' - $element');
    });
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
    print('_isContinousAttribution(): "$name", range: $range');
    TextAttributionMarker markerBefore = _getNearestMarkerAtOrBefore(range.start, name: name);
    print(' - marker before: $markerBefore');

    if (markerBefore == null || markerBefore.isEnd) {
      return false;
    }

    final indexBefore = attributions.indexOf(markerBefore);
    final nextMarker = attributions
        .sublist(indexBefore)
        .firstWhere((marker) => marker.name == name && marker.offset > markerBefore.offset, orElse: () => null);
    print(' - next marker: $nextMarker');

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

  TextAttributionMarker _getNearestMarkerAtOrBefore(
    int offset, {
    String name,
  }) {
    TextAttributionMarker markerBefore;
    final markers = name != null ? attributions.where((marker) => marker.name == name) : attributions;

    for (final marker in markers) {
      if (marker.offset <= offset) {
        markerBefore = marker;
      }
      if (marker.offset > offset) {
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
    print('computeTextSpan() - text length: ${text.length}');
    print(' - attributions used to compute spans:');
    for (final marker in attributions) {
      print('   - $marker');
    }

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      print(' - text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: baseStyle);
    }

    final spanBuilder = TextSpanBuilder(text: text);

    // Cut up attributions in a series of corresponding "start"
    // and "end" points for every different combination of
    // attributions.
    final startPoints = <int>[0]; // we always start at zero
    final endPoints = <int>[];

    print(' - accumulating start and end points:');
    for (final marker in attributions) {
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
          ' - mismatch between number of start points and end points. Text length: ${text.length}, Start: ${startPoints.length} -> ${startPoints}, End: ${endPoints.length} -> ${endPoints}, from attributions: $attributions');
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
    final attributions = getAllAttributionsAt(offset);
    // print(' - attributions at $offset: $attributions');
    return _addStyles(baseStyle ?? TextStyle(), attributions);
  }

  Set<String> getAllAttributionsAt(int offset) {
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
      attributions: _copyAttributionRegion(startCopyOffset, endCopyOffset),
    );
  }

  List<TextAttributionMarker> _copyAttributionRegion(int startOffset, [int endOffset]) {
    endOffset = endOffset ?? text.length - 1;
    print('_copyAttributionRegion() - start: $startOffset, end: $endOffset');

    final List<TextAttributionMarker> cutAttributions = [];

    print(' - inspecting existing markers in full text');
    // TODO: this logic was adjusted to use count maps instead of Set's
    //       with added/removed names. This was done if a `start` and
    //       `end` marker exist at the same offset, the order is not
    //       guaranteed to be `start` then `end`. The reverse order results
    //       in incorrect belief that we need to insert start and end nodes.
    //       This map count solution solves that problem. It needs to be
    //       replicated in the other areas of this class that do the same
    //       thing.
    final Map<String, int> foundStartMarkers = {};
    final Map<String, int> foundEndMarkers = {};

    // Analyze all markers that appear before the start of
    // the copy range so that we can insert any appropriate
    // `start` markers at the beginning of the copy range.
    attributions //
        .where((marker) => marker.offset < startOffset) //
        .forEach((marker) {
      print(' - marker before the copy region: $marker');
      // Track any markers that begin before the `startOffset`
      // and continue beyond `startOffset`.
      if (marker.isStart) {
        print(' - remembering this marker to insert in copied region');
        foundStartMarkers.putIfAbsent(marker.name, () => 0);
        foundStartMarkers[marker.name] += 1;
      } else {
        print(
            ' - this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundStartMarkers.putIfAbsent(marker.name, () => 0);
        foundStartMarkers[marker.name] -= 1;
      }
    });

    // Insert any `start` markers at the start of the copy region
    // so that we maintain attribution symmetry.
    foundStartMarkers.forEach((markerName, count) {
      if (count == 1) {
        // Found an unmatched `start` marker. Replace it.
        print(' - inserting "$markerName" marker at start of copy region to maintain symmetry.');
        cutAttributions.add(TextAttributionMarker(
          name: markerName,
          offset: 0,
          markerType: AttributionMarkerType.start,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception(
            'Found an unbalanced number of `start` and `end` markers before offset: $startOffset - $attributions');
      }
    });

    // Directly copy every marker that appears within the cut
    // region.
    attributions //
        .where((marker) => startOffset <= marker.offset && marker.offset <= endOffset) //
        .forEach((marker) {
      print(' - copying "${marker.name}" at ${marker.offset} from original text to copy region.');
      cutAttributions.add(marker.copyWith(
        offset: marker.offset - startOffset,
      ));
    });

    // Analyze all markers that appear after the end of
    // the copy range so that we can insert any appropriate
    // `end` markers at the end of the copy range.
    attributions //
        .reversed //
        .where((marker) => marker.offset > endOffset) //
        .forEach((marker) {
      print(' - marker after the copy region: $marker');
      // Track any markers that end after the `endOffset`
      // and start before `endOffset`.
      if (marker.isEnd) {
        print(' - remembering this marker to insert in copied region');
        foundEndMarkers.putIfAbsent(marker.name, () => 0);
        foundEndMarkers[marker.name] += 1;
      } else {
        print(
            ' - this marker counters an earlier one we found. We will not re-insert this marker in the copied region');
        foundEndMarkers.putIfAbsent(marker.name, () => 0);
        foundEndMarkers[marker.name] -= 1;
      }
    });

    // Insert any `end` markers at the end of the copy region
    // so that we maintain attribution symmetry.
    foundEndMarkers.forEach((markerName, count) {
      if (count == 1) {
        // Found an unmatched `end` marker. Replace it.
        print(' - inserting "$markerName" marker at end of copy region to maintain symmetry.');
        cutAttributions.add(TextAttributionMarker(
          name: markerName,
          offset: endOffset - startOffset,
          markerType: AttributionMarkerType.end,
        ));
      } else if (count < 0 || count > 1) {
        throw Exception(
            'Found an unbalanced number of `start` and `end` markers after offset: $endOffset - $attributions');
      }
    });

    print(' - copied attributions:');
    for (final attribution in cutAttributions) {
      print('   - $attribution');
    }

    return cutAttributions;
  }

  AttributedText copyAndAppend(AttributedText other) {
    print('copyAndAppend()');
    print(' - our attributions before pushing them:');
    for (final marker in attributions) {
      print('   - $marker');
    }
    if (other.text.isEmpty) {
      print(' - `other` has no text. Returning a direct copy of ourselves.');
      return AttributedText(
        text: text,
        attributions: List.from(attributions),
      );
    }

    // Push back all the `other` markers to make room for the
    // text we're putting in front of them.

    final pushDistance = text.length;
    print(' - pushing `other` markers by text length: $pushDistance');
    print(' - `other` attributions before pushing them:');
    for (final marker in other.attributions) {
      print('   - $marker');
    }
    final List<TextAttributionMarker> appendedAttributions = other.attributions
        .map(
          (marker) => marker.copyWith(offset: marker.offset + pushDistance),
        )
        .toList();

    // Combine `this` and `other` attributions into one list.
    final List<TextAttributionMarker> combinedAttributions = List.from(attributions)..addAll(appendedAttributions);
    print(' - combined attributions before merge:');
    for (final marker in combinedAttributions) {
      print('   - $marker');
    }

    // Clean up the boundary between the two lists of attributions
    // by merging compatible attributions that meet at teh boundary.
    _mergeBackToBackAttributions(combinedAttributions, text.length - 1);

    print(' - combined attributions after merge:');
    for (final marker in combinedAttributions) {
      print('   - $marker');
    }

    return AttributedText(
      text: text + other.text,
      attributions: combinedAttributions,
    );
  }

  bool _hasMarker(TextAttributionMarker marker) {
    final matchingMarker = attributions.firstWhere((existingMarker) => existingMarker == marker, orElse: () => null);
    return matchingMarker != null;
  }

  void _mergeBackToBackAttributions(List<TextAttributionMarker> attributions, int mergePoint) {
    print(' - merging attributions at $mergePoint');
    // Look for any compatible attributions at
    // `mergePoint` and `mergePoint+1` and combine them.
    final startEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint).toList();
    final endEdgeMarkers = attributions.where((marker) => marker.offset == mergePoint + 1).toList();
    for (final startEdgeMarker in startEdgeMarkers) {
      print(' - marker on left side: $startEdgeMarker');
      final matchingEndEdgeMarker = endEdgeMarkers
          .firstWhere((marker) => marker.name == startEdgeMarker.name && marker.isStart, orElse: () => null);
      print(' - matching marker on right side? $matchingEndEdgeMarker');
      if (startEdgeMarker.isEnd && matchingEndEdgeMarker != null) {
        // These two attributions should be combined into one.
        // To do this, delete these two markers from the original
        // attribution list.
        print(' - removing both markers because they offset each other');
        attributions..remove(startEdgeMarker)..remove(matchingEndEdgeMarker);
      }
    }
  }

  AttributedText insertString({
    @required String textToInsert,
    @required int startOffset,
    List<String> applyAttributions = const [],
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
    print(' - initial attributions:');
    for (final attribution in attributions) {
      print('   - ${attribution.name} - ${attribution.markerType}: ${attribution.offset}');
    }
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    List<TextAttributionMarker> contractedAttributions = _contractAttributions(
      attributions: attributions,
      startOffset: startOffset,
      count: endOffset - startOffset,
    );
    print(' - reduced text length: ${reducedText.length}');
    print(' - remaining attributions:');
    for (final attribution in contractedAttributions) {
      print('   - ${attribution.name} - ${attribution.markerType}: ${attribution.offset}');
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
    contractedAttributions.addAll(attributions.where((marker) => marker.offset < startOffset));

    print(' - removing $count characters starting at $startOffset');
    final needToEndAttributions = <String>{};
    final needToStartAttributions = <String>{};
    attributions
        .where((marker) => (startOffset <= marker.offset) && (marker.offset < startOffset + count))
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
      final offset = startOffset > 0 ? startOffset - 1 : 0;
      print(' - adding back a start marker at $offset');
      contractedAttributions.add(TextAttributionMarker(
        name: name,
        offset: offset,
        markerType: AttributionMarkerType.start,
      ));
    });
    needToEndAttributions.forEach((name) {
      final offset = startOffset > 0 ? startOffset - 1 : 0;
      print(' - adding back an end marker at $offset');
      contractedAttributions.add(TextAttributionMarker(
        name: name,
        offset: offset,
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
