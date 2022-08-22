import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'example_document.dart';
import 'tokenization.dart';

/// Example of a `SuperEditor` with popover tag selection.
///
/// When running this example, type a "#" or "@" to search for terms
/// or users.
class ExampleEditorWithTagging extends StatefulWidget {
  @override
  _ExampleEditorWithTaggingState createState() => _ExampleEditorWithTaggingState();
}

class _ExampleEditorWithTaggingState extends State<ExampleEditorWithTagging> {
  final GlobalKey _docLayoutKey = GlobalKey();

  late Document _doc;
  late DocumentEditor _docEditor;
  late DocumentComposer _composer;
  late CommonEditorOperations _docOps;

  late FocusNode _editorFocusNode;

  late ScrollController _scrollController;

  final _darkBackground = const Color(0xFF222222);
  final _lightBackground = Colors.white;
  bool _isLight = true;

  OverlayEntry? _textFormatBarOverlayEntry;

  @override
  void initState() {
    super.initState();
    _doc = createInitialDocument();
    _composer = DocumentComposer();
    _docEditor = DocumentEditor(
      document: _doc as MutableDocument,
      postProcesses: [
        TokenizeBeginningOfParagraph(_composer),
      ],
    );
    _docOps = CommonEditorOperations(
      editor: _docEditor,
      composer: _composer,
      documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
    );
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    if (_textFormatBarOverlayEntry != null) {
      _textFormatBarOverlayEntry!.remove();
    }

    _scrollController.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  DocumentGestureMode get _gestureMode {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return DocumentGestureMode.android;
      case TargetPlatform.iOS:
        return DocumentGestureMode.iOS;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return DocumentGestureMode.mouse;
    }
  }

  bool get _isMobile => _gestureMode != DocumentGestureMode.mouse;

  DocumentInputSource get _inputSource {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // return DocumentInputSource.ime;
        return DocumentInputSource.keyboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _buildEditor(),
            ),
            if (_isMobile) _buildMountedToolbar(),
          ],
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return ColoredBox(
      color: _isLight ? _lightBackground : _darkBackground,
      child: SuperEditor(
        editor: _docEditor,
        composer: _composer,
        focusNode: _editorFocusNode,
        scrollController: _scrollController,
        documentLayoutKey: _docLayoutKey,
        documentOverlayBuilders: [
          DefaultCaretOverlayBuilder(
            CaretStyle().copyWith(color: _isLight ? Colors.black : Colors.redAccent),
          ),
        ],
        selectionStyle: _isLight
            ? defaultSelectionStyle
            : SelectionStyles(
                selectionColor: Colors.red.withOpacity(0.3),
              ),
        componentBuilders: defaultComponentBuilders,
        gestureMode: _gestureMode,
        inputSource: _inputSource,
        keyboardActions: _inputSource == DocumentInputSource.ime ? defaultImeKeyboardActions : defaultKeyboardActions,
      ),
    );
  }

  Widget _buildMountedToolbar() {
    return MultiListenableBuilder(
      listenables: <Listenable>{
        _doc,
        _composer.selectionNotifier,
      },
      builder: (_) {
        final selection = _composer.selection;

        if (selection == null) {
          return const SizedBox();
        }

        return KeyboardEditingToolbar(
          document: _doc,
          composer: _composer,
          commonOps: _docOps,
        );
      },
    );
  }
}
