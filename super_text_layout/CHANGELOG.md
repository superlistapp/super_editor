## [0.1.6] - May, 2023
 * Explicitly upgraded to Dart 3 support.
 * Bumped `attributed_text` dependency to `0.2.2`.

## [0.1.5] - April, 2023
Added support for font scaling
 
 * Bumped `attributed_text` dependency to `0.2.1`.
 
## [0.1.4] - Oct, 2022
Fixed a `NullPointerException` in `SuperTextLayout`

## [0.1.3] - July, 2022
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0`

## [0.1.2] - DEPRECATED - July, 2022
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0`

## [0.1.1] - DEPRECATED - July, 2022
Added `estimatedLineHeight` to `TextLayout`. The method is experimental - it may be removed later

## [0.1.0] - May, 2022
The `super_text_layout` package is extracted from `super_editor`

 * Introduces `SuperText` widget to render text with layers above and beneath the text
 * Introduces `SuperTextWithSelection` to easily paint text with traditional user selections, 
   which replaces previous uses of `SuperSelectableText` from earlier super_editor work
