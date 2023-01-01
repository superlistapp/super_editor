import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'document_ime_communication.dart';

/// Widget that watches a [FocusNode] and instructs the client to [closeIme] when
/// the [FocusNode] loses focus.
class ImeFocusPolicy extends StatefulWidget {
  const ImeFocusPolicy({
    Key? key,
    this.focusNode,
    this.closeImeOnFocusLost = true,
    required this.closeIme,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  /// Whether to instruct the client to [closeIme] when the [FocusNode] loses
  /// focus.
  ///
  /// Defaults to `true`.
  final bool closeImeOnFocusLost;

  /// Callback that should close the IME connection.
  final VoidCallback closeIme;

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
    if (!_focusNode.hasFocus && widget.closeImeOnFocusLost) {
      editorImeLog.fine("Editor IME interactor lost focus. Closing the IME connection.");
      widget.closeIme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that enforces policies between IME connections and document selections.
///
/// This widget can automatically open the software keyboard when the document
/// selection changes, such as when the user places the caret in the middle of a
/// paragraph.
///
/// This widget can automatically remove the document selection when the IME
/// connection closes.
class DocumentSelectionOpenAndCloseImePolicy extends StatefulWidget {
  const DocumentSelectionOpenAndCloseImePolicy({
    Key? key,
    this.isEnabled = true,
    required this.focusNode,
    required this.selection,
    required this.imeConnectionController,
    this.openKeyboardOnSelectionChange = true,
    this.clearSelectionWhenImeDisconnects = true,
    required this.child,
  }) : super(key: key);

  /// Whether this widget's policies should be enabled.
  ///
  /// When `false`, this widget does nothing.
  final bool isEnabled;

  final FocusNode focusNode;

  /// Notifies this widget of changes to a document's selection.
  final ValueNotifier<DocumentSelection?> selection;

  /// Controls the document editor's connection to the platform's Input
  /// Method Engine (IME).
  final ImeConnection imeConnectionController;

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

    _wasAttached = widget.imeConnectionController.isAttached;
    widget.imeConnectionController.addListener(_onConnectionChange);

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

    if (widget.imeConnectionController != oldWidget.imeConnectionController) {
      oldWidget.imeConnectionController.removeListener(_onConnectionChange);
      widget.imeConnectionController.addListener(_onConnectionChange);

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // We switched IME controllers, which means we may have switched from
        // one with a connection to one without a connection, or vis-a-versa.
        // Run our connection change check.
        //
        // Also, we run this at the end of the frame, because we might clear
        // the document selection, which might cause other widgets in the tree
        // to call setState(), which would cause an exception during
        // didUpdateWidget().
        _onConnectionChange();
      });
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChange);
    widget.imeConnectionController.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    print("DocumentSelectionOpenAndCloseImePolicy onSelectionChange() - is policy enabled: ${widget.isEnabled}");
    if (!widget.isEnabled) {
      return;
    }

    print(
        " - selection: ${widget.selection.value}, should open automatically: ${widget.openKeyboardOnSelectionChange}");
    if (widget.selection.value != null && widget.openKeyboardOnSelectionChange) {
      // There's a new document selection, and our policy wants the keyboard to be
      // displayed whenever the selection changes. Show the keyboard.
      print(" - showing the IME because of selection policy");
      editorImeLog
          .fine("[DocumentImeAndSelectionPolicy] - opening the IME keyboard because the document selection changed");
      widget.imeConnectionController.show();
    }
  }

  void _onConnectionChange() {
    print("DocumentSelectionOpenAndCloseImePolicy onConnectionChange() - is policy enabled: ${widget.isEnabled}");
    if (!widget.isEnabled) {
      return;
    }

    print(
        " - was attached: $_wasAttached, is attached: ${widget.imeConnectionController.isAttached}, should clear selection: ${widget.clearSelectionWhenImeDisconnects}");
    if (_wasAttached && !widget.imeConnectionController.isAttached && widget.clearSelectionWhenImeDisconnects) {
      // The IME connection closed and our policy wants us to clear the document
      // selection when that happens.
      print(" - clearing document selection because of policy");
      editorImeLog.fine("[DocumentImeAndSelectionPolicy] - clearing document selection because the IME closed");
      widget.selection.value = null;

      // If we clear SuperEditor's selection, but leave SuperEditor focused, then
      // SuperEditor will automatically place the caret at the end of the document.
      // This is because SuperEditor always expects a place for text input when it
      // has focus. To prevent this from happening, we explicitly remove focus
      // from SuperEditor.
      widget.focusNode.unfocus();
    }

    _wasAttached = widget.imeConnectionController.isAttached;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
