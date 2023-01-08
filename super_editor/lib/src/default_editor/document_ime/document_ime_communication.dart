import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import 'document_delta_editing.dart';
import 'document_serialization.dart';

/// Sends messages to, and receives messages from, the platform Input Method Engine (IME),
/// for the purpose of document editing.

/// Widget that keeps a document and its selection synchronized with the value
/// in the platform Input Method Engine (IME).
///
/// When the [document] or its [selection] changes, the [document] and [selection]
/// are serialized and sent to the IME.
class DocumentToImeSynchronizer extends StatefulWidget {
  const DocumentToImeSynchronizer({
    Key? key,
    required this.document,
    required this.selection,
    required this.imeComposingRegion,
    required this.imeConnection,
    required this.documentImeClient,
    required this.child,
  }) : super(key: key);

  /// [Document] whose content is serialized and sent to the platform IME.
  final Document document;

  /// The document's current selection.
  final ValueNotifier<DocumentSelection?> selection;

  /// The platform IME's desired composing region, which represents a section
  /// of IME text that the platform is thinking about changing, such as spelling
  /// autocorrection.
  final ValueListenable<TextRange> imeComposingRegion;

  /// A connection to the platform IME, which might be open or closed.
  ///
  /// For Flutter test timing purposes, it's critical that [imeConnection] be
  /// a [ValueListenable]. By notifying this widget through a [ValueListenable],
  /// this widget is able to talk to the IME immediately, without waiting for
  /// another tree pump, i.e., `didUpdateWidget()`. In other words, by using
  /// a [ValueListenable] instead of a raw [TextInputConnection], this widget
  /// can setup the initial IME content on the very first `pumpWidget()` within
  /// a test, without requiring additional `pump()`s. Existing tests depend on
  /// this fact.
  final ValueListenable<TextInputConnection?> imeConnection;

  // TODO: the only reason we require a DocumentImeInputClient instead of
  //       a regular client is so we can set the editing value on it. We should
  //       either get this working with a regular client, or define a much more
  //       narrow API
  /// A client that knows how to talk to the platform IME, by receiving
  /// content updates from the platform, and then subsequently sending
  /// new content values to the platform.
  final DocumentImeInputClient documentImeClient;

  final Widget child;

  @override
  State<DocumentToImeSynchronizer> createState() => _DocumentToImeSynchronizerState();
}

class _DocumentToImeSynchronizerState extends State<DocumentToImeSynchronizer> {
  DocumentImeSerializer? _currentImeSerialization;
  bool _hasSentInitialImeValue = false;
  bool _needsSync = false;

  @override
  void initState() {
    super.initState();

    widget.document.addListener(_onDocumentChange);
    widget.selection.addListener(_onSelectionChange);
    widget.imeConnection.addListener(_onImeConnectionChange);

    if (widget.selection.value != null) {
      _sendDocumentToIme();
    }
  }

  @override
  void didUpdateWidget(DocumentToImeSynchronizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
      _sendDocumentToImeOnNextFrame();
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    }

    if (widget.imeConnection != oldWidget.imeConnection) {
      oldWidget.imeConnection.removeListener(_onImeConnectionChange);
      widget.imeConnection.addListener(_onImeConnectionChange);
      _onImeConnectionChange();
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChange);
    widget.selection.removeListener(_onSelectionChange);
    widget.imeConnection.removeListener(_onImeConnectionChange);
    super.dispose();
  }

  void _onDocumentChange() {
    editorImeLog.finer(
        "[DocumentToImeSynchronizer] - document change. Sending document and selection to IME on the next frame.");
    _sendDocumentToImeOnNextFrame();
  }

  void _onSelectionChange() {
    if (widget.selection.value != null) {
      editorImeLog.finer(
          "[DocumentToImeSynchronizer] - selection change. Sending document and selection to IME on the next frame.");
      _sendDocumentToImeOnNextFrame();
    }
  }

  void _onImeConnectionChange() {
    if (widget.imeConnection.value != null && widget.imeConnection.value!.attached) {
      // The IME just connected. Send over our current document and selection.
      editorImeLog.fine(
          "[DocumentToImeSynchronizer] - An IME connection was just opened. Sending current document and selection to IME.");
      _sendDocumentToImeOnNextFrame();
    }
  }

  void _sendDocumentToImeOnNextFrame() {
    if (!_hasSentInitialImeValue) {
      // If we haven't sent any version of the document to the IME, yet, then
      // go ahead and greedily send the current document and selection. This is
      // important in tests because tests run a single `pump()` and expect the
      // initial document to be in the IME already. If we wait another frame, then
      // some tests will need to `pump()` a 2nd time, but those tests won't understand
      // why they need to do that. We avoid that confusion by immediately sending
      // the document to the IME for the first version of the document that we get.
      WidgetsBinding.instance.runAsSoonAsPossible(_sendDocumentToIme);
      return;
    }

    _needsSync = true;
    WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
      if (!mounted) {
        // This widget is no longer in the tree. Assume that means we shouldn't
        // talk to the IME, anymore.
        return;
      }

      // Send the document to the IME so that we give the editing system an opportunity to
      // make all desired changes. Otherwise, we might send the document and selection to
      // the IME in the middle of an operation that's in an inconsistent state.
      // TODO: When atomic commands are implemented, remove this frame callback.
      if (!_needsSync) {
        // We might get a bunch of change events, leading to a bunch of these post frame
        // callbacks. We only want to sync one time. We track that with _needsSync.
        return;
      }

      _needsSync = false;
      _sendDocumentToIme();
    });
  }

  void _sendDocumentToIme() {
    editorImeLog.fine("[DocumentToImeSynchronizer] - Trying to send document to IME");
    // if (!widget.imeValue.isConnectedToIme) {
    if (widget.imeConnection.value == null || !widget.imeConnection.value!.attached) {
      editorImeLog.fine("[DocumentToImeSynchronizer] - Not connected to IME. Not sending document to IME.");
      return;
    }

    if (widget.selection.value == null) {
      // There's no selection, which means there's nothing to edit. Return.
      editorImeLog.fine("[DocumentToImeSynchronizer] - There's no document selection. Not sending anything to IME.");
      return;
    }

    editorImeLog.fine("[DocumentToImeSynchronizer] - Serializing and sending document and selection to IME");
    editorImeLog.fine("[DocumentToImeSynchronizer] - Selection: ${widget.selection.value}");
    editorImeLog.fine("[DocumentToImeSynchronizer] - Composing region: ${widget.imeComposingRegion.value}");
    final newDocSerialization = DocumentImeSerializer(
      widget.document,
      widget.selection.value!,
    );
    TextRange composingRegion = widget.imeComposingRegion.value;

    editorImeLog.finer(
        "Did we prepend a placeholder in the previous document serialization? ${_currentImeSerialization?.didPrependPlaceholder}");
    editorImeLog.finer("Desired composing region: ${widget.imeComposingRegion.value}");
    editorImeLog
        .finer("Did new document serialization prepend a placeholder? ${newDocSerialization.didPrependPlaceholder}");
    editorImeLog.finer("New composing region: $composingRegion");

    // if (_currentImeSerialization != null &&
    //     _currentImeSerialization!.didPrependPlaceholder &&
    //     composingRegion.isValid &&
    //     !newDocSerialization.didPrependPlaceholder) {
    if (composingRegion.isValid && newDocSerialization.didPrependPlaceholder) {
      // // The IME's desired composing region includes the prepended placeholder.
      // // The updated IME value doesn't have a prepended placeholder, adjust
      // // the composing region bounds.
      // editorImeLog.finer(
      //     "Pulling back the composing region bounds because the serialized IME value no longer includes prepended placeholder text");
      // assert(composingRegion.start - 2 >= 0, "Invalid composing start index: ${composingRegion.start - 2}");
      // assert(composingRegion.end - 2 >= 0, "Invalid composing end index: ${composingRegion.end - 2}");
      // assert(composingRegion.end - 2 <= newDocSerialization.toTextEditingValue().text.length,
      //     "Invalid composing end index: ${composingRegion.end - 2}");
      // composingRegion = TextRange(
      //   start: composingRegion.start - 2,
      //   end: composingRegion.end - 2,
      // );

      // TODO: we only want to push back the composing region if the original composing
      //       region was defined without prepended characters.
      //
      //       We have 4 possibilities:
      //       - new composing region expects prepended characters, and there are
      //       - new composing region expects prepended characters, but there aren't any
      //       - new composing region doesn't expect prepended characters, and there aren't
      //       - new composing region doesn't expect prepended characters, and there are
      //
      //       This is something that has become complicated because we separated the
      //       application of IME deltas to a document, from the serialization of a
      //       document to IME.
      composingRegion = TextRange(
        start: composingRegion.start + 2,
        end: composingRegion.end + 2,
      );
    }

    _currentImeSerialization = newDocSerialization;
    final textEditingValue = newDocSerialization.toTextEditingValue().copyWith(composing: composingRegion);
    editorImeLog.fine("[DocumentToImeSynchronizer] - Sending IME serialization:");
    editorImeLog.fine("[DocumentToImeSynchronizer] - $textEditingValue");
    widget.documentImeClient.currentTextEditingValue = textEditingValue;
    editorImeLog.fine("[DocumentToImeSynchronizer] - Done sending document to IME");
    _hasSentInitialImeValue = true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A [TextInputClient] that applies IME operations to a [Document].
class DocumentImeInputClient with TextInputClient, DeltaTextInputClient {
  DocumentImeInputClient({
    required this.textDeltasDocumentEditor,
    required this.imeConnection,
    FloatingCursorController? floatingCursorController,
  }) {
    _floatingCursorController = floatingCursorController;
  }

  final TextDeltasDocumentEditor textDeltasDocumentEditor;

  final ValueListenable<TextInputConnection?> imeConnection;

  late FloatingCursorController? _floatingCursorController;

  bool _hasOutstandingMutatingChanges = false;

  @override
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();
  TextEditingValue? _lastTextEditingValueSentToOs;
  set currentTextEditingValue(TextEditingValue newValue) {
    _currentTextEditingValue = newValue;

    if (_isApplyingDeltas) {
      // We're in the middle of applying a series of text deltas. Don't
      // send any updates to the IME because it will conflict with the
      // changes we're actively processing.
      editorImeLog.fine("Ignoring new TextEditingValue because we're applying deltas");
      return;
    }

    if (newValue != _lastTextEditingValueSentToOs) {
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _lastTextEditingValueSentToOs = _currentTextEditingValue;
      imeConnection.value?.setEditingState(_currentTextEditingValue);
    } else if (_hasOutstandingMutatingChanges) {
      // We've been given a new IME value, and it's the same as our existing IME
      // value. But, we also have outstanding mutating changes.
      //
      // We applied at least one delta that should have altered the content in
      // the serialized IME value, but our local value before the edit is the same
      // as the local value after the edit. Why is that, and what should we do?
      //
      // Sometimes the IME reports changes to us, but our document doesn't change
      // in ways that's reflected in the IME.
      //
      // Example: The user has a caret in an empty paragraph. That empty paragraph
      // includes a couple hidden characters, so the IME value might look like:
      //
      //     ". |"
      //
      // The ". " substring is invisible to the user and the "|" represents the caret at
      // the beginning of the empty paragraph.
      //
      // Then the user inserts a newline "\n". This causes Super Editor to insert a new,
      // empty paragraph node, and place the caret in the new, empty paragraph. At this
      // point, we have an issue:
      //
      // This class still sees the TextEditingValue as: ". |"
      //
      // However, the OS IME thinks the TextEditingValue is: ". |\n"
      //
      // In this situation, even though our desired TextEditingValue looks identical to what it
      // was before, it's not identical to what the operating system thinks it is. We need to
      // send our TextEditingValue back to the OS so that the OS doesn't think there's a "\n"
      // sitting in the edit region.
      editorImeLog.fine(
          "Sending forceful update to IME because our local TextEditingValue didn't change, but the IME may have:");
      editorImeLog.fine("$currentTextEditingValue");
      imeConnection.value?.setEditingState(currentTextEditingValue);
      _hasOutstandingMutatingChanges = false;
    } else {
      editorImeLog.fine("Ignoring new TextEditingValue because it's the same as the existing one: $newValue");
    }
  }

  bool _isApplyingDeltas = false;

  @override
  void updateEditingValue(TextEditingValue value) {
    editorImeLog.info("Received new TextEditingValue from OS: $value");
    _currentTextEditingValue = value;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) {
      return;
    }

    editorImeLog.fine("Received edit deltas from platform: ${textEditingDeltas.length} deltas");
    for (final delta in textEditingDeltas) {
      editorImeLog.fine("$delta");
    }

    final imeValueBeforeChange = currentTextEditingValue;
    editorImeLog.fine("IME value before applying deltas: $imeValueBeforeChange");

    _isApplyingDeltas = true;
    textDeltasDocumentEditor.applyDeltas(textEditingDeltas);
    _isApplyingDeltas = false;

    // If we had 1+ delta that changed the content of the document, remember that.
    // We need this accounting in "set currentTextEditingValue" because, in some
    // cases, our serialized IME value needs to be forcefully set because the IME
    // thinks there's content that shouldn't be there, such as a newline "/n".
    // See "set currentTextEditingValue" for more info.
    _hasOutstandingMutatingChanges =
        textEditingDeltas.where((element) => element is! TextEditingDeltaNonTextUpdate).toList().isNotEmpty;

    // Note: after the completion of applying deltas, we expect some other part of the
    // system to call us back with "set currentTextEditingValue" with whatever that
    // final serialized value should be. That's where execution should pick up from here.
  }

  @override
  void performAction(TextInputAction action) {
    editorImeLog.fine("IME says to perform action: $action");
    textDeltasDocumentEditor.performAction(action);
  }

  @override
  void performSelector(String selectorName) {
    editorImeLog.fine("IME says to perform selector (not implemented): $selectorName");
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
      case FloatingCursorDragState.Update:
        _floatingCursorController?.offset = point.offset;
        break;
      case FloatingCursorDragState.End:
        _floatingCursorController?.offset = null;
        break;
    }
  }

  @override
  void connectionClosed() {
    editorImeLog.info("IME connection was closed");
  }
}
