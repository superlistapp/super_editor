import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class FeatherEditor extends StatefulWidget {
  const FeatherEditor({super.key});

  @override
  State<FeatherEditor> createState() => _FeatherEditorState();
}

class _FeatherEditorState extends State<FeatherEditor> {
  late final Editor _editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument.empty();
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          _FormattingToolbar(editor: _editor),
          const Divider(thickness: 1, height: 1, color: _borderColor),
          Expanded(
            child: _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return ColoredBox(
      // TODO: Without transparent color, the tap gesture isn't picked up and the
      //       user can't place the caret. This should probably be handled in SuperEditor
      //       somewhere.
      color: Colors.transparent,
      child: SuperEditor(
        editor: _editor,
        document: _document,
        composer: _composer,
      ),
    );
  }
}

class _FormattingToolbar extends StatefulWidget {
  const _FormattingToolbar({
    super.key,
    required this.editor,
  });

  final Editor editor;

  @override
  State<_FormattingToolbar> createState() => _FormattingToolbarState();
}

class _FormattingToolbarState extends State<_FormattingToolbar> {
  late DocumentComposer _composer;
  late Document _document;
  late final EditListener _editListener;

  final _fullySelectedTextFormats = <Attribution>{};

  @override
  void initState() {
    super.initState();

    _editListener = FunctionalEditListener(_onEdit);
    widget.editor.addListener(_editListener);

    _composer = widget.editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    _composer.selectionNotifier.addListener(_onSelectionChange);
    _document = widget.editor.context.find<MutableDocument>(Editor.documentKey);
  }

  @override
  void didUpdateWidget(_FormattingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor) {
      oldWidget.editor.removeListener(_editListener);
      widget.editor.addListener(_editListener);
    }

    final newComposer = widget.editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    if (newComposer != _composer) {
      _composer.selectionNotifier.removeListener(_onSelectionChange);
      _composer = newComposer;
      _composer.selectionNotifier.addListener(_onSelectionChange);
    }

    _document = widget.editor.context.find<MutableDocument>(Editor.documentKey);
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(_onSelectionChange);
    widget.editor.removeListener(_editListener);

    super.dispose();
  }

  void _onEdit(List<EditEvent> changes) {
    if (changes.whereType<DocumentEdit>().isEmpty) {
      return;
    }

    // It's possible that even without a selection change, the document
    // styles changed out from under our selection. Re-compute the fully
    // selected text formats.
    _updateFormatButtonStates();
  }

  void _onSelectionChange() {
    _updateFormatButtonStates();
  }

  /// Inspects the selected text and updates all toolbar format buttons based on
  /// any formatting throughout the currently selected text.
  void _updateFormatButtonStates() {
    final selection = _composer.selection;
    final fullySelectedTextFormats = _findFullySelectedTextFormats(selection);
    if (const DeepCollectionEquality().equals(_fullySelectedTextFormats, fullySelectedTextFormats)) {
      return;
    }

    setState(() {
      _fullySelectedTextFormats
        ..clear()
        ..addAll(fullySelectedTextFormats);
    });
  }

  Set<Attribution> _findFullySelectedTextFormats(DocumentSelection? selection) {
    if (selection == null) {
      return {};
    }
    if (selection.isCollapsed) {
      return {};
    }

    return _document.getAllAttributions(selection);
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(
        size: 20,
      ),
      child: Wrap(
        children: [
          _ToggleTextFormatButton(
            editor: widget.editor,
            icon: Icons.format_bold,
            format: boldAttribution,
            selectedFormats: _fullySelectedTextFormats,
          ),
          _ToggleTextFormatButton(
            editor: widget.editor,
            icon: Icons.format_italic,
            format: italicsAttribution,
            selectedFormats: _fullySelectedTextFormats,
          ),
          _ToggleTextFormatButton(
            editor: widget.editor,
            icon: Icons.format_underline,
            format: underlineAttribution,
            selectedFormats: _fullySelectedTextFormats,
          ),
          _ToggleTextFormatButton(
            editor: widget.editor,
            icon: Icons.strikethrough_s,
            format: strikethroughAttribution,
            selectedFormats: _fullySelectedTextFormats,
          ),
          //----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_quote),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.code),
          ),
          //----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.link),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.photo),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.video_file),
          ),
          // IconButton(
          //   onPressed: () {},
          //   icon: const Icon(Icons.function),
          // ),
          // TODO: formula
          // ----
          // IconButton(
          //   onPressed: () {},
          //   icon: const Icon(Icons.format_h1),
          // ),
          // IconButton(
          //   onPressed: () {},
          //   icon: const Icon(Icons.format_h2),
          // ),
          // ----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_list_numbered),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.checklist),
          ),
          // -----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.subscript),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.superscript),
          ),
          // ---
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_indent_decrease),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_indent_increase),
          ),
          // ----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_textdirection_l_to_r),
          ),
          // ----
          // TODO: dropdown for named text size
          // ----
          // TODO: dropdown for heading level
          // ----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.text_format),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.texture),
          ),
          // ----
          // TODO: font selection
          // ----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.format_align_left),
          ),
          // ----
          // TODO: remove text style
          // ----
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.import_export),
          ),
        ],
      ),
    );
  }
}

class _ToggleTextFormatButton extends StatelessWidget {
  const _ToggleTextFormatButton({
    required this.editor,
    required this.icon,
    required this.format,
    required this.selectedFormats,
  });

  final Editor editor;
  final IconData icon;
  final Attribution format;
  final Set<Attribution> selectedFormats;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: selectedFormats.contains(format) ? Colors.blue : Colors.black,
      onPressed: () {
        toggleInlineFormat(editor, format);
      },
    );
  }
}

void toggleInlineFormat(Editor editor, Attribution inlineFormat) {
  final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);
  final selection = composer.selection;
  if (selection == null || selection.isCollapsed) {
    return;
  }

  editor.execute([
    ToggleTextAttributionsRequest(
      documentRange: selection,
      attributions: {boldAttribution},
    ),
  ]);
}

class _ToggleBlockFormatButton extends StatelessWidget {
  const _ToggleBlockFormatButton({
    required this.editor,
    required this.icon,
    required this.format,
    required this.selectedBlockFormat,
  });

  final Editor editor;
  final IconData icon;
  final Attribution format;
  final Attribution? selectedBlockFormat;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: format == selectedBlockFormat ? Colors.blue : Colors.black,
      onPressed: () {
        toggleBlockFormat(editor, format);
      },
    );
  }
}

void toggleBlockFormat(Editor editor, Attribution format) {
  //
}

const _borderColor = Color(0xFFDDDDDD);
