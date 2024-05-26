---
title: Add a Popover Toolbar
---

# Add a Popover Toolbar

To display a Popover Toolbar, it is recomended to use an `OverlayPortal`. To do that, start by wraping `SuperEditor` with an `OverlayPortal` and give it a toolbar builder:

```dart
class MyApp extends StatefulWidget {
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  /// Controls the visibility of the toolbar.
  final _popoverToolbarController = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _popoverToolbarController,
      overlayChildBuilder: _buildPopoverToolbar,
      child: SuperEditor(),
    );
  }

  Widget _buildPopoverToolbar() {
    return const SizedBox();
  }
}
```

# Showing the toolbar

Usually, a Popover Toolbar is displayed when the user selects some content. To do that, listen for selection changes to show or hide the toolbar:

```dart
class MyAppState extends State<MyApp> {
  // ...
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  // ...

  @override
  void initState() {
    super.initState();
    _document = MutableDocument.empty();

    _composer = MutableDocumentComposer();
    _composer.selectionNotifier.addListener(_hideOrShowToolbar);
  }

  void _hideOrShowToolbar() {
    final selection = _composer.selection;
    if (selection == null) {
      // Nothing is selected. We don't want to show a toolbar in this case.
      _popoverToolbarController.hide();
      return;
    }

    if (selection.isCollapsed) {
      // We only want to show the toolbar when a span of text
      // is selected. Therefore, we ignore collapsed selections.
      _popoverToolbarController.hide();
      return;
    }

    // We have an expanded selection. Show the toolbar.
    _popoverToolbarController.show();
  }

  // ...
}
```

# Aligning the toolbar with the content

By default, no alignment is enforced to the toolbar. To align it with the content, and make it follow the content, it is recomended to use the `follow_the_leader` package.

Start by adding `follow_the_leader` to your dependencies in your `pubspec.yaml`.

```yaml
dependencies:
  follow_the_leader: latest_version
```

Wrap `SuperEditor` with a `KeyedSubtree` widget to delimit the viewport area and assign a `GlobalKey` to it. This is used to prevent the toolbar from going off-screen.

```dart
class MyAppState extends State<MyApp> {
  // ...
  final GlobalKey _viewportKey = GlobalKey();
  // ...

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      // ...
      child: KeyedSubtree(
        key: _viewportKey,
        child: SuperEditor(),
      ),
    );
  }
}
```

Create a `SelectionLayerLinks` instance and pass it to the `SuperEditor`. This object holds the links that make it possible to follow the content.

```dart
class MyAppState extends State<MyApp> {
  // ...
  final SelectionLayerLinks _selectionLayerLinks = SelectionLayerLinks();
  // ...

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      // ...
      child: KeyedSubtree(
        // ...
        child: SuperEditor(
          selectionLayerLinks: _selectionLayerLinks,
        ),
      ),
    );
  }
}
```

Create a `FollowerBoundary` to configure the boundary of the area where the toolbar is allowed to be.

```dart
class MyAppState extends State<MyApp> {
  // ...
  late FollowerBoundary _screenBoundary;
  // ...

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Confine the toolbar to the bounds of the widget attached
    // to the _viewportKey.
    _screenBoundary = WidgetFollowerBoundary(
      boundaryKey: _viewportKey,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }
}
```

Create a `FollowerAligner` to configure how the toolbar should be aligned with the selected content.

```dart
class MyAppState extends State<MyApp> {
  // ...
  late final FollowerAligner _toolbarAligner;
  // ...

  @override
  void initState() {
    super.initState();
    // Place the toolbar above the content by default.
    _toolbarAligner = CupertinoPopoverToolbarAligner(_viewportKey);
  };

  // ...
}
```

Finally, wrap the toolbar with a `Follower` widget.

```dart
class MyAppState extends State<MyApp> {
  // ...
  Widget _buildPopoverToolbar() {
    return Follower.withAligner(
      // Make the toolbar follow the expanded selection.
      link: _selectionLayerLinks.expandedSelectionBoundsLink,

      // Configure how the toolbar is aligned to the content.
      aligner: _toolbarAligner,

      // Configure the boundary where the toolbar is allowed
      // to be displayed.
      boundary: _screenBoundary,

      showWhenUnlinked: false,
      child: _buildToolbarContent(),
    );
  }

  Widget _buildToolbarContent() {
    return const SizedBox();
  }

  // ...
}
```

# Showing different toolbars depending on the content

To show different toolbar depending on the content, check the type of the selected node and show/hide the appropriate toolbars.

```dart
class MyAppState extends State<MyApp> {
  // ...
  void _hideOrShowToolbar() {
    // ...
    if (selection.base.nodeId != selection.extent.nodeId) {
      // Since we want to show different toolbars depending on the content,
      // we don't show the toolbar if more than one node is selected.
      _popoverToolbarController.hide();
      _imageToolbarController.hide();
      return;
    }

    // Grab the selected node to check its type.
    final selectedNode = _document.getNodeById(selection.extent.nodeId);

    if (selectedNode is ImageNode) {
      // The selected node is an image. Show the image toolbar and hide
      // the text toolbar.
      _popoverToolbarController.hide();
      _imageToolbarController.show();
      return;
    }

    // The currently selected node isn't an image. Hide the image toolbar
    // if it's visible.
    _imageToolbarController.hide();

    if (selectedNode is TextNode) {
      // The selected node is a text node, e.g., a paragraph, a list item,
      // a task, etc. Show the text toolbar and hide the image toolbar.
      _imageToolbarController.show();
      _popoverToolbarController.show();
      return;
    }

    // The currently selected node isn't a text node. Hide the text toolbar
    // if it's visible.
    _popoverToolbarController.hide();
  }
}
```

# Sharing the editor focus with the toolbar

In order to make it possible for the user to interact with focusable items in the toolbar, while keeping the editor focused (with non-primary focus), it is necessary to share focus between the editor and the popover toolbar.

To do that, create a `FocusNode` for the popover, and setup focus sharing by using a `SuperEditorPopover` widget.

```dart
class MyAppState extends State<MyApp> {
  // ...
  final FocusNode _popoverFocusNode = FocusNode();

  @override
  void dispose() {
    _popoverFocusNode.dispose();
    super.dispose();
  }

  // ...
  Widget _buildToolbarContent() {
    return SuperEditorPopover(
      popoverFocusNode: _popoverFocusNode,
      editorFocusNode: _editorFocusNode,
      // The toolbar content.
      child: SizedBox(),
    );
  }
}
```
