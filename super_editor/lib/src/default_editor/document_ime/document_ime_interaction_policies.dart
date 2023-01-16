import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter_scheduler.dart';

/// Widget that opens and closes an [imeConnection] based on the [focusNode] gaining
/// and losing primary focus.
class ImeFocusPolicy extends StatefulWidget {
  const ImeFocusPolicy({
    Key? key,
    this.focusNode,
    required this.imeConnection,
    required this.imeClientFactory,
    required this.imeConfiguration,
    this.openImeOnPrimaryFocusGain = true,
    this.closeImeOnPrimaryFocusLost = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode], which is watched for changes based
  /// on this widget's [closeImeOnPrimaryFocusLost] policy.
  final FocusNode? focusNode;

  /// The connection between this app and the platform Input Method Engine (IME).
  final ValueNotifier<TextInputConnection?> imeConnection;

  /// Factory method that creates a [TextInputClient], which is used to
  /// attach to the platform IME based on this widget's policy.
  final TextInputClient Function() imeClientFactory;

  /// The desired [TextInputConfiguration] for the IME connection, used
  /// when this widget attaches to the platform IME based on this widget's
  /// policy.
  final TextInputConfiguration imeConfiguration;

  /// Whether to open an [imeConnection] when the [FocusNode] gains primary focus.
  ///
  /// Defaults to `true`.
  final bool openImeOnPrimaryFocusGain;

  /// Whether to close the [imeConnection] when the [FocusNode] loses primary focus.
  ///
  /// Defaults to `true`.
  final bool closeImeOnPrimaryFocusLost;

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
    if (_focusNode.hasPrimaryFocus &&
        widget.openImeOnPrimaryFocusGain &&
        (widget.imeConnection.value == null || !widget.imeConnection.value!.attached)) {
      editorPoliciesLog
          .info("[${widget.runtimeType}] - Document editor gained primary focus. Opening an IME connection.");
      WidgetsBinding.instance.runAsSoonAsPossible(() {
        if (!mounted) {
          return;
        }

        editorImeLog.finer("[${widget.runtimeType}] - creating new TextInputConnection to IME");
        widget.imeConnection.value = TextInput.attach(
          widget.imeClientFactory(),
          widget.imeConfiguration,
        )..show();
      }, debugLabel: 'Open IME Connection on Primary Focus Change');
    }

    if (!_focusNode.hasPrimaryFocus && widget.closeImeOnPrimaryFocusLost) {
      editorPoliciesLog
          .info("[${widget.runtimeType}] - Document editor lost primary focus. Closing the IME connection.");
      widget.imeConnection.value?.close();
      widget.imeConnection.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that enforces policies between IME connections, focus, and document selections.
///
/// This widget can automatically open and close the software keyboard when the document
/// selection changes, such as when the user places the caret in the middle of a
/// paragraph.
///
/// This widget can automatically remove the document selection when the editor loses focus.
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
    this.clearSelectionWhenEditorLosesFocus = true,
    this.clearSelectionWhenImeConnectionCloses = true,
    required this.child,
  }) : super(key: key);

  /// The document editor's [FocusNode].
  ///
  /// Focus plays a role in multiple policies:
  ///
  ///  * When focus is lost, this widget may clear the editor's selection.
  ///
  ///  * When this widget closes the IME connection, it unfocuses this [focusNode].
  final FocusNode focusNode;

  /// Whether this widget's policies should be enabled.
  ///
  /// When `false`, this widget does nothing.
  final bool isEnabled;

  /// The document editor's current selection.
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

  /// Whether the document's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

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

    widget.focusNode.addListener(_onFocusChange);

    widget.selection.addListener(_onSelectionChange);
    if (widget.selection.value != null) {
      _onSelectionChange();
      _onConnectionChange();
    }
  }

  @override
  void didUpdateWidget(DocumentSelectionOpenAndCloseImePolicy oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _onFocusChange();
    }

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
    widget.focusNode.removeListener(_onFocusChange);
    widget.selection.removeListener(_onSelectionChange);
    widget.imeConnection.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.isEnabled) {
      return;
    }

    if (!widget.focusNode.hasFocus && widget.clearSelectionWhenEditorLosesFocus) {
      editorPoliciesLog.info("[${widget.runtimeType}] - clearing editor selection because the editor lost all focus");
      widget.selection.value = null;
    }
  }

  void _onSelectionChange() {
    if (!widget.isEnabled) {
      return;
    }

    if (widget.selection.value != null && widget.focusNode.hasPrimaryFocus && widget.openKeyboardOnSelectionChange) {
      // There's a new document selection, and our policy wants the keyboard to be
      // displayed whenever the selection changes. Show the keyboard.
      if (widget.imeConnection.value == null || !widget.imeConnection.value!.attached) {
        WidgetsBinding.instance.runAsSoonAsPossible(() {
          if (!mounted) {
            return;
          }

          editorPoliciesLog
              .info("[${widget.runtimeType}] - opening the IME keyboard because the document selection changed");
          editorImeConnectionLog.finer("[${widget.runtimeType}] - creating new TextInputConnection to IME");
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
      editorPoliciesLog
          .info("[${widget.runtimeType}] - closing the IME keyboard because the document selection was cleared");
      widget.imeConnection.value!.close();
    }
  }

  void _onConnectionChange() {
    if (!mounted) {
      return;
    }

    _clearSelectionIfDesired();

    _wasAttached = widget.imeConnection.value?.attached ?? false;
  }

  void _clearSelectionIfDesired() {
    if (!widget.isEnabled) {
      // None of this widget's policies are activated.
      return;
    }

    if (!widget.clearSelectionWhenImeConnectionCloses) {
      // This policy isn't activated.
      return;
    }

    if (!_wasAttached || (widget.imeConnection.value?.attached ?? false)) {
      // We didn't go from closed to open. Our policy doesn't apply.

      return;
    }

    final hasNonPrimaryFocus = widget.focusNode.hasFocus && !widget.focusNode.hasPrimaryFocus;
    if (hasNonPrimaryFocus) {
      // We don't want to mess with selection when the editor has non-primary focus. Non-primary
      // focus means that the editor is in the focus path, but isn't receiving input. The editor
      // might currently be deferring to something like a URL toolbar, where the user is typing
      // a URL. The user expects the editor to keep its current selection while they type the URL.
      editorPoliciesLog.info(
          "[${widget.runtimeType}] - policy wants to clear selection because IME closed, but the editor has non-primary focus, so we aren't clearing the selection");
      return;
    }

    // The IME connection closed and our policy wants us to clear the document
    // selection when that happens.
    editorPoliciesLog.info(
        "[${widget.runtimeType}] - clearing document selection because the IME closed and the editor didn't have non-primary focus");
    widget.selection.value = null;

    // If we clear SuperEditor's selection, but leave SuperEditor with primary focus,
    // then SuperEditor will automatically place the caret at the end of the document.
    // This is because SuperEditor always expects a place for text input when it
    // has primary focus. To prevent this from happening, we explicitly remove focus
    // from SuperEditor.
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
