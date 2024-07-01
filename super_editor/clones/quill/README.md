# Feather

A Flutter clone of Quill

## Features TODO
At the time of writing, this clone is a pretty close approximation to the standard Quill editor.
However, the following updates should be made to more closely align with Quill.

 * Convert block types by line, not node.
   * Given a multi-line code block, when the user selects the code and presses the code button to
     turn the code back into a paragraph, only the selected lines are switched from code to a paragraph.
 * Multiline blockquotes shouldn't be allowed (as per observation of the standard Quill editor).
 * Back-to-back code blocks should automatically be combined into one code block.
 * All nodes should support horizontal alignment (not just text nodes).