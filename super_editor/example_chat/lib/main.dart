import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  initLoggers(Level.ALL, {
    // messagePageLayoutLog,
    // messageEditorHeightLog,
  });

  runApp(
    MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: _ChatDemo(),
          resizeToAvoidBottomInset: false,
        );
      }),
    ),
  );
}

class _ChatDemo extends StatelessWidget {
  const _ChatDemo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth / constraints.maxHeight <= 1) {
          // Show phone experience.
          return _ChatPage();
        }

        // Show the tablet experience.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 64,
            ),
            Container(
              width: 1,
              color: Colors.black.withValues(alpha: 0.1),
            ),
            Spacer(),
            Container(
              width: 1,
              color: Colors.black.withValues(alpha: 0.1),
            ),
            SizedBox(
              width: 450,
              child: _ChatPage(),
            ),
          ],
        );
      },
    );
  }
}

/// A chat experience, which includes a simulated list of comments, as well as
/// a bottom-mounted message editor.
class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _messagePageController = MessagePageController();

  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: 96,
      bottomSheetMinimumHeight: 148,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.purpleAccent.shade100),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: bottomSpacing,
                child: _ChatThread(),
              ),
            ],
          ),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return _EditorBottomSheet(
          messagePageController: _messagePageController,
        );
      },
    );
  }
}

/// A simulated chat conversation thread, which is simulated as a bottom-aligned
/// list of tiles.
class _ChatThread extends StatelessWidget {
  const _ChatThread();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      // ^ The list starts at the bottom and grows upward. This is how
      //   we should layout chat conversations where the most recent
      //   message appears at the bottom, and you want to retain the
      //   scroll offset near the newest messages, not the oldest.
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white.withValues(alpha: 0.5),
            child: ListTile(
              title: Text("Item $index"),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet, which includes a message editor.
class _EditorBottomSheet extends StatefulWidget {
  const _EditorBottomSheet({
    required this.messagePageController,
  });

  final MessagePageController messagePageController;

  @override
  State<_EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<_EditorBottomSheet> {
  final _dragIndicatorKey = GlobalKey();

  final _editorSheetKey = GlobalKey();
  late final Editor _editor;

  final _hasSelection = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("This is a pre-existing"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("message"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("It's tall for quick"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("testing of"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("intrinsic height that"),
          ),
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText("exceeds available space"),
          ),
        ],
      ),
      composer: MutableDocumentComposer(),
    );
    _editor.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void dispose() {
    _editor.composer.selectionNotifier.removeListener(_onSelectionChange);
    _editor.dispose();

    super.dispose();
  }

  void _onSelectionChange() {
    _hasSelection.value = _editor.composer.selection != null;

    // If the editor doesn't have a selection then when it's collapsed it
    // should be in preview mode. If the editor does have a selection, then
    // when it's collapsed, it should be in intrinsic height mode.
    widget.messagePageController.collapsedMode =
        _hasSelection.value ? MessagePageSheetCollapsedMode.intrinsic : MessagePageSheetCollapsedMode.preview;
  }

  double _dragTouchOffsetFromIndicator = 0;

  void _onVerticalDragStart(DragStartDetails details) {
    _dragTouchOffsetFromIndicator = _dragFingerOffsetFromIndicator(details.globalPosition);

    widget.messagePageController.onDragStart(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    widget.messagePageController.onDragUpdate(
      details.globalPosition.dy - _dragIndicatorOffsetFromTop + _dragTouchOffsetFromIndicator,
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    widget.messagePageController.onDragEnd();
  }

  void _onVerticalDragCancel() {
    widget.messagePageController.onDragEnd();
  }

  double get _dragIndicatorOffsetFromTop {
    final editorSheetBox = _editorSheetKey.currentContext!.findRenderObject();
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero, ancestor: editorSheetBox).dy;
  }

  double _dragFingerOffsetFromIndicator(Offset globalDragOffset) {
    final dragIndicatorBox = _dragIndicatorKey.currentContext!.findRenderObject()! as RenderBox;

    return dragIndicatorBox.localToGlobal(Offset.zero).dy - globalDragOffset.dy;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: _editorSheetKey,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: KeyboardScaffoldSafeArea(
        child: Stack(
          // ^ Warning: Do not try to turn this into a Column. A Column will
          //   break the careful sizing behavior of the bottom sheet.
          children: [
            _buildSheetContent(),
            _buildDragHandle(),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return Padding(
      padding: EdgeInsets.only(
        top: 40,
        // ^ To make space for the drag handle in the Stack.

        bottom: MediaQuery.paddingOf(context).bottom,
        // ^ Avoid the bottom notch when the keyboard is closed.
      ),
      child: BottomSheetEditorHeight(
        previewHeight: 72,
        child: _ChatEditor(
          key: _editorKey,
          editor: _editor,
          messagePageController: widget.messagePageController,
        ),
      ),
    );
  }

  // FIXME: Keyboard keeps closing without a bunch of global keys. Either
  //        document why, or figure out how to operate without all the keys.
  final _editorKey = GlobalKey();

  Widget _buildDragHandle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: _onVerticalDragCancel,
          behavior: HitTestBehavior.opaque,
          // ^ Opaque to handle tough events in our invisible padding.
          child: Padding(
            padding: const EdgeInsets.all(18),
            // ^ Expand the hit area with invisible padding.
            child: Container(
              key: _dragIndicatorKey,
              width: 32,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An editor for composing chat messages.
class _ChatEditor extends StatefulWidget {
  const _ChatEditor({
    super.key,
    required this.editor,
    required this.messagePageController,
  });

  final Editor editor;
  final MessagePageController messagePageController;

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> {
  final _editorFocusNode = FocusNode();

  final _scrollController = ScrollController();

  late final KeyboardPanelController<_Panel> _keyboardPanelController;
  late final SoftwareKeyboardController _softwareKeyboardController;
  final _isImeConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _softwareKeyboardController = SoftwareKeyboardController();
    _keyboardPanelController = KeyboardPanelController(
      _softwareKeyboardController,
    );

    widget.messagePageController.addListener(_onMessagePageControllerChange);

    _editorFocusNode.addListener(() {
      print(
          "Editor focus change. Has primary: ${_editorFocusNode.hasPrimaryFocus}. Has non-primary: ${_editorFocusNode.hasFocus}.");
    });

    _scrollController.addListener(() {
      print("Scroll change to: ${_scrollController.offset}");
      // print("StackTrace:\n${StackTrace.current}");
      // print("\n\n");
    });
  }

  @override
  void didUpdateWidget(_ChatEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messagePageController != oldWidget.messagePageController) {
      oldWidget.messagePageController.removeListener(_onMessagePageControllerChange);
      widget.messagePageController.addListener(_onMessagePageControllerChange);
    }
  }

  @override
  void dispose() {
    widget.messagePageController.removeListener(_onMessagePageControllerChange);

    _scrollController.dispose();

    _keyboardPanelController.dispose();
    _isImeConnected.dispose();

    super.dispose();
  }

  void _onMessagePageControllerChange() {
    if (widget.messagePageController.isPreview) {
      // Always scroll the editor to the top when in preview mode.
      _scrollController.position.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardPanelScaffold(
      controller: _keyboardPanelController,
      isImeConnected: _isImeConnected,
      toolbarBuilder: (BuildContext context, _Panel? openPanel) {
        return Container(
          width: double.infinity,
          height: 54,
          color: Colors.white.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Spacer(),
              GestureDetector(
                onTap: () {
                  _softwareKeyboardController.close();
                },
                child: Icon(Icons.keyboard_hide_outlined),
              ),
            ],
          ),
        );
      },
      keyboardPanelBuilder: (BuildContext context, _Panel? openPanel) {
        return SizedBox();
      },
      contentBuilder: (BuildContext context, _Panel? openPanel) {
        return SuperEditorFocusOnTap(
          editorFocusNode: _editorFocusNode,
          editor: widget.editor,
          child: SuperEditor(
            key: _editorKey,
            focusNode: _editorFocusNode,
            editor: widget.editor,
            scrollController: _scrollController,
            softwareKeyboardController: _softwareKeyboardController,
            isImeConnected: _isImeConnected,
            imePolicies: SuperEditorImePolicies(),
            selectionPolicies: SuperEditorSelectionPolicies(),
            shrinkWrap: true,
            stylesheet: _chatStylesheet,
            componentBuilders: [
              const HintComponentBuilder("Send a message...", _hintTextStyleBuilder),
              ...defaultComponentBuilders,
            ],
          ),
        );
      },
    );
  }

  final _editorKey = GlobalKey();
}

final _chatStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
          Styles.textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header3"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 12),
        };
      },
    ),
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 48),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
  inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
);

TextStyle _hintTextStyleBuilder(context) => TextStyle(
      color: Colors.grey,
    );

// FIXME: This widget is required because of the current shrink wrap behavior
//        of Super Editor. If we set `shrinkWrap` to `false` then the bottom
//        sheet always expands to max height. But if we set `shrinkWrap` to
//        `true`, when we manually expand the bottom sheet, the only
//        tappable area is wherever the document components actually appear.
//        In the average case, that means only the top area of the bottom
//        sheet can be tapped to place the caret.
//
//        This widget should wrap Super Editor and make the whole area tappable.
/// A widget, that when pressed, gives focus to the [editorFocusNode], and places
/// the caret at the end of the content within an [editor].
///
/// It's expected that the [child] subtree contains the associated `SuperEditor`,
/// which owns the [editor] and [editorFocusNode].
class SuperEditorFocusOnTap extends StatelessWidget {
  const SuperEditorFocusOnTap({
    super.key,
    required this.editorFocusNode,
    required this.editor,
    required this.child,
  });

  final FocusNode editorFocusNode;

  final Editor editor;

  /// The SuperEditor that we're wrapping with this tap behavior.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editorFocusNode,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: editor.composer.selectionNotifier,
          builder: (context, child) {
            final shouldControlTap = editor.composer.selection == null || !editorFocusNode.hasFocus;
            return GestureDetector(
              onTap: editor.composer.selection == null || !editorFocusNode.hasFocus ? _selectEditor : null,
              behavior: HitTestBehavior.opaque,
              child: IgnorePointer(
                ignoring: shouldControlTap,
                // ^ Prevent the Super Editor from aggressively responding to
                //   taps, so that we can respond.
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }

  void _selectEditor() {
    editorFocusNode.requestFocus();

    final endNode = editor.document.last;
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: endNode.id,
            nodePosition: endNode.endPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      )
    ]);
  }
}

enum _Panel {
  thePanel;
}
