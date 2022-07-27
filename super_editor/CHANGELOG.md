## [0.2.2] - July, 2022: Desktop IME
 * Use the input method engine (IME) on Desktop (previously only available on mobile)
 * A number of `SuperTextField` fixes and improvements. These changes are part of the path to the next release, which is focused on stabilizing `SuperTextField`.

## [0.2.1] - ~July, 2022: Desktop IME~ (Removed from pub)
 * Use the input method engine (IME) on Desktop (previously only available on mobile)
 * A number of `SuperTextField` fixes and improvements. These changes are part of the path to the next release, which is focused on stabilizing `SuperTextField`.

## [0.2.0] - Feb, 2022: Mobile Support
 * Mobile document editing
 * Mobile text field editing
 * More document style controls

## [0.1.0] - June 3, 2021

The first release of Super Editor.

 * Document and editor abstractions
   * See `Document` for a readable document
   * See `MutableDocument` for a mutable document
   * See `DocumentEditor` to commit document changes in a transactional manner
   * See `DocumentSelection` for a logical representation of selected document content
   * See `DocumentLayout` for the base abstraction for a visual document layout
 * Out-of-the-box editor: Commonly used types of content, visual layout, and user interactions are supported
   by artifacts available in the `default_editor` package.
 * Markdown serialization is available in the `serialization` package.
 * SuperTextField: An early version of a custom text field called `SuperTextField` is available in
   the `infrastructure` package.
 * SuperSelectableText: All text display in Super Editor is based on the `SuperSelectableText` widget,
   which is available in the `infrastructure` package.
 * AttributedText: a logical representation of text with attributed spans is available
   in the `infrastructure` package.
 * AttributedSpans: a logical representation of attributed spans is available in the
   `infrastructure` package.
