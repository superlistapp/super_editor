import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Creates the desired [TextStyle] given the [attributions] associated
/// with a span of text.
///
/// The [attributions] set may be empty.
typedef AttributionStyleBuilder = TextStyle Function(Set<Attribution> attributions);

extension ToSpanRange on TextRange {
  SpanRange toSpanRange() => SpanRange(start, end);
}

extension ComputeTextSpan on AttributedText {
  /// Returns a Flutter [InlineSpan] comprised of styled text and widgets
  /// based on an [AttributedText].
  ///
  /// The given [styleBuilder] interprets the meaning of every attribution
  /// and constructs [TextStyle]s accordingly.
  ///
  /// The given [inlineWidgetBuilder] interprets every placeholder `Object`
  /// and builds a corresponding inline widget.
  InlineSpan computeInlineSpan(
    BuildContext context,
    AttributionStyleBuilder styleBuilder,
    InlineWidgetBuilderChain inlineWidgetBuilderChain,
  ) {
    if (isEmpty) {
      // There is no text and therefore no attributions.
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final inlineSpans = <InlineSpan>[];

    final collapsedSpans = spans.collapseSpans(contentLength: length);
    var spanIndex = 0;
    var span = collapsedSpans.first;

    int start = 0;
    while (start < length) {
      late int contentEnd;
      if (placeholders[start] != null) {
        // This section is a placeholder.
        contentEnd = start + 1;

        final textStyle = styleBuilder({});
        Widget? inlineWidget;
        for (final builder in inlineWidgetBuilderChain) {
          inlineWidget = builder(context, textStyle, placeholders[start]!);
          if (inlineWidget != null) {
            break;
          }
        }

        if (inlineWidget != null) {
          inlineSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: inlineWidget,
            ),
          );
        }
      } else {
        // This section is text. The end of this text is either the
        // end of the AttributedText, or the index of the next placeholder.
        contentEnd = span.end + 1;
        for (final entry in placeholders.entries) {
          if (entry.key > start) {
            contentEnd = entry.key;
            break;
          }
        }

        inlineSpans.add(
          TextSpan(
            text: substring(start, contentEnd),
            style: styleBuilder(span.attributions),
          ),
        );
      }

      if (contentEnd == span.end + 1) {
        // The content and span end at the same place.
        start = contentEnd;
      } else if (contentEnd < span.end + 1) {
        // The content ends before the span.
        start = contentEnd;
      } else {
        // The span ends before the content.
        start = span.end + 1;
      }

      if (start > span.end && start < length) {
        spanIndex += 1;
        span = collapsedSpans[spanIndex];
      }
    }

    return TextSpan(
      text: "",
      children: inlineSpans,
      style: styleBuilder({}),
    );
  }

  /// Returns a Flutter [TextSpan] that is styled based on the
  /// attributions within this [AttributedText].
  ///
  /// The given [styleBuilder] interprets the meaning of every
  /// attribution and constructs [TextStyle]s accordingly.
  @Deprecated("Use computeInlineSpan() instead, which adds support for inline widgets.")
  TextSpan computeTextSpan(AttributionStyleBuilder styleBuilder) {
    attributionsLog.fine('text length: ${text.length}');
    attributionsLog.fine('attributions used to compute spans:');
    attributionsLog.fine(spans.toString());

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      attributionsLog.fine('text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final collapsedSpans = spans.collapseSpans(contentLength: text.length);
    final textSpans = collapsedSpans
        .map((attributedSpan) => TextSpan(
              text: text.substring(attributedSpan.start, attributedSpan.end + 1),
              style: styleBuilder(attributedSpan.attributions),
            ))
        .toList();

    return textSpans.length == 1
        ? textSpans.first
        : TextSpan(
            children: textSpans,
            style: styleBuilder({}),
          );
  }
}

/// A Chain of Responsibility that builds widgets for text inline placeholders.
///
/// The first [InlineWidgetBuilder] that returns a non-null [Widget] is used by
/// the client.
typedef InlineWidgetBuilderChain = List<InlineWidgetBuilder>;

/// Builder that returns a [Widget] for a given [placeholder], or `null`
/// if this builder doesn't know how to build the given [placeholder].
///
/// The given [textStyle] is the style applied to the text in the vicinity
/// of the placeholder.
typedef InlineWidgetBuilder = Widget? Function(
  BuildContext context,
  TextStyle textStyle,
  Object placeholder,
);
