import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

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
    editorImeLog.fine("[_ClosureAwareImeClientDecorator] - IME connection was closed");
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
