import 'dart:async';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import 'document_ime.dart';
import 'document_selection.dart';

/// Maintains a [DocumentSelection] within a [Document] and
/// uses that selection to edit the document.
class DocumentComposer with ChangeNotifier {
  /// Constructs a [DocumentComposer] with the given [initialSelection].
  ///
  /// The [initialSelection] may be omitted if no initial selection is
  /// desired.
  DocumentComposer({
    required Document document,
    DocumentSelection? initialSelection,
    ImeConfiguration? imeConfiguration,
    this.automaticallyOpenKeyboardOnSelectionChange = true,
    this.clearSelectionWhenImeDisconnects = true,
  })  : _document = document,
        imeConfiguration = ValueNotifier(imeConfiguration ?? const ImeConfiguration()),
        _preferences = ComposerPreferences() {
    _streamController = StreamController<DocumentSelectionChange>.broadcast();
    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);
    selectionNotifier.value = initialSelection;
    _preferences.addListener(() {
      editorLog.fine("Composer preferences changed");
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _preferences.dispose();
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);
    super.dispose();
  }

  /// The document that's being edited by this [DocumentComposer].
  final Document _document;

  /// Processes all IME input.
  @visibleForTesting
  SoftwareKeyboardHandler? get softwareKeyboardHandler => _softwareKeyboardHandler;

  SoftwareKeyboardHandler? _softwareKeyboardHandler;

  set softwareKeyboardHandler(SoftwareKeyboardHandler? newHandler) {
    if (newHandler == _softwareKeyboardHandler) {
      return;
    }

    final wasHandlerNull = _softwareKeyboardHandler == null;
    _softwareKeyboardHandler = newHandler;

    if (wasHandlerNull && selection != null && automaticallyOpenKeyboardOnSelectionChange) {
      // Previously, we had no IME support, and now we do. We also have an existing
      // document selection, and we want to automatically open the keyboard when the
      // selection changes. We'll treat our new IME support like a selection change, and
      // open the keyboard.
      showImeInput();
    }
  }

  /// Whether this [DocumentComposer] is configured to open, close,
  /// and to talk the IME.
  ///
  /// When an editor uses a physical keyboard, this property is
  /// expected to be `false`.
  bool get _isConfiguredToUseIme => softwareKeyboardHandler != null;

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
  bool clearSelectionWhenImeDisconnects;

  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  bool automaticallyOpenKeyboardOnSelectionChange;

  /// Returns the current [DocumentSelection] for a [Document].
  DocumentSelection? get selection => selectionNotifier.value;

  /// Sets the current [selection] for a [Document] using [SelectionReason.userInteraction] as the reason.
  set selection(DocumentSelection? newSelection) {
    if (newSelection != selectionNotifier.value) {
      selectionNotifier.value = newSelection;

      notifyListeners();

      _updateImeConnectionAfterSelectionChange();
    }
  }

  /// Sets the current [selection] for a [Document].
  ///
  /// [reason] represents what caused the selection change to happen.
  void setSelectionWithReason(DocumentSelection? newSelection, [Object reason = SelectionReason.userInteraction]) {
    _latestSelectionChange = DocumentSelectionChange(
      selection: newSelection,
      reason: reason,
    );

    _streamController.sink.add(_latestSelectionChange);

    // Remove the listener, so we don't emit another DocumentSelectionChange.
    selectionNotifier.removeListener(_onSelectionChangedBySelectionNotifier);

    // Updates the selection, so both _latestSelectionChange and selectionNotifier are in sync.
    selectionNotifier.value = newSelection;

    selectionNotifier.addListener(_onSelectionChangedBySelectionNotifier);

    _updateImeConnectionAfterSelectionChange();
  }

  /// Returns the reason for the most recent selection change in the composer.
  ///
  /// For example, a selection might change as a result of user interaction, or as
  /// a result of another user editing content, or some other reason.
  Object? get latestSelectionChangeReason => _latestSelectionChange.reason;

  /// Returns the most recent selection change in the composer.
  ///
  /// The [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  DocumentSelectionChange get latestSelectionChange => _latestSelectionChange;
  late DocumentSelectionChange _latestSelectionChange;

  /// A stream of document selection changes.
  ///
  /// Each new [DocumentSelectionChange] includes the most recent document selection,
  /// along with the reason that the selection changed.
  ///
  /// Listen to this [Stream] when the selection reason is needed. Otherwise, use [selectionNotifier].
  Stream<DocumentSelectionChange> get selectionChanges => _streamController.stream;
  late StreamController<DocumentSelectionChange> _streamController;

  /// Notifies whenever the current [DocumentSelection] changes.
  ///
  /// If the selection change reason is needed, use [selectionChanges] instead.
  final selectionNotifier = ValueNotifier<DocumentSelection?>(null);

  /// Clears the current [selection].
  void clearSelection() {
    selection = null;
  }

  void _onSelectionChangedBySelectionNotifier() {
    _latestSelectionChange = DocumentSelectionChange(
      selection: selectionNotifier.value,
      reason: SelectionReason.userInteraction,
    );

    _streamController.sink.add(_latestSelectionChange);

    _updateImeConnectionAfterSelectionChange();
  }

  void _updateImeConnectionAfterSelectionChange() {
    if (!_isConfiguredToUseIme) {
      return;
    }

    if (selection != null && automaticallyOpenKeyboardOnSelectionChange) {
      showImeInput();
    }
  }

  bool get isAttachedToIme => _imeConnection != null;

  TextInputConnection? _imeConnection;
  @visibleForTesting
  EditorImeClient? imeClient;

  final ValueNotifier<ImeConfiguration> imeConfiguration;

  DocumentImeSerializer? _currentImeSerialization;

  // TODO: get rid of this parameters. They should be constructor injected, or perhaps set explicitly
  void openIme([FloatingCursorController? floatingCursorController]) {
    print("Opening IME");
    if (isAttachedToIme) {
      print("Already attached to the IME");
      // We're already connected to the IME.
      return;
    }
    if (softwareKeyboardHandler == null) {
      throw Exception("Tried to open an IME connection without an existing softwareKeyboardHandler");
    }

    editorImeLog.info('Attaching TextInputClient to TextInput');

    imeClient = EditorImeClient(
      softwareKeyboardHandler: softwareKeyboardHandler!,
      floatingCursorController: floatingCursorController,
      sendDocumentToIme: syncImeWithDocumentAndSelection,
    );

    _imeConnection = TextInput.attach(
      imeClient!,
      _createInputConfiguration(),
    );

    imeClient!.imeConnection = _imeConnection;

    syncImeWithDocumentAndSelection();

    _imeConnection!
      ..show()
      ..setEditingState(imeClient!.currentTextEditingValue);

    print('Is attached to input client? ${_imeConnection!.attached}');
    editorImeLog.fine('Is attached to input client? ${_imeConnection!.attached}');
  }

  // TODO: get rid of these parameters. They should be constructor injected, or perhaps set explicitly
  void showImeInput([FloatingCursorController? floatingCursorController]) {
    if (isAttachedToIme && !imeClient!.isApplyingDeltas) {
      // Note: ^ We don't re-serialize and send to IME while we're in the middle
      // of applying deltas because we might be in an inconsistent state. A sync
      // will be done when all the deltas have been applied.
      _imeConnection!.show();
      editorImeLog
          .fine("Document composer changed while attached to IME. Re-serializing the document and sending to the IME.");
      // Pass an empty composing region because the user may have dragged the caret
      // across nodes, in which case the previous composing region might be invalid.
      syncImeWithDocumentAndSelection(TextRange.empty);
    } else if (!isAttachedToIme) {
      openIme(floatingCursorController);
    }
  }

  void updateImeConfig(TextInputConfiguration config) {
    _imeConnection?.updateConfig(config);
  }

  TextInputConfiguration _createInputConfiguration() {
    final imeConfig = imeConfiguration.value;

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

  void syncImeWithDocumentAndSelection([TextRange? newComposingRegion]) {
    if (imeClient!.isApplyingDeltas) {
      editorImeLog.fine("Tried to syncImeWithDocumentAndSelection() but we're applying deltas. Ignoring.");
      return;
    }

    if (selection != null) {
      editorImeLog.fine("Syncing IME with Doc and Composer, given composing region: $newComposingRegion");

      final newDocSerialization = DocumentImeSerializer(
        _document,
        selection!,
      );

      editorImeLog.fine("Previous doc serialization did prepend? ${_currentImeSerialization?.didPrependPlaceholder}");
      editorImeLog.fine("Desired composing region: $newComposingRegion");
      editorImeLog.fine("Did new doc prepend placeholder? ${newDocSerialization.didPrependPlaceholder}");
      TextRange composingRegion = newComposingRegion ?? imeClient!.currentTextEditingValue.composing;
      editorImeLog.fine("New composing region: $composingRegion");
      if (_currentImeSerialization != null &&
          _currentImeSerialization!.didPrependPlaceholder &&
          composingRegion.isValid &&
          !newDocSerialization.didPrependPlaceholder) {
        // The IME's desired composing region includes the prepended placeholder.
        // The updated IME value doesn't have a prepended placeholder, adjust
        // the composing region bounds.
        assert(composingRegion.start - 2 >= 0, "Invalid composing start index: ${composingRegion.start - 2}");
        assert(composingRegion.end - 2 >= 0, "Invalid composing end index: ${composingRegion.end - 2}");
        assert(composingRegion.end - 2 <= newDocSerialization.toTextEditingValue().text.length,
            "Invalid composing end index: ${composingRegion.end - 2}");
        composingRegion = TextRange(
          start: composingRegion.start - 2,
          end: composingRegion.end - 2,
        );
      }

      _currentImeSerialization = newDocSerialization;
      imeClient!.currentTextEditingValue =
          newDocSerialization.toTextEditingValue().copyWith(composing: composingRegion);
    }
  }

  void closeIme() {
    if (!isAttachedToIme) {
      return;
    }

    editorImeLog.info('Detaching TextInputClient from TextInput.');

    if (imeConfiguration.value.clearSelectionWhenImeDisconnects) {
      selection = null;
    }

    imeClient?.imeConnection = null;
    _imeConnection!.close();
    _imeConnection = null;

    if (clearSelectionWhenImeDisconnects) {
      selection = null;
    }
  }

  final ComposerPreferences _preferences;

  /// Returns the composition preferences for this composer.
  ComposerPreferences get preferences => _preferences;
}

/// Holds preferences about user input, to be used for the
/// next character that is entered. This facilitates things
/// like a "bold mode" or "italics mode" when there is no
/// bold or italics text around the caret.
class ComposerPreferences with ChangeNotifier {
  final Set<Attribution> _currentAttributions = {};

  /// Returns the styles that should be applied to the next
  /// character that is entered in a [Document].
  Set<Attribution> get currentAttributions => _currentAttributions;

  /// Adds [attribution] to [currentAttributions].
  void addStyle(Attribution attribution) {
    _currentAttributions.add(attribution);
    notifyListeners();
  }

  /// Adds all [attributions] to [currentAttributions].
  void addStyles(Set<Attribution> attributions) {
    _currentAttributions.addAll(attributions);
    notifyListeners();
  }

  /// Removes [attributions] from [currentAttributions].
  void removeStyle(Attribution attributions) {
    _currentAttributions.remove(attributions);
    notifyListeners();
  }

  /// Removes all [attributions] from [currentAttributions].
  void removeStyles(Set<Attribution> attributions) {
    _currentAttributions.removeAll(attributions);
    notifyListeners();
  }

  /// Adds or removes [attribution] to/from [currentAttributions] depending
  /// on whether [attribution] is already in [currentAttributions].
  void toggleStyle(Attribution attribution) {
    if (_currentAttributions.contains(attribution)) {
      _currentAttributions.remove(attribution);
    } else {
      _currentAttributions.add(attribution);
    }
    notifyListeners();
  }

  /// Adds or removes all [attributions] to/from [currentAttributions] depending
  /// on whether each attribution is already in [currentAttributions].
  void toggleStyles(Set<Attribution> attributions) {
    for (final attribution in attributions) {
      if (_currentAttributions.contains(attribution)) {
        _currentAttributions.remove(attribution);
      } else {
        _currentAttributions.add(attribution);
      }
    }
    notifyListeners();
  }

  /// Removes all styles from [currentAttributions].
  void clearStyles() {
    _currentAttributions.clear();
    notifyListeners();
  }
}

/// Represents a change of a [DocumentSelection].
///
/// The [reason] represents what cause the selection to change.
/// For example, [SelectionReason.userInteraction] represents
/// a selection change caused by the user interacting with the editor.
class DocumentSelectionChange {
  DocumentSelectionChange({
    this.selection,
    required this.reason,
  });

  final DocumentSelection? selection;
  final Object reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelectionChange && selection == other.selection && reason == other.reason;

  @override
  int get hashCode => (selection?.hashCode ?? 0) ^ reason.hashCode;
}

/// Holds common reasons for selection changes.
/// Developers aren't limited to these selection change reasons. Any object can be passed as
/// a reason for a selection change. However, some Super Editor behavior is based on [userInteraction].
class SelectionReason {
  /// Represents a change caused by an user interaction.
  static const userInteraction = "userInteraction";

  /// Represents a changed caused by an event which was not initiated by the user.
  static const contentChange = "contentChange";
}
