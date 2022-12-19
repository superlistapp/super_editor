import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_ime.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import 'attributions.dart';
import 'document_input_keyboard.dart';
import 'list_items.dart';

/// Governs document input that comes from the operating system's
/// Input Method Engine (IME).
///
/// IME input is the only form of input that can come from a mobile
/// device's software keyboard. In a desktop environment with a
/// physical keyboard, developers can choose to respond to IME input
/// or individual key presses on the keyboard. For key press input,
/// see super_editor's keyboard input support.

/// Document interactor that changes a document based on IME input
/// from the operating system.
class DocumentImeInteractor extends StatefulWidget {
  const DocumentImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    required this.softwareKeyboardHandler,
    this.hardwareKeyboardActions = const [],
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  final EditContext editContext;

  final SoftwareKeyboardHandler softwareKeyboardHandler;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  final FloatingCursorController? floatingCursorController;

  final Widget child;

  @override
  State createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor> implements ImeInputOwner {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    widget.editContext.composer.selectionNotifier.addListener(_onSelectionChange);
    widget.editContext.composer.imeConfiguration.addListener(_onClientWantsDifferentImeConfiguration);
    widget.editContext.composer.softwareKeyboardHandler = widget.softwareKeyboardHandler;
  }

  @override
  void didUpdateWidget(DocumentImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }

    if (widget.editContext.composer.selectionNotifier != oldWidget.editContext.composer.selectionNotifier) {
      oldWidget.editContext.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.editContext.composer.selectionNotifier.addListener(_onSelectionChange);
    }
    if (widget.editContext.composer.imeConfiguration != oldWidget.editContext.composer.imeConfiguration) {
      oldWidget.editContext.composer.imeConfiguration.removeListener(_onClientWantsDifferentImeConfiguration);
      oldWidget.editContext.composer.imeConfiguration.addListener(_onClientWantsDifferentImeConfiguration);
    }
    if (widget.softwareKeyboardHandler != oldWidget.softwareKeyboardHandler) {
      widget.editContext.composer.softwareKeyboardHandler = widget.softwareKeyboardHandler;
    }
  }

  @override
  void dispose() {
    _detachFromIme();

    widget.editContext.composer.softwareKeyboardHandler = null;
    widget.editContext.composer.imeConfiguration.removeListener(_onClientWantsDifferentImeConfiguration);
    widget.editContext.composer.selectionNotifier.removeListener(_onSelectionChange);

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient => widget.editContext.composer.imeClient!;

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      editorImeLog.info('Gained focus');
      // TODO: Do we actually want to attach to IME when we gain focus, even if there's no selection?
      // if (widget.automaticallyOpenKeyboardOnSelectionChange) {
      //   editorImeLog.info('Attaching to IME');
      //   _attachToIme();
      // }
    } else {
      editorImeLog.info('Lost focus');
      _detachFromIme();
    }
  }

  void _onSelectionChange() {
    final selection = widget.editContext.composer.selection;
    editorImeLog.info("Document composer (${widget.editContext.composer.hashCode}) changed. New selection: $selection");

    if (selection == null) {
      _detachFromIme();
      // } else if (widget.automaticallyOpenKeyboardOnSelectionChange) {
      //   widget.editContext.composer.showImeInput(widget.floatingCursorController);
    } else if (isAttachedToIme) {
      widget.editContext.composer.syncImeWithDocumentAndSelection();
    }
  }

  void _onClientWantsDifferentImeConfiguration() {
    if (!isAttachedToIme) {
      return;
    }

    editorImeLog.fine(
        "Updating IME to use new config with action button: ${widget.editContext.composer.imeConfiguration.value.keyboardActionButton}");
    widget.editContext.composer.updateImeConfig(_createInputConfiguration());
  }

  bool get isAttachedToIme => widget.editContext.composer.isAttachedToIme;

  // void _attachToIme() {
  //   widget.editContext.composer.openIme(widget.floatingCursorController);
  // }

  TextInputConfiguration _createInputConfiguration() {
    final imeConfig = widget.editContext.composer.imeConfiguration.value;

    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: imeConfig.enableAutocorrect,
      enableSuggestions: imeConfig.enableSuggestions,
      inputAction: imeConfig.keyboardActionButton,
      keyboardAppearance: imeConfig.keyboardBrightness,
    );
  }

  void _detachFromIme() {
    widget.editContext.composer.closeIme();
  }

  KeyEventResult _onKeyPressed(FocusNode node, RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      editorKeyLog.finer("Received key event, but ignoring because it's not a down event: $keyEvent");
      return KeyEventResult.handled;
    }

    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < widget.hardwareKeyboardActions.length) {
      instruction = widget.hardwareKeyboardActions[index](
        editContext: widget.editContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    switch (instruction) {
      case ExecutionInstruction.haltExecution:
        return KeyEventResult.handled;
      case ExecutionInstruction.continueExecution:
      case ExecutionInstruction.blocked:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: widget.hardwareKeyboardActions.isEmpty ? null : _onKeyPressed,
      child: widget.child,
    );
  }
}

/// Applies software keyboard edits to a document.
class SoftwareKeyboardHandler {
  const SoftwareKeyboardHandler({
    required this.editor,
    required this.composer,
    required this.commonOps,
  });

  final DocumentEditor editor;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    for (final delta in textEditingDeltas) {
      editorImeLog.info("Applying delta: $delta");
      if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta);
      } else if (delta is TextEditingDeltaReplacement) {
        _applyReplacement(delta);
      } else if (delta is TextEditingDeltaDeletion) {
        _applyDeletion(delta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _applyNonTextChange(delta);
      } else {
        editorImeLog.shout("Unknown IME delta type: ${delta.runtimeType}");
      }
    }
  }

  void _applyInsertion(TextEditingDeltaInsertion delta) {
    editorImeLog.fine('Inserted text: "${delta.textInserted}"');
    editorImeLog.fine("Insertion offset: ${delta.insertionOffset}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.textInserted == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
        performAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }
      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    editorImeLog.fine(
        "Inserting text: ${delta.textInserted}, insertion offset: ${delta.insertionOffset}, ime selection: ${delta.selection}");

    insert(
      TextPosition(offset: delta.insertionOffset, affinity: delta.selection.affinity),
      delta.textInserted,
    );
  }

  void _applyReplacement(TextEditingDeltaReplacement delta) {
    editorImeLog.fine("Text replaced: '${delta.textReplaced}'");
    editorImeLog.fine("Replacement text: '${delta.replacementText}'");
    editorImeLog.fine("Replaced range: ${delta.replacedRange}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.replacementText == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
        performAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping replacement delta because its a newline");
      }
      return;
    }

    if (delta.replacementText == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    replace(delta.replacedRange, delta.replacementText);
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    // editorImeLog.fine("App-side selection - ${currentTextEditingValue.selection}");
    // editorImeLog.fine("App-side composing - ${currentTextEditingValue.composing}");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");
    // currentTextEditingValue = _currentTextEditingValue.copyWith(composing: delta.composing);
  }

  void insert(TextPosition insertionPosition, String textInserted) {
    if (textInserted == "\n") {
      // Newlines are handled in performAction()
      return;
    }

    editorImeLog.fine('Inserting "$textInserted" at position "$insertionPosition"');
    editorImeLog.fine("Serializing document to perform IME operation");
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );
    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = docSerializer.imeToDocumentSelection(
      TextSelection.fromPosition(insertionPosition),
    );
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = composer.selection;
    composer.selection = insertionSelection;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = commonOps.insertPlainText(textInserted);
    editorImeLog.fine("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      composer.selection = selectionBeforeInsertion;
    }

    commonOps.convertParagraphByPatternMatching(
      composer.selection!.extent.nodeId,
    );
  }

  void replace(TextRange replacedRange, String replacementText) {
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );

    final replacementSelection = docSerializer.imeToDocumentSelection(TextSelection(
      baseOffset: replacedRange.start,
      // TODO: the delta API is wrong for TextRange.end, it should be exclusive,
      //       but it's implemented as inclusive. Change this code when Flutter
      //       fixes the problem.
      extentOffset: replacedRange.end,
    ));

    if (replacementSelection != null) {
      composer.selection = replacementSelection;
    }
    editorImeLog.fine("Replacing selection: $replacementSelection");
    editorImeLog.fine('With text: "$replacementText"');

    if (replacementText == "\n") {
      performAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);

    commonOps.convertParagraphByPatternMatching(
      composer.selection!.extent.nodeId,
    );
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );
    final docSelectionToDelete = docSerializer.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

    if (docSelectionToDelete == null) {
      final selectedNodeIndex = editor.document.getNodeIndexById(
        composer.selection!.extent.nodeId,
      );
      if (selectedNodeIndex > 0) {
        // The user is trying to delete upstream at the start of a node.
        // This action requires intervention because the IME doesn't know
        // that there's more content before this node. Instruct the editor
        // to run a delete action upstream, which will take the desired
        // "backspace" behavior at the start of this node.
        commonOps.deleteUpstream();
        editorImeLog.fine("Deleted upstream. New selection: ${composer.selection}");
        return;
      }
    }

    editorImeLog.fine("Running selection deletion operation");
    composer.selection = docSelectionToDelete;
    commonOps.deleteSelection();
  }

  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        if (!composer.selection!.isCollapsed) {
          commonOps.deleteSelection();
        }
        commonOps.insertBlockLevelNewline();
        break;
      case TextInputAction.none:
        // no-op
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
      case TextInputAction.next:
      case TextInputAction.previous:
      case TextInputAction.continueAction:
      case TextInputAction.join:
      case TextInputAction.route:
      case TextInputAction.emergencyCall:
      case TextInputAction.unspecified:
        editorImeLog.warning("User pressed unhandled action button: $action");
        break;
    }
  }
}

/// Toolbar that provides document editing capabilities, like converting
/// paragraphs to blockquotes and list items, and inserting horizontal
/// rules.
///
/// This toolbar is intended to be placed just above the keyboard on a
/// mobile device.
class KeyboardEditingToolbar extends StatelessWidget {
  const KeyboardEditingToolbar({
    Key? key,
    required this.document,
    required this.composer,
    required this.commonOps,
    this.brightness,
  }) : super(key: key);

  final Document document;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;
  final Brightness? brightness;

  bool get _isBoldActive => _doesSelectionHaveAttributions({boldAttribution});
  void _toggleBold() => _toggleAttributions({boldAttribution});

  bool get _isItalicsActive => _doesSelectionHaveAttributions({italicsAttribution});
  void _toggleItalics() => _toggleAttributions({italicsAttribution});

  bool get _isUnderlineActive => _doesSelectionHaveAttributions({underlineAttribution});
  void _toggleUnderline() => _toggleAttributions({underlineAttribution});

  bool get _isStrikethroughActive => _doesSelectionHaveAttributions({strikethroughAttribution});
  void _toggleStrikethrough() => _toggleAttributions({strikethroughAttribution});

  bool _doesSelectionHaveAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return false;
    }

    if (selection.isCollapsed) {
      return composer.preferences.currentAttributions.containsAll(attributions);
    }

    return document.doesSelectedTextContainAttributions(selection, attributions);
  }

  void _toggleAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return;
    }

    selection.isCollapsed
        ? commonOps.toggleComposerAttributions(attributions)
        : commonOps.toggleAttributionsOnSelection(attributions);
  }

  void _convertToHeader1() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header1Attribution,
        },
      );
    } else {
      selectedNode.putMetadataValue('blockType', header1Attribution);
    }
  }

  void _convertToHeader2() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header2Attribution,
        },
      );
    } else {
      selectedNode.putMetadataValue('blockType', header2Attribution);
    }
  }

  void _convertToParagraph() {
    commonOps.convertToParagraph();
  }

  void _convertToOrderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.ordered, selectedNode.text);
  }

  void _convertToUnorderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.unordered, selectedNode.text);
  }

  void _convertToBlockquote() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToBlockquote(selectedNode.text);
  }

  void _convertToHr() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    selectedNode.text = AttributedText(text: '--- ');
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: const TextNodePosition(offset: 4),
      ),
    );
    commonOps.convertParagraphByPatternMatching(selectedNode.id);
  }

  void _closeKeyboard() {
    composer.selection = null;
  }

  @override
  Widget build(BuildContext context) {
    final selection = composer.selection;

    if (selection == null) {
      return const SizedBox();
    }

    final brightness = this.brightness ?? MediaQuery.of(context).platformBrightness;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: brightness,
        disabledColor: brightness == Brightness.light ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: brightness == Brightness.light ? Colors.black : Colors.white,
        ),
        child: Material(
          child: Container(
            width: double.infinity,
            height: 48,
            color: brightness == Brightness.light ? const Color(0xFFDDDDDD) : const Color(0xFF222222),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ListenableBuilder(
                        listenable: composer,
                        builder: (context) {
                          final selectedNode = document.getNodeById(selection.extent.nodeId);
                          final isSingleNodeSelected = selection.extent.nodeId == selection.base.nodeId;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleBold : null,
                                icon: const Icon(Icons.format_bold),
                                color: _isBoldActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleItalics : null,
                                icon: const Icon(Icons.format_italic),
                                color: _isItalicsActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleUnderline : null,
                                icon: const Icon(Icons.format_underline),
                                color: _isUnderlineActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleStrikethrough : null,
                                icon: const Icon(Icons.strikethrough_s),
                                color: _isStrikethroughActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header1Attribution)
                                    ? _convertToHeader1
                                    : null,
                                icon: const Icon(Icons.title),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header2Attribution)
                                    ? _convertToHeader2
                                    : null,
                                icon: const Icon(Icons.title),
                                iconSize: 18,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        ((selectedNode is ParagraphNode &&
                                                selectedNode.hasMetadataValue('blockType')) ||
                                            (selectedNode is TextNode && selectedNode is! ParagraphNode))
                                    ? _convertToParagraph
                                    : null,
                                icon: const Icon(Icons.wrap_text),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode && selectedNode.type != ListItemType.ordered))
                                    ? _convertToOrderedListItem
                                    : null,
                                icon: const Icon(Icons.looks_one_rounded),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode &&
                                                selectedNode.type != ListItemType.unordered))
                                    ? _convertToUnorderedListItem
                                    : null,
                                icon: const Icon(Icons.list),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is TextNode &&
                                        (selectedNode is! ParagraphNode ||
                                            selectedNode.getMetadataValue('blockType') != blockquoteAttribution)
                                    ? _convertToBlockquote
                                    : null,
                                icon: const Icon(Icons.format_quote),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is ParagraphNode &&
                                        selectedNode.text.text.isEmpty
                                    ? _convertToHr
                                    : null,
                                icon: const Icon(Icons.horizontal_rule),
                              ),
                            ],
                          );
                        }),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFCCCCCC),
                ),
                IconButton(
                  onPressed: _closeKeyboard,
                  icon: const Icon(Icons.keyboard_hide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
