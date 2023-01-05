import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
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
    required this.imeValue,
    required this.child,
  }) : super(key: key);

  /// [Document] whose content is serialized and sent to the platform IME.
  final Document document;

  /// Notifies this widget of changes to a document's selection.
  final ValueNotifier<DocumentSelection?> selection;

  /// The platform IME's desired composing region, which represents a section
  /// of IME text that the platform is thinking about changing, such as spelling
  /// autocorrection.
  final ValueNotifier<TextRange> imeComposingRegion;

  /// A connection to the platform IME, which might be open or closed.
  final ImeConnection imeConnection;

  /// The IME's current editing value.
  final ImeValue imeValue;

  final Widget child;

  @override
  State<DocumentToImeSynchronizer> createState() => _DocumentToImeSynchronizerState();
}

class _DocumentToImeSynchronizerState extends State<DocumentToImeSynchronizer> {
  DocumentImeSerializer? _currentImeSerialization;
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
      _sendDocumentToIme();
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    }

    if (widget.imeConnection != oldWidget.imeConnection) {
      oldWidget.imeConnection.removeListener(_onImeConnectionChange);
      widget.imeConnection.addListener(_onImeConnectionChange);
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
    print("[DocumentToImeSynchronizer] - document change. Sending document and selection to IME on the next frame.");
    _sendDocumentToImeOnNextFrame();
  }

  void _onSelectionChange() {
    if (widget.selection.value == null) {
      // Without a selection, there's no place for IME input to go. Close the IME.
      widget.imeValue.closeConnection();
    } else {
      print("[DocumentToImeSynchronizer] - selection change. Sending document and selection to IME on the next frame.");
      _sendDocumentToImeOnNextFrame();
    }
  }

  void _onImeConnectionChange() {
    if (widget.imeConnection.isAttached) {
      print("An IME connection was just opened. Sending current document and selection to IME.");
      // The IME just connected. Send over our current document and selection.
      _sendDocumentToImeOnNextFrame();
    }
  }

  void _sendDocumentToImeOnNextFrame() {
    _needsSync = true;
    WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
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
    if (!widget.imeValue.isConnectedToIme) {
      return;
    }

    print("Sending document to IME with composing region: ${widget.imeComposingRegion.value}");

    if (widget.selection.value == null) {
      // There's no selection, which means there's nothing to edit. Return.
      print("There's no document selection. Not sending anything to IME.");
      return;
    }

    editorImeLog.fine("Serializing and sending document and selection to IME");
    editorImeLog.fine("Selection: ${widget.selection.value}");
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
    print("Sending IME serialization:");
    print("$textEditingValue");
    print("Setting currentTextEditingValue on ImeValue");
    widget.imeValue.currentTextEditingValue = textEditingValue;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// TODO: get rid of this class
//
// This class is a temporary hack so that our synchronization widget doesn't serialize and
// send documents while we're applying deltas.
//
// The root problem here is that we're letting the document send change notifications in
// the middle of a series of edits. From a public perspective, those edits should be seen
// as a single edit. The upcoming atomic commands API should make sure to include tooling
// to prevent change notifications until all pending changes have been applied.
class ImeEditorStatus {
  ImeEditorStatus(this._editor);

  final DocumentImeInputClient _editor;

  bool get isEditInProgress => _editor.isApplyingDeltas;
}

/// A slice of IME functionality that's required by [DocumentToImeSynchronizer].
abstract class ImeValue {
  TextEditingValue get currentTextEditingValue;

  set currentTextEditingValue(TextEditingValue newValue);

  bool get isConnectedToIme;

  void closeConnection();
}

abstract class ImeConnection with ChangeNotifier {
  /// Returns `true` if there's an open connection to the platform
  /// Input Method Engine (IME).
  bool get isAttached;

  /// Opens a connection to the platform Input Method Engine (IME).
  bool open();

  /// Shows the input controls associated with the IME, e.g., the software keyboard,
  /// and also connects to the IME, if no connection is present.
  void show();

  /// Closes the connection to the platform Input Method Engine (IME).
  void close();
}

/// Connection to the platform's IME.
class DocumentImeConnection with ChangeNotifier implements ImeConnection {
  DocumentImeConnection({
    required DeltaTextInputClient imeClient,
  }) {
    _imeClient = _ClosureAwareImeClientDecorator(imeClient, _onConnectionClosed);
  }

  late final DeltaTextInputClient _imeClient;

  /// Returns `true` if this [DocumentImeConnection] is currently connected to the platform
  /// Input Method Engine (IME).
  ///
  /// Note, it's possible to have an IME connection with a hidden keyboard. To
  /// ensure the keyboard is visible for a given IME connection, call [show].
  @override
  bool get isAttached => imeConnection != null && imeConnection!.attached;

  TextInputConnection? get imeConnection => _imeConnection;
  TextInputConnection? _imeConnection;
  DocumentImeConfiguration _imeConfig = const DocumentImeConfiguration();

  /// Connects the platform Input Method Engine (IME) and (optionally) shows the
  /// standard input UI, e.g., a software keyboard.
  ///
  /// The software keyboard might hide while an IME connection remains open.
  /// To show the software keyboard for an existing IME connection, use
  /// [showImeInput].
  @override
  bool open({bool showImeInput = true}) {
    if (isAttached) {
      // We're already connected to the IME.
      return true;
    }

    _imeConnection = TextInput.attach(_imeClient, _createInputConfiguration());
    print("Opened IME connection: $imeConnection");
    if (imeConnection!.attached == false) {
      // We failed to connect to the platform IME.
      print("IME connection is not attached. Null'ing it out");
      _imeConnection = null;
      return false;
    }

    if (showImeInput) {
      imeConnection!.show();
    }

    // Notify listeners that a connection was opened.
    notifyListeners();
    return true;
  }

  /// Shows the standard input UI (e.g., software keyboard) for an IME
  /// connection that's already open.
  ///
  /// To open an IME connection, use [open].
  @override
  void show() {
    if (!isAttached) {
      print("Not attached. Opening connection to show keyboard.");
      open();
      return;
    }

    print("Already attached. Calling show()");
    imeConnection!.show();
  }

  /// Sets the desired [TextInputConfiguration] for the IME to the given [config],
  /// and updates the existing platform configuration, if this [DocumentImeConnection] is
  /// currently connected to the platform IME.
  void configureIme(DocumentImeConfiguration config) {
    if (config == _imeConfig) {
      return;
    }

    _imeConfig = config;
    if (isAttached) {
      _imeConnection!.updateConfig(_createInputConfiguration());
    }
  }

  TextInputConfiguration _createInputConfiguration() {
    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: _imeConfig.enableAutocorrect,
      enableSuggestions: _imeConfig.enableSuggestions,
      inputAction: _imeConfig.keyboardActionButton,
      keyboardAppearance: _imeConfig.keyboardBrightness,
    );
  }

  /// Closes an open connection to the platform's Input Method Engine (IME).
  @override
  void close() {
    if (!isAttached) {
      return;
    }

    print("Closing IME connection");
    _imeConnection!.close();
    _imeConnection = null;

    // We notify listeners about closing the connection. Technically, we shouldn't have to
    // notify listeners here, because the IME client is supposed to get a closure message.
    // However, we're not getting that message in widget tests. Either Flutter is completely
    // broken with the message, or Flutter's test IME implementation is broken. To get around
    // that in tests, we notify listeners from here.
    notifyListeners();
  }

  void _onConnectionClosed() {
    // Notify listeners that the connection was closed.
    notifyListeners();
  }
}

/// A [DeltaTextInputClient] that forwards all calls to the given [_client], and
/// also notifies [_onConnectionClosed] when the IME connection closes.
///
/// This decorator is needed because [TextInputConnection] has no way to listen
/// for when its connection is closed. By wrapping its [TextInputClient] with
/// this decorator, the code that owns the [TextInputConnection] can receive
/// a notification when the connection closes.
class _ClosureAwareImeClientDecorator implements DeltaTextInputClient {
  _ClosureAwareImeClientDecorator(this._client, this._onConnectionClosed);

  final DeltaTextInputClient _client;
  final VoidCallback _onConnectionClosed;

  @override
  void connectionClosed() {
    print("[_ClosureAwareImeClientDecorator] - IME connection was closed");
    _onConnectionClosed();
    _client.connectionClosed();
  }

  @override
  AutofillScope? get currentAutofillScope => _client.currentAutofillScope;

  @override
  TextEditingValue? get currentTextEditingValue => _client.currentTextEditingValue;

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    _client.didChangeInputControl(oldControl, newControl);
  }

  @override
  void insertTextPlaceholder(Size size) {
    _client.insertTextPlaceholder(size);
  }

  @override
  void performAction(TextInputAction action) {
    _client.performAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    _client.performPrivateCommand(action, data);
  }

  @override
  void performSelector(String selectorName) {
    _client.performSelector(selectorName);
  }

  @override
  void removeTextPlaceholder() {
    _client.removeTextPlaceholder();
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    _client.showAutocorrectionPromptRect(start, end);
  }

  @override
  void showToolbar() {
    _client.showToolbar();
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _client.updateEditingValue(value);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _client.updateEditingValueWithDeltas(textEditingDeltas);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    _client.updateFloatingCursor(point);
  }
}

/// A [TextInputClient] that applies IME operations to a [Document].
class DocumentImeInputClient with TextInputClient, DeltaTextInputClient {
  DocumentImeInputClient({
    // TODO: textDeltasDocumentEditor is enough for text editing deltas, but about
    //       the non-delta IME operations, like perform selector?
    required this.textDeltasDocumentEditor,
    required this.sendTextEditingValueToIme,
    FloatingCursorController? floatingCursorController,
  }) {
    _floatingCursorController = floatingCursorController;
  }

  final TextDeltasDocumentEditor textDeltasDocumentEditor;

  final void Function(TextEditingValue value) sendTextEditingValueToIme;

  late FloatingCursorController? _floatingCursorController;

  bool _hasOutstandingMutatingChanges = false;

  @override
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();
  TextEditingValue? _lastTextEditingValueSentToOs;
  set currentTextEditingValue(TextEditingValue newValue) {
    print("Setting currentTextEditingValue to $newValue");
    _currentTextEditingValue = newValue;

    if (isApplyingDeltas) {
      // We're in the middle of applying a series of text deltas. Don't
      // send any updates to the IME because it will conflict with the
      // changes we're actively processing.
      editorImeLog.fine("Ignoring new TextEditingValue because we're applying deltas");
      return;
    }

    if (newValue != _lastTextEditingValueSentToOs) {
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _lastTextEditingValueSentToOs = _currentTextEditingValue;
      sendTextEditingValueToIme(_currentTextEditingValue);
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
      sendTextEditingValueToIme(currentTextEditingValue);
      _hasOutstandingMutatingChanges = false;
    } else {
      editorImeLog.fine("Ignoring new TextEditingValue because it's the same as the existing one: $newValue");
    }
  }

  // TODO: make this private again
  bool isApplyingDeltas = false;

  @override
  void updateEditingValue(TextEditingValue value) {
    print("updateEditingValue: $value");
    editorImeLog.info("Received new TextEditingValue from OS: $value");
    _currentTextEditingValue = value;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    print("updateEditingValueWithDeltas: $textEditingDeltas");
    if (textEditingDeltas.isEmpty) {
      return;
    }

    editorImeLog.fine("Received edit deltas from platform: ${textEditingDeltas.length} deltas");
    for (final delta in textEditingDeltas) {
      editorImeLog.fine("$delta");
    }

    final imeValueBeforeChange = currentTextEditingValue;
    editorImeLog.fine("IME value before applying deltas: $imeValueBeforeChange");

    isApplyingDeltas = true;
    textDeltasDocumentEditor.applyDeltas(textEditingDeltas);
    isApplyingDeltas = false;

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
    // TODO: implement this method starting with Flutter 3.3.4
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
    editorImeLog.info("IME connection closed");
  }
}

/// Input Method Engine (IME) configuration for document text input.
///
/// The IME is an operating system component that observes text that's
/// being edited, and intercepts keyboard input to apply transforms to
/// the user's input. The alternative to IME input is for an app to
/// listen and respond to each individual keyboard key. On mobile, IME
/// input is the only available input system because there is no physical
/// keyboard.
class DocumentImeConfiguration {
  const DocumentImeConfiguration({
    this.enableAutocorrect = true,
    this.enableSuggestions = true,
    this.keyboardBrightness = Brightness.light,
    this.keyboardActionButton = TextInputAction.newline,
    this.clearSelectionWhenImeDisconnects = false,
  });

  /// Whether the OS should offer auto-correction options to the user.
  final bool enableAutocorrect;

  /// Whether the OS should offer text completion suggestions to the user.
  final bool enableSuggestions;

  /// The brightness of the software keyboard (only applies to platforms
  /// with a software keyboard).
  final Brightness keyboardBrightness;

  /// The action button that's displayed on a software keyboard, e.g.,
  /// new-line, done, go, etc.
  final TextInputAction keyboardActionButton;

  /// Whether the document's selection should be cleared (removed) when the
  /// IME disconnects, i.e., the software keyboard closes.
  ///
  /// Typically, on devices with software keyboards, the keyboard is critical
  /// to all document editing. In such cases, it should be reasonable to clear
  /// the selection when the keyboard closes.
  ///
  /// Some apps include editing features that can operate when the keyboard is
  /// closed. For example, some apps display special editing options behind the
  /// keyboard. The user closes the keyboard, uses the special options, and then
  /// re-opens the keyboard. In this case, the document selection **shouldn't**
  /// be cleared when the keyboard closes, because the special options behind the
  /// keyboard still need to operate on that selection.
  final bool clearSelectionWhenImeDisconnects;

  DocumentImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
    bool? clearSelectionWhenImeDisconnects,
  }) {
    return DocumentImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
      clearSelectionWhenImeDisconnects: clearSelectionWhenImeDisconnects ?? this.clearSelectionWhenImeDisconnects,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentImeConfiguration &&
          runtimeType == other.runtimeType &&
          enableAutocorrect == other.enableAutocorrect &&
          enableSuggestions == other.enableSuggestions &&
          keyboardBrightness == other.keyboardBrightness &&
          keyboardActionButton == other.keyboardActionButton;

  @override
  int get hashCode =>
      enableAutocorrect.hashCode ^
      enableSuggestions.hashCode ^
      keyboardBrightness.hashCode ^
      keyboardActionButton.hashCode;
}
