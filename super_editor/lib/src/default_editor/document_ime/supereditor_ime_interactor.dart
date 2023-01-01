import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import '../document_input_keyboard.dart';
import 'document_delta_editing.dart';
import 'document_ime_communication.dart';
import 'document_ime_hardware_keyboard.dart';
import 'document_ime_interaction_policies.dart';

/// Document interactor that edits a document based on IME input
/// from the operating system.
// TODO: instead of an IME interactor, try defining more granular interactors, e.g.,
//       TextDeltaInteractor, FloatingCursorInteractor, ScribbleInteractor.
//       The concept of the IME is so broad in functionality that if we mimic that
//       concept, we're going to get stuck piling unrelated behaviors into one place.
//       To make this division of responsibility possible, each of those interactors
//       could receive a proxy TextInputClient, which allows each interactor to say
//       proxyInputClient.addClient(myFocusedClient).
class DocumentImeInteractor extends StatefulWidget {
  const DocumentImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    this.softwareKeyboardController,
    this.openKeyboardOnSelectionChange = true,
    this.clearSelectionWhenImeDisconnects = true,
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
  /// When [openKeyboardOnSelectionChange] and [clearSelectionWhenImeDisconnects]
  /// are `false`, an app can use this controller to manually open and close the
  /// software keyboard, as needed.
  ///
  /// When [openKeyboardOnSelectionChange] and [clearSelectionWhenImeDisconnects]
  /// are `true`, this controller probably shouldn't be used, because the commands
  /// to open and close the keyboard might conflict with teh automated behavior.
  final SoftwareKeyboardController? softwareKeyboardController;

  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  final bool openKeyboardOnSelectionChange;

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
  State createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor>
    implements ImeInputOwner, SoftwareKeyboardControllerDelegate {
  late FocusNode _focusNode;

  late final DocumentImeConnection _documentImeConnection;
  late final DocumentImeInputClient _documentImeClient;
  late final TextDeltasDocumentEditor _textDeltasDocumentEditor;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());

    _textDeltasDocumentEditor = TextDeltasDocumentEditor(
      editor: widget.editContext.editor,
      selection: widget.editContext.composer.selectionNotifier,
      imeComposingRegion: widget.editContext.composer.imeComposingRegion,
      commonOps: widget.editContext.commonOps,
    );
    _documentImeClient = DocumentImeInputClient(
      textDeltasDocumentEditor: _textDeltasDocumentEditor,
      floatingCursorController: widget.floatingCursorController,
      sendTextEditingValueToIme: (newValue) {
        _documentImeConnection.imeConnection?.setEditingState(newValue);
      },
    );
    _documentImeConnection = DocumentImeConnection(imeClient: _documentImeClient);

    widget.softwareKeyboardController?.attach(this);
  }

  @override
  void didUpdateWidget(DocumentImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.softwareKeyboardController != oldWidget.softwareKeyboardController) {
      oldWidget.softwareKeyboardController?.detach();
      widget.softwareKeyboardController?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.softwareKeyboardController?.detach();

    _documentImeConnection.close();

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient => _documentImeClient;

  bool get isAttachedToIme => _documentImeConnection.isAttached;

  @override
  bool get isConnectedToIme => isAttachedToIme;

  @override
  void open() {
    print("IME Interactor: showing keyboard");
    _documentImeConnection.show();
  }

  @override
  void close() {
    _documentImeConnection.close();
  }

  @override
  Widget build(BuildContext context) {
    print("BUILDING IME Interactor");
    return ImeFocusPolicy(
      focusNode: _focusNode,
      closeIme: _documentImeConnection.close,
      child: DocumentSelectionOpenAndCloseImePolicy(
        focusNode: _focusNode,
        selection: widget.editContext.composer.selectionNotifier,
        imeConnectionController: _documentImeConnection,
        openKeyboardOnSelectionChange: widget.openKeyboardOnSelectionChange,
        clearSelectionWhenImeDisconnects: widget.clearSelectionWhenImeDisconnects,
        child: DocumentImeHardwareKeyEditor(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: widget.editContext,
          hardwareKeyboardActions: widget.hardwareKeyboardActions,
          child: ListenableBuilder(
            // Rebuilds whenever an IME connection opens or closes.
            listenable: _documentImeConnection,
            builder: (context) {
              print("BUILDING Document IME connection listenable builder");
              return DocumentToImeSynchronizer(
                document: widget.editContext.editor.document,
                selection: widget.editContext.composer.selectionNotifier,
                imeConnection: _documentImeConnection,
                imeComposingRegion: widget.editContext.composer.imeComposingRegion,
                imeValue: SuperEditorImeValue(
                  _documentImeConnection,
                  _documentImeClient,
                ),
                child: widget.child,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Controller that can be used to open and close the software keyboard
/// from outside of `SuperEditor`.
class SoftwareKeyboardController {
  SoftwareKeyboardControllerDelegate? _delegate;

  /// Whether this controller is currently attached to a delegate that
  /// knows how to open and close the software keyboard.
  bool get hasDelegate => _delegate != null;

  /// Attaches this controller to a delegate that knows how to open and
  /// close the software keyboard.
  void attach(SoftwareKeyboardControllerDelegate delegate) {
    print("Attaching software keyboard controller to delegate: $delegate");
    _delegate = delegate;
  }

  /// Detaches this controller from its delegate.
  ///
  /// This controller can't open or close the software keyboard while
  /// detached from a delegate that knows how to make that happen.
  void detach() {
    print("Detaching software keyboard controller from delegate");
    _delegate = null;
  }

  /// Whether the delegate is currently connected to the platform IME.
  bool get isConnectedToIme {
    assert(hasDelegate);
    return _delegate?.isConnectedToIme ?? false;
  }

  /// Opens the software keyboard.
  void open() {
    assert(hasDelegate);
    _delegate?.open();
  }

  /// Closes the software keyboard.
  void close() {
    assert(hasDelegate);
    _delegate?.close();
  }
}

/// Delegate that's attached to a [SoftwareKeyboardController] to implement
/// the opening and closing of the software keyboard.
abstract class SoftwareKeyboardControllerDelegate {
  /// Whether this delegate is currently connected to the platform IME.
  bool get isConnectedToIme;

  /// Opens the software keyboard.
  void open();

  /// Closes the software keyboard.
  void close();
}

/// An [ImeValue] that's implemented specifically for use with a `SuperEditor` widget.
class SuperEditorImeValue implements ImeValue {
  SuperEditorImeValue(this._imeConnection, this._client);

  final DocumentImeConnection _imeConnection;
  final DocumentImeInputClient _client;

  @override
  TextEditingValue get currentTextEditingValue => _client.currentTextEditingValue;

  @override
  set currentTextEditingValue(TextEditingValue newValue) {
    _client.currentTextEditingValue = newValue;
    _imeConnection.imeConnection?.setEditingState(newValue);
  }

  @override
  bool get isConnectedToIme => _imeConnection.isAttached;

  @override
  void closeConnection() => _imeConnection.close();
}
