import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

/// Super Editor demo that uses the native iOS context menu as the floating toolbar
/// for both Super Editor and Super Text Field.
///
/// By default, Super Editor and Super Text Field display a floating toolbar that's
/// painted by Flutter. By using Flutter, you gain full control over appearance, and
/// the available options. However, recent versions of iOS have security settings
/// that bring up an annoying warning if you attempt to run a "paste" command without
/// using their native iOS toolbar. For that reason, Super Editor makes it possible
/// to show the native iOS toolbar.
class NativeIosContextMenuFeatureDemo extends StatefulWidget {
  const NativeIosContextMenuFeatureDemo({super.key});

  @override
  State<NativeIosContextMenuFeatureDemo> createState() => _NativeIosContextMenuFeatureDemoState();
}

class _NativeIosContextMenuFeatureDemoState extends State<NativeIosContextMenuFeatureDemo> {
  final _documentLayoutKey = GlobalKey();

  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final CommonEditorOperations _commonEditorOperations;

  late final SuperEditorIosControlsController _toolbarController;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument.empty();
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
    );
    _commonEditorOperations = CommonEditorOperations(
      document: _document,
      editor: _editor,
      composer: _composer,
      documentLayoutResolver: () => _documentLayoutKey.currentState as DocumentLayout,
    );

    _toolbarController = SuperEditorIosControlsController(
      toolbarBuilder: _buildToolbar,
    );
  }

  @override
  void dispose() {
    _toolbarController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: _buildEditor(),
      supplemental: _buildTextField(),
    );
  }

  Widget _buildEditor() {
    return SuperEditorIosControlsScope(
      controller: _toolbarController,
      child: IntrinsicHeight(
        child: SuperEditor(
          editor: _editor,
          documentLayoutKey: _documentLayoutKey,
          selectionStyle: SelectionStyles(
            selectionColor: Colors.red.withOpacity(0.3),
          ),
          stylesheet: defaultStylesheet.copyWith(
            addRulesAfter: [
              ...darkModeStyles,
            ],
          ),
          documentOverlayBuilders: [
            if (defaultTargetPlatform == TargetPlatform.iOS) ...[
              // Adds a Leader around the document selection at a focal point for the
              // iOS floating toolbar.
              SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
              // Displays caret and drag handles, specifically for iOS.
              SuperEditorIosHandlesDocumentLayerBuilder(
                handleColor: Colors.red,
              ),
            ],

            if (defaultTargetPlatform == TargetPlatform.android) ...[
              // Adds a Leader around the document selection at a focal point for the
              // Android floating toolbar.
              SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
              // Displays caret and drag handles, specifically for Android.
              SuperEditorAndroidHandlesDocumentLayerBuilder(
                caretColor: Colors.red,
              ),
            ],

            // Displays caret for typical desktop use-cases.
            DefaultCaretOverlayBuilder(
              caretStyle: const CaretStyle().copyWith(color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    Key mobileToolbarKey,
    LeaderLink focalPoint,
  ) {
    if (_editor.composer.selection == null) {
      return const SizedBox();
    }

    return iOSSystemPopoverEditorToolbarWithFallbackBuilder(
      context,
      mobileToolbarKey,
      focalPoint,
      _commonEditorOperations,
      SuperEditorIosControlsScope.rootOf(context),
    );
  }

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _SuperTextFieldWithNativeContextMenu(),
    );
  }
}

class _SuperTextFieldWithNativeContextMenu extends StatefulWidget {
  const _SuperTextFieldWithNativeContextMenu({Key? key}) : super(key: key);

  @override
  State<_SuperTextFieldWithNativeContextMenu> createState() => _SuperTextFieldWithNativeContextMenuState();
}

class _SuperTextFieldWithNativeContextMenuState extends State<_SuperTextFieldWithNativeContextMenu> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SuperIOSTextField(
        padding: const EdgeInsets.all(12),
        caretStyle: CaretStyle(color: Colors.red),
        selectionColor: defaultSelectionColor,
        handlesColor: Colors.red,
        textStyleBuilder: (attributions) {
          return defaultTextFieldStyleBuilder(attributions).copyWith(
            color: Colors.white,
            fontSize: 18,
          );
        },
        hintBehavior: HintBehavior.displayHintUntilTextEntered,
        hintBuilder: (_) {
          return Text(
            "Enter text and open toolbar",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          );
        },
        popoverToolbarBuilder: iOSSystemPopoverTextFieldToolbarWithFallback,
      ),
    );
  }
}
