## [0.1.5]
Added support for font scaling (April, 2023)
 
 * Bumped `attributed_text` dependency to `0.2.1`.
 
## [0.1.4]
Fixed a `NullPointerException` in `SuperTextLayout` (Oct, 2022)

## [0.1.3]
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0` (July, 2022)

## [0.1.2] - DEPRECATED
Upgraded the dependency on `attributed_text` from `0.1.3` to `0.2.0` (July, 2022)

## [0.1.1] - DEPRECATED
Added `estimatedLineHeight` to `TextLayout`. The method is experimental - it may be removed later (July, 2022)

## [0.1.0]
The `super_text_layout` package is extracted from `super_editor` (May, 2022)

 * Introduces `SuperText` widget to render text with layers above and beneath the text
 * Introduces `SuperTextWithSelection` to easily paint text with traditional user selections, 
   which replaces previous uses of `SuperSelectableText` from earlier super_editor work
