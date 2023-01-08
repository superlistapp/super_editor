import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import '../document_hardware_keyboard/document_input_keyboard.dart';
import 'document_delta_editing.dart';
import 'document_ime_communication.dart';
import 'document_ime_interaction_policies.dart';
import 'ime_keyboard_control.dart';

/// [SuperEditor] interactor that edits a document based on IME input
/// from the operating system.
// TODO: instead of an IME interactor, try defining more granular interactors, e.g.,
//       TextDeltaInteractor, FloatingCursorInteractor, ScribbleInteractor.
//       The concept of the IME is so broad in functionality that if we mimic that
//       concept, we're going to get stuck piling unrelated behaviors into one place.
//       To make this division of responsibility possible, each of those interactors
//       could receive a proxy TextInputClient, which allows each interactor to say
//       proxyInputClient.addClient(myFocusedClient).
class SuperEditorImeInteractor extends StatefulWidget {
  const SuperEditorImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    this.softwareKeyboardController,
    this.imePolicies = const SuperEditorImePolicies(),
    this.imeConfiguration = const SuperEditorImeConfiguration(),
    this.hardwareKeyboardActions = const [],
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  /// All resources that are needed to edit a document.
  final EditContext editContext;

  /// Controller that opens and closes the software keyboard.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [SuperEditorImePolicies.clearSelectionWhenImeDisconnects] are `false`,
  /// an app can use this controller to manually open and close the software
  /// keyboard, as needed.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [clearSelectionWhenImeDisconnects] are `true`, this controller probably
  /// shouldn't be used, because the commands to open and close the keyboard
  /// might conflict with teh automated behavior.
  final SoftwareKeyboardController? softwareKeyboardController;

  /// Policies that dictate when and how `SuperEditor` should interact with the
  /// platform IME.
  final SuperEditorImePolicies imePolicies;

  /// Preferences for how the platform IME should look and behave during editing.
  final SuperEditorImeConfiguration imeConfiguration;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  /// Controls "floating cursor" behavior for iOS devices.
  ///
  /// The floating cursor is an iOS-only feature. Flutter reports floating cursor
  /// messages through the IME API, which is why this controller is offered as
  /// a property on this IME interactor.
  final FloatingCursorController? floatingCursorController;

  final Widget child;

  @override
  State createState() => _SuperEditorImeInteractorState();
}

class _SuperEditorImeInteractorState extends State<SuperEditorImeInteractor> implements ImeInputOwner {
  late FocusNode _focusNode;

  final _imeConnection = ValueNotifier<TextInputConnection?>(null);
  late TextInputConfiguration _textInputConfiguration;
  late final DocumentImeInputClient _documentImeClient;
  // _documentImeConnection functions as both a TextInputConnection and a
  // DeltaTextInputClient. This is required for a very specific reason that
  // occurs in specific situations. To understand why we need it, check the
  // implementation of DocumentImeInputClient. If we find a less confusing
  // way to handle that scenario, then get rid of this property.
  final _documentImeConnection = ValueNotifier<DocumentImeInputClient?>(null);
  late final TextDeltasDocumentEditor _textDeltasDocumentEditor;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());

    _textDeltasDocumentEditor = TextDeltasDocumentEditor(
      editor: widget.editContext.editor,
      selection: widget.editContext.composer.selectionNotifier,
      composingRegion: widget.editContext.composer.composingRegion,
      commonOps: widget.editContext.commonOps,
    );
    _documentImeClient = DocumentImeInputClient(
      textDeltasDocumentEditor: _textDeltasDocumentEditor,
      imeConnection: _imeConnection,
      floatingCursorController: widget.floatingCursorController,
    );

    _imeConnection.addListener(_onImeConnectionChange);

    _textInputConfiguration = widget.imeConfiguration.toTextInputConfiguration();
  }

  @override
  void didUpdateWidget(SuperEditorImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.imeConfiguration != oldWidget.imeConfiguration) {
      _textInputConfiguration = widget.imeConfiguration.toTextInputConfiguration();
      if (_isAttachedToIme) {
        _imeConnection.value!.updateConfig(_textInputConfiguration);
      }
    }
  }

  @override
  void dispose() {
    _imeConnection.removeListener(_onImeConnectionChange);
    _imeConnection.value?.close();

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient => _documentImeClient;

  bool get _isAttachedToIme => _imeConnection.value?.attached ?? false;

  void _onImeConnectionChange() {
    if (_imeConnection.value == null) {
      _documentImeConnection.value = null;
    } else {
      _documentImeConnection.value = _documentImeClient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorHardwareKeyHandler(
      focusNode: _focusNode,
      editContext: widget.editContext,
      keyboardActions: widget.hardwareKeyboardActions,
      autofocus: widget.autofocus,
      child: DocumentSelectionOpenAndCloseImePolicy(
        focusNode: _focusNode,
        selection: widget.editContext.composer.selectionNotifier,
        imeConnection: _imeConnection,
        imeClientFactory: () => _documentImeClient,
        imeConfiguration: _textInputConfiguration,
        openKeyboardOnSelectionChange: widget.imePolicies.openKeyboardOnSelectionChange,
        closeKeyboardOnSelectionLost: widget.imePolicies.closeKeyboardOnSelectionLost,
        clearSelectionWhenImeDisconnects: widget.imePolicies.clearSelectionWhenImeDisconnects,
        child: ImeFocusPolicy(
          focusNode: _focusNode,
          imeConnection: _imeConnection,
          child: SoftwareKeyboardOpener(
            controller: widget.softwareKeyboardController,
            imeConnection: _imeConnection,
            createImeClient: () => _documentImeClient,
            createImeConfiguration: () => _textInputConfiguration,
            child: DocumentToImeSynchronizer(
              document: widget.editContext.editor.document,
              selection: widget.editContext.composer.selectionNotifier,
              composingRegion: widget.editContext.composer.composingRegion,
              imeConnection: _documentImeConnection,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A collection of policies that dictate how and when `SuperEditor` should
/// interact with the IME, such as opening the software keyboard whenever
/// `SuperEditor`'s selection changes ([openKeyboardOnSelectionChange]).
class SuperEditorImePolicies {
  const SuperEditorImePolicies({
    this.openKeyboardOnSelectionChange = true,
    this.closeKeyboardOnSelectionLost = true,
    this.clearSelectionWhenImeDisconnects = true,
  });

  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  final bool openKeyboardOnSelectionChange;

  /// Whether the software keyboard should be closed whenever the editor goes from
  /// having a selection to not having a selection.
  ///
  /// In a typical app, this property should be `true`, because there's no place to
  /// apply IME input when there's no editor selection.
  final bool closeKeyboardOnSelectionLost;

  /// Whether the document's selection should be cleared (removed) when the
  /// IME disconnects, i.e., the software keyboard closes.
  ///
  /// Typically, on devices with software keyboards, the keyboard is critical
  /// to all document editing. In such cases, it would be reasonable to clear
  /// the selection when the keyboard closes.
  ///
  /// Some apps include editing features that can operate when the keyboard is
  /// closed. For example, some apps display special editing options behind the
  /// keyboard. The user closes the keyboard, uses the special options, and then
  /// re-opens the keyboard. In this case, the document selection **shouldn't**
  /// be cleared when the keyboard closes, because the special options behind the
  /// keyboard still need to operate on that selection.
  final bool clearSelectionWhenImeDisconnects;
}

/// Input Method Engine (IME) configuration for document text input.
class SuperEditorImeConfiguration {
  const SuperEditorImeConfiguration({
    this.enableAutocorrect = true,
    this.enableSuggestions = true,
    this.keyboardBrightness = Brightness.light,
    this.keyboardActionButton = TextInputAction.newline,
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

  TextInputConfiguration toTextInputConfiguration() {
    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: enableAutocorrect,
      enableSuggestions: enableSuggestions,
      inputAction: keyboardActionButton,
      keyboardAppearance: keyboardBrightness,
    );
  }

  SuperEditorImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
    bool? clearSelectionWhenImeDisconnects,
  }) {
    return SuperEditorImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorImeConfiguration &&
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
