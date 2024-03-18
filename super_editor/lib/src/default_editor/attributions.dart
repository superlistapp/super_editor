import 'dart:ui';

import 'package:attributed_text/attributed_text.dart';

/// Header 1 style block attribution.
const header1Attribution = NamedAttribution('header1');

/// Header 2 style block attribution.
const header2Attribution = NamedAttribution('header2');

/// Header 3 style block attribution.
const header3Attribution = NamedAttribution('header3');

/// Header 4 style block attribution.
const header4Attribution = NamedAttribution('header4');

/// Header 5 style block attribution.
const header5Attribution = NamedAttribution('header5');

/// Header 6 style block attribution.
const header6Attribution = NamedAttribution('header6');

/// Plain paragraph block attribution.
const paragraphAttribution = NamedAttribution('paragraph');

/// Blockquote attribution
const blockquoteAttribution = NamedAttribution('blockquote');

/// Bold style attribution.
const boldAttribution = NamedAttribution('bold');

/// Italics style attribution.
const italicsAttribution = NamedAttribution('italics');

/// Underline style attribution.
const underlineAttribution = NamedAttribution('underline');

/// Strikethrough style attribution.
const strikethroughAttribution = NamedAttribution('strikethrough');

/// Code style attribution.
const codeAttribution = NamedAttribution('code');

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a text color change.
///
/// Every [ColorAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [ColorAttribution]s
/// from overlapping.
class ColorAttribution implements Attribution {
  const ColorAttribution(this.color);

  @override
  String get id => 'color';

  final Color color;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ColorAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() {
    return '[ColorAttribution]: $color';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a backgrounnd color change.
///
/// Every [BackgroundColorAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [BackgroundColorAttribution]s
/// from overlapping.
class BackgroundColorAttribution implements Attribution {
  const BackgroundColorAttribution(this.color);

  @override
  String get id => 'background_color';

  final Color color;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundColorAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() {
    return '[BackgroundColorAttribution]: $color';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a font size change.
///
/// Every [FontSizeAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [FontSizeAttribution]s
/// from overlapping.
class FontSizeAttribution implements Attribution {
  const FontSizeAttribution(this.fontSize);

  @override
  String get id => 'font_size';

  final double fontSize;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontSizeAttribution && runtimeType == other.runtimeType && fontSize == other.fontSize;

  @override
  int get hashCode => fontSize.hashCode;

  @override
  String toString() {
    return '[FontSizeAttribution]: $fontSize';
  }
}

/// Attribution to be used within [AttributedText] to
/// represent a link.
///
/// Every [LinkAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [LinkAttribution]s
/// from overlapping.
///
/// If [LinkAttribution] does not meet your development needs,
/// a different class or value can be used to implement links
/// within [AttributedText]. This class doesn't have a special
/// relationship with [AttributedText].
class LinkAttribution implements Attribution {
  LinkAttribution({
    required this.url,
  });

  @override
  String get id => 'link';

  final Uri url;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LinkAttribution && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() {
    return '[LinkAttribution]: $url';
  }
}
