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
  /// The given [inlineWidgetBuilders] interprets every placeholder `Object`
  /// and builds a corresponding inline widget.
  InlineSpan computeInlineSpan(
    BuildContext context,
    AttributionStyleBuilder styleBuilder,
    InlineWidgetBuilderChain inlineWidgetBuilders,
  ) {
    if (isEmpty) {
      // There is no text and therefore no attributions.
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final inlineSpans = <InlineSpan>[];

    final collapsedSpans = spans.collapseSpans(contentLength: length);

    for (final span in collapsedSpans) {
      final textStyle = styleBuilder(span.attributions);

      // A single span might be divided in multiple inline spans if there are placeholders.
      // Keep track of the start of the current inline span.
      int startOfInlineSpan = span.start;

      // Look for placeholders within the current span and split the span accordingly.
      int characterIndex = span.start;
      while (characterIndex <= span.end) {
        if (placeholders[characterIndex] != null) {
          // We found a placeholder. Build a widget for it.

          if (characterIndex > startOfInlineSpan) {
            // There is text before the placeholder.
            inlineSpans.add(
              TextSpan(
                text: substring(startOfInlineSpan, characterIndex),
                style: textStyle,
              ),
            );
          }

          Widget? inlineWidget;
          for (final builder in inlineWidgetBuilders) {
            inlineWidget = builder(context, textStyle, placeholders[characterIndex]!);
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

          // Start another inline span after the placeholder.
          startOfInlineSpan = characterIndex + 1;
        }

        characterIndex += 1;
      }

      if (startOfInlineSpan <= span.end) {
        // There is text after the last placeholder or there is no placeholder at all.
        inlineSpans.add(
          TextSpan(
            text: substring(startOfInlineSpan, span.end + 1),
            style: textStyle,
          ),
        );
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
