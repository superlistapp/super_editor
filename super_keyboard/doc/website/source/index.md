---
title: Get Started
contentRenderers:
  - jinja
  - markdown
---
The `super_keyboard` plugin provides two primary mechanisms to observe the state
of the software keyboard: a widget builder, and a direct listener.

The states of a software keyboard are:
* Closed
* Opening
* Open
* Closing

<div class="warning">
  <p><b>WARNING:</b> iOS and Android are somewhat unreliable in reporting these states. This plugin
does the best it can to forward keyboard state changes, but you might discover situations
where a state is skipped, or reported late. There's nothing this plugin can do about that.</p>
</div>

Use the `SuperKeyboardBuilder` to rebuild a subtree whenever the status of the
keyboard changes:

{{ components.codeSampleBuilder() }}

Use `SuperKeyboard` to directly listen for keyboard state changes:

{{ components.codeSampleDirectListening() }}