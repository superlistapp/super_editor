<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845431-e83699df-5c6c-4e9c-90fc-c12277cc2f48.png" width="300" alt="Super Editor"><br>
  <span><b>Open source, configurable, extensible text editor and document renderer for Flutter.</b></span><br><br>
</p>

<p align="center"><b>Super Editor works with any backend. Plug yours in and go!</b></p><br>

<p align="center">Super Editor was initiated by <a href="https://superlist.com">Superlist</a> and is implemented and maintained by the <a href="https://flutterbountyhunters.com">Flutter Bounty Hunters</a>, Superlist, and the contributors.</p>

<hr>

<p align="center">Do you use Flutter's <b>stable</b> branch? Be sure to checkout <code>super_editor</code>'s <b><a href="https://github.com/superlistapp/super_editor/commits/stable">stable</a></b> branch, for compatibility.<br>Do you use Flutter's <b>master</b> branch? Be sure to checkout <code>super_editor</code>'s <b><a href="https://github.com/superlistapp/super_editor/commits/main">main</a></b> branch, for compabitility.</p>

<hr>

<p align="center"><img src="https://raw.githubusercontent.com/superlistapp/super_editor/main/super_editor/doc/marketing/readme-header.png" width="500" alt="Super Editor"></p>

<h2 align="center">Super Editor & Super Text Field</h2>

Please see the [SuperEditor README](super_editor/README.md) about how to use the packages, or run the [sample editor](super_editor/example/README.md).

A web demo is accessible at [https://superlist.com/SuperEditor](https://superlist.com/SuperEditor/).

<hr>

<h2 align="center">We're building an entire toolkit!</h2>
You might notice that this is a mono-repo, which includes multiple projects. That's because we're not just building an editor. We're building a document editing toolkit. In fact, we're revolutionizing all text layout and editing with Flutter! Check out some of our supporting projects.

<p float="left">
  <a href="super_editor/README.md"><img src="https://user-images.githubusercontent.com/7259036/170845431-e83699df-5c6c-4e9c-90fc-c12277cc2f48.png" width="300" alt="Super Editor"></a>
  <a href="super_text_layout/README.md"><img src="https://user-images.githubusercontent.com/7259036/170845454-e7a6e0ec-07f0-4f80-be31-3e5730a72aaf.png" width="300" alt="Super Text Layout"></a>
  <a href="attributed_text/README.md"><img src="https://user-images.githubusercontent.com/7259036/170845473-268655ac-3fec-47c1-86ab-41a1391aa1e0.png" width="300" alt="Attributed Text"></a>
</p>

<h2 align="center">Mono-repo Versioning</h2>
If you have compilation errors when using the GitHub version of super_editor, try overriding dependencies for the other packages in this mono-repo, e.g., super_editor_markdown, super_text_layout, and attributed_text. This project often makes changes to multiple packages within the mono-repo, which requires that you use the latest main or stable version of every package.

You can override your dependencies as follows:

```yaml
dependency_overrides:
  super_editor:
    git:
      url: https://github.com/superlistapp/super_editor
      path: super_editor
      ref: stable # or "main"
  super_editor_markdown:
    git:
      url: https://github.com/superlistapp/super_editor
      path: super_editor_markdown
      ref: stable
  super_text_layout:
    git:
      url: https://github.com/superlistapp/super_editor
      path: super_text_layout
      ref: stable
  attributed_text:
    git:
      url: https://github.com/superlistapp/super_editor
      path: attributed_text
      ref: stable
```
