import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';

/// Governs document input that comes from a the operating systems
/// Input Method Engine (IME).
///
/// IME input is the only form of input that can come from a mobile
/// device's software keyboard. In a desktop environment with a
/// physical keyboard, developers can choose to respond to IME input
/// or individual key presses on the keyboard. For key press input,
/// see super_editor's keyboard input support.

/// Document interactor that changes a document based on IME input
/// from the operating system.
class DocumentImeInteractor extends StatefulWidget {
  const DocumentImeInteractor({
    Key? key,
    this.focusNode,
    required this.editContext,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;
  final EditContext editContext;
  final Widget child;

  @override
  _DocumentImeInteractorState createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor> {
  @override
  Widget build(BuildContext context) {
    return ErrorWidget("DocumentImeInteractor is not yet implemented!");
  }
}
