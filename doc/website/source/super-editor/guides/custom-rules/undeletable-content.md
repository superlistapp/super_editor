---
title: Un-Deletable Content
---
Apps might include content within a document that the user shouldn't be able to
delete. For example, a blog post editor might want to retain a title node at the
top, no matter what. 

The reason(s) for including un-deletable content can vary dramatically across
different apps and use-cases. As a result, the amount of work you need to do to
support un-deletable content can vary as well. This guide shows some approaches
that might help you achieve your goals.

## Un-selectable Components
TODO: Prevent a component from visually appearing selected.

## Preventing Deletion
TODO: Prevent or restore a node that the user tried to delete with the `Editor`.

## Healing Document Structure
TODO: Ensure there is always at least one node above and below an unselectable component.