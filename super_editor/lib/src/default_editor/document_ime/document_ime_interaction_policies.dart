import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter_scheduler.dart';

/// Widget that watches a [FocusNode] and closes the [imeConnection] when
/// the [FocusNode] loses focus.
class ImeFocusPolicy extends StatefulWidget {
  const ImeFocusPolicy({
    Key? key,
    this.focusNode,
    this.closeImeOnFocusLost = true,
    required this.imeConnection,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode], which is watched for changes based
  /// on this widget's [closeImeOnFocusLost] policy.
  final FocusNode? focusNode;

  /// Whether to close the [imeConnection] when the [FocusNode] loses focus.
  ///
  /// Defaults to `true`.
  final bool closeImeOnFocusLost;

  /// The connection between this app and the platform Input Method Engine (IME).
  final ValueListenable<TextInputConnection?> imeConnection;

  final Widget child;

  @override
  State<ImeFocusPolicy> createState() => _ImeFocusPolicyState();
}

class _ImeFocusPolicyState extends State<ImeFocusPolicy> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ImeFocusPolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    editorImeLog.finer(
        "[${widget.runtimeType}] - onFocusChange(). Has focus: ${_focusNode.hasFocus}. Close IME policy enabled: ${widget.closeImeOnFocusLost}");
    if (!_focusNode.hasFocus && widget.closeImeOnFocusLost) {
      editorImeLog.info("[${widget.runtimeType}] - Document editor lost focus. Closing the IME connection.");
      widget.imeConnection.value?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that enforces policies between IME connections and document selections.
///
/// This widget can automatically open and close the software keyboard when the document
/// selection changes, such as when the user places the caret in the middle of a
/// paragraph.
///
/// This widget can automatically remove the document selection when the IME
/// connection closes.
class DocumentSelectionOpenAndCloseImePolicy extends StatefulWidget {
  const DocumentSelectionOpenAndCloseImePolicy({
    Key? key,
    required this.focusNode,
    this.isEnabled = true,
    required this.selection,
    required this.imeConnection,
    required this.imeClientFactory,
    required this.imeConfiguration,
    this.openKeyboardOnSelectionChange = true,
    this.closeKeyboardOnSelectionLost = true,
    this.clearSelectionWhenImeDisconnects = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode].
  ///
  /// When this widget closes the IME connection, it unfocuses this [focusNode].
  final FocusNode focusNode;

  /// Whether this widget's policies should be enabled.
  ///
  /// When `false`, this widget does nothing.
  final bool isEnabled;

  /// Notifies this widget of changes to a document's selection.
  final ValueNotifier<DocumentSelection?> selection;

  /// The current connection from this app to the platform IME.
  final ValueNotifier<TextInputConnection?> imeConnection;

  /// Factory method that creates a [TextInputClient], which is used to
  /// attach to the platform IME based on this widget's selection policy.
  final TextInputClient Function() imeClientFactory;

  /// The desired [TextInputConfiguration] for the IME connection, used
  /// when this widget attaches to the platform IME based on this widget's
  /// selection policy.
  final TextInputConfiguration imeConfiguration;

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

  final Widget child;

  @override
  State<DocumentSelectionOpenAndCloseImePolicy> createState() => _DocumentSelectionOpenAndCloseImePolicyState();
}

class _DocumentSelectionOpenAndCloseImePolicyState extends State<DocumentSelectionOpenAndCloseImePolicy> {
  bool _wasAttached = false;

  @override
  void initState() {
    super.initState();

    _wasAttached = widget.imeConnection.value?.attached ?? false;
    widget.imeConnection.addListener(_onConnectionChange);

    widget.selection.addListener(_onSelectionChange);
    if (widget.selection.value != null) {
      _onSelectionChange();
      _onConnectionChange();
    }
  }

  @override
  void didUpdateWidget(DocumentSelectionOpenAndCloseImePolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    }

    if (widget.imeConnection != oldWidget.imeConnection) {
      oldWidget.imeConnection.removeListener(_onConnectionChange);
      widget.imeConnection.addListener(_onConnectionChange);

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // We switched IME connection references, which means we may have switched
        // from one with a connection to one without a connection, or vis-a-versa.
        // Run our connection change check.
        //
        // Also, we run this at the end of the frame, because this call might clear
        // the document selection, which might cause other widgets in the tree
        // to call setState(), which would cause an exception during didUpdateWidget().
        _onConnectionChange();
      });
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);
    widget.imeConnection.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    editorImeLog.finer(
        "[${widget.runtimeType}] onSelectionChange() - widget enabled: ${widget.isEnabled}, open keyboard on selection enabled: ${widget.openKeyboardOnSelectionChange}, selection: ${widget.selection.value}");
    if (!widget.isEnabled) {
      return;
    }

    if (widget.selection.value != null && widget.openKeyboardOnSelectionChange) {
      // There's a new document selection, and our policy wants the keyboard to be
      // displayed whenever the selection changes. Show the keyboard.
      editorImeLog.info("[${widget.runtimeType}] - opening the IME keyboard because the document selection changed");

      if (widget.imeConnection.value == null || !widget.imeConnection.value!.attached) {
        WidgetsBinding.instance.runAsSoonAsPossible(() {
          if (!mounted) {
            return;
          }

          editorImeLog.finer("[${widget.runtimeType}] - creating new TextInputConnection to IME");
          widget.imeConnection.value = TextInput.attach(
            widget.imeClientFactory(),
            widget.imeConfiguration,
          )..show();
        }, debugLabel: 'Open IME Connection on Selection Change');
      } else {
        widget.imeConnection.value!.show();
      }
    } else if (widget.imeConnection.value != null &&
        widget.selection.value == null &&
        widget.closeKeyboardOnSelectionLost) {
      // There's no document selection, and our policy wants the keyboard to be
      // closed whenever the editor loses its selection. Close the keyboard.
      editorImeLog
          .info("[${widget.runtimeType}] - closing the IME keyboard because the document selection was cleared");
      widget.imeConnection.value!.close();
    }
  }

  void _onConnectionChange() {
    if (!mounted) {
      return;
    }

    editorImeLog.finer(
        "[${widget.runtimeType}] onConnectionChange() - widget enabled: ${widget.isEnabled}, clear selection when IME disconnects enabled: ${widget.clearSelectionWhenImeDisconnects}, new connection: ${widget.imeConnection.value}, was attached before: $_wasAttached");
    if (widget.isEnabled &&
        widget.clearSelectionWhenImeDisconnects &&
        _wasAttached &&
        !(widget.imeConnection.value?.attached ?? false)) {
      // The IME connection closed and our policy wants us to clear the document
      // selection when that happens.
      editorImeLog.info("[${widget.runtimeType}] - clearing document selection because the IME closed");
      widget.selection.value = null;

      // If we clear SuperEditor's selection, but leave SuperEditor focused, then
      // SuperEditor will automatically place the caret at the end of the document.
      // This is because SuperEditor always expects a place for text input when it
      // has focus. To prevent this from happening, we explicitly remove focus
      // from SuperEditor.
      widget.focusNode.unfocus();
    }

    _wasAttached = widget.imeConnection.value?.attached ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
