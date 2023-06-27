import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../../_logging.dart';

final _log = imeTextFieldLog;

/// An [AttributedTextEditingController] that integrates the platform's Input
/// Method Engine (IME) changes into the text, selection, and composing region
/// of a text field's content.
///
/// On mobile, all user input must pass through the platform IME, therefore this
/// integration is required for any mobile text field. On desktop, an app developer
/// can choose between the IME and direct keyboard interaction. An app developer can
/// use this controller on desktop to reflect IME changes, just like on mobile. By
/// using the IME on desktop, apps gain access to auto-correction and language
/// composition features.
///
/// Rather than re-implement all of [AttributedTextEditingController],
/// [ImeAttributedTextEditingController] wraps another [AttributedTextEditingController]
/// and defers to that controller wherever possible.
///
/// By default, an [ImeAttributedTextEditingController] is not connected to the platform
/// IME. To connect to the IME, call `attachToIme`. To detach from the IME, call
/// `detachFromIme`.
class ImeAttributedTextEditingController extends AttributedTextEditingController
    with TextInputClient, DeltaTextInputClient {
  ImeAttributedTextEditingController({
    AttributedTextEditingController? controller,
    bool disposeClientController = true,
    void Function(RawFloatingCursorPoint)? onIOSFloatingCursorChange,
    Brightness keyboardAppearance = Brightness.light,
    TextInputConnectionFactory? inputConnectionFactory,
  })  : _realController = controller ?? AttributedTextEditingController(),
        _disposeClientController = disposeClientController,
        _inputConnectionFactory = inputConnectionFactory,
        _onIOSFloatingCursorChange = onIOSFloatingCursorChange,
        _keyboardAppearance = keyboardAppearance {
    _realController.addListener(_onInnerControllerChange);
  }

  @override
  void dispose() {
    if (_disposeClientController) {
      _realController.dispose();
    }

    super.dispose();
  }

  /// The appearance of the software keyboard.
  ///
  /// Only used for iOS devices.
  Brightness get keyboardAppearance => _keyboardAppearance;
  Brightness _keyboardAppearance;

  final AttributedTextEditingController _realController;

  @Deprecated("this property is exposed temporarily as super_editor evaluates what to do with controllers")
  AttributedTextEditingController get innerController => _realController;

  final bool _disposeClientController;

  // Only for testing purposes.
  final TextInputConnectionFactory? _inputConnectionFactory;

  void Function(RawFloatingCursorPoint)? _onIOSFloatingCursorChange;

  /// Sets the callback that's invoked whenever the floating cursor changes
  /// position on iOS.
  ///
  /// The "floating cursor" is an iOS-specific UI element. When the user presses
  /// and holds the space bar, a red caret appears over the given text block. As
  /// the user moves their finger over the keyboard, the red "floating cursor"
  /// moves across the screen in the same direction. The actual caret for the
  /// text is grey, and it snaps to the text position that's nearest to the
  /// "floating cursor".
  ///
  /// The floating cursor's position is reported by Flutter through a
  /// `TextInputClient`, which is why this controller is required to offer this
  /// information.
  set onIOSFloatingCursorChange(void Function(RawFloatingCursorPoint)? callback) {
    _onIOSFloatingCursorChange = callback;
  }

  TextInputConnection? _inputConnection;
  bool _isKeyboardDisplayDesired = false;

  bool get isAttachedToIme => _inputConnection != null && _inputConnection!.attached;

  void attachToIme({
    bool autocorrect = true,
    bool enableSuggestions = true,
    TextInputAction textInputAction = TextInputAction.done,
    TextInputType textInputType = TextInputType.text,
  }) {
    if (isAttachedToIme) {
      // We're already connected to the IME.
      return;
    }

    final imeConfig = TextInputConfiguration(
      autocorrect: autocorrect,
      enableDeltaModel: true,
      enableSuggestions: enableSuggestions,
      inputAction: textInputAction,
      inputType: textInputType,
      keyboardAppearance: keyboardAppearance,
    );
    _inputConnection = _inputConnectionFactory?.call(this, imeConfig) ?? TextInput.attach(this, imeConfig);
    _inputConnection!.show();
    _sendEditingValueToPlatform();
    _log.fine('Is attached to input client? ${_inputConnection!.attached}');
  }

  void updateTextInputConfiguration({
    bool autocorrect = true,
    bool enableSuggestions = true,
    TextInputAction textInputAction = TextInputAction.done,
    TextInputType textInputType = TextInputType.text,
    Brightness keyboardAppearance = Brightness.light,
  }) {
    // Change the keyboard appearance even if we are detached from the IME.
    // In the next time we attach to the IME, the keyboard appearance is used.
    _keyboardAppearance = keyboardAppearance;

    if (!isAttachedToIme) {
      // We're not attached to the IME, so there is nothing to update.
      return;
    }

    // Close the current connection.
    _inputConnection?.close();

    // Open a new connection with the new configuration.
    final imeConfig = TextInputConfiguration(
      autocorrect: autocorrect,
      enableDeltaModel: true,
      enableSuggestions: enableSuggestions,
      inputAction: textInputAction,
      inputType: textInputType,
      keyboardAppearance: keyboardAppearance,
    );
    _inputConnection = _inputConnectionFactory?.call(this, imeConfig) ?? TextInput.attach(this, imeConfig);
    _inputConnection!.show();
    _sendEditingValueToPlatform();
  }

  void detachFromIme() {
    _log.fine('Closing input connection');
    _inputConnection?.close();
  }

  void showKeyboard() {
    _isKeyboardDisplayDesired = true;
    _inputConnection?.show();
  }

  void toggleKeyboard() {
    _isKeyboardDisplayDesired = !_isKeyboardDisplayDesired;
    if (_isKeyboardDisplayDesired) {
      _inputConnection?.show();
    } else {
      _inputConnection?.close();
    }
  }

  void hideKeyboard() {
    _isKeyboardDisplayDesired = false;
    _inputConnection?.close();
  }

  //------ Start TextInputClient ----
  // Whether to forward text changes to the platform.
  //
  // Sometimes text changes originate from the platform, and other times changes
  // originate from the app side, e.g., user selection, programmatic changes, etc.
  // When changes come from the app, we want to forward those to platform. But,
  // when changes originate from the platform, we don't want to send those back
  // to the platform as changes. This flag differentiates between the two situations.
  bool _sendTextChangesToPlatform = true;

  /// Whether we should handle [TextEditingDeltaNonTextUpdate]s.
  bool _allowNonTextDeltas = true;

  void _onInnerControllerChange() {
    if (_sendTextChangesToPlatform) {
      _sendEditingValueToPlatform();
    }

    // This method was called in response to our inner controller sending a
    // change notification. Forward that change notification to our listeners,
    // because we wrap _realController as a proxy.
    notifyListeners();
  }

  TextEditingValue? _latestPlatformTextEditingValue;

  void _onReceivedTextEditingValueFromPlatform(TextEditingValue newValue) {
    if (newValue == _latestPlatformTextEditingValue) {
      // The value didn't change. Don't let us get into an infinite loop
      // with the IME where it keeps sending us the same value over and over.
      return;
    }

    // We have to send the value back to the platform to acknowledge receipt.
    _sendEditingValueToPlatform();
  }

  void _sendEditingValueToPlatform() {
    if (!isAttachedToIme) {
      return;
    }

    // In some platforms, like macOS, whenever we call setEditingState(), the engine send us back a
    // non-text delta to sync its state with our state.
    //
    // We have no way to know if the delta means that the selection/composing region changed,
    // or if it means that the engine is syncing its state.
    //
    // If we always handle the non-text deltas, we might end up in an endless loop of deltas.
    // To avoid this, we don't handle any non-text deltas until the next frame, after we call setEditingState.
    //
    // Remove this as soon as https://github.com/flutter/flutter/issues/118759 is resolved.
    _allowNonTextDeltas = false;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _allowNonTextDeltas = true;
    });

    _log.fine('Sending TextEditingValue to platform: $currentTextEditingValue');
    _latestPlatformTextEditingValue = currentTextEditingValue;
    _inputConnection!.setEditingState(currentTextEditingValue!);
  }

  void Function(TextInputAction)? _onPerformActionPressed;
  set onPerformActionPressed(Function(TextInputAction)? callback) => _onPerformActionPressed = callback;
  Function(TextInputAction)? get onPerformActionPressed => _onPerformActionPressed;

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue(
        text: text.text,
        selection: selection,
        composing: composingRegion,
      );

  @override
  void updateEditingValue(TextEditingValue value) {
    _log.fine('New platform TextEditingValue: $value');
    _onReceivedTextEditingValueFromPlatform(value);

    if (_latestPlatformTextEditingValue != currentTextEditingValue) {
      _sendTextChangesToPlatform = false;
      text = AttributedText(text: value.text);
      selection = value.selection;
      composingRegion = value.composing;
      _sendTextChangesToPlatform = true;
    }
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    _log.fine('Received text editing deltas from platform...');
    if (deltas.isEmpty) {
      return;
    }

    // After we call setEditingState(), we ignore non-text deltas until the end of the current frame.
    //
    // This is because, in some platforms, we get a TextEditingDeltaNonTextUpdate after this call.
    // The engine sends this delta to synchronize the editing value.
    //
    // Handling this synchronization delta may cause endless loops.
    final allowedDeltas =
        _allowNonTextDeltas ? deltas : deltas.where((e) => e is! TextEditingDeltaNonTextUpdate).toList();
    if (allowedDeltas.isEmpty) {
      return;
    }

    // Prevent us from sending these changes back to the platform as we alter
    // the _realController. Turn this flag back to `true` after the changes.
    _sendTextChangesToPlatform = false;

    for (final delta in allowedDeltas) {
      if (delta is TextEditingDeltaInsertion) {
        _log.fine('Processing insertion: $delta');
        if (selection.isCollapsed && delta.insertionOffset == selection.extentOffset) {
          // This action appears to be user input at the caret.
          insertAtCaret(
            text: delta.textInserted,
            newComposingRegion: delta.composing,
          );
        } else {
          // We're not sure what this action represents. Either the current selection
          // isn't collapsed, or this insertion is taking place at a location other than
          // where the caret currently sits. Insert the content, applying upstream styles,
          // and then push/expand the current selection as needed around the new content.
          insert(
            newText: AttributedText(
              text: delta.textInserted,
            ),
            insertIndex: delta.insertionOffset,
            newSelection: delta.selection,
            newComposingRegion: delta.composing,
          );
        }
      } else if (delta is TextEditingDeltaDeletion) {
        _log.fine('Processing deletion: $delta');
        delete(
          from: delta.deletedRange.start,
          to: delta.deletedRange.end,
          newSelection: delta.selection,
          newComposingRegion: delta.composing,
        );
      } else if (delta is TextEditingDeltaReplacement) {
        _log.fine('Processing replacement: $delta');
        replace(
          newText: AttributedText(text: delta.replacementText),
          from: delta.replacedRange.start,
          to: delta.replacedRange.end,
          newSelection: delta.selection,
        );
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _log.fine('Processing selection/composing change: $delta');
        update(
          selection: delta.selection,
          composingRegion: delta.composing,
        );
      }
    }

    // Now that we're done applying all the deltas, start sending text changes
    // to the platform again.
    _sendTextChangesToPlatform = true;

    _onReceivedTextEditingValueFromPlatform(currentTextEditingValue!);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    _onIOSFloatingCursorChange?.call(point);
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void performAction(TextInputAction action) {
    _onPerformActionPressed?.call(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // performPrivateCommand() provides a representation for unofficial
    // input commands to be executed. This appears to be an extension point
    // or an escape hatch for input functionality that an app needs to support,
    // but which does not exist at the OS/platform level.
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // no-op
  }

  @override
  void connectionClosed() {
    _log.info('TextInputClient: connectionClosed()');
    _inputConnection = null;
    _latestPlatformTextEditingValue = null;
  }

  @override
  void performSelector(String selectorName) {
    // TODO: implement this method starting with Flutter 3.3.4
  }
  //------ End TextInputClient -----

  @override
  AttributedText get text => _realController.text;
  @override
  set text(AttributedText newValue) => _realController.text = newValue;

  @override
  TextSelection get selection => _realController.selection;
  @override
  set selection(TextSelection newValue) => _realController.selection = newValue;

  @override
  Set<Attribution> get composingAttributions => _realController.composingAttributions;
  @override
  set composingAttributions(Set<Attribution> attributions) => _realController.composingAttributions = attributions;

  @override
  TextRange get composingRegion => _realController.composingRegion;
  @override
  set composingRegion(TextRange newValue) => _realController.composingRegion = newValue;

  @override
  void updateTextAndSelection({required AttributedText text, required TextSelection selection}) {
    _realController.updateTextAndSelection(
      text: text,
      selection: selection,
    );
  }

  @override
  bool isSelectionWithinTextBounds(TextSelection selection) {
    return _realController.isSelectionWithinTextBounds(selection);
  }

  @override
  void toggleSelectionAttributions(List<Attribution> attributions) {
    _realController.toggleSelectionAttributions(attributions);
  }

  @override
  void clearSelectionAttributions() {
    _realController.clearSelectionAttributions();
  }

  @override
  void addComposingAttributions(Set<Attribution> attributions) {
    _realController.addComposingAttributions(attributions);
  }

  @override
  void removeComposingAttributions(Set<Attribution> attributions) {
    _realController.removeComposingAttributions(attributions);
  }

  @override
  void toggleComposingAttributions(Set<Attribution> attributions) {
    _realController.toggleComposingAttributions(attributions);
  }

  @override
  void clearComposingAttributions() {
    _realController.clearComposingAttributions();
  }

  @override
  void insert({
    required AttributedText newText,
    required int insertIndex,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    _realController.insert(
      newText: newText,
      insertIndex: insertIndex,
      newSelection: newSelection,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void insertNewline() => _realController.insertNewline();

  @override
  void insertAtCaret({required String text, TextRange? newComposingRegion}) {
    _realController.insertAtCaret(
      text: text,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void insertAtCaretUnstyled({required String text, TextRange? newComposingRegion}) {
    _realController.insertAtCaretUnstyled(
      text: text,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void insertAtCaretWithUpstreamAttributions({required String text, TextRange? newComposingRegion}) {
    _realController.insertAtCaretWithUpstreamAttributions(
      text: text,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void insertAttributedTextAtCaret({required AttributedText attributedText, TextRange? newComposingRegion}) {
    _realController.insertAttributedTextAtCaret(
      attributedText: attributedText,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void replaceSelectionWithAttributedText({
    required AttributedText attributedReplacementText,
    TextRange? newComposingRegion,
  }) {
    _realController.replaceSelectionWithAttributedText(
      attributedReplacementText: attributedReplacementText,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void replaceSelectionWithTextAndUpstreamAttributions(
      {required String replacementText, TextRange? newComposingRegion}) {
    _realController.replaceSelectionWithTextAndUpstreamAttributions(
      replacementText: replacementText,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void replaceSelectionWithUnstyledText({required String replacementText, TextRange? newComposingRegion}) {
    _realController.replaceSelectionWithUnstyledText(
      replacementText: replacementText,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void replace({
    required AttributedText newText,
    required int from,
    required int to,
    TextSelection? newSelection,
    TextRange? newComposingRegion,
  }) {
    _realController.replace(
      newText: newText,
      from: from,
      to: to,
      newSelection: newSelection,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void delete({required int from, required int to, TextSelection? newSelection, TextRange? newComposingRegion}) {
    _realController.delete(
      from: from,
      to: to,
      newSelection: newSelection,
      newComposingRegion: newComposingRegion,
    );
  }

  @override
  void deleteNextCharacter({TextRange? newComposingRegion}) {
    _realController.deleteNextCharacter(newComposingRegion: newComposingRegion);
  }

  @override
  void deletePreviousCharacter({TextRange? newComposingRegion}) {
    _realController.deletePreviousCharacter(newComposingRegion: newComposingRegion);
  }

  @override
  void deleteSelection({TextRange? newComposingRegion}) {
    _realController.deleteSelection(newComposingRegion: newComposingRegion);
  }

  @override
  void update({AttributedText? text, TextSelection? selection, TextRange? composingRegion}) {
    _realController.update(
      text: text,
      selection: selection,
      composingRegion: composingRegion,
    );
  }

  @override
  TextSpan buildTextSpan(AttributionStyleBuilder styleBuilder) {
    return _realController.buildTextSpan(styleBuilder);
  }

  @override
  void clear() {
    _realController.clear();
  }

  @override
  void deleteCharacter(TextAffinity direction) {
    _realController.deleteCharacter(direction);
  }

  @override
  void copySelectedTextToClipboard() {
    _realController.copySelectedTextToClipboard();
  }

  @override
  void deleteSelectedText() {
    _realController.deleteSelectedText();
  }

  @override
  void deleteTextOnLineBeforeCaret({required ProseTextLayout textLayout}) {
    _realController.deleteTextOnLineBeforeCaret(textLayout: textLayout);
  }

  @override
  void insertCharacter(String character) {
    _realController.insertCharacter(character);
  }

  @override
  void moveCaretHorizontally({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveLeft,
    required MovementModifier? movementModifier,
  }) {
    _realController.moveCaretHorizontally(
      textLayout: textLayout,
      expandSelection: expandSelection,
      moveLeft: moveLeft,
      movementModifier: movementModifier,
    );
  }

  @override
  void moveCaretVertically({
    required ProseTextLayout textLayout,
    required bool expandSelection,
    required bool moveUp,
  }) {
    _realController.moveCaretVertically(
      textLayout: textLayout,
      expandSelection: expandSelection,
      moveUp: moveUp,
    );
  }

  @override
  Future<void> pasteClipboard() {
    return _realController.pasteClipboard();
  }

  @override
  void selectAll() {
    _realController.selectAll();
  }
}

typedef TextInputConnectionFactory = TextInputConnection Function(
    TextInputClient client, TextInputConfiguration configuration);
