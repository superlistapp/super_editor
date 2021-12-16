import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

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
    required this.editContext,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;
  final EditContext editContext;
  final Widget child;

  @override
  _DocumentImeInteractorState createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor> implements DeltaTextInputClient {
  late FocusNode _focusNode;

  TextInputConnection? _inputConnection;

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    widget.editContext.composer.addListener(_onComposerChange);

    _attachToIme();
  }

  @override
  void didUpdateWidget(DocumentImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }

    if (widget.editContext.composer != oldWidget.editContext.composer) {
      oldWidget.editContext.composer.removeListener(_onComposerChange);
      widget.editContext.composer.addListener(_onComposerChange);
    }
  }

  @override
  void dispose() {
    _detachFromIme();

    widget.editContext.composer.removeListener(_onComposerChange);

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      editorImeLog.info('Gained focus');
      _attachToIme();
    } else {
      editorImeLog.info('Lost focus');
      _detachFromIme();
    }
  }

  void _onComposerChange() {
    final selection = widget.editContext.composer.selection;

    if (selection == null) {
      _currentTextEditingValue = const TextEditingValue();
    } else {
      // TODO: if within single text node, set normal text editing value
      // TODO: if multiple nodes and all text, maybe combine the text into text editing value
      // TODO: if multiple nodes and mixed content, figure out what makes sense

      final selectedNode = widget.editContext.editor.document.getNodeById(selection.extent.nodeId);
      if (selectedNode is ParagraphNode) {
        editorImeLog.info("Doc selection: $selection");
        final textSelection = TextSelection(
          baseOffset: (selection.base.nodePosition as TextNodePosition).offset,
          extentOffset: (selection.extent.nodePosition as TextNodePosition).offset,
        );
        editorImeLog.info("Text selection: $textSelection");
        final text = selectedNode.text.text.substring(textSelection.baseOffset, textSelection.extentOffset);

        _currentTextEditingValue = TextEditingValue(text: selectedNode.text.text, selection: textSelection);

        editorImeLog.info("Updating text editing value: $_currentTextEditingValue");
        _inputConnection!.setEditingState(_currentTextEditingValue);
      }
    }
  }

  bool get isAttachedToIme => _inputConnection != null && _inputConnection!.attached;

  void _attachToIme() {
    if (isAttachedToIme) {
      // We're already connected to the IME.
      return;
    }

    editorImeLog.info('Attaching TextInputClient to TextInput');
    _inputConnection = TextInput.attach(
        this,
        const TextInputConfiguration(
          // TODO: make this configurable
          autocorrect: true,
          enableDeltaModel: true,
          // TODO: make this configurable
          enableSuggestions: true,
          // TODO: make this configurable
          inputAction: TextInputAction.newline,
        ));

    _inputConnection!
      ..show()
      ..setEditingState(currentTextEditingValue);

    editorImeLog.fine('Is attached to input client? ${_inputConnection!.attached}');
  }

  void _detachFromIme() {
    if (!isAttachedToIme) {
      return;
    }

    editorImeLog.info('Detaching TextInputClient from TextInput.');

    widget.editContext.composer.selection = null;

    _inputConnection!.close();
  }

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();
  set currentTextEditingValue(TextEditingValue newValue) {
    if (newValue != _currentTextEditingValue) {
      _currentTextEditingValue = newValue;
      _inputConnection?.setEditingState(_currentTextEditingValue);
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    setState(() {
      _currentTextEditingValue = value;
    });
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    for (final delta in textEditingDeltas) {
      delta.apply(_currentTextEditingValue);
    }
  }

  @override
  void performAction(TextInputAction action) {
    // TODO: implement performAction
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // TODO: implement performPrivateCommand
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // TODO: implement showAutocorrectionPromptRect
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // TODO: implement updateFloatingCursor
  }

  @override
  void connectionClosed() {
    // TODO: implement connectionClosed
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: widget.child,
    );
  }
}

TextEditingValue selectedContentToTextEditingValue(Document doc, DocumentSelection selection) {
  final baseNode = doc.getNodeById(selection.base.nodeId)!;
  final baseNodeIndex = doc.getNodeIndex(baseNode);
  final extentNode = doc.getNodeById(selection.extent.nodeId)!;
  final extentNodeIndex = doc.getNodeIndex(extentNode);

  final startNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
  final startPosition = baseNodeIndex <= extentNodeIndex ? selection.base.nodePosition : selection.extent.nodePosition;
  final endNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
  final endPosition = baseNodeIndex <= extentNodeIndex ? selection.extent.nodePosition : selection.base.nodePosition;

  if (startNode.id == endNode.id) {
    // The document selection is all in one node.
    if (startNode is! TextNode) {
      // The only content selected is non-text, which we can't send to
      // the IME. We'll treat that as an empty IME editing value.
      return const TextEditingValue();
    }

    // Part of a single TextNode is selected. Configure the TextEditingValue
    // to select part of a text blob.
    return TextEditingValue(
      text: startNode.text.text,
      selection: TextSelection(
        baseOffset: (startPosition as TextNodePosition).offset,
        extentOffset: (endPosition as TextNodePosition).offset,
      ),
    );
  }

  // There are 2+ nodes selected. Collect the TextNodes and combine
  // into a single text blob.
  final startNodeIndex = doc.getNodeIndex(startNode);
  final endNodeIndex = doc.getNodeIndex(endNode);
  final textNodes = <TextNode>[];
  for (int i = startNodeIndex; i <= endNodeIndex; i += 1) {
    final node = doc.getNodeAt(i);
    if (node is TextNode) {
      textNodes.add(node);
    }
  }

  if (textNodes.isEmpty) {
    return const TextEditingValue();
  }

  final buffer = StringBuffer();
  int charCountBeforeSelection = 0;
  int charCountAfterSelection = 0;
  for (int i = 0; i < textNodes.length; i += 1) {
    if (textNodes[i].id == startNode.id) {
      charCountBeforeSelection = (startPosition as TextNodePosition).offset;
    } else if (i == textNodes.length - 1) {
      charCountAfterSelection = textNodes[i].text.text.length - (endPosition as TextNodePosition).offset;
    }

    if (i > 0) {
      buffer.write('\n');
    }
    buffer.write(textNodes[i].text.text);
  }

  return TextEditingValue(
    text: buffer.toString(),
    selection: TextSelection(
      baseOffset: charCountBeforeSelection,
      extentOffset: buffer.length - charCountAfterSelection,
    ),
  );
}
