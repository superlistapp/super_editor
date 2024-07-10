import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/flutter_extensions/finders.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Inspects a given [SuperReader] in the widget tree.
class SuperReaderInspector {
  /// Returns `true` if the given [SuperReader] widget currently has focus, or
  /// `false` otherwise.
  ///
  /// {@template super_document_finder}
  /// By default, this method expects a single [SuperReader] in the widget tree and
  /// finds it `byType`. To specify one [SuperReader] among many, pass a [superDocumentFinder].
  /// {@endtemplate}
  static bool hasFocus([Finder? finder]) {
    final element = (finder ?? find.byType(SuperReader)).evaluate().single as StatefulElement;
    final superDocument = element.state as SuperReaderState;
    return superDocument.focusNode.hasFocus;
  }

  /// Returns the [Document] within the [SuperReader] matched by [finder],
  /// or the singular [SuperReader] in the widget tree, if [finder] is `null`.
  ///
  /// {@macro super_document_finder}
  static Document? findDocument([Finder? finder]) {
    final element = (finder ?? find.byType(SuperReader)).evaluate().single as StatefulElement;
    final superDocument = element.state as SuperReaderState;
    return superDocument.document;
  }

  /// Returns the current [DocumentSelection] for the [SuperReader] matched by
  /// [finder], or the singular [SuperReader] in the widget tree, if [finder]
  /// is `null`.
  ///
  /// {@macro super_document_finder}
  static DocumentSelection? findDocumentSelection([Finder? finder]) {
    final element = (finder ?? find.byType(SuperReader)).evaluate().single as StatefulElement;
    final superDocument = element.state as SuperReaderState;
    return superDocument.selection;
  }

  /// Returns the (x,y) offset for the component which renders the node with the given [nodeId].
  ///
  /// {@macro super_document_finder}
  static Offset findComponentOffset(String nodeId, Alignment alignment, [Finder? finder]) {
    final documentLayout = _findDocumentLayout(finder);
    final component = documentLayout.getComponentByNodeId(nodeId);
    assert(component != null);
    final componentBox = component!.context.findRenderObject() as RenderBox;
    final rect = componentBox.localToGlobal(Offset.zero) & componentBox.size;
    return alignment.withinRect(rect);
  }

  /// Returns `true` if the entire content rectangle at [position] is visible on
  /// screen, or `false` otherwise.
  ///
  /// {@macro super_document_finder}
  static bool isPositionVisibleGlobally(DocumentPosition position, Size globalSize, [Finder? finder]) {
    final documentLayout = _findDocumentLayout(finder);
    final positionRect = documentLayout.getRectForPosition(position)!;
    final globalDocumentOffset = documentLayout.getGlobalOffsetFromDocumentOffset(Offset.zero);
    final globalPositionRect = positionRect.translate(globalDocumentOffset.dx, globalDocumentOffset.dy);

    return globalPositionRect.top >= 0 &&
        globalPositionRect.left >= 0 &&
        globalPositionRect.bottom <= globalSize.height &&
        globalPositionRect.right <= globalSize.width;
  }

  /// Finds and returns the [Widget] that configures the [DocumentComponent] with the
  /// given [nodeId].
  ///
  /// The given [nodeId] must exist in the [SuperReader]'s document. The [Widget] that
  /// configures the give node must be of type [WidgetType].
  ///
  /// {@macro super_document_finder}
  static WidgetType findWidgetForComponent<WidgetType>(String nodeId, [Finder? superDocumentFinder]) {
    final documentLayout = _findDocumentLayout(superDocumentFinder);
    final widget = (documentLayout.getComponentByNodeId(nodeId) as TextComponentState).widget;
    if (widget is! WidgetType) {
      throw Exception("Looking for a component's widget. Expected type $WidgetType, but found ${widget.runtimeType}");
    }

    return widget as WidgetType;
  }

  /// Returns the [AttributedText] within the [ParagraphNode] associated with the
  /// given [nodeId].
  ///
  /// There must be a [ParagraphNode] with the given [nodeId], displayed in a
  /// [SuperReader].
  ///
  /// {@macro super_document_finder}
  static AttributedText findTextInParagraph(String nodeId, [Finder? superDocumentFinder]) {
    final documentLayout = _findDocumentLayout(superDocumentFinder);
    return (documentLayout.getComponentByNodeId(nodeId) as TextComponentState).widget.text;
  }

  /// Finds the paragraph with the given [nodeId] and returns the paragraph's content as a [TextSpan].
  ///
  /// A [TextSpan] is the fundamental way that Flutter styles text. It's the lowest level reflection
  /// of what the user will see, short of rendering the actual UI.
  ///
  /// {@macro super_reader_finder}
  static TextSpan findRichTextInParagraph(String nodeId, [Finder? superReaderFinder]) {
    final documentLayout = _findDocumentLayout(superReaderFinder);

    final textComponentState = documentLayout.getComponentByNodeId(nodeId)!;
    final superText = find
        .descendant(of: find.byWidget(textComponentState.widget), matching: find.byType(SuperText))
        .evaluate()
        .single
        .widget as SuperText;
    return superText.richText as TextSpan;
  }

  /// Finds and returns the [TextStyle] that's applied to the top-level of the [TextSpan]
  /// in the paragraph with the given [nodeId].
  ///
  /// {@macro super_document_finder}
  static TextStyle? findParagraphStyle(String nodeId, [Finder? superDocumentFinder]) {
    final documentLayout = _findDocumentLayout(superDocumentFinder);

    final textComponentState = documentLayout.getComponentByNodeId(nodeId)!;
    final superText = find
        .descendant(of: find.byWidget(textComponentState.widget), matching: find.byType(SuperText))
        .evaluate()
        .single
        .widget as SuperText;
    return superText.richText.style;
  }

  /// Returns the [DocumentNode] at given the [index].
  ///
  /// The given [index] must be a valid node index inside the [Document].The node at [index]
  /// must be of type [NodeType].
  ///
  /// {@macro super_document_finder}
  static NodeType getNodeAt<NodeType extends DocumentNode>(int index, [Finder? superDocumentFinder]) {
    final doc = findDocument(superDocumentFinder);

    if (doc == null) {
      throw Exception('SuperReader not found');
    }

    if (index >= doc.nodeCount) {
      throw Exception('Tried to access index $index in a document where the max index is ${doc.nodeCount - 1}');
    }

    final node = doc.getNodeAt(index);
    if (node is! NodeType) {
      throw Exception('Tried to access a ${node.runtimeType} as $NodeType');
    }

    return node;
  }

  /// Finds the [DocumentLayout] that backs a [SuperReader] in the widget tree.
  ///
  /// {@macro super_document_finder}
  static DocumentLayout _findDocumentLayout([Finder? superDocumentFinder]) {
    late final Finder layoutFinder;
    if (superDocumentFinder != null) {
      layoutFinder = find.descendant(of: superDocumentFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    final documentLayoutElement = layoutFinder.evaluate().single as StatefulElement;
    return documentLayoutElement.state as DocumentLayout;
  }

  /// Returns `true` if [SuperReader]'s policy believes that a mobile toolbar should
  /// be visible right now, or `false` otherwise.
  ///
  /// This inspection is different from [isMobileToolbarVisible] in a couple ways:
  ///  * On mobile web, [SuperReader] defers to the browser's built-in overlay
  ///    controls. Therefore, [wantsMobileToolbarToBeVisible] is `true` but
  ///    [isMobileToolbarVisible] is `false`.
  ///  * When an app customizes the toolbar, [SuperReader] might want to build
  ///    and display a toolbar, but the app overrode the toolbar widget and chose
  ///    to build empty space instead of a toolbar. In this case
  ///    [wantsMobileToolbarToBeVisible] is `true`, but [isMobileToolbarVisible]
  ///    is `false`.
  static bool wantsMobileToolbarToBeVisible([Finder? superReaderFinder]) {
    // TODO: add Android support
    final toolbarManager = find.state<SuperReaderIosToolbarOverlayManagerState>(superReaderFinder);
    if (toolbarManager == null) {
      throw Exception(
          "Tried to verify that SuperReader wants mobile toolbar to be visible, but couldn't find the toolbar manager widget.");
    }

    return toolbarManager.wantsToDisplayToolbar;
  }

  /// Returns `true` if the mobile floating toolbar is currently visible, or `false`
  /// if it's not.
  ///
  /// The mobile floating toolbar looks different for iOS and Android, but on both
  /// platforms it appears on top of the editor, near selected content.
  ///
  /// This method doesn't take a `superReaderFinder` because the toolbar is displayed
  /// in the application overlay, and is therefore completely independent from the
  /// [SuperReader] subtree. There's no obvious way to associate a toolbar with
  /// a specific [SuperReader].
  ///
  /// See also: [wantsMobileToolbarToBeVisible].
  static bool isMobileToolbarVisible() {
    return find.byKey(DocumentKeys.mobileToolbar).evaluate().isNotEmpty;
  }

  /// Returns `true` if [SuperReader]'s policy believes that a mobile magnifier
  /// should be visible right now, or `false` otherwise.
  ///
  /// This inspection is different from [isMobileMagnifierVisible] in a couple ways:
  ///  * On mobile web, [SuperReader] defers to the browser's built-in overlay
  ///    controls. Therefore, [wantsMobileMagnifierToBeVisible] is `true` but
  ///    [isMobileMagnifierVisible] is `false`.
  ///  * When an app customizes the magnifier, [SuperReader] might want to build
  ///    and display a magnifier, but the app overrode the magnifier widget and chose
  ///    to build empty space instead of a magnifier. In this case
  ///    [wantsMobileMagnifierToBeVisible] is `true`, but [isMobileMagnifierVisible]
  ///    is `false`.
  static bool wantsMobileMagnifierToBeVisible([Finder? superReaderFinder]) {
    // TODO: add Android support
    final magnifierManager = find.state<SuperReaderIosMagnifierOverlayManagerState>(superReaderFinder);
    if (magnifierManager == null) {
      throw Exception(
          "Tried to verify that SuperReader wants mobile magnifier to be visible, but couldn't find the magnifier manager widget.");
    }

    return magnifierManager.wantsToDisplayMagnifier;
  }

  /// Returns `true` if a mobile magnifier is currently visible, or `false` if it's
  /// not.
  ///
  /// The mobile magnifier looks different for iOS and Android. The magnifier also
  /// follows different focal points depending on whether it's iOS or Android.
  /// But in both cases, a magnifier is a small shape near the user's finger or
  /// selection, which shows the editor content at an enlarged/magnified level.
  ///
  /// This method doesn't take a `superReaderFinder` because the magnifier is displayed
  /// in the application overlay, and is therefore completely independent from the
  /// [SuperReader] subtree. There's no obvious way to associate a magnifier with
  /// a specific [SuperReader].
  ///
  /// See also: [wantsMobileMagnifierToBeVisible]
  static bool isMobileMagnifierVisible() {
    return find.byKey(DocumentKeys.magnifier).evaluate().isNotEmpty;
  }

  /// Returns `true` if any type of mobile drag handles are visible, or `false`
  /// if not.
  ///
  /// On iOS, drag handles include the caret, as well as the upstream and downstream
  /// handles.
  ///
  /// On Android, drag handles include the caret handle, as well as the upstream and
  /// downstream drag handles. The caret drag handle on Android disappears after a brief
  /// period of inactivity, and reappears upon another user interaction.
  static Finder findAllMobileDragHandles([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return find.byWidgetPredicate(
          (widget) =>
              widget.key == DocumentKeys.androidCaretHandle ||
              widget.key == DocumentKeys.upstreamHandle ||
              widget.key == DocumentKeys.downstreamHandle,
        );
      case TargetPlatform.iOS:
        return find.byWidgetPredicate(
          (widget) =>
              widget.key == DocumentKeys.caret ||
              widget.key == DocumentKeys.upstreamHandle ||
              widget.key == DocumentKeys.downstreamHandle,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  static Finder findMobileCaret([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return find.byKey(DocumentKeys.caret);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  static Finder findMobileCaretDragHandle([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return find.byKey(DocumentKeys.androidCaretHandle);
      case TargetPlatform.iOS:
        return find.byKey(DocumentKeys.caret);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  static Finder findMobileExpandedDragHandles([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return find.byWidgetPredicate(
          (widget) => widget.key == DocumentKeys.upstreamHandle || widget.key == DocumentKeys.downstreamHandle,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  static Finder findMobileUpstreamDragHandle([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return find.byKey(DocumentKeys.upstreamHandle);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  static Finder findMobileDownstreamDragHandle([Finder? superReaderFinder]) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return find.byKey(DocumentKeys.downstreamHandle);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return FindsNothing();
    }
  }

  SuperReaderInspector._();
}
