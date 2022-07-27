## [0.2.0] - July, 2022

BREAKING - Attributions in an `AttributedText` are now visited by a `AttributionVisitor` instead of a callback, and the visitor receives span markers in a more useful way.

## [0.1.3] - June 3, 2022

Changed the `meta` dependency to a version that's compatible with Flutter

## [0.1.2] - June 2, 2022 (DEPRECATED)

Fixed a couple bugs related to merging attribution spans when adding new spans.

## [0.1.1] - April 4, 2022

Downgraded `collection` from `1.16.0` to `1.15.0` because `flutter_test` is pinned to `1.15.0`

## [0.1.0] - April 2, 2022

The first release of attributed_text, which was extracted from super_editor.