import 'package:flutter/painting.dart';

/// A function that calculates the pixels to indent a text block in a document, given
/// the [blockTextStyle], and the [indent] level.
///
/// A text block is a document block that contains text, e.g., paragraph, list item, task.
typedef TextBlockIndentCalculator = double Function(TextStyle blockTextStyle, int indent);
